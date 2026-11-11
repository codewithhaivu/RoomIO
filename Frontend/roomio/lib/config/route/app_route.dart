import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:roomio/features/saved_room/presentation/pages/saved_rooms_page.dart';
import 'package:roomio/features/saved_room/presentation/widgets/saved_rooms_scope.dart';
import 'package:roomio/features/notification/presentation/bloc/notification_bloc.dart';
import 'package:roomio/features/notification/presentation/pages/notifications_page.dart';
import 'package:roomio/features/chat/domain/entities/chat.dart';
import 'package:roomio/features/chat/presentation/bloc/chat_bloc.dart';
import 'package:roomio/features/chat/presentation/pages/chat_list_page.dart';
import 'package:roomio/features/chat/presentation/pages/chat_page.dart';
import 'package:roomio/features/chat/presentation/widgets/chat_session_gate.dart';
import 'package:roomio/features/rental/presentation/bloc/remote/remote_rental_bloc.dart';
import 'package:roomio/features/rental/presentation/pages/rentals_page.dart';
import 'package:roomio/features/rental/presentation/pages/rental_qr_code_page.dart';
import 'package:roomio/features/rental/presentation/pages/rental_verify_page.dart';
import 'package:roomio/features/rental/presentation/pages/rental_scan_page.dart';
import 'package:roomio/features/appointment/domain/entities/appointment.dart';
import 'package:roomio/features/appointment/presentation/bloc/remote/remote_appointment_bloc.dart';
import 'package:roomio/features/appointment/presentation/pages/appointments_page.dart';
import 'package:roomio/features/appointment/presentation/pages/appointment_form_page.dart';
import 'package:roomio/features/auth/presentation/bloc/remote/login/remote_login_bloc.dart';
import 'package:roomio/features/auth/presentation/bloc/remote/register/remote_register_bloc.dart';
import 'package:roomio/features/auth/presentation/pages/check_phone_page.dart';
import 'package:roomio/features/auth/presentation/pages/login_page.dart';
import 'package:roomio/features/auth/presentation/pages/register_page.dart';
import 'package:roomio/features/auth/presentation/pages/forgot_password_otp_page.dart';
import 'package:roomio/features/auth/presentation/pages/reset_password_page.dart';
import 'package:roomio/features/auth/presentation/bloc/remote/forgot_password/remote_forgot_password_bloc.dart';
import 'package:roomio/features/auth/presentation/pages/register_otp_page.dart';
import 'package:roomio/features/auth/presentation/pages/register_password_page.dart';
import 'package:roomio/features/auth/presentation/pages/home_page.dart';
import 'package:roomio/features/profile/presentation/pages/create_profile_page.dart';
import 'package:roomio/features/profile/presentation/pages/update_profile_page.dart';
import 'package:roomio/features/profile/presentation/bloc/remote/remote_profile_bloc.dart';
import 'package:roomio/injection_container.dart';
import 'package:roomio/config/route/room_route_gate.dart';
import 'package:roomio/features/room/domain/entities/room_entities.dart';
import 'package:roomio/features/room/presentation/bloc/remote/landlord/room_form_location_cubit.dart';
import 'package:roomio/features/room/presentation/bloc/remote/catalog/remote_room_catalog_cubit.dart';
import 'package:roomio/features/room/presentation/bloc/remote/landlord/remote_landlord_room_bloc.dart';
import 'package:roomio/features/room/presentation/bloc/remote/tenant/remote_tenant_room_bloc.dart';
import 'package:roomio/features/room/presentation/bloc/remote/detail/remote_room_detail_bloc.dart';
import 'package:roomio/features/room/presentation/pages/my_rooms_page.dart';
import 'package:roomio/features/room/presentation/pages/room_form_page.dart';
import 'package:roomio/features/room/presentation/pages/search_rooms_page.dart';
import 'package:roomio/features/room/presentation/pages/room_detail_page.dart';

// Import các màn hình và Bloc của bạn vào đây
// import 'injection_container.dart'; (chứa biến sl của GetIt)

class AppRoutes {
  // Định nghĩa tên các tuyến đường cho dễ gọi, đỡ gõ sai chữ
  static const String home = '/home';
  static const String checkPhone = '/check_phone';
  static const String login = '/login';
  static const String register = '/register';
  static const String registerOtp = '/register_otp';
  static const String registerPassword = '/register_password';
  static const String forgotPasswordOtp = '/forgot_password_otp';
  static const String resetPassword = '/reset_password';
  static const String createProfile = '/create_profile';
  static const String updateProfile = '/update_profile';
  static const String myRooms = '/my_rooms';
  static const String roomForm = '/room_form';
  static const String searchRooms = '/search_rooms';
  static const String savedRooms = '/saved_rooms';
  static const String roomDetail = '/room_detail';
  static const String appointments = '/appointments';
  static const String appointmentForm = '/appointment_form';
  static const String rentals = '/rentals';
  static const String rentalQRCode = '/rental_qr_code';
  static const String rentalVerify = '/rental_verify';
  static const String rentalScan = '/rental_scan';
  static const String chatList = '/chats';
  static const String chat = '/chat';
  static const String notifications = '/notifications';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case notifications:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => RoomRouteGate(
            builder: (_, _) => BlocProvider(
              create: (_) => sl<NotificationBloc>(),
              child: const NotificationsPage(),
            ),
          ),
        );
      case chatList:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => ChatSessionGate(
            builder: (_, session) => BlocProvider(
              create: (_) => sl<ChatBloc>(param1: session),
              child: const ChatListPage(),
            ),
          ),
        );
      case chat:
        final conversation = settings.arguments;
        if (conversation is! ConversationResponse ||
            conversation.targetUserId.trim().isEmpty) {
          return MaterialPageRoute(
            settings: settings,
            builder: (_) => Scaffold(
              appBar: AppBar(title: const Text('Tin nhắn')),
              body: const Center(
                child: Text('Thông tin hội thoại không hợp lệ.'),
              ),
            ),
          );
        }
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => ChatSessionGate(
            builder: (_, session) =>
                conversation.targetUserId == session.accountId
                ? Scaffold(
                    appBar: AppBar(title: const Text('Tin nhắn')),
                    body: const Center(
                      child: Text('Không thể nhắn tin cho chính mình.'),
                    ),
                  )
                : BlocProvider(
                    create: (_) => sl<ChatBloc>(param1: session),
                    child: ChatPage(
                      conversation: conversation,
                      session: session,
                    ),
                  ),
          ),
        );
      // 1. MÀN HÌNH NHẬP SỐ ĐIỆN THOẠI
      case checkPhone:
        return MaterialPageRoute(
          builder: (_) => BlocProvider(
            create: (_) => sl<RemoteLoginBloc>(), // Tiêm Bloc CheckPhone
            child: const CheckPhonePage(),
          ),
        );

      // 2. MÀN HÌNH ĐĂNG NHẬP (Hứng dữ liệu tên và số điện thoại)
      case login:
        // Hứng cục dữ liệu truyền sang từ màn CheckPhone
        final args = settings.arguments as Map<String, dynamic>;

        return MaterialPageRoute(
          builder: (_) => BlocProvider(
            create: (_) => sl<RemoteLoginBloc>(), // Tiêm Bloc Login
            child: LoginPage(
              phoneNumber: args['phoneNumber'],
              userName: args['userName'], // Truyền tên "Anh Hải" vào đây
            ),
          ),
        );

      // 3. MÀN HÌNH ĐĂNG KÝ (Hứng số điện thoại chưa có tài khoản)
      case register:
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => BlocProvider(
            create: (_) => sl<RemoteRegisterBloc>(),
            child: RegisterPage(phoneNumber: args['phoneNumber']),
          ),
        );

      case registerOtp:
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => BlocProvider(
            create: (_) => sl<RemoteRegisterBloc>(),
            child: RegisterOtpPage(
              phoneNumber: args['phoneNumber'],
              role: args['role'],
            ),
          ),
        );

      case registerPassword:
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => BlocProvider(
            create: (_) => sl<RemoteRegisterBloc>(),
            child: RegisterPasswordPage(
              phoneNumber: args['phoneNumber'],
              role: args['role'],
            ),
          ),
        );

      // 4. MÀN HÌNH XÁC NHẬN OTP QUÊN MẬT KHẨU
      case forgotPasswordOtp:
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => BlocProvider(
            create: (_) => sl<RemoteForgotPasswordBloc>(),
            child: ForgotPasswordOtpPage(phoneNumber: args['phoneNumber']),
          ),
        );

      // 5. MÀN HÌNH ĐẶT LẠI MẬT KHẨU
      case resetPassword:
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => BlocProvider(
            create: (_) => sl<RemoteForgotPasswordBloc>(),
            child: ResetPasswordPage(phoneNumber: args['phoneNumber']),
          ),
        );

      // 6. MÀN HÌNH TẠO HỒ SƠ (CREATE PROFILE)
      case createProfile:
        final args = settings.arguments as Map<String, dynamic>?;
        final role = args?['role'] as String? ?? 'CUSTOMER';
        return MaterialPageRoute(
          builder: (_) => BlocProvider(
            create: (_) => sl<RemoteProfileBloc>(param1: role),
            child: CreateProfilePage(role: role),
          ),
        );

      // 7. MÀN HÌNH CHỈNH SỬA HỒ SƠ (UPDATE PROFILE)
      case updateProfile:
        final updateArgs = settings.arguments as Map<String, dynamic>?;
        final updateRole = updateArgs?['role'] as String? ?? 'CUSTOMER';
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => BlocProvider(
            create: (_) => sl<RemoteProfileBloc>(param1: updateRole),
            child: const UpdateProfilePage(),
          ),
        );

      // 8. MÀN HÌNH CHÍNH (HOME)
      case home:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const HomePage(),
        );

      // 9. ROOM: LANDLORD
      case myRooms:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => RoomRouteGate(
            landlordOnly: true,
            builder: (_, _) => BlocProvider(
              create: (_) => sl<RemoteLandlordRoomBloc>(),
              child: const MyRoomsPage(),
            ),
          ),
        );

      case roomForm:
        final args = settings.arguments;
        final room = args is RoomEntity
            ? args
            : args is Map
            ? args['room']
            : null;
        if ((args != null && args is! RoomEntity && args is! Map) ||
            (room != null && room is! RoomEntity) ||
            (args is Map && args.isNotEmpty && room == null)) {
          return _invalidRoomRoute(settings);
        }
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => RoomRouteGate(
            landlordOnly: true,
            builder: (_, _) => MultiBlocProvider(
              providers: [
                BlocProvider(create: (_) => sl<RemoteLandlordRoomBloc>()),
                BlocProvider(
                  create: (_) =>
                      sl<RoomFormLocationCubit>()
                        ..initialize((room as RoomEntity?)?.location),
                ),
                BlocProvider(
                  create: (_) => sl<RemoteRoomCatalogCubit>()..loadCatalog(),
                ),
              ],
              child: RoomFormPage(initialRoom: room as RoomEntity?),
            ),
          ),
        );

      // 10. ROOM: TENANT
      case savedRooms:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => RoomRouteGate(
            tenantOnly: true,
            builder: (_, _) => const SavedRoomsScope(child: SavedRoomsPage()),
          ),
        );

      case searchRooms:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => RoomRouteGate(
            builder: (_, isLandlord) => SavedRoomsScope(
              child: BlocProvider(
                create: (_) => sl<RemoteTenantRoomBloc>(),
                child: SearchRoomsPage(canSaveRooms: !isLandlord),
              ),
            ),
          ),
        );
      // 11. ROOM: CHI TIẾT DÙNG CHUNG
      case roomDetail:
        final args = settings.arguments;
        final roomId = args is String
            ? args
            : args is Map
            ? args['roomId']
            : null;
        if (roomId is! String || roomId.trim().isEmpty) {
          return _invalidRoomRoute(settings);
        }
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => RoomRouteGate(
            builder: (_, isLandlord) => MultiBlocProvider(
              providers: [
                BlocProvider(create: (_) => sl<RemoteRoomDetailBloc>()),
                if (isLandlord)
                  BlocProvider(create: (_) => sl<RemoteLandlordRoomBloc>()),
              ],
              child: RoomDetailPage(roomId: roomId, isLandlord: isLandlord),
            ),
          ),
        );

      // 12. APPOINTMENT: DANH SÁCH THEO VAI TRÒ TRONG PHIÊN ĐĂNG NHẬP
      case appointments:
        final args = settings.arguments;
        final roomId = args is String
            ? args
            : args is Map
            ? args['roomId']
            : null;
        final appointmentId = args is Map ? args['appointmentId'] : null;
        if ((args != null && args is! String && args is! Map) ||
            (args is Map &&
                args.isNotEmpty &&
                roomId == null &&
                appointmentId == null) ||
            (roomId != null && (roomId is! String || roomId.trim().isEmpty)) ||
            (appointmentId != null &&
                (appointmentId is! String || appointmentId.trim().isEmpty))) {
          return _invalidAppointmentRoute(settings);
        }
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => RoomRouteGate(
            builder: (_, isLandlord) => BlocProvider(
              create: (_) => sl<RemoteAppointmentBloc>(),
              child: AppointmentsPage(
                isLandlord: isLandlord,
                roomId: roomId as String?,
                appointmentId: appointmentId as String?,
              ),
            ),
          ),
        );

      // 13. APPOINTMENT: KHÁCH THUÊ ĐẶT / ĐỔI LỊCH CHO MỘT PHÒNG
      case appointmentForm:
        final args = settings.arguments;
        final initial = args is AppointmentEntityResponse ? args : null;
        final roomId = initial?.idRoom ?? (args is Map ? args['roomId'] : null);
        final roomName =
            initial?.nameRoom ?? (args is Map ? args['roomName'] : null);
        if (roomId is! String ||
            roomId.trim().isEmpty ||
            roomName is! String ||
            roomName.trim().isEmpty ||
            (initial != null && initial.idAppointment.trim().isEmpty)) {
          return _invalidAppointmentRoute(settings);
        }
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => RoomRouteGate(
            tenantOnly: true,
            builder: (_, _) => BlocProvider(
              create: (_) => sl<RemoteAppointmentBloc>(),
              child: AppointmentFormPage(
                roomId: roomId,
                roomName: roomName,
                initialAppointment: initial,
              ),
            ),
          ),
        );

      // 14. RENTAL: DANH SÁCH THEO VAI TRÒ TRONG PHIÊN ĐĂNG NHẬP
      case rentals:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => RoomRouteGate(
            builder: (_, isLandlord) => BlocProvider(
              create: (_) => sl<RemoteRentalBloc>(),
              child: RentalsPage(isLandlord: isLandlord),
            ),
          ),
        );

      case rentalQRCode:
        final args = settings.arguments;
        final roomId = args is Map ? args['roomId'] : null;
        final roomName = args is Map ? args['roomName'] : null;
        if (roomId is! String ||
            roomId.trim().isEmpty ||
            roomName is! String ||
            roomName.trim().isEmpty) {
          return MaterialPageRoute(
            settings: settings,
            builder: (_) => Scaffold(
              appBar: AppBar(title: const Text('Mã thuê phòng')),
              body: const Center(
                child: Text(
                  'Thông tin phòng không hợp lệ. Vui lòng mở lại từ phòng.',
                ),
              ),
            ),
          );
        }
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => RoomRouteGate(
            landlordOnly: true,
            builder: (_, _) => BlocProvider(
              create: (_) => sl<RemoteRentalBloc>(),
              child: RentalQRCodePage(roomId: roomId, roomName: roomName),
            ),
          ),
        );

      case rentalVerify:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => RoomRouteGate(
            tenantOnly: true,
            builder: (_, _) => BlocProvider(
              create: (_) => sl<RemoteRentalBloc>(),
              child: const RentalVerifyPage(),
            ),
          ),
        );

      case rentalScan:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => RoomRouteGate(
            tenantOnly: true,
            builder: (_, _) => const RentalScanPage(),
          ),
        );

      // Báo lỗi nếu gọi sai tên Route
      default:
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(child: Text('Không tìm thấy màn hình!')),
          ),
        );
    }
  }

  static Route<dynamic> _invalidAppointmentRoute(
    RouteSettings settings,
  ) => MaterialPageRoute(
    settings: settings,
    builder: (_) => Scaffold(
      appBar: AppBar(title: const Text('Lịch hẹn xem phòng')),
      body: const Center(
        child: Text(
          'Thông tin lịch hẹn không hợp lệ. Vui lòng mở lại từ phòng hoặc danh sách lịch hẹn.',
        ),
      ),
    ),
  );

  static Route<dynamic> _invalidRoomRoute(RouteSettings settings) =>
      MaterialPageRoute(
        settings: settings,
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Phòng trọ')),
          body: const Center(
            child: Text(
              'Thông tin phòng không hợp lệ. Vui lòng mở lại từ danh sách.',
            ),
          ),
        ),
      );
}
