import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:roomio/features/room/domain/entities/room_location_error.dart';
import 'package:roomio/features/room/presentation/bloc/remote/landlord/room_form_location_cubit.dart';
import 'package:roomio/features/room/presentation/widgets/room_ui.dart';

class RoomLocationPicker extends StatefulWidget {
  const RoomLocationPicker({super.key});
  @override
  State<RoomLocationPicker> createState() => _RoomLocationPickerState();
}

class _RoomLocationPickerState extends State<RoomLocationPicker> {
  late final TextEditingController _address;
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _address = TextEditingController(
      text: context.read<RoomFormLocationCubit>().state.query,
    );
  }

  @override
  void dispose() {
    _address.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<RoomFormLocationCubit, RoomFormLocationState>(
    listener: (context, state) {
      if (_address.text != state.query) {
        _address.value = TextEditingValue(
          text: state.query,
          selection: TextSelection.collapsed(offset: state.query.length),
        );
      }
    },
    builder: (context, state) {
      final cubit = context.read<RoomFormLocationCubit>();
      final locating = state.status == RoomFormLocationStatus.locating;
      return RoomSection(
        title: 'Vị trí',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              key: const ValueKey('room-form-address'),
              controller: _address,
              focusNode: _focus,
              enabled: !state.busy,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: 'Địa chỉ / tên vị trí',
                errorMaxLines: 3,
                hintText: 'Nhập tên đường, phường hoặc địa chỉ',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: state.status == RoomFormLocationStatus.suggesting
                    ? const Padding(
                        padding: EdgeInsets.all(16),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : _address.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Xóa địa chỉ',
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _address.clear();
                          cubit.queryChanged('');
                          _focus.requestFocus();
                        },
                      ),
              ),
              onChanged: cubit.queryChanged,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Vui lòng chọn địa chỉ phòng.';
                }
                if (state.location == null ||
                    value.trim() != state.location!.name) {
                  return 'Chọn địa chỉ từ gợi ý hoặc sử dụng vị trí hiện tại.';
                }
                return null;
              },
            ),
            if (state.suggestions.isNotEmpty)
              Card(
                elevation: 1,
                margin: const EdgeInsets.only(top: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ...state.suggestions.map(
                      (suggestion) => ListTile(
                        dense: true,
                        leading: const Icon(
                          Icons.location_on_outlined,
                          size: 20,
                        ),
                        title: Text(suggestion.description),
                        onTap: () {
                          _focus.unfocus();
                          cubit.selectSuggestion(suggestion);
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                      child: Text(
                        'Goong Maps',
                        textAlign: TextAlign.end,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : const Color(0xFF5E5E5E),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: state.busy
                    ? null
                    : () {
                        _focus.unfocus();
                        cubit.useCurrentLocation();
                      },
                icon: const Icon(Icons.my_location, size: 20),
                label: Text(
                  locating
                      ? 'Đang xác định địa chỉ…'
                      : 'Sử dụng vị trí hiện tại',
                ),
              ),
            ),
            if (state.busy) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: 8),
              Text(
                locating
                    ? 'Đang lấy GPS và tên đường…'
                    : 'Đang xác nhận địa chỉ…',
              ),
            ],
            if (state.error != null) ...[
              const SizedBox(height: 8),
              Text(
                state.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              Wrap(
                spacing: 8,
                children: [
                  if (state.locationIssue ==
                          RoomLocationIssue.serviceDisabled ||
                      state.locationIssue ==
                          RoomLocationIssue.permissionDeniedForever)
                    TextButton(
                      onPressed: cubit.openSettings,
                      child: const Text('Mở cài đặt'),
                    ),
                  TextButton(
                    onPressed: () {
                      if (state.locationIssue != null) {
                        cubit.useCurrentLocation();
                      } else {
                        cubit.queryChanged(_address.text);
                      }
                    },
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            ],
            if (state.location != null)
              Row(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('Đã xác định vị trí phòng')),
                ],
              ),
          ],
        ),
      );
    },
  );
}
