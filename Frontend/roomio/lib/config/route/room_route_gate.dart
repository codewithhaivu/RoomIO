import 'package:flutter/material.dart';
import 'package:roomio/core/storage/secure_storage_service.dart';
import 'package:roomio/features/room/presentation/widgets/room_ui.dart';
import 'package:roomio/injection_container.dart';

/// Vai trò được đọc từ phiên đăng nhập, không lấy từ route arguments.
class RoomRouteGate extends StatefulWidget {
  final bool landlordOnly;
  final bool tenantOnly;
  final Widget Function(BuildContext, bool isLandlord) builder;
  const RoomRouteGate({
    super.key,
    this.landlordOnly = false,
    this.tenantOnly = false,
    required this.builder,
  }) : assert(!landlordOnly || !tenantOnly);
  @override
  State<RoomRouteGate> createState() => _RoomRouteGateState();
}

class _RoomRouteGateState extends State<RoomRouteGate> {
  late Future<String?> _role;
  @override
  void initState() {
    super.initState();
    _role = sl<SecureStorageService>().getRole();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<String?>(
    future: _role,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (snapshot.hasError) {
        return Scaffold(
          appBar: AppBar(),
          body: RoomMessage(
            message: 'Không thể đọc phiên đăng nhập.',
            onAction: () =>
                setState(() => _role = sl<SecureStorageService>().getRole()),
          ),
        );
      }
      final role = snapshot.data;
      final isLandlord = role == 'LANDLORD';
      if (role != 'LANDLORD' && role != 'CUSTOMER' && role != 'TENANT') {
        return Scaffold(
          appBar: AppBar(),
          body: const RoomMessage(message: 'Vui lòng đăng nhập để tiếp tục.'),
        );
      }
      if (widget.landlordOnly && !isLandlord) {
        return Scaffold(
          appBar: AppBar(),
          body: const RoomMessage(message: 'Chức năng này dành cho chủ trọ.'),
        );
      }
      if (widget.tenantOnly && isLandlord) {
        return Scaffold(
          appBar: AppBar(),
          body: const RoomMessage(
            message: 'Chức năng này dành cho khách thuê.',
          ),
        );
      }
      return widget.builder(context, isLandlord);
    },
  );
}
