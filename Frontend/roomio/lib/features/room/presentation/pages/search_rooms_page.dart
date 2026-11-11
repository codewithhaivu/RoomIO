import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:roomio/config/route/app_route.dart';
import 'package:roomio/features/room/domain/entities/room_location_error.dart';
import 'package:roomio/features/room/domain/entities/room_place_suggestion.dart';
import 'package:roomio/features/room/domain/entities/room_request_entities.dart';
import 'package:roomio/features/room/presentation/bloc/remote/tenant/remote_tenant_room_bloc.dart';
import 'package:roomio/features/room/presentation/bloc/remote/tenant/remote_tenant_room_event.dart';
import 'package:roomio/features/room/presentation/bloc/remote/tenant/remote_tenant_room_state.dart';
import 'package:roomio/features/saved_room/domain/entities/save_room.dart';
import 'package:roomio/features/saved_room/presentation/cubit/saved_rooms_cubit.dart';
import 'package:roomio/features/saved_room/presentation/widgets/saved_room_card.dart';
import 'package:roomio/features/room/presentation/widgets/room_ui.dart';

class SearchRoomsPage extends StatefulWidget {
  final bool canSaveRooms;
  const SearchRoomsPage({super.key, this.canSaveRooms = true});
  @override
  State<SearchRoomsPage> createState() => _SearchRoomsPageState();
}

class _SearchRoomsPageState extends State<SearchRoomsPage> {
  final _address = TextEditingController();
  final _focusNode = FocusNode();
  double _radius = 10;
  LocationSuggestion? _selectedArea;

  @override
  void initState() {
    super.initState();
    context.read<RemoteTenantRoomBloc>().add(
      const GetLocationSuggestionsEvent(),
    );
  }

  @override
  void dispose() {
    _address.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _findAddress([String? address]) {
    final query = (address ?? _address.text).trim();
    if (query.isEmpty) {
      roomSnackBar(
        context,
        'Nhập vị trí bạn muốn tìm hoặc chọn Vị trí của bạn.',
      );
      _focusNode.requestFocus();
      return;
    }
    final suggestions = context
        .read<RemoteTenantRoomBloc>()
        .locationSuggestionsState;
    if (suggestions is RemoteLocationSuggestionsSuccess) {
      for (final location in suggestions.locations) {
        if (location.nameDistrict.toLowerCase() == query.toLowerCase()) {
          _selectArea(location);
          return;
        }
      }
    }
    _selectedArea = null;
    _address.text = query;
    _focusNode.unfocus();
    context.read<RemoteTenantRoomBloc>().add(
      SearchRoomsByAddressEvent(address: query, radius: _radius),
    );
    setState(() {});
  }

  void _selectArea(LocationSuggestion location) {
    setState(() {
      _selectedArea = location;
      _address.text = location.nameDistrict;
    });
    _focusNode.unfocus();
    _searchArea(location, _radius);
  }

  void _searchArea(LocationSuggestion location, double radius) {
    context.read<RemoteTenantRoomBloc>().add(
      SearchRoomsByAreaEvent(
        request: SearchRoomsByAreaRequestEntity(
          locationId: location.locationId,
          district: location.nameDistrict,
          radius: radius,
        ),
      ),
    );
  }

  void _nearMe() {
    _selectedArea = null;
    _focusNode.unfocus();
    context.read<RemoteTenantRoomBloc>().add(
      SearchRoomsNearMeEvent(radius: _radius),
    );
  }

  void _changeRadius(double value, RemoteTenantRoomState state) {
    setState(() => _radius = value);
    if (state is RemoteSearchRoomsSuccess && _selectedArea != null) {
      _searchArea(_selectedArea!, value);
    } else if (state is RemoteSearchRoomsSuccess && state.location != null) {
      context.read<RemoteTenantRoomBloc>().add(
        SearchRoomsAtLocationEvent(location: state.location!, radius: value),
      );
    }
  }

  String _locationError(RoomLocationIssue issue) => switch (issue) {
    RoomLocationIssue.serviceDisabled =>
      'GPS đang tắt. Bật dịch vụ vị trí để tìm phòng ở gần bạn.',
    RoomLocationIssue.permissionDenied =>
      'Bạn chưa cho phép truy cập vị trí. Hãy thử lại hoặc tìm bằng tên địa điểm.',
    RoomLocationIssue.permissionDeniedForever =>
      'Quyền vị trí đang bị chặn. Bạn có thể cấp lại quyền trong cài đặt ứng dụng.',
    RoomLocationIssue.timeout =>
      'Chưa xác định được vị trí. Kiểm tra kết nối hoặc thử một địa điểm cụ thể hơn.',
    RoomLocationIssue.addressNotFound =>
      'Không tìm thấy địa điểm. Hãy nhập thêm tên đường, quận hoặc thành phố.',
    RoomLocationIssue.unsupported =>
      'Thiết bị này chưa hỗ trợ tra cứu vị trí. Hãy dùng ứng dụng trên Android hoặc iOS.',
    RoomLocationIssue.unavailable =>
      'Dịch vụ vị trí chưa sẵn sàng. Vui lòng kiểm tra kết nối và thử lại.',
  };

  Widget _failure(RoomLocationIssue issue) {
    final settings = switch (issue) {
      RoomLocationIssue.serviceDisabled => RoomLocationSettings.location,
      RoomLocationIssue.permissionDeniedForever => RoomLocationSettings.app,
      _ => null,
    };
    return RoomSection(
      title: 'Chưa thể tìm phòng',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(_locationError(issue)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (settings != null)
                FilledButton.icon(
                  onPressed: () => context.read<RemoteTenantRoomBloc>().add(
                    OpenRoomLocationSettingsEvent(settings: settings),
                  ),
                  icon: const Icon(Icons.settings_outlined),
                  label: Text(
                    settings == RoomLocationSettings.location
                        ? 'Bật vị trí'
                        : 'Mở cài đặt',
                  ),
                ),
              OutlinedButton(
                onPressed: () => context.read<RemoteTenantRoomBloc>().add(
                  const RetryRoomSearchEvent(),
                ),
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _popularPlaces() {
    final status = context
        .read<RemoteTenantRoomBloc>()
        .locationSuggestionsState;
    final query = _address.text.trim().toLowerCase();
    final locations = status is RemoteLocationSuggestionsSuccess
        ? status.locations
        : const <LocationSuggestion>[];
    final suggestions = locations
        .where((item) => item.nameDistrict.toLowerCase().contains(query))
        .toList();
    return RoomSection(
      title: query.isEmpty ? 'Địa điểm gợi ý' : 'Chọn địa điểm',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (query.isNotEmpty)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.search),
              title: Text('Tìm “${_address.text.trim()}”'),
              subtitle: const Text('Tìm địa điểm và các phòng xung quanh'),
              onTap: _findAddress,
            ),
          if (status is RemoteLocationSuggestionsLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (status is RemoteLocationSuggestionsFailure)
            RoomMessage(
              message: roomError(status.dio),
              onAction: () => context.read<RemoteTenantRoomBloc>().add(
                const GetLocationSuggestionsEvent(),
              ),
            ),
          if (status is RemoteLocationSuggestionsSuccess && suggestions.isEmpty)
            Text(
              query.isEmpty
                  ? 'Chưa có khu vực gợi ý.'
                  : 'Không có khu vực phù hợp với tên đã nhập.',
            ),
          ...suggestions.map(
            (item) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.location_on_outlined),
              title: Text(item.nameDistrict),
              subtitle: const Text('Tìm phòng trong khu vực này'),
              trailing: const Icon(Icons.north_west, size: 18),
              onTap: () => _selectArea(item),
            ),
          ),
          if (query.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Bạn cũng có thể nhập tên đường, trường học hoặc địa chỉ cụ thể.',
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Tìm phòng'),
      actions: [
        if (widget.canSaveRooms)
          IconButton(
            tooltip: 'Phòng đã lưu',
            icon: const Icon(Icons.favorite_border),
            onPressed: () => Navigator.pushNamed(context, AppRoutes.savedRooms),
          ),
      ],
    ),
    body: SafeArea(
      child: BlocConsumer<RemoteTenantRoomBloc, RemoteTenantRoomState>(
        listener: (context, state) {
          final search = state is RemoteLocationSuggestionsState
              ? state.searchState
              : state;
          if (search is RemoteSearchRoomsSuccess && widget.canSaveRooms) {
            context.read<SavedRoomsCubit>().observeRooms(search.rooms);
          }
          if (state is RemoteSearchRoomsSuccess && state.location != null) {
            _address.text = state.location!.name;
          }
        },
        builder: (context, blocState) {
          final state = blocState is RemoteLocationSuggestionsState
              ? blocState.searchState
              : blocState;
          final busy =
              state is RemoteTenantRoomLoading ||
              state is RemoteDeterminingRoomLocation ||
              state is RemoteResolvingRoomAddress;
          final message = state is RemoteDeterminingRoomLocation
              ? 'Đang xác định vị trí của bạn…'
              : state is RemoteResolvingRoomAddress
              ? 'Đang tìm địa điểm…'
              : 'Đang tìm phòng quanh đây…';
          return ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Bạn muốn tìm phòng ở đâu?',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextField(
                key: const ValueKey('room-location-search'),
                controller: _address,
                focusNode: _focusNode,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Nhập vị trí bạn muốn tìm',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _address.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Xóa tìm kiếm',
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _selectedArea = null;
                            _address.clear();
                            context.read<RemoteTenantRoomBloc>().add(
                              const ResetRoomLocationSearchEvent(),
                            );
                            setState(() {});
                            _focusNode.requestFocus();
                          },
                        ),
                ),
                onChanged: (_) {
                  _selectedArea = null;
                  context.read<RemoteTenantRoomBloc>().add(
                    const ResetRoomLocationSearchEvent(),
                  );
                  setState(() {});
                },
                onSubmitted: _findAddress,
              ),
              const SizedBox(height: 12),
              Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primaryContainer,
                    child: Icon(
                      Icons.my_location,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  title: const Text('Vị trí của bạn'),
                  subtitle: const Text('Tự động tìm phòng gần vị trí hiện tại'),
                  trailing: state is RemoteDeterminingRoomLocation
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.chevron_right),
                  onTap: busy ? null : _nearMe,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Bán kính tìm kiếm',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [3.0, 5.0, 10.0, 20.0]
                    .map(
                      (value) => ChoiceChip(
                        label: Text('${value.toInt()} km'),
                        selected: _radius == value,
                        onSelected: busy
                            ? null
                            : (_) => _changeRadius(value, state),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 20),
              if (busy)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(message, textAlign: TextAlign.center),
                    ],
                  ),
                ),
              if (state is RemoteTenantRoomInitial) _popularPlaces(),
              if (state is RemoteRoomLocationFailure) _failure(state.issue),
              if (state is RemoteTenantRoomFailure)
                RoomMessage(
                  message: roomError(state.dio),
                  onAction: () => context.read<RemoteTenantRoomBloc>().add(
                    const RetryRoomSearchEvent(),
                  ),
                ),
              if (state is RemoteRoomLocationChoices)
                RoomSection(
                  title: 'Chọn địa điểm phù hợp',
                  child: Column(
                    children: state.locations
                        .map(
                          (location) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.place_outlined),
                            title: Text(location.name),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              _selectedArea = null;
                              _focusNode.unfocus();
                              context.read<RemoteTenantRoomBloc>().add(
                                SearchRoomsAtLocationEvent(
                                  location: location,
                                  radius: _radius,
                                ),
                              );
                            },
                          ),
                        )
                        .toList(),
                  ),
                ),
              if (state is RemoteSearchRoomsSuccess) ...[
                Text(
                  'Tìm thấy ${state.rooms.length} phòng',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (state.location != null)
                  Text(
                    'Quanh ${state.location!.name} · Bán kính ${(state.radius ?? _radius).toInt()} km',
                  ),
                if (_selectedArea != null)
                  Text(
                    '${_selectedArea!.nameDistrict} · Bán kính ${_radius.toInt()} km',
                  ),
                const SizedBox(height: 16),
                if (state.rooms.isEmpty)
                  const RoomMessage(
                    message:
                        'Chưa có phòng trong khu vực này. Hãy thử tăng bán kính hoặc chọn nơi khác.',
                  ),
                ...state.rooms.map(
                  (room) => SavedRoomCard(
                    key: ValueKey(room.id),
                    room: RoomResponse.fromNearbyRoom(room),
                    distance: room.distance,
                    initiallySaved: room.isSaved,
                    enableSaving: widget.canSaveRooms,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    ),
  );
}
