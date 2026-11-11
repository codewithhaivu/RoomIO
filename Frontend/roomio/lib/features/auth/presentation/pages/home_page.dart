import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:roomio/config/route/app_route.dart';
import 'package:roomio/core/resource/data_state.dart';
import 'package:roomio/core/storage/secure_storage_service.dart';
import 'package:roomio/features/auth/presentation/bloc/remote/app_auth/remote_app_auth_bloc.dart';
import 'package:roomio/features/auth/presentation/bloc/remote/app_auth/remote_app_auth_event.dart';
import 'package:roomio/features/auth/presentation/bloc/remote/app_auth/remote_app_auth_state.dart';
import 'package:roomio/features/profile/domain/entities/profile.dart';
import 'package:roomio/features/profile/domain/usecase/landlord/get_profile.dart';
import 'package:roomio/features/profile/domain/usecase/tenant/get_profile.dart';
import 'package:roomio/injection_container.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  ProfileEntity? _profile;
  String _role = 'CUSTOMER';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final secureStorage = sl<SecureStorageService>();
      final storedRole = await secureStorage.getRole();
      if (storedRole != null && storedRole.isNotEmpty) {
        _role = storedRole;
      }

      final profileResult = _role == 'LANDLORD'
          ? await sl<GetProfileLandLordUseCase>()(null)
          : await sl<GetProfileTenantUseCase>()(null);

      if (profileResult is DataSuccess) {
        _profile = profileResult.data;
      }
    } catch (_) {
      // Ignore error, profile may be empty
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _onLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text(
          'Bạn có chắc chắn muốn đăng xuất khỏi tài khoản không?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final secureStorage = sl<SecureStorageService>();
      final token = await secureStorage.getRefreshToken() ?? '';
      if (!mounted) return;
      final auth = context.read<RemoteAppAuthBloc>();
      if (auth.state is RemoteAppAuthLoading) return;
      final navigator = Navigator.of(context);
      final finished = auth.stream.firstWhere(
        (state) =>
            state is AppUnauthenticated || state is RemoteAppAuthErrorState,
      );
      auth.add(LogoutEvent(token: token));
      await finished;
      if (navigator.mounted) {
        navigator.pushNamedAndRemoveUntil(
          AppRoutes.checkPhone,
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLandlord = _role == 'LANDLORD';

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Roomio'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Làm mới',
            onPressed: _loadProfileData,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Đăng xuất',
            onPressed: _onLogout,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadProfileData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Profile Header Card
                    Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 46,
                              backgroundColor: theme.primaryColor.withValues(
                                alpha: 0.1,
                              ),
                              foregroundImage:
                                  (_profile?.avartarUrl != null &&
                                      _profile!.avartarUrl!.isNotEmpty)
                                  ? NetworkImage(_profile!.avartarUrl!)
                                  : null,
                              onForegroundImageError:
                                  (_profile?.avartarUrl?.isNotEmpty ?? false)
                                  ? (_, _) {}
                                  : null,
                              child: Icon(
                                Icons.person,
                                size: 48,
                                color: theme.primaryColor,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              _profile?.name ?? 'Chưa cập nhật tên',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: theme.primaryColor.withValues(
                                  alpha: 0.1,
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                isLandlord ? 'Chủ trọ' : 'Khách thuê',
                                style: TextStyle(
                                  color: theme.primaryColor,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            if (_profile?.description != null &&
                                _profile!.description!.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Text(
                                _profile!.description!,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                            OutlinedButton.icon(
                              onPressed: () {
                                if (_profile?.name == null) {
                                  // Chưa có hồ sơ → Tạo mới
                                  Navigator.pushNamed(
                                    context,
                                    AppRoutes.createProfile,
                                    arguments: {'role': _role},
                                  ).then((_) => _loadProfileData());
                                } else {
                                  // Đã có hồ sơ → Chỉnh sửa
                                  Navigator.pushNamed(
                                    context,
                                    AppRoutes.updateProfile,
                                    arguments: {
                                      'profile': _profile,
                                      'role': _role,
                                    },
                                  ).then((_) => _loadProfileData());
                                }
                              },
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              label: Text(
                                _profile?.name == null
                                    ? 'Thiết lập hồ sơ'
                                    : 'Chỉnh sửa hồ sơ',
                              ),
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    Card(
                      child: ListTile(
                        leading: Icon(
                          Icons.event_note_outlined,
                          color: theme.colorScheme.primary,
                        ),
                        title: const Text('Lịch hẹn xem phòng'),
                        subtitle: Text(
                          isLandlord
                              ? 'Quản lý lịch hẹn với khách thuê'
                              : 'Theo dõi lịch xem phòng của bạn',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.pushNamed(
                          context,
                          AppRoutes.appointments,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Card(
                      child: ListTile(
                        leading: Icon(
                          Icons.home_work_outlined,
                          color: theme.colorScheme.primary,
                        ),
                        title: Text(
                          isLandlord ? 'Khách đang thuê' : 'Phòng đang thuê',
                        ),
                        subtitle: Text(
                          isLandlord
                              ? 'Quản lý khách thuê và mã thuê phòng'
                              : 'Xem phòng và xác nhận thuê bằng mã',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () =>
                            Navigator.pushNamed(context, AppRoutes.rentals),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Quick Actions Based on Role
                    Text(
                      isLandlord ? 'Quản lý phòng trọ' : 'Khám phá phòng trọ',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildActionCard(
                            context,
                            icon: isLandlord
                                ? Icons.add_home_outlined
                                : Icons.search,
                            title: isLandlord ? 'Đăng tin phòng' : 'Tìm phòng',
                            color: Colors.blue,
                            onTap: () => Navigator.pushNamed(
                              context,
                              isLandlord
                                  ? AppRoutes.roomForm
                                  : AppRoutes.searchRooms,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildActionCard(
                            context,
                            icon: isLandlord
                                ? Icons.list_alt
                                : Icons.bookmark_border,
                            title: isLandlord
                                ? 'Danh sách phòng'
                                : 'Phòng đã lưu',
                            color: Colors.teal,
                            onTap: isLandlord
                                ? () => Navigator.pushNamed(
                                    context,
                                    AppRoutes.myRooms,
                                  )
                                : () => Navigator.pushNamed(
                                    context,
                                    AppRoutes.savedRooms,
                                  ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildActionCard(
                            context,
                            icon: Icons.chat_bubble_outline,
                            title: 'Tin nhắn',
                            color: Colors.orange,
                            onTap: () => Navigator.pushNamed(
                              context,
                              AppRoutes.chatList,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildActionCard(
                            context,
                            icon: Icons.notifications_none,
                            title: 'Thông báo',
                            color: Colors.purple,
                            onTap: () => Navigator.pushNamed(
                              context,
                              AppRoutes.notifications,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
