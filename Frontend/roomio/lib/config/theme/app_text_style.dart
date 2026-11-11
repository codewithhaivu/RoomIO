import 'package:flutter/material.dart';

class AppTextStyle {
  // Định nghĩa các bộ chữ dùng chung cho toàn App
  static TextTheme get textTheme {
    return const TextTheme(
      // 1. Nhóm TITLE (Dành cho Tiêu đề màn hình, ví dụ: "Xin chào, Anh Hải", "Đăng nhập")
      titleLarge: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold, // Sẽ tự nhận file BeVietnamPro-Bold.ttf
      ),
      titleMedium: TextStyle(
        fontSize: 20,
        fontWeight:
            FontWeight.w600, // Sẽ tự nhận file BeVietnamPro-SemiBold.ttf
      ),

      // 2. Nhóm BODY (Dành cho văn bản đọc bình thường, mô tả)
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight:
            FontWeight.normal, // Sẽ tự nhận file BeVietnamPro-Regular.ttf
      ),
      bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.normal),

      // 3. Nhóm LABEL (Dành cho chữ bên trong Nút bấm, Ô TextField...)
      labelLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    );
  }
}

// ==========================================
// MẸO CHUYÊN NGHIỆP: EXTENSION GIÚP GÕ CODE UI SIÊU NHANH
// ==========================================
extension TextStyleExtension on BuildContext {
  // Thay vì phải gõ dài dòng: Theme.of(context).textTheme.titleLarge
  // Bạn chỉ cần gõ: context.titleLarge

  TextStyle? get titleLarge => Theme.of(this).textTheme.titleLarge;
  TextStyle? get titleMedium => Theme.of(this).textTheme.titleMedium;
  TextStyle? get bodyLarge => Theme.of(this).textTheme.bodyLarge;
  TextStyle? get bodyMedium => Theme.of(this).textTheme.bodyMedium;
  TextStyle? get labelLarge => Theme.of(this).textTheme.labelLarge;
}
