import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:roomio/config/route/app_route.dart';
import 'package:roomio/config/route/push_notification_navigator.dart';
import 'package:roomio/config/theme/app_theme.dart';
import 'package:roomio/core/firebase/fcm_service.dart';
import 'package:roomio/features/auth/presentation/bloc/remote/login/remote_login_bloc.dart';
import 'package:roomio/features/auth/presentation/pages/check_phone_page.dart';
import 'package:roomio/features/auth/presentation/pages/home_page.dart';
import 'package:roomio/injection_container.dart';
import 'package:roomio/features/auth/presentation/bloc/remote/app_auth/remote_app_auth_bloc.dart';
import 'package:roomio/features/auth/presentation/bloc/remote/app_auth/remote_app_auth_event.dart';
import 'package:roomio/features/auth/presentation/bloc/remote/app_auth/remote_app_auth_state.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDependencies();
  final pushNavigator = sl<PushNotificationNavigator>();
  await sl<FcmService>().initialize(
    shouldShow: pushNavigator.shouldShow,
    onTap: pushNavigator.onTap,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final pushNavigator = sl<PushNotificationNavigator>();
    // 1. Bọc MaterialApp bằng BlocProvider để cung cấp AuthBloc cho toàn app
    return BlocProvider<RemoteAppAuthBloc>(
      // 2. Vừa khởi tạo Bloc là gọi ngay sự kiện kiểm tra Token
      create: (context) =>
          sl<RemoteAppAuthBloc>()..add(const CheckAuthStatusEvent()),

      // 3. Lắng nghe trạng thái để quyết định vẽ màn hình nào
      child: BlocConsumer<RemoteAppAuthBloc, RemoteAppAuthState>(
        listener: (_, state) {
          if (state is AppAuthenticated || state is AppUnauthenticated) {
            pushNavigator.resolveStartup();
          }
        },
        builder: (context, state) {
          return MaterialApp(
            title: 'Roomio',
            theme: AppTheme.light,
            home: _getInitialPage(state),
            onGenerateRoute: AppRoutes.onGenerateRoute,
            navigatorObservers: [pushNavigator],
          );
        },
      ),
    );
  }

  Widget _getInitialPage(RemoteAppAuthState state) {
    if (state is AppAuthenticated) {
      return const HomePage();
    } else if (state is AppUnauthenticated) {
      return BlocProvider<RemoteLoginBloc>(
        create: (context) => sl<RemoteLoginBloc>(),
        child: const CheckPhonePage(),
      );
    }

    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
