import 'package:flutter_test/flutter_test.dart';
import 'package:roomio/injection_container.dart';
import 'package:roomio/features/room/data/data_sources/remote/room_api_service.dart';
import 'package:roomio/features/room/data/repository/room_repository_impl.dart';
import 'package:roomio/features/room/domain/repository/room_repository.dart';
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
import 'package:roomio/features/room/presentation/bloc/remote/tenant/remote_tenant_room_bloc.dart';
import 'package:roomio/features/room/presentation/bloc/remote/detail/remote_room_detail_bloc.dart';

void main() {
  test(
    'DI resolves room data layer, all use cases and independent Bloc factories',
    () async {
      await sl.reset();
      addTearDown(() => sl.reset());
      await initializeDependencies();
      expect(sl<RoomApiService>(), same(sl<RoomApiService>()));
      expect(sl<RoomRepository>(), isA<RoomRepositoryImpl>());
      expect(sl<RoomRepository>(), same(sl<RoomRepository>()));
      expect(sl<PostRoomUseCase>(), same(sl<PostRoomUseCase>()));
      expect(
        sl<UploadRoomImagesUseCase>(),
        same(sl<UploadRoomImagesUseCase>()),
      );
      expect(sl<GetListRoomUseCase>(), same(sl<GetListRoomUseCase>()));
      expect(sl<UpdateRoomUseCase>(), same(sl<UpdateRoomUseCase>()));
      expect(
        sl<UpdateStatusRoomUseCase>(),
        same(sl<UpdateStatusRoomUseCase>()),
      );
      expect(sl<GetDetailRoomUseCase>(), same(sl<GetDetailRoomUseCase>()));
      expect(
        sl<GetLocationSuggestionsUseCase>(),
        same(sl<GetLocationSuggestionsUseCase>()),
      );
      expect(
        sl<SearchRoomByPositionUseCase>(),
        same(sl<SearchRoomByPositionUseCase>()),
      );
      expect(
        sl<SearchRoomsByAreaUseCase>(),
        same(sl<SearchRoomsByAreaUseCase>()),
      );
      final landlord = sl<RemoteLandlordRoomBloc>();
      final otherLandlord = sl<RemoteLandlordRoomBloc>();
      final tenant = sl<RemoteTenantRoomBloc>();
      final otherTenant = sl<RemoteTenantRoomBloc>();
      final detail = sl<RemoteRoomDetailBloc>();
      final otherDetail = sl<RemoteRoomDetailBloc>();
      expect(landlord, isNot(same(otherLandlord)));
      expect(tenant, isNot(same(otherTenant)));
      expect(detail, isNot(same(otherDetail)));
      await Future.wait([
        landlord.close(),
        otherLandlord.close(),
        tenant.close(),
        otherTenant.close(),
        detail.close(),
        otherDetail.close(),
      ]);
    },
  );
}
