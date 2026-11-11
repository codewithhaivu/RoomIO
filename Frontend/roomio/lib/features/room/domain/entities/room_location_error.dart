enum RoomLocationIssue {
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  timeout,
  addressNotFound,
  unsupported,
  unavailable,
}

class RoomLocationException implements Exception {
  final RoomLocationIssue issue;
  const RoomLocationException(this.issue);
}

enum RoomLocationSettings { app, location }
