import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roomio/config/route/app_route.dart';
import 'package:roomio/features/chat/domain/repository/chat_repository.dart';
import 'package:roomio/features/chat/presentation/pages/chat_page.dart';
import 'package:roomio/features/chat/presentation/widgets/contact_landlord_button.dart';
import 'package:roomio/injection_container.dart';
import 'chat_test_support.dart';
import '../room/room_test_support.dart' show detailJson;
import 'package:roomio/features/room/data/models/room_detail_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeChatRepository repository;
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({
      'role': 'CUSTOMER',
      'access_token': sessionToken('tenant-id'),
    });
    await sl.reset();
    await initializeDependencies();
    repository = FakeChatRepository();
    await sl.unregister<ChatRepository>();
    sl.registerSingleton<ChatRepository>(repository);
  });
  tearDown(() async {
    await sl.reset();
    await repository.events.close();
  });

  Future<void> launch(
    WidgetTester tester, {
    String? route,
    Object? arguments,
    Widget? home,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: AppRoutes.onGenerateRoute,
        home:
            home ??
            Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.pushNamed(
                    context,
                    route!,
                    arguments: arguments,
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
      ),
    );
    if (route != null) await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  test('room details decode account ID and tolerate the current response', () {
    final data = detailJson;
    expect(RoomDetailModel.fromJson(data).landlord.accountId, isNull);
    data['landlord']['account_id'] = 'landlord-id';
    expect(RoomDetailModel.fromJson(data).landlord.accountId, 'landlord-id');
  });

  test(
    'room details accept id_account and prefer account_id when both exist',
    () {
      final data = detailJson;
      data['landlord']['id_account'] = 'landlord-id';
      expect(RoomDetailModel.fromJson(data).landlord.accountId, 'landlord-id');
      data['landlord']['account_id'] = 'canonical-account-id';
      expect(
        RoomDetailModel.fromJson(data).landlord.accountId,
        'canonical-account-id',
      );
    },
  );

  Future<void> roomApi({
    required bool withAccountId,
    String accountKey = 'account_id',
  }) async {
    final data = detailJson;
    if (withAccountId) data['landlord'][accountKey] = 'landlord-id';
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              statusCode: 200,
              data: data,
            ),
          );
        },
      ),
    );
    await sl.unregister<Dio>();
    sl.registerSingleton<Dio>(dio);
    addTearDown(() => dio.close(force: true));
  }

  testWidgets('room detail contacts the landlord using the account ID', (
    tester,
  ) async {
    await roomApi(withAccountId: true);
    await launch(tester, route: AppRoutes.roomDetail, arguments: 'room-id');
    final button = find.byType(ContactLandlordButton);
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    expect(
      tester.widget<ContactLandlordButton>(button).landlordAccountId,
      'landlord-id',
    );
    await tester.tap(find.text('Liên hệ chủ trọ'));
    await tester.pumpAndSettle();
    expect(find.byType(ChatPage), findsOneWidget);
    expect(
      tester.widget<ChatPage>(find.byType(ChatPage)).conversation.targetUserId,
      'landlord-id',
    );
    expect(repository.sent, isEmpty);
  });

  testWidgets('room detail without account ID does not send to a guessed ID', (
    tester,
  ) async {
    await roomApi(withAccountId: false);
    await launch(tester, route: AppRoutes.roomDetail, arguments: 'room-id');
    expect(find.byType(ContactLandlordButton), findsNothing);
    expect(find.text('Chưa có thông tin liên hệ của chủ trọ.'), findsOneWidget);
    expect(repository.historyCalls, 0);
    expect(repository.sent, isEmpty);
  });

  testWidgets('room detail also opens chat with id_account response', (
    tester,
  ) async {
    await roomApi(withAccountId: true, accountKey: 'id_account');
    await launch(tester, route: AppRoutes.roomDetail, arguments: 'room-id');
    final button = find.byType(ContactLandlordButton);
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Liên hệ chủ trọ'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<ChatPage>(find.byType(ChatPage)).conversation.targetUserId,
      'landlord-id',
    );
    expect(repository.sent, isEmpty);
  });

  testWidgets('inbox lists message-bearing conversations and opens chat', (
    tester,
  ) async {
    repository.conversations = [
      conversation(),
      conversation(target: 'empty', text: ' '),
    ];
    await launch(tester, route: AppRoutes.chatList);
    expect(find.text('Chủ trọ An'), findsOneWidget);
    expect(find.byType(ListTile), findsOneWidget);
    expect(find.byType(ContactLandlordButton), findsNothing);
    await tester.tap(find.byType(ListTile));
    await tester.pumpAndSettle();
    expect(find.byType(ChatPage), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(repository.sent, isEmpty);
  });

  testWidgets('empty ChatPage has no first-contact button or composer', (
    tester,
  ) async {
    repository.history = [];
    final bloc = chatBloc(repository);
    await launch(
      tester,
      home: BlocProvider.value(
        value: bloc,
        child: ChatPage(conversation: conversation(), session: tenant),
      ),
    );
    expect(find.byType(ContactLandlordButton), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(find.textContaining('Chưa có tin nhắn'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    addTearDown(bloc.close);
  });

  testWidgets(
    'socket and REST send scroll to latest and failures preserve draft',
    (tester) async {
      repository.history = List.generate(
        40,
        (i) => message(
          id: 'history-$i',
          content: 'Tin nhắn lịch sử $i',
          minute: i,
        ),
      );
      final bloc = chatBloc(repository);
      await launch(
        tester,
        home: BlocProvider.value(
          value: bloc,
          child: ChatPage(conversation: conversation(), session: tenant),
        ),
      );
      final listFinder = find.byKey(const Key('chat_messages'));
      await tester.drag(listFinder, const Offset(0, 500));
      await tester.pumpAndSettle();
      final controller = tester.widget<ListView>(listFinder).controller!;
      expect(controller.offset, greaterThan(0));
      repository.events.add(
        Right(
          message(
            id: 'live',
            sender: 'landlord-id',
            receiver: 'tenant-id',
            content: 'Tin nhắn mới nhất',
            minute: 50,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(controller.offset, closeTo(0, .1));
      expect(find.text('Tin nhắn mới nhất'), findsOneWidget);

      repository.sendValid = false;
      await tester.enterText(find.byType(TextField), 'Giữ bản nháp này');
      await tester.tap(find.byTooltip('Gửi tin nhắn'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Giữ bản nháp này',
      );
      repository.sendValid = true;
      await tester.drag(listFinder, const Offset(0, 500));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Gửi tin nhắn'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      expect(controller.offset, closeTo(0, .1));
      await tester.pumpWidget(const SizedBox.shrink());
      addTearDown(bloc.close);
    },
  );

  testWidgets(
    'contact existing conversation opens without first-message dialog',
    (tester) async {
      await launch(
        tester,
        home: const Scaffold(
          body: ContactLandlordButton(
            landlordAccountId: 'landlord-id',
            landlordName: 'Chủ trọ An',
          ),
        ),
      );
      await tester.tap(find.text('Liên hệ chủ trọ'));
      await tester.pumpAndSettle();
      expect(find.byType(ChatPage), findsOneWidget);
      expect(repository.sent, isEmpty);
    },
  );

  testWidgets(
    'contact requires explicit content and creates through REST before navigation',
    (tester) async {
      repository.history = [];
      await launch(
        tester,
        home: const Scaffold(
          body: ContactLandlordButton(
            landlordAccountId: 'landlord-id',
            landlordName: 'Chủ trọ An',
          ),
        ),
      );
      await tester.tap(find.text('Liên hệ chủ trọ'));
      await tester.pumpAndSettle();
      expect(find.byType(ChatPage), findsNothing);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(repository.sent, isEmpty);
      await tester.enterText(find.byType(TextField), 'Tôi muốn xem phòng');
      repository.sendValid = false;
      await tester.tap(find.text('Gửi và mở hội thoại'));
      await tester.pumpAndSettle();
      expect(find.byType(ChatPage), findsNothing);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Tôi muốn xem phòng',
      );
      repository.sendValid = true;
      await tester.tap(find.text('Gửi và mở hội thoại'));
      await tester.pumpAndSettle();
      expect(find.byType(ChatPage), findsOneWidget);
      expect(repository.sent.last.content, 'Tôi muốn xem phòng');
    },
  );

  testWidgets('landlord has no contact button', (tester) async {
    FlutterSecureStorage.setMockInitialValues({
      'role': 'LANDLORD',
      'access_token': sessionToken('landlord-id'),
    });
    await launch(
      tester,
      home: const Scaffold(
        body: ContactLandlordButton(
          landlordAccountId: 'another-owner',
          landlordName: 'Chủ trọ khác',
        ),
      ),
    );
    expect(find.text('Liên hệ chủ trọ'), findsNothing);
    expect(repository.historyCalls, 0);
  });

  testWidgets('unknown role cannot access chat routes', (tester) async {
    FlutterSecureStorage.setMockInitialValues({
      'role': 'STAFF',
      'access_token': sessionToken('staff-id'),
    });
    await launch(tester, route: AppRoutes.chatList);
    expect(find.text('Vui lòng đăng nhập lại để mở tin nhắn.'), findsOneWidget);
    expect(repository.listCalls, 0);
  });

  testWidgets('narrow layout with larger text fits without overflow', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 700);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final bloc = chatBloc(repository);
    await launch(
      tester,
      home: MediaQuery(
        data: const MediaQueryData(
          size: Size(320, 700),
          textScaler: TextScaler.linear(1.5),
        ),
        child: BlocProvider.value(
          value: bloc,
          child: ChatPage(conversation: conversation(), session: tenant),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    addTearDown(bloc.close);
  });
}
