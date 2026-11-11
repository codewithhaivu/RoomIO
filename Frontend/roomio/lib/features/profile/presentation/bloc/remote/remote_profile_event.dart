abstract class RemoteProfileEvent{
  const RemoteProfileEvent();
}

class CreateProfileEvent extends RemoteProfileEvent{
  final String name;
  final String gender;
  final String description;
  final String avatarUrl;

  const CreateProfileEvent({
    required this.name,
    required this.gender,
    required this.description,
    required this.avatarUrl,
  });
}

class UpdateProfileEvent extends RemoteProfileEvent{
  final String? name;
  final String? gender;
  final String? description;
  final String? avatarUrl;

  const UpdateProfileEvent({
    this.name,
    this.gender,
    this.description,
    this.avatarUrl,
  });
}

// ignore: camel_case_types
class getProfileEvent extends RemoteProfileEvent{
  const getProfileEvent();
}

class UploadAvatarEvent extends RemoteProfileEvent{
  final String avatarUrl;

  const UploadAvatarEvent({required this.avatarUrl});
}