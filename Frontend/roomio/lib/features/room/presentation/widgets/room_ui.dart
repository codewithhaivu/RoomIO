import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

String roomMoney(double amount) {
  final parts = amount.toStringAsFixed(0).split('');
  final result = StringBuffer();
  for (var index = 0; index < parts.length; index++) {
    if (index > 0 && (parts.length - index) % 3 == 0) result.write('.');
    result.write(parts[index]);
  }
  return '$result đ';
}

const roomStatuses = <String, String>{
  'AVAILABLE': 'Còn trống',
  'RENTED': 'Đã cho thuê',
  'UNAVAILABLE': 'Tạm ngưng',
};
const roomTypes = <String, String>{
  'ROOM': 'Phòng trọ',
  'STUDIO': 'Studio',
  'APARTMENT': 'Căn hộ',
  'SHARED': 'Ở ghép',
};

String roomError(DioException error) {
  final data = error.response?.data;
  if (data is Map) {
    final detail = data['detail'] ?? data['message'] ?? data['Message'];
    if (detail is String && detail.isNotEmpty) return detail;
    if (detail is List) {
      return 'Thông tin chưa hợp lệ. Vui lòng kiểm tra lại các trường.';
    }
  }
  return switch (error.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.receiveTimeout ||
    DioExceptionType.sendTimeout => 'Kết nối quá lâu. Vui lòng thử lại.',
    DioExceptionType.connectionError =>
      'Không thể kết nối máy chủ. Vui lòng kiểm tra mạng.',
    _ => 'Không thể hoàn tất yêu cầu. Vui lòng thử lại.',
  };
}

void roomSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

class RoomSection extends StatelessWidget {
  final String title;
  final Widget child;
  const RoomSection({super.key, required this.title, required this.child});

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 16),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          child,
        ],
      ),
    ),
  );
}

class RoomMessage extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  const RoomMessage({
    super.key,
    this.icon = Icons.info_outline,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 44, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          if (onAction != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onAction,
              child: Text(actionLabel ?? 'Thử lại'),
            ),
          ],
        ],
      ),
    ),
  );
}

class RoomNetworkImage extends StatelessWidget {
  final String? url;
  final double? height;
  const RoomNetworkImage({super.key, required this.url, this.height});

  @override
  Widget build(BuildContext context) {
    final placeholder = ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Center(child: Icon(Icons.home_outlined, size: 44)),
    );
    return SizedBox(
      height: height,
      width: double.infinity,
      child: url == null || url!.trim().isEmpty
          ? placeholder
          : Image.network(
              url!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => placeholder,
              loadingBuilder: (_, child, progress) =>
                  progress == null ? child : placeholder,
            ),
    );
  }
}

class RoomStatusBadge extends StatelessWidget {
  final String status;
  const RoomStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) => Chip(
    avatar: Icon(
      status == 'AVAILABLE' ? Icons.check_circle_outline : Icons.home_outlined,
      size: 18,
    ),
    label: Text(roomStatuses[status] ?? status),
    visualDensity: VisualDensity.compact,
  );
}

Future<String?> chooseRoomStatus(BuildContext context, String current) {
  return showDialog<String>(
    context: context,
    builder: (context) => SimpleDialog(
      title: const Text('Đổi trạng thái phòng'),
      children: roomStatuses.entries
          .map(
            (entry) => SimpleDialogOption(
              onPressed: entry.key == current
                  ? null
                  : () => Navigator.pop(context, entry.key),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      entry.key == current
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(entry.value)),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    ),
  );
}
