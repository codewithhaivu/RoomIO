import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roomio/features/room/domain/entities/room_request_entities.dart';
import 'package:roomio/features/room/domain/usecases/landlord/post_room.dart';
import 'package:roomio/features/room/domain/usecases/landlord/upload_images.dart';
import 'package:roomio/features/room/domain/usecases/landlord/get_list_room.dart';
import 'package:roomio/features/room/domain/usecases/landlord/update_room.dart';
import 'package:roomio/features/room/domain/usecases/landlord/update_status_room.dart';
import 'package:roomio/features/room/domain/usecases/get_detail_room.dart';
import 'package:roomio/features/room/domain/usecases/tenant/search_room_by_position.dart';
import 'package:roomio/features/room/domain/usecases/tenant/search_rooms_by_area.dart';
import 'package:roomio/features/room/domain/usecases/tenant/get_location_suggestions.dart';
import 'package:roomio/features/room/presentation/bloc/remote/landlord/remote_landlord_room_bloc.dart';
import 'package:roomio/features/room/presentation/bloc/remote/landlord/remote_landlord_room_event.dart';
import 'package:roomio/features/room/presentation/bloc/remote/landlord/remote_landlord_room_state.dart';
import 'package:roomio/features/room/presentation/bloc/remote/tenant/remote_tenant_room_bloc.dart';
import 'package:roomio/features/room/presentation/bloc/remote/tenant/remote_tenant_room_event.dart';
import 'package:roomio/features/room/presentation/bloc/remote/tenant/remote_tenant_room_state.dart';
import 'package:roomio/features/room/presentation/bloc/remote/detail/remote_room_detail_bloc.dart';
import 'package:roomio/features/room/presentation/bloc/remote/detail/remote_room_detail_event.dart';
import 'package:roomio/features/room/presentation/bloc/remote/detail/remote_room_detail_state.dart';
import 'room_test_support.dart';
import 'room_location_test_support.dart';
import 'package:roomio/features/room/domain/usecases/tenant/get_current_room_location.dart';
import 'package:roomio/features/room/domain/usecases/tenant/search_room_locations.dart';
import 'package:roomio/features/room/domain/usecases/tenant/open_room_location_settings.dart';

Future<void> dispatch<E, S>(
  Bloc<E, S> bloc,
  E event,
  List<dynamic> states,
) async {
  final expectation = expectLater(bloc.stream, emitsInOrder(states));
  bloc.add(event);
  await expectation;
}

void main() {
  late RoomTestApi api;
  late RemoteLandlordRoomBloc landlord;
  late RemoteTenantRoomBloc tenant;
  late RemoteRoomDetailBloc detail;

  setUp(() {
    api = RoomTestApi();
    final repository = api.repository;
    landlord = RemoteLandlordRoomBloc(
      PostRoomUseCase(repository),
      UploadRoomImagesUseCase(repository),
      GetListRoomUseCase(repository),
      UpdateRoomUseCase(repository),
      UpdateStatusRoomUseCase(repository),
    );
    tenant = RemoteTenantRoomBloc(
      SearchRoomByPositionUseCase(repository),
      SearchRoomsByAreaUseCase(repository),
      GetCurrentRoomLocationUseCase(FakeRoomLocationRepository()),
      SearchRoomLocationsUseCase(FakeRoomLocationRepository()),
      OpenRoomLocationSettingsUseCase(FakeRoomLocationRepository()),
      GetLocationSuggestionsUseCase(repository),
    );
    detail = RemoteRoomDetailBloc(GetDetailRoomUseCase(repository));
    api.responseFor = (options) => switch (options.path) {
      '/images/upload' => {
        'response': [imageJson],
      },
      '/me' => {
        'rooms': [roomJson],
      },
      '/nearby/position' || '/nearby/district' => {
        'rooms': [nearbyJson],
      },
      '/room-id/RENTED' => {'Message': 'Updated'},
      '/room-id' => detailJson,
      _ => roomJson,
    };
  });

  tearDown(() async {
    await landlord.close();
    await tenant.close();
    await detail.close();
    api.dispose();
  });

  test(
    'post event uploads first and passes returned images to postRoom',
    () async {
      await dispatch(
        landlord,
        PostRoomEvent(
          request: postRequest,
          uploadRequest: UploadRoomImagesRequestEntity(
            images: [api.imageFile],
            isThumbnails: [true],
          ),
        ),
        [const RemoteLandlordRoomLoading(), isA<RemotePostRoomSuccess>()],
      );
      expect(api.requests.map((request) => request.uri.path), [
        '/rooms/images/upload',
        '/rooms',
      ]);
      expect(api.requests.last.data['images'], [imageJson, imageJson]);
      expect((landlord.state as RemotePostRoomSuccess).room.id, 'room-id');
    },
  );

  test(
    'update uploads new images before patch and preserves existing images',
    () async {
      await dispatch(
        landlord,
        UpdateRoomEvent(
          request: const UpdateRoomRequestEntity(
            roomId: 'room-id',
            images: [image],
            name: 'Updated room',
          ),
          uploadRequest: UploadRoomImagesRequestEntity(
            images: [api.imageFile],
            isThumbnails: [false],
          ),
        ),
        [const RemoteLandlordRoomLoading(), isA<RemoteUpdateRoomSuccess>()],
      );
      expect(api.requests.map((request) => request.path), [
        '/images/upload',
        '/room-id',
      ]);
      expect(api.requests.last.method, 'PATCH');
      expect(api.requests.last.data['name'], 'Updated room');
      expect(api.requests.last.data['images'], [imageJson, imageJson]);
    },
  );

  test('update stops before patch when uploading fails', () async {
    final error = DioException(
      requestOptions: RequestOptions(path: '/images/upload'),
    );
    api.error = error;
    await dispatch(
      landlord,
      UpdateRoomEvent(
        request: const UpdateRoomRequestEntity(
          roomId: 'room-id',
          images: [image],
        ),
        uploadRequest: UploadRoomImagesRequestEntity(
          images: [api.imageFile],
          isThumbnails: [true],
        ),
      ),
      [
        const RemoteLandlordRoomLoading(),
        RemoteLandlordRoomFailure(dio: error),
      ],
    );
    expect(api.requests.map((request) => request.path), ['/images/upload']);
  });

  test('failed upload stops the post event before creating a room', () async {
    final error = DioException(
      requestOptions: RequestOptions(path: '/images/upload'),
    );
    api.error = error;
    await dispatch(
      landlord,
      PostRoomEvent(
        request: postRequest,
        uploadRequest: UploadRoomImagesRequestEntity(
          images: [api.imageFile],
          isThumbnails: [true],
        ),
      ),
      [
        const RemoteLandlordRoomLoading(),
        RemoteLandlordRoomFailure(dio: error),
      ],
    );
    expect(api.requests.map((request) => request.path), ['/images/upload']);
  });

  test(
    'landlord events cover existing images, standalone upload, listing, patch and status',
    () async {
      await dispatch(landlord, const PostRoomEvent(request: postRequest), [
        const RemoteLandlordRoomLoading(),
        isA<RemotePostRoomSuccess>(),
      ]);
      expect(api.requests.single.data['images'], [imageJson]);

      await dispatch(
        landlord,
        UploadRoomImagesEvent(
          request: UploadRoomImagesRequestEntity(
            images: [api.imageFile],
            isThumbnails: [true],
          ),
        ),
        [
          const RemoteLandlordRoomLoading(),
          isA<RemoteUploadRoomImagesSuccess>().having(
            (state) => state.images.single.props,
            'uploaded image fields',
            image.props,
          ),
        ],
      );

      await dispatch(landlord, const GetListRoomEvent(), [
        const RemoteLandlordRoomLoading(),
        isA<RemoteGetListRoomSuccess>(),
      ]);
      expect(
        (landlord.state as RemoteGetListRoomSuccess).rooms.single.id,
        'room-id',
      );

      await dispatch(
        landlord,
        const UpdateRoomEvent(
          request: UpdateRoomRequestEntity(
            roomId: 'room-id',
            rentalPrice: 5000000,
          ),
        ),
        [const RemoteLandlordRoomLoading(), isA<RemoteUpdateRoomSuccess>()],
      );
      expect(api.requests.last.data, {'rental_price': 5000000.0});

      await dispatch(
        landlord,
        const UpdateStatusRoomEvent(roomId: 'room-id', status: 'RENTED'),
        [
          const RemoteLandlordRoomLoading(),
          const RemoteUpdateStatusRoomSuccess(message: 'Updated'),
        ],
      );
    },
  );

  test(
    'tenant searches forward both request types and district default radius',
    () async {
      await dispatch(
        tenant,
        const SearchRoomByPositionEvent(
          request: SearchRoomByPositionRequestEntity(
            latitude: 10.8,
            longitude: 106.7,
            radius: 5,
          ),
        ),
        [const RemoteTenantRoomLoading(), isA<RemoteSearchRoomsSuccess>()],
      );
      expect(api.requests.last.queryParameters['radius'], 5);
      expect(
        (tenant.state as RemoteSearchRoomsSuccess).rooms.single.distance,
        1.5,
      );

      await dispatch(
        tenant,
        const SearchRoomsByAreaEvent(
          request: SearchRoomsByAreaRequestEntity(
            locationId: 'location-id',
            district: 'Thu Duc',
          ),
        ),
        [const RemoteTenantRoomLoading(), isA<RemoteSearchRoomsSuccess>()],
      );
      expect(api.requests.last.queryParameters, {
        'location_id': 'location-id',
        'district': 'Thu Duc',
        'radius': 10.0,
      });
    },
  );

  test('detail event emits detail with landlord', () async {
    await dispatch(detail, const GetDetailRoomEvent(roomId: 'room-id'), [
      const RemoteRoomDetailLoading(),
      isA<RemoteRoomDetailSuccess>(),
    ]);
    final state = detail.state as RemoteRoomDetailSuccess;
    expect(state.roomDetail.room.id, 'room-id');
    expect(state.roomDetail.landlord.fullName, 'Landlord');
  });

  test('every event emits failure with the repository DioException', () async {
    final error = DioException(requestOptions: RequestOptions(path: '/rooms'));
    api.error = error;
    final landlordEvents = <RemoteLandlordRoomEvent>[
      const PostRoomEvent(request: postRequest),
      UploadRoomImagesEvent(
        request: UploadRoomImagesRequestEntity(
          images: [api.imageFile],
          isThumbnails: [true],
        ),
      ),
      const GetListRoomEvent(),
      const UpdateRoomEvent(
        request: UpdateRoomRequestEntity(roomId: 'room-id'),
      ),
      const UpdateStatusRoomEvent(roomId: 'room-id', status: 'RENTED'),
    ];
    for (final event in landlordEvents) {
      await dispatch(landlord, event, [
        const RemoteLandlordRoomLoading(),
        RemoteLandlordRoomFailure(dio: error),
      ]);
    }
    for (final event in <RemoteTenantRoomEvent>[
      const SearchRoomByPositionEvent(
        request: SearchRoomByPositionRequestEntity(
          latitude: 10.8,
          longitude: 106.7,
          radius: 5,
        ),
      ),
      const SearchRoomsByAreaEvent(
        request: SearchRoomsByAreaRequestEntity(
          locationId: 'location-id',
          district: 'Thu Duc',
        ),
      ),
    ]) {
      await dispatch(tenant, event, [
        const RemoteTenantRoomLoading(),
        RemoteTenantRoomFailure(dio: error),
      ]);
    }
    await dispatch(detail, const GetDetailRoomEvent(roomId: 'room-id'), [
      const RemoteRoomDetailLoading(),
      RemoteRoomDetailFailure(dio: error),
    ]);
  });
}
