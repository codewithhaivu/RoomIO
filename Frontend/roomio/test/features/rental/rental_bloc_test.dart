import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roomio/core/resource/data_state.dart';
import 'package:roomio/features/rental/domain/entities/rental.dart';
import 'package:roomio/features/rental/presentation/bloc/remote/remote_rental_bloc.dart';
import 'package:roomio/features/rental/presentation/bloc/remote/remote_rental_event.dart';
import 'package:roomio/features/rental/presentation/bloc/remote/remote_rental_state.dart';
import 'rental_test_support.dart';

Future<void> dispatch(
  RemoteRentalBloc bloc,
  RemoteRentalEvent event,
  RemoteRentalStatus status,
) async {
  final done = bloc.stream.firstWhere((state) => state.requestStatus == status);
  bloc.add(event);
  await done;
}

void main() {
  late FakeRentalRepository repository;
  late RemoteRentalBloc bloc;
  late DateTime now;
  setUp(() {
    repository = FakeRentalRepository();
    now = DateTime.utc(2026, 10, 22, 9);
    bloc = rentalBloc(repository, now: () => now);
  });
  tearDown(() => bloc.close());

  test('both role-specific use cases load their domain data', () async {
    await dispatch(bloc, const GetMyTenantsEvent(), RemoteRentalStatus.loaded);
    expect(bloc.state.tenants, [tenant]);
    await dispatch(
      bloc,
      const GetCurrentRentRoomEvent(),
      RemoteRentalStatus.loaded,
    );
    expect(bloc.state.rooms, [rentedRoom]);
  });

  test(
    'QR TTL includes network delay, expires, and can be regenerated',
    () async {
      repository.creating = Completer<DataState<RentalResponse>>();
      final ready = bloc.stream.firstWhere(
        (state) => state.requestStatus == RemoteRentalStatus.codeReady,
      );
      bloc.add(const CreateRentalQRCodeEvent(roomId: 'room-id'));
      await Future<void>.delayed(Duration.zero);
      now = now.add(const Duration(seconds: 10));
      repository.creating!.complete(DataSuccess(repository.code));
      await ready;
      expect(bloc.state.remainingSeconds, 50);
      expect(repository.createdRoom, 'room-id');
      now = now.add(const Duration(seconds: 51));
      final expired = bloc.stream.firstWhere(
        (state) => state.remainingSeconds == 0,
      );
      bloc.add(const RentalQRCodeTickEvent());
      await expired;
      expect(bloc.state.hasActiveCode, isFalse);
      repository.creating = null;
      await dispatch(
        bloc,
        const CreateRentalQRCodeEvent(roomId: 'room-id'),
        RemoteRentalStatus.codeReady,
      );
      expect(bloc.state.hasActiveCode, isTrue);
      expect(bloc.state.remainingSeconds, 60);
    },
  );

  test(
    'delayed creation cannot display a code whose server TTL already passed',
    () async {
      repository.creating = Completer<DataState<RentalResponse>>();
      final ready = bloc.stream.firstWhere(
        (state) => state.requestStatus == RemoteRentalStatus.codeReady,
      );
      bloc.add(const CreateRentalQRCodeEvent(roomId: 'room-id'));
      await Future<void>.delayed(Duration.zero);
      now = now.add(const Duration(seconds: 65));
      repository.creating!.complete(DataSuccess(repository.code));
      await ready;
      expect(bloc.state.hasActiveCode, isFalse);
    },
  );

  test(
    'verification forwards exact code and preserves false instead of assuming success',
    () async {
      repository.verification = const RentalVerifyResponse(
        message: 'Invalid code',
        isValid: false,
      );
      await dispatch(
        bloc,
        const VerifyRentalQRCodeEvent(
          request: RentalVerifyRequest(token: '012345'),
        ),
        RemoteRentalStatus.verified,
      );
      expect(repository.verifiedRequest!.token, '012345');
      expect(bloc.state.verification!.isValid, isFalse);
    },
  );

  test('duplicate confirmation is sent only once', () async {
    repository.verifying = Completer<DataState<RentalVerifyResponse>>();
    final done = bloc.stream.firstWhere(
      (state) => state.requestStatus == RemoteRentalStatus.verified,
    );
    const event = VerifyRentalQRCodeEvent(
      request: RentalVerifyRequest(token: '012345'),
    );
    bloc.add(event);
    bloc.add(event);
    await Future<void>.delayed(Duration.zero);
    expect(repository.verifyCalls, 1);
    repository.verifying!.complete(DataSuccess(repository.verification));
    await done;
  });

  test(
    'destroy removes the correct relation locally and never refetches',
    () async {
      await dispatch(
        bloc,
        const GetMyTenantsEvent(),
        RemoteRentalStatus.loaded,
      );
      final before = bloc.state;
      await dispatch(
        bloc,
        const DestroyRentalRelationEvent(rentalRelationId: 'rental-id'),
        RemoteRentalStatus.ended,
      );
      expect(repository.destroyedId, 'rental-id');
      expect(repository.listCalls, 1);
      expect(bloc.state.tenants, isEmpty);
      expect(before.tenants, [tenant]);
    },
  );

  test('failed destroy keeps the list available for retry', () async {
    await dispatch(bloc, const GetMyTenantsEvent(), RemoteRentalStatus.loaded);
    repository.error = DioException(
      requestOptions: RequestOptions(),
      type: DioExceptionType.connectionError,
    );
    await dispatch(
      bloc,
      const DestroyRentalRelationEvent(rentalRelationId: 'rental-id'),
      RemoteRentalStatus.failure,
    );
    expect(bloc.state.tenants, [tenant]);
    repository.error = null;
    await dispatch(
      bloc,
      const DestroyRentalRelationEvent(rentalRelationId: 'rental-id'),
      RemoteRentalStatus.ended,
    );
    expect(bloc.state.tenants, isEmpty);
  });

  test('stale GET cannot overwrite the newer list', () async {
    final old = Completer<DataState<List<TenantRentalResponse>>>();
    final latest = Completer<DataState<List<TenantRentalResponse>>>();
    repository.loads.addAll([old, latest]);
    bloc.add(const GetMyTenantsEvent());
    await Future<void>.delayed(Duration.zero);
    final loaded = bloc.stream.firstWhere(
      (state) => state.requestStatus == RemoteRentalStatus.loaded,
    );
    bloc.add(const GetMyTenantsEvent());
    await Future<void>.delayed(Duration.zero);
    latest.complete(const DataSuccess([]));
    await loaded;
    old.complete(DataSuccess([tenant]));
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state.tenants, isEmpty);
  });
}
