import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:roomio/config/route/push_notification_navigator.dart';
import 'package:roomio/core/firebase/fcm_service.dart';
import 'package:roomio/features/notification/application/notification_device_sync.dart';
import 'package:roomio/features/notification/data/data_sources/remote/device_api_service.dart';
import 'package:roomio/features/notification/data/data_sources/remote/notification_api_service.dart';
import 'package:roomio/features/notification/data/repository/notification_repository_impl.dart';
import 'package:roomio/features/notification/domain/repository/notification_repository.dart';
import 'package:roomio/features/notification/domain/usecases/get_notifications.dart';
import 'package:roomio/features/notification/domain/usecases/mark_notification_read.dart';
import 'package:roomio/features/notification/domain/usecases/register_device.dart';
import 'package:roomio/features/notification/domain/usecases/unregister_device.dart';
import 'package:roomio/features/notification/domain/usecases/update_device.dart';
import 'package:roomio/features/notification/presentation/bloc/notification_bloc.dart';
import 'package:roomio/features/chat/data/data_sources/remote/chat_api_service.dart';
import 'package:roomio/features/chat/data/data_sources/remote/chat_websocket_service.dart';
import 'package:roomio/features/chat/data/repository/chat_repository_impl.dart';
import 'package:roomio/features/chat/domain/entities/chat.dart';
import 'package:roomio/features/chat/domain/repository/chat_repository.dart';
import 'package:roomio/features/chat/domain/usecases/contact_landlord_usecase.dart';
import 'package:roomio/features/chat/domain/usecases/get_conversations_usecase.dart';
import 'package:roomio/features/chat/domain/usecases/get_messages_usecase.dart';
import 'package:roomio/features/chat/domain/usecases/listen_to_messages_usecase.dart';
import 'package:roomio/features/chat/domain/usecases/send_message_usecase.dart';
import 'package:roomio/features/chat/presentation/bloc/chat_bloc.dart';
import 'package:roomio/features/rental/data/data_sources/remote/rental_api_service.dart';
import 'package:roomio/features/rental/data/repository/rental_repository_impl.dart';
import 'package:roomio/features/rental/domain/repository/rental_repository.dart';
import 'package:roomio/features/rental/domain/usecases/create_qr_code.dart';
import 'package:roomio/features/rental/domain/usecases/verify_qr_code.dart';
import 'package:roomio/features/rental/domain/usecases/destroy_relation.dart';
import 'package:roomio/features/rental/domain/usecases/get_my_tenants.dart';
import 'package:roomio/features/rental/domain/usecases/get_current_rent_room.dart';
import 'package:roomio/features/rental/presentation/bloc/remote/remote_rental_bloc.dart';
import 'package:roomio/features/appointment/data/data_sources/remote/appointment_api_service.dart';
import 'package:roomio/features/appointment/data/repository/appointment_repository_impl.dart';
import 'package:roomio/features/appointment/domain/repository/appointment_repository.dart';
import 'package:roomio/features/appointment/domain/usecases/send_appointment.dart';
import 'package:roomio/features/appointment/domain/usecases/get_all_appointments.dart';
import 'package:roomio/features/appointment/domain/usecases/confirm_appointment.dart';
import 'package:roomio/features/appointment/domain/usecases/destroy_appointment.dart';
import 'package:roomio/features/appointment/domain/usecases/update_appointment.dart';
import 'package:roomio/features/appointment/presentation/bloc/remote/remote_appointment_bloc.dart';
import 'package:roomio/core/network/app_interceptor.dart';
import 'package:roomio/core/storage/secure_storage_service.dart';
import 'package:roomio/features/auth/data/data_sources/remote/account_api_service.dart';
import 'package:roomio/features/auth/data/repository/account_repository_impl.dart';
import 'package:roomio/features/auth/domain/repository/account_repository.dart';
// Các UseCase imports ...
import 'package:roomio/features/auth/domain/usecase/check_phone.dart';
import 'package:roomio/features/auth/domain/usecase/get_new_token.dart';
import 'package:roomio/features/auth/domain/usecase/login.dart';
import 'package:roomio/features/auth/domain/usecase/logout.dart';
import 'package:roomio/features/auth/domain/usecase/register.dart';
import 'package:roomio/features/auth/domain/usecase/reset_password.dart';
import 'package:roomio/features/auth/domain/usecase/send_otp_forgot_password.dart';
import 'package:roomio/features/auth/domain/usecase/send_otp_register.dart';
import 'package:roomio/features/auth/domain/usecase/verify_otp_forgot_password.dart';
import 'package:roomio/features/auth/domain/usecase/verify_otp_register.dart';
// Bloc imports ...
import 'package:roomio/features/auth/presentation/bloc/remote/app_auth/remote_app_auth_bloc.dart';
import 'package:roomio/features/auth/presentation/bloc/remote/app_auth/remote_app_auth_event.dart'; // IMPORT EVENT
import 'package:roomio/features/auth/presentation/bloc/remote/forgot_password/remote_forgot_password_bloc.dart';
import 'package:roomio/features/auth/presentation/bloc/remote/login/remote_login_bloc.dart';
import 'package:roomio/features/auth/presentation/bloc/remote/register/remote_register_bloc.dart';
// Profile Data sources & Repositories ...
import 'package:roomio/features/profile/data/data_sources/remote/profile_landlord_api_service.dart';
import 'package:roomio/features/profile/data/data_sources/remote/profile_tenant_api_service.dart';
import 'package:roomio/features/profile/data/repository/profile_landlord_repository_impl.dart';
import 'package:roomio/features/profile/data/repository/profile_tenant_repository_impl.dart';
// Profile UseCases ...
import 'package:roomio/features/profile/domain/usecase/landlord/create_profile.dart';
import 'package:roomio/features/profile/domain/usecase/landlord/get_profile.dart';
import 'package:roomio/features/profile/domain/usecase/landlord/update_profile.dart';
import 'package:roomio/features/profile/domain/usecase/landlord/upload_avatar.dart';
import 'package:roomio/features/profile/domain/usecase/tenant/create_profile.dart';
import 'package:roomio/features/profile/domain/usecase/tenant/get_profile.dart';
import 'package:roomio/features/profile/domain/usecase/tenant/update_profile.dart';
import 'package:roomio/features/profile/domain/usecase/tenant/upload_avatar.dart';
// Profile Bloc ...
import 'package:roomio/features/profile/presentation/bloc/remote/remote_profile_bloc.dart';

// Room Data sources & Repositories ...
import 'package:roomio/features/room/data/data_sources/remote/room_api_service.dart';
import 'package:roomio/features/room/data/repository/room_repository_impl.dart';
import 'package:roomio/features/room/domain/repository/room_repository.dart';
// Room UseCases ...
import 'package:roomio/features/room/domain/usecases/landlord/post_room.dart';
import 'package:roomio/features/room/domain/usecases/landlord/upload_images.dart';
import 'package:roomio/features/room/domain/usecases/landlord/get_list_room.dart';
import 'package:roomio/features/room/domain/usecases/landlord/update_room.dart';
import 'package:roomio/features/room/domain/usecases/landlord/update_status_room.dart';
import 'package:roomio/features/room/domain/usecases/get_detail_room.dart';
import 'package:roomio/features/room/domain/usecases/tenant/search_room_by_position.dart';
import 'package:roomio/features/room/domain/usecases/tenant/search_rooms_by_area.dart';
import 'package:roomio/features/room/domain/usecases/tenant/get_location_suggestions.dart';
// Room Blocs ...
import 'package:roomio/features/room/presentation/bloc/remote/landlord/remote_landlord_room_bloc.dart';
import 'package:roomio/features/room/presentation/bloc/remote/tenant/remote_tenant_room_bloc.dart';
import 'package:roomio/features/room/presentation/bloc/remote/detail/remote_room_detail_bloc.dart';

import 'package:roomio/features/room/data/data_sources/remote/room_catalog_api_service.dart';
import 'package:roomio/features/room/data/repository/room_catalog_repository_impl.dart';
import 'package:roomio/features/room/domain/repository/room_catalog_repository.dart';
import 'package:roomio/features/room/domain/usecases/get_room_catalog.dart';
import 'package:roomio/features/room/presentation/bloc/remote/catalog/remote_room_catalog_cubit.dart';

import 'package:roomio/features/room/data/data_sources/local/room_location_data_source.dart';
import 'package:roomio/features/room/data/repository/room_location_repository_impl.dart';
import 'package:roomio/features/room/domain/repository/room_location_repository.dart';
import 'package:roomio/features/room/domain/usecases/tenant/get_current_room_location.dart';
import 'package:roomio/features/room/domain/usecases/tenant/search_room_locations.dart';
import 'package:roomio/features/room/domain/usecases/tenant/open_room_location_settings.dart';

import 'package:roomio/features/room/data/data_sources/remote/goong_places_api_service.dart';
import 'package:roomio/features/room/data/repository/room_places_repository_impl.dart';
import 'package:roomio/features/room/domain/repository/room_places_repository.dart';
import 'package:roomio/features/room/domain/usecases/landlord/autocomplete_room_address.dart';
import 'package:roomio/features/room/domain/usecases/landlord/resolve_room_place.dart';
import 'package:roomio/features/room/domain/usecases/landlord/reverse_room_location.dart';
import 'package:roomio/features/room/presentation/bloc/remote/landlord/room_form_location_cubit.dart';

import 'package:roomio/features/review/data/data_sources/remote/review_api_service.dart';
import 'package:roomio/features/review/data/repository/review_repository_impl.dart';
import 'package:roomio/features/review/domain/repository/review_repository.dart';
import 'package:roomio/features/review/domain/usecases/get_reviews.dart';
import 'package:roomio/features/review/domain/usecases/post_review.dart';
import 'package:roomio/features/review/domain/usecases/update_review.dart';
import 'package:roomio/features/review/domain/usecases/delete_review.dart';
import 'package:roomio/features/review/presentation/bloc/review_bloc.dart';

import 'package:roomio/features/saved_room/data/data_sources/remote/save_room_api_service.dart';
import 'package:roomio/features/saved_room/data/repository/save_room_repository_impl.dart';
import 'package:roomio/features/saved_room/domain/repository/save_room_repository.dart';
import 'package:roomio/features/saved_room/domain/usecases/get_saved_rooms.dart';
import 'package:roomio/features/saved_room/domain/usecases/save_room.dart';
import 'package:roomio/features/saved_room/domain/usecases/unsave_room.dart';
import 'package:roomio/features/saved_room/presentation/cubit/saved_rooms_cubit.dart';

final sl = GetIt.instance;

Future<void> initializeDependencies() async {
  // --- 1. CORE & STORAGE ---
  sl.registerLazySingleton<FlutterSecureStorage>(
    () => const FlutterSecureStorage(),
  );

  sl.registerLazySingleton<SecureStorageService>(
    () => SecureStorageService(
      sl(),
      onSessionChanged: () => sl<SavedRoomsCubit>().reset(),
    ),
  );

  // --- 2. NETWORK ---
  // Khởi tạo Interceptor trước (Đã xóa UseCase, chỉ truyền Storage và Callback)
  sl.registerLazySingleton<AppInterceptor>(
    () => AppInterceptor(
      sl(),
      onUnauthorized: () {
        sl<NotificationDeviceSync>().expireSession();
        // Nút bấm khẩn cấp: Bắn event để Bloc đá user ra ngoài
        sl<RemoteAppAuthBloc>().add(const TokenExpiredEvent());
      },
    ),
  );

  // Khởi tạo Dio
  sl.registerLazySingleton<Dio>(() {
    final options = BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    );
    final dio = Dio(options);

    // Gắn Interceptor vào Dio
    dio.interceptors.add(sl<AppInterceptor>());
    return dio;
  });

  // --- 3. DATA SOURCES & REPOSITORIES ---
  sl.registerLazySingleton<AccountApiService>(() => AccountApiService(sl()));
  sl.registerLazySingleton<AccountRepository>(
    () => AccountRepositoryImpl(sl()),
  );

  // Profile Data Sources & Repositories
  sl.registerLazySingleton<ProfileLandlordApiService>(
    () => ProfileLandlordApiService(sl()),
  );
  sl.registerLazySingleton<ProfileTenantApiService>(
    () => ProfileTenantApiService(sl()),
  );
  sl.registerLazySingleton<ProfileLandlordRepositoryImpl>(
    () => ProfileLandlordRepositoryImpl(sl()),
  );
  sl.registerLazySingleton<ProfileTenantRepositoryImpl>(
    () => ProfileTenantRepositoryImpl(sl()),
  );

  // Room Data Sources & Repositories
  sl.registerLazySingleton<GoongPlacesApiService>(
    () => GoongPlacesApiService(),
  );
  sl.registerLazySingleton<RoomPlacesRepository>(
    () => RoomPlacesRepositoryImpl(sl()),
  );
  sl.registerLazySingleton<RoomLocationDataSource>(
    () => RoomLocationDataSource(),
  );
  sl.registerLazySingleton<RoomLocationRepository>(
    () => RoomLocationRepositoryImpl(sl()),
  );
  sl.registerLazySingleton<RoomApiService>(() => RoomApiService(sl()));
  sl.registerLazySingleton<RoomRepository>(() => RoomRepositoryImpl(sl()));
  sl.registerLazySingleton<RoomCatalogApiService>(
    () => RoomCatalogApiService(sl()),
  );
  sl.registerLazySingleton<RoomCatalogRepository>(
    () => RoomCatalogRepositoryImpl(sl()),
  );

  // Appointment Data Sources & Repositories
  sl.registerLazySingleton<AppointmentApiService>(
    () => AppointmentApiService(sl()),
  );
  sl.registerLazySingleton<AppointmentRepository>(
    () => AppointmentRepositoryImpl(sl()),
  );

  // Rental Data Sources & Repositories
  sl.registerLazySingleton<RentalApiService>(() => RentalApiService(sl()));
  sl.registerLazySingleton<RentalRepository>(() => RentalRepositoryImpl(sl()));

  // Review Data Source & Repository
  sl.registerLazySingleton<ReviewApiService>(() => ReviewApiService(sl()));
  sl.registerLazySingleton<ReviewRepository>(() => ReviewRepositoryImpl(sl()));

  // Saved Room Data Source & Repository
  sl.registerLazySingleton<SavedRoomApiService>(
    () => SavedRoomApiService(sl()),
  );
  sl.registerLazySingleton<SaveRoomRepository>(
    () => SaveRoomRepositoryImpl(sl()),
  );
  // --- 4. USECASES ---
  sl.registerLazySingleton<NotificationlApiService>(
    () => NotificationlApiService(sl()),
  );
  sl.registerLazySingleton<DeviceApiService>(() => DeviceApiService(sl()));
  sl.registerLazySingleton<NotificationRepository>(
    () => NotificationRepositoryImpl(sl(), sl()),
  );
  sl.registerLazySingleton<GetNotificationsUseCase>(
    () => GetNotificationsUseCase(sl()),
  );
  sl.registerLazySingleton<MarkNotificationReadUseCase>(
    () => MarkNotificationReadUseCase(sl()),
  );
  sl.registerLazySingleton<RegisterDeviceUseCase>(
    () => RegisterDeviceUseCase(sl()),
  );
  sl.registerLazySingleton<UpdateDeviceUseCase>(
    () => UpdateDeviceUseCase(sl()),
  );
  sl.registerLazySingleton<UnregisterDeviceUseCase>(
    () => UnregisterDeviceUseCase(sl()),
  );
  sl.registerLazySingleton<FcmService>(
    FcmService.new,
    dispose: (service) => service.dispose(),
  );
  sl.registerLazySingleton<NotificationDeviceSync>(
    () => NotificationDeviceSync(
      sl(),
      // Keep device IDs available across JWT cleanup and failed unregisters.
      const FlutterSecureStorage(
        aOptions: AndroidOptions(storageNamespace: 'roomio_push_devices'),
      ),
      sl(),
      sl(),
      sl(),
    ),
    dispose: (service) => service.dispose(),
  );
  sl.registerLazySingleton<PushNotificationNavigator>(
    () => PushNotificationNavigator(sl(), sl()),
  );
  sl.registerFactory<NotificationBloc>(() => NotificationBloc(sl(), sl()));
  sl.registerLazySingleton<ChatApiService>(() => ChatApiService(sl()));
  sl.registerLazySingleton<ChatWebSocketService>(
    () => ChatWebSocketService(sl()),
    dispose: (service) => service.disconnect(),
  );
  sl.registerLazySingleton<ChatRepository>(
    () => ChatRepositoryImpl(sl(), sl()),
  );
  sl.registerLazySingleton<GetConversationsUseCase>(
    () => GetConversationsUseCase(sl()),
  );
  sl.registerLazySingleton<GetMessagesUseCase>(() => GetMessagesUseCase(sl()));
  sl.registerLazySingleton<SendMessageUseCase>(() => SendMessageUseCase(sl()));
  sl.registerLazySingleton<ListenToMessagesUseCase>(
    () => ListenToMessagesUseCase(sl()),
  );
  sl.registerLazySingleton<ContactLandlordUseCase>(
    () => ContactLandlordUseCase(sl()),
  );
  sl.registerFactoryParam<ChatBloc, ChatSession, dynamic>(
    (session, _) => ChatBloc(sl(), sl(), sl(), sl(), session),
  );

  sl.registerLazySingleton<CheckPhoneUseCase>(() => CheckPhoneUseCase(sl()));
  sl.registerLazySingleton<GetNewTokenUseCase>(() => GetNewTokenUseCase(sl()));
  sl.registerLazySingleton<LoginUseCase>(() => LoginUseCase(sl()));
  sl.registerLazySingleton<LogoutUseCase>(() => LogoutUseCase(sl()));
  sl.registerLazySingleton<RegisterUseCase>(() => RegisterUseCase(sl()));
  sl.registerLazySingleton<ResetPasswordUseCase>(
    () => ResetPasswordUseCase(sl()),
  );
  sl.registerLazySingleton<SendOTPForgotPasswordUseCase>(
    () => SendOTPForgotPasswordUseCase(sl()),
  );
  sl.registerLazySingleton<SendOTPRegisterUseCase>(
    () => SendOTPRegisterUseCase(sl()),
  );
  sl.registerLazySingleton<VerifyOTPForgotPasswordUseCase>(
    () => VerifyOTPForgotPasswordUseCase(sl()),
  );
  sl.registerLazySingleton<VerifyOTPRegisterUseCase>(
    () => VerifyOTPRegisterUseCase(sl()),
  );

  // Profile Landlord UseCases
  sl.registerLazySingleton<CreateProfileLandLordUseCase>(
    () => CreateProfileLandLordUseCase(sl<ProfileLandlordRepositoryImpl>()),
  );
  sl.registerLazySingleton<UpdateProfileLandLordUseCase>(
    () => UpdateProfileLandLordUseCase(sl<ProfileLandlordRepositoryImpl>()),
  );
  sl.registerLazySingleton<GetProfileLandLordUseCase>(
    () => GetProfileLandLordUseCase(sl<ProfileLandlordRepositoryImpl>()),
  );
  sl.registerLazySingleton<UploadAvatarLandLordUseCase>(
    () => UploadAvatarLandLordUseCase(sl<ProfileLandlordRepositoryImpl>()),
  );

  // Profile Tenant UseCases
  sl.registerLazySingleton<CreateProfileTenantUseCase>(
    () => CreateProfileTenantUseCase(sl<ProfileTenantRepositoryImpl>()),
  );
  sl.registerLazySingleton<UpdateProfileTenantUseCase>(
    () => UpdateProfileTenantUseCase(sl<ProfileTenantRepositoryImpl>()),
  );
  sl.registerLazySingleton<GetProfileTenantUseCase>(
    () => GetProfileTenantUseCase(sl<ProfileTenantRepositoryImpl>()),
  );
  sl.registerLazySingleton<UploadAvatarTenantUseCase>(
    () => UploadAvatarTenantUseCase(sl<ProfileTenantRepositoryImpl>()),
  );

  // Room Landlord UseCases
  sl.registerLazySingleton<AutocompleteRoomAddressUseCase>(
    () => AutocompleteRoomAddressUseCase(sl()),
  );
  sl.registerLazySingleton<ResolveRoomPlaceUseCase>(
    () => ResolveRoomPlaceUseCase(sl()),
  );
  sl.registerLazySingleton<ReverseRoomLocationUseCase>(
    () => ReverseRoomLocationUseCase(sl()),
  );
  sl.registerLazySingleton<PostRoomUseCase>(() => PostRoomUseCase(sl()));
  sl.registerLazySingleton<UploadRoomImagesUseCase>(
    () => UploadRoomImagesUseCase(sl()),
  );
  sl.registerLazySingleton<GetListRoomUseCase>(() => GetListRoomUseCase(sl()));
  sl.registerLazySingleton<UpdateRoomUseCase>(() => UpdateRoomUseCase(sl()));
  sl.registerLazySingleton<UpdateStatusRoomUseCase>(
    () => UpdateStatusRoomUseCase(sl()),
  );

  // Room Tenant UseCases
  sl.registerLazySingleton<GetCurrentRoomLocationUseCase>(
    () => GetCurrentRoomLocationUseCase(sl()),
  );
  sl.registerLazySingleton<SearchRoomLocationsUseCase>(
    () => SearchRoomLocationsUseCase(sl()),
  );
  sl.registerLazySingleton<OpenRoomLocationSettingsUseCase>(
    () => OpenRoomLocationSettingsUseCase(sl()),
  );
  sl.registerLazySingleton<SearchRoomByPositionUseCase>(
    () => SearchRoomByPositionUseCase(sl()),
  );
  sl.registerLazySingleton<SearchRoomsByAreaUseCase>(
    () => SearchRoomsByAreaUseCase(sl()),
  );
  sl.registerLazySingleton<GetLocationSuggestionsUseCase>(
    () => GetLocationSuggestionsUseCase(sl()),
  );

  // Room Common UseCases
  sl.registerLazySingleton<GetRoomCatalogUseCase>(
    () => GetRoomCatalogUseCase(sl()),
  );
  sl.registerLazySingleton<GetDetailRoomUseCase>(
    () => GetDetailRoomUseCase(sl()),
  );

  // Appointment UseCases
  sl.registerLazySingleton<SendAppointmentUseCase>(
    () => SendAppointmentUseCase(sl()),
  );
  sl.registerLazySingleton<GetAllAppointmentsUseCase>(
    () => GetAllAppointmentsUseCase(sl()),
  );
  sl.registerLazySingleton<ConfirmAppointmentUseCase>(
    () => ConfirmAppointmentUseCase(sl()),
  );
  sl.registerLazySingleton<DestroyAppointmentUseCase>(
    () => DestroyAppointmentUseCase(sl()),
  );
  sl.registerLazySingleton<UpdateAppointmentUseCase>(
    () => UpdateAppointmentUseCase(sl()),
  );

  // Rental UseCases
  sl.registerLazySingleton<CreateRentalQRCodeUseCase>(
    () => CreateRentalQRCodeUseCase(sl()),
  );
  sl.registerLazySingleton<VerifyRentalQRCodeUseCase>(
    () => VerifyRentalQRCodeUseCase(sl()),
  );
  sl.registerLazySingleton<DestroyRentalRelationUseCase>(
    () => DestroyRentalRelationUseCase(sl()),
  );
  sl.registerLazySingleton<GetMyTenantsUseCase>(
    () => GetMyTenantsUseCase(sl()),
  );
  sl.registerLazySingleton<GetCurrentRentRoomUseCase>(
    () => GetCurrentRentRoomUseCase(sl()),
  );

  // Review UseCases
  sl.registerLazySingleton<GetReviewsUseCase>(() => GetReviewsUseCase(sl()));
  sl.registerLazySingleton<PostReviewUseCase>(() => PostReviewUseCase(sl()));
  sl.registerLazySingleton<UpdateReviewUseCase>(
    () => UpdateReviewUseCase(sl()),
  );
  sl.registerLazySingleton<DeleteReviewUseCase>(
    () => DeleteReviewUseCase(sl()),
  );
  // Saved Room UseCases
  sl.registerLazySingleton<GetSavedRoomsUseCase>(
    () => GetSavedRoomsUseCase(sl()),
  );
  sl.registerLazySingleton<SaveRoomUseCase>(() => SaveRoomUseCase(sl()));
  sl.registerLazySingleton<UnsaveRoomUseCase>(() => UnsaveRoomUseCase(sl()));
  // --- 5. BLOCS ---
  // LƯU Ý: Tùy theo số lượng biến trong Constructor của Bloc mà truyền số lượng sl() tương ứng.

  sl.registerFactory<RemoteLoginBloc>(
    () => RemoteLoginBloc(sl(), sl(), sl(), sl()),
  );

  sl.registerFactory<RemoteRegisterBloc>(
    () => RemoteRegisterBloc(
      sl(),
      sl(),
      sl(),
    ), // Bạn tự check lại số biến trong file
  );

  sl.registerFactory<RemoteForgotPasswordBloc>(
    () => RemoteForgotPasswordBloc(sl(), sl(), sl()),
  );

  sl.registerFactory<RemoteAppAuthBloc>(
    () => RemoteAppAuthBloc(sl(), sl(), sl()),
  );

  // Profile Bloc
  sl.registerFactoryParam<RemoteProfileBloc, String?, dynamic>(
    (role, _) => RemoteProfileBloc(
      role ?? 'CUSTOMER',
      sl<CreateProfileLandLordUseCase>(),
      sl<UpdateProfileLandLordUseCase>(),
      sl<GetProfileLandLordUseCase>(),
      sl<UploadAvatarLandLordUseCase>(),
      sl<CreateProfileTenantUseCase>(),
      sl<UpdateProfileTenantUseCase>(),
      sl<GetProfileTenantUseCase>(),
      sl<UploadAvatarTenantUseCase>(),
    ),
  );

  // Room Blocs
  sl.registerFactory<RoomFormLocationCubit>(
    () => RoomFormLocationCubit(sl(), sl(), sl(), sl(), sl()),
  );
  sl.registerFactory<RemoteRoomCatalogCubit>(
    () => RemoteRoomCatalogCubit(sl()),
  );
  sl.registerFactory<RemoteLandlordRoomBloc>(
    () => RemoteLandlordRoomBloc(sl(), sl(), sl(), sl(), sl()),
  );
  sl.registerFactory<RemoteTenantRoomBloc>(
    () => RemoteTenantRoomBloc(sl(), sl(), sl(), sl(), sl(), sl()),
  );
  sl.registerFactory<RemoteRoomDetailBloc>(() => RemoteRoomDetailBloc(sl()));

  // Appointment Bloc
  sl.registerFactory<RemoteAppointmentBloc>(
    () => RemoteAppointmentBloc(sl(), sl(), sl(), sl(), sl()),
  );

  // Search and saved-room routes share state until the signed-in session changes.
  sl.registerLazySingleton<SavedRoomsCubit>(
    () => SavedRoomsCubit(sl(), sl(), sl()),
    dispose: (cubit) => cubit.close(),
  );
  // Review Bloc: each embedded section owns its room's instance.
  sl.registerFactoryParam<ReviewBloc, String, dynamic>(
    (roomId, _) => ReviewBloc(sl(), sl(), sl(), sl(), roomId: roomId),
  );
  // Rental Bloc
  sl.registerFactory<RemoteRentalBloc>(
    () => RemoteRentalBloc(sl(), sl(), sl(), sl(), sl()),
  );
}
