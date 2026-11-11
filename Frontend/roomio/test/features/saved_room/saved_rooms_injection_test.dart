import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roomio/core/storage/secure_storage_service.dart';
import 'package:roomio/features/saved_room/data/data_sources/remote/save_room_api_service.dart';
import 'package:roomio/features/saved_room/data/repository/save_room_repository_impl.dart';
import 'package:roomio/features/saved_room/domain/repository/save_room_repository.dart';
import 'package:roomio/features/saved_room/domain/usecases/get_saved_rooms.dart';
import 'package:roomio/features/saved_room/domain/usecases/save_room.dart';
import 'package:roomio/features/saved_room/domain/usecases/unsave_room.dart';
import 'package:roomio/features/saved_room/presentation/cubit/saved_rooms_cubit.dart';
import 'package:roomio/features/saved_room/presentation/cubit/saved_rooms_state.dart';
import 'package:roomio/injection_container.dart';
import 'saved_room_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    await sl.reset();
    await initializeDependencies();
  });
  tearDown(() => sl.reset());

  test(
    'DI resolves all layers and one shared Cubit per application session',
    () {
      expect(sl<SavedRoomApiService>(), same(sl<SavedRoomApiService>()));
      expect(sl<SaveRoomRepository>(), isA<SaveRoomRepositoryImpl>());
      expect(sl<GetSavedRoomsUseCase>(), same(sl<GetSavedRoomsUseCase>()));
      expect(sl<SaveRoomUseCase>(), same(sl<SaveRoomUseCase>()));
      expect(sl<UnsaveRoomUseCase>(), same(sl<UnsaveRoomUseCase>()));
      expect(sl<SavedRoomsCubit>(), same(sl<SavedRoomsCubit>()));
    },
  );

  test(
    'new login and logout clear favorites; token refresh preserves them',
    () async {
      await sl.unregister<SaveRoomRepository>();
      sl.registerSingleton<SaveRoomRepository>(FakeSaveRoomRepository());
      final cubit = sl<SavedRoomsCubit>();
      final storage = sl<SecureStorageService>();
      await cubit.toggle(room, isSaved: false);
      await storage.saveAccessToken('refreshed-same-account');
      expect(cubit.state.rooms, [room]);
      await storage.saveTokens(
        accessToken: 'new-account',
        rfToken: 'refresh',
        role: 'CUSTOMER',
      );
      expect(cubit.state, const SavedRoomsState());
      await cubit.toggle(room, isSaved: false);
      await storage.clearAll();
      expect(cubit.state, const SavedRoomsState());
      expect(await storage.getAccessToken(), isNull);
    },
  );
}
