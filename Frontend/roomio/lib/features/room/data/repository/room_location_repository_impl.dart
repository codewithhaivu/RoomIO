import 'dart:async';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:roomio/features/room/data/data_sources/local/room_location_data_source.dart';
import 'package:roomio/features/room/domain/entities/room_location_error.dart';
import 'package:roomio/features/room/domain/entities/room_sub_entities.dart';
import 'package:roomio/features/room/domain/repository/room_location_repository.dart';

class RoomLocationRepositoryImpl implements RoomLocationRepository {
  final RoomLocationDataSource _dataSource;
  RoomLocationRepositoryImpl(this._dataSource);

  Future<T> _run<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on RoomLocationException {
      rethrow;
    } on TimeoutException {
      throw const RoomLocationException(RoomLocationIssue.timeout);
    } on LocationServiceDisabledException {
      throw const RoomLocationException(RoomLocationIssue.serviceDisabled);
    } on PermissionDeniedException {
      throw const RoomLocationException(RoomLocationIssue.permissionDenied);
    } on MissingPluginException {
      throw const RoomLocationException(RoomLocationIssue.unsupported);
    } on UnsupportedError {
      throw const RoomLocationException(RoomLocationIssue.unsupported);
    } on PlatformException catch (error) {
      throw RoomLocationException(
        error.code == 'NOT_FOUND' || error.code == 'NoResultFound'
            ? RoomLocationIssue.addressNotFound
            : RoomLocationIssue.unavailable,
      );
    } on Exception {
      throw const RoomLocationException(RoomLocationIssue.unavailable);
    }
  }

  @override
  Future<LocationEntity> getCurrentLocation() =>
      _run(_dataSource.getCurrentLocation);
  @override
  Future<List<LocationEntity>> searchLocations(String address) =>
      _run(() => _dataSource.searchLocations(address));
  @override
  Future<LocationEntity> reverseGeocode(LocationEntity location) =>
      _run(() => _dataSource.reverseGeocode(location));
  @override
  Future<bool> openSettings(RoomLocationSettings settings) =>
      _run(() => _dataSource.openSettings(settings));
}
