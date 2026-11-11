import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:roomio/features/room/presentation/widgets/room_ui.dart';
import 'package:roomio/features/saved_room/presentation/cubit/saved_rooms_cubit.dart';
import 'package:roomio/features/saved_room/presentation/cubit/saved_rooms_state.dart';
import 'package:roomio/injection_container.dart';

/// Route providers reuse the same session Cubit; popping a route must not close it.
class SavedRoomsScope extends StatelessWidget {
  final Widget child;
  const SavedRoomsScope({super.key, required this.child});

  @override
  Widget build(BuildContext context) => BlocProvider.value(
    value: sl<SavedRoomsCubit>(),
    child: BlocListener<SavedRoomsCubit, SavedRoomsState>(
      listenWhen: (previous, current) =>
          current.failureSequence > previous.failureSequence,
      listener: (context, state) {
        // A search route underneath SavedRoomsPage must not show a second SnackBar.
        if (ModalRoute.of(context)?.isCurrent == false) return;
        final error = state.mutationError;
        if (error != null) roomSnackBar(context, roomError(error));
      },
      child: child,
    ),
  );
}
