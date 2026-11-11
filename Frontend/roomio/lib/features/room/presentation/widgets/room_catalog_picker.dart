import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:roomio/features/room/domain/entities/room_sub_entities.dart';
import 'package:roomio/features/room/presentation/bloc/remote/catalog/remote_room_catalog_cubit.dart';
import 'package:roomio/features/room/presentation/widgets/room_ui.dart';

class RoomCatalogPicker extends StatelessWidget {
  final Set<String> interiors;
  final Set<String> amenities;
  final List<InteriorEntity> existingInteriors;
  final List<AmenityEntity> existingAmenities;
  final void Function(String, bool) onInteriorChanged;
  final void Function(String, bool) onAmenityChanged;
  const RoomCatalogPicker({
    super.key,
    required this.interiors,
    required this.amenities,
    required this.onInteriorChanged,
    required this.onAmenityChanged,
    this.existingInteriors = const [],
    this.existingAmenities = const [],
  });

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<RemoteRoomCatalogCubit, RemoteRoomCatalogState>(
        builder: (context, state) {
          final interiorOptions = {
            for (final item in existingInteriors) item.id: item.name,
          };
          final amenityOptions = {
            for (final item in existingAmenities) item.id: item.name,
          };
          if (state is RemoteRoomCatalogSuccess) {
            interiorOptions.addAll({
              for (final item in state.catalog.interiors) item.id: item.name,
            });
            amenityOptions.addAll({
              for (final item in state.catalog.amenities) item.id: item.name,
            });
          }
          Widget options(
            Map<String, String> values,
            Set<String> selected,
            void Function(String, bool) onChanged,
          ) => values.isEmpty
              ? const Text('Chưa có lựa chọn nào.')
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: values.entries
                      .map(
                        (item) => FilterChip(
                          label: Text(item.value),
                          selected: selected.contains(item.key),
                          onSelected: (value) => onChanged(item.key, value),
                        ),
                      )
                      .toList(),
                );
          return RoomSection(
            title: 'Nội thất và tiện ích',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (state is RemoteRoomCatalogLoading)
                  const LinearProgressIndicator(),
                if (state is RemoteRoomCatalogFailure)
                  RoomMessage(
                    message: roomError(state.dio),
                    onAction: context
                        .read<RemoteRoomCatalogCubit>()
                        .loadCatalog,
                  ),
                const Text('Nội thất'),
                const SizedBox(height: 8),
                options(interiorOptions, interiors, onInteriorChanged),
                const SizedBox(height: 16),
                const Text('Tiện ích'),
                const SizedBox(height: 8),
                options(amenityOptions, amenities, onAmenityChanged),
              ],
            ),
          );
        },
      );
}
