import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:roomio/features/room/domain/entities/room_entities.dart';
import 'package:roomio/features/room/presentation/bloc/remote/landlord/room_form_location_cubit.dart';
import 'package:roomio/features/room/presentation/widgets/room_location_picker.dart';
import 'package:roomio/features/room/domain/entities/room_request_entities.dart';
import 'package:roomio/features/room/domain/entities/room_sub_entities.dart';
import 'package:roomio/features/room/presentation/bloc/remote/landlord/remote_landlord_room_bloc.dart';
import 'package:roomio/features/room/presentation/bloc/remote/landlord/remote_landlord_room_event.dart';
import 'package:roomio/features/room/presentation/bloc/remote/landlord/remote_landlord_room_state.dart';
import 'package:roomio/features/room/presentation/widgets/room_catalog_picker.dart';
import 'package:roomio/features/room/presentation/widgets/room_photo_picker.dart';
import 'package:roomio/features/room/presentation/widgets/room_input.dart';
import 'package:roomio/features/room/presentation/widgets/room_ui.dart';

class RoomFormPage extends StatefulWidget {
  final RoomEntity? initialRoom;
  const RoomFormPage({super.key, this.initialRoom});
  @override
  State<RoomFormPage> createState() => _RoomFormPageState();
}

class _RoomFormPageState extends State<RoomFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _fields = <String, TextEditingController>{};
  final _interiors = <String>{};
  final _amenities = <String>{};
  final _images = <RoomImageEntity>[];
  final _files = <File>[];
  String _status = 'AVAILABLE';
  String _roomType = 'ROOM';
  int _thumbnailIndex = 0;
  bool _picking = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final room = widget.initialRoom;
    final values = <String, String>{
      'name': room?.name ?? '',
      'area': room?.area.toString() ?? '',
      'rentalPrice': room?.rentalPrice.toString() ?? '',
      'electricityFee': room?.electricityFee.toString() ?? '0',
      'waterFee': room?.waterFee.toString() ?? '0',
      'serviceFee': room?.serviceFee.toString() ?? '0',
      'parkingFee': room?.parkingFee.toString() ?? '0',
    };
    for (final entry in values.entries) {
      _fields[entry.key] = TextEditingController(text: entry.value);
    }
    if (room != null) {
      _status = room.status;
      _roomType = room.roomType;
      _interiors.addAll(room.interiors.map((item) => item.id));
      _amenities.addAll(room.amenities.map((item) => item.id));
      _images.addAll(room.images);
      final thumbnail = _images.indexWhere((image) => image.isThumbnail);
      _thumbnailIndex = thumbnail < 0 ? 0 : thumbnail;
    }
  }

  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickPhotos() async {
    if (_picking || _saving) return;
    setState(() => _picking = true);
    try {
      final picked = await ImagePicker().pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (!mounted) return;
      setState(() {
        final paths = _files.map((file) => file.path).toSet();
        _files.addAll(
          picked
              .where((file) => paths.add(file.path))
              .map((file) => File(file.path)),
        );
      });
    } catch (_) {
      if (mounted) {
        roomSnackBar(context, 'Không thể chọn ảnh. Vui lòng thử lại.');
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  void _removePhoto(int index) {
    setState(() {
      if (index < _images.length) {
        _images.removeAt(index);
      } else {
        _files.removeAt(index - _images.length);
      }
      if (index < _thumbnailIndex) _thumbnailIndex--;
      if (_thumbnailIndex >= _images.length + _files.length) {
        _thumbnailIndex = 0;
      }
    });
  }

  void _save() {
    final locationState = context.read<RoomFormLocationCubit>().state;
    if (_saving ||
        _picking ||
        locationState.busy ||
        !_formKey.currentState!.validate()) {
      return;
    }
    final location = locationState.location;
    if (location == null) return;
    if (_images.isEmpty && _files.isEmpty) {
      roomSnackBar(context, 'Vui lòng chọn ít nhất một ảnh phòng.');
      return;
    }
    FocusScope.of(context).unfocus();
    final images = List<RoomImageEntity>.generate(
      _images.length,
      (index) => RoomImageEntity(
        imageUrl: _images[index].imageUrl,
        publicId: _images[index].publicId,
        isThumbnail: index == _thumbnailIndex,
      ),
    );
    final upload = _files.isEmpty
        ? null
        : UploadRoomImagesRequestEntity(
            images: List<File>.of(_files),
            isThumbnails: List<bool>.generate(
              _files.length,
              (index) => index + _images.length == _thumbnailIndex,
            ),
          );
    setState(() => _saving = true);
    final bloc = context.read<RemoteLandlordRoomBloc>();
    if (widget.initialRoom == null) {
      bloc.add(
        PostRoomEvent(
          request: PostRoomRequestEntity(
            name: _fields['name']!.text.trim(),
            area: roomNumber(_fields['area']!),
            waterFee: roomNumber(_fields['waterFee']!),
            serviceFee: roomNumber(_fields['serviceFee']!),
            parkingFee: roomNumber(_fields['parkingFee']!),
            rentalPrice: roomNumber(_fields['rentalPrice']!),
            electricityFee: roomNumber(_fields['electricityFee']!),
            status: _status,
            roomType: _roomType,
            location: location,
            interiors: _interiors.toList(),
            amenities: _amenities.toList(),
            images: images,
          ),
          uploadRequest: upload,
        ),
      );
    } else {
      bloc.add(
        UpdateRoomEvent(
          request: UpdateRoomRequestEntity(
            roomId: widget.initialRoom!.id,
            name: _fields['name']!.text.trim(),
            area: roomNumber(_fields['area']!),
            waterFee: roomNumber(_fields['waterFee']!),
            serviceFee: roomNumber(_fields['serviceFee']!),
            parkingFee: roomNumber(_fields['parkingFee']!),
            rentalPrice: roomNumber(_fields['rentalPrice']!),
            electricityFee: roomNumber(_fields['electricityFee']!),
            status: _status,
            roomType: _roomType,
            location: location,
            interiors: _interiors.toList(),
            amenities: _amenities.toList(),
            images: images,
          ),
          uploadRequest: upload,
        ),
      );
    }
  }

  Widget _dropdown(
    String label,
    String value,
    Map<String, String> choices,
    ValueChanged<String> onChanged,
  ) {
    final options = {...choices, if (!choices.containsKey(value)) value: value};
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: options.entries
            .map(
              (entry) =>
                  DropdownMenuItem(value: entry.key, child: Text(entry.value)),
            )
            .toList(),
        onChanged: (value) {
          if (value != null) onChanged(value);
        },
      ),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<RoomFormLocationCubit, RoomFormLocationState>(
    builder: (context, locationState) =>
        BlocConsumer<RemoteLandlordRoomBloc, RemoteLandlordRoomState>(
          listener: (context, state) {
            if (state is RemotePostRoomSuccess ||
                state is RemoteUpdateRoomSuccess) {
              setState(() => _saving = false);
              roomSnackBar(
                context,
                widget.initialRoom == null
                    ? 'Đăng phòng thành công!'
                    : 'Cập nhật phòng thành công!',
              );
              Navigator.pop(context, true);
            } else if (state is RemoteLandlordRoomFailure) {
              setState(() => _saving = false);
              roomSnackBar(context, roomError(state.dio));
            }
          },
          builder: (context, state) {
            final busy = _saving || state is RemoteLandlordRoomLoading;
            final resolvingLocation = locationState.busy;
            return PopScope(
              canPop: !busy,
              child: Scaffold(
                appBar: AppBar(
                  title: Text(
                    widget.initialRoom == null ? 'Đăng tin phòng' : 'Sửa phòng',
                  ),
                ),
                body: SafeArea(
                  child: Column(
                    children: [
                      if (busy) const LinearProgressIndicator(),
                      Expanded(
                        child: AbsorbPointer(
                          absorbing: busy || _picking,
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                children: [
                                  RoomSection(
                                    title: 'Thông tin phòng',
                                    child: Column(
                                      children: [
                                        RoomInput(
                                          label: 'Tên phòng',
                                          controller: _fields['name']!,
                                        ),
                                        _dropdown(
                                          'Loại phòng',
                                          _roomType,
                                          roomTypes,
                                          (value) =>
                                              setState(() => _roomType = value),
                                        ),
                                        _dropdown(
                                          'Trạng thái',
                                          _status,
                                          roomStatuses,
                                          (value) =>
                                              setState(() => _status = value),
                                        ),
                                        RoomInput(
                                          label: 'Diện tích (m²)',
                                          controller: _fields['area']!,
                                          numeric: true,
                                          minimum: 0.01,
                                        ),
                                        RoomInput(
                                          label: 'Giá thuê (đ/tháng)',
                                          controller: _fields['rentalPrice']!,
                                          numeric: true,
                                          minimum: 1,
                                        ),
                                        RoomInput(
                                          label: 'Tiền điện (đ/kWh)',
                                          controller:
                                              _fields['electricityFee']!,
                                          numeric: true,
                                          minimum: 0,
                                        ),
                                        RoomInput(
                                          label: 'Tiền nước (đ/tháng)',
                                          controller: _fields['waterFee']!,
                                          numeric: true,
                                          minimum: 0,
                                        ),
                                        RoomInput(
                                          label: 'Phí dịch vụ (đ/tháng)',
                                          controller: _fields['serviceFee']!,
                                          numeric: true,
                                          minimum: 0,
                                        ),
                                        RoomInput(
                                          label: 'Phí gửi xe (đ/tháng)',
                                          controller: _fields['parkingFee']!,
                                          numeric: true,
                                          minimum: 0,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const RoomLocationPicker(),
                                  RoomCatalogPicker(
                                    interiors: _interiors,
                                    amenities: _amenities,
                                    existingInteriors:
                                        widget.initialRoom?.interiors ?? [],
                                    existingAmenities:
                                        widget.initialRoom?.amenities ?? [],
                                    onInteriorChanged: (id, selected) =>
                                        setState(() {
                                          if (selected) {
                                            _interiors.add(id);
                                          } else {
                                            _interiors.remove(id);
                                          }
                                        }),
                                    onAmenityChanged: (id, selected) =>
                                        setState(() {
                                          if (selected) {
                                            _amenities.add(id);
                                          } else {
                                            _amenities.remove(id);
                                          }
                                        }),
                                  ),
                                  RoomPhotoPicker(
                                    images: _images,
                                    files: _files,
                                    thumbnailIndex: _thumbnailIndex,
                                    onPick: _pickPhotos,
                                    onRemove: _removePhoto,
                                    onThumbnailChanged: (index) =>
                                        setState(() => _thumbnailIndex = index),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: busy || _picking || resolvingLocation
                                ? null
                                : _save,
                            icon: busy || _picking || resolvingLocation
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.check),
                            label: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              child: Text(
                                busy
                                    ? 'Đang tải ảnh và lưu phòng…'
                                    : resolvingLocation
                                    ? 'Đang xác định địa chỉ…'
                                    : _picking
                                    ? 'Đang chọn ảnh…'
                                    : widget.initialRoom == null
                                    ? 'Đăng phòng'
                                    : 'Lưu thay đổi',
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
  );
}
