import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:roomio/features/room/presentation/widgets/room_ui.dart';

class RentalScanPage extends StatefulWidget {
  const RentalScanPage({super.key});
  @override
  State<RentalScanPage> createState() => _RentalScanPageState();
}

class _RentalScanPageState extends State<RentalScanPage> {
  bool _returned = false;
  void _detected(BarcodeCapture capture) {
    if (_returned || !mounted) return;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value != null && RegExp(r'^[0-9]{6}$').hasMatch(value)) {
        _returned = true;
        Navigator.pop(context, value);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final supported =
        kIsWeb ||
        {
          TargetPlatform.android,
          TargetPlatform.iOS,
          TargetPlatform.macOS,
        }.contains(defaultTargetPlatform);
    return Scaffold(
      appBar: AppBar(title: const Text('Quét mã thuê phòng')),
      body: supported
          ? Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Hướng camera vào mã QR gồm 6 chữ số do chủ trọ cung cấp.',
                  ),
                ),
                Expanded(
                  child: MobileScanner(
                    onDetect: _detected,
                    errorBuilder: (context, error) => RoomMessage(
                      icon: Icons.no_photography_outlined,
                      message:
                          'Không thể mở camera. Hãy kiểm tra quyền máy ảnh hoặc nhập mã thủ công.',
                      actionLabel: 'Nhập mã thủ công',
                      onAction: () => Navigator.pop(context),
                    ),
                  ),
                ),
              ],
            )
          : const RoomMessage(
              message:
                  'Thiết bị này chưa hỗ trợ quét QR. Hãy nhập mã 6 chữ số từ chủ trọ.',
            ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: OutlinedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Nhập mã thủ công'),
        ),
      ),
    );
  }
}
