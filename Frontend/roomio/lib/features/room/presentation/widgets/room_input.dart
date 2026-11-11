import 'package:flutter/material.dart';

class RoomInput extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool numeric;
  final bool requiredValue;
  final double? minimum;
  final double? maximum;
  final String? helperText;
  final int maxLines;
  final String? Function(String?)? validator;

  const RoomInput({
    super.key,
    required this.label,
    required this.controller,
    this.numeric = false,
    this.requiredValue = true,
    this.minimum,
    this.maximum,
    this.helperText,
    this.maxLines = 1,
    this.validator,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
        helperMaxLines: 3,
      ),
      maxLines: maxLines,
      keyboardType: numeric
          ? const TextInputType.numberWithOptions(decimal: true, signed: true)
          : null,
      validator:
          validator ??
          (value) {
            final text = value?.trim() ?? '';
            if (text.isEmpty) {
              return requiredValue ? 'Vui lòng nhập $label' : null;
            }
            if (!numeric) return null;
            final number = double.tryParse(text.replaceAll(',', '.'));
            if (number == null || !number.isFinite) {
              return 'Vui lòng nhập số hợp lệ';
            }
            if (minimum != null && number < minimum!) {
              return 'Giá trị tối thiểu là $minimum';
            }
            if (maximum != null && number > maximum!) {
              return 'Giá trị tối đa là $maximum';
            }
            return null;
          },
    ),
  );
}

double roomNumber(TextEditingController controller) =>
    double.parse(controller.text.trim().replaceAll(',', '.'));
