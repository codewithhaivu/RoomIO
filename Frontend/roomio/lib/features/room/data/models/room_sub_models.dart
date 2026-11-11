import 'package:roomio/features/room/domain/entities/room_place_suggestion.dart';
import 'package:roomio/features/room/domain/entities/room_sub_entities.dart';

class LocationModel extends LocationEntity {
  const LocationModel({
    required super.name,
    required super.longitude,
    required super.latitude,
  });

  factory LocationModel.fromEntity(LocationEntity entity) {
    return LocationModel(
      name: entity.name,
      longitude: entity.longitude,
      latitude: entity.latitude,
    );
  }

  factory LocationModel.fromJson(Map<String, dynamic> json) {
    return LocationModel(
      name: json['name'] ?? '',
      longitude: (json['longitude'] as num).toDouble(),
      latitude: (json['latitude'] as num).toDouble(),
    );
  }
  Map<String, dynamic> toJson() {
    return {"name": name, "longitude": longitude, "latitude": latitude};
  }
}

class InteriorModel extends InteriorEntity {
  const InteriorModel({required super.id, required super.name});
  factory InteriorModel.fromJson(Map<String, dynamic> json) {
    return InteriorModel(id: json['id'] ?? '', name: json['name'] ?? '');
  }
}

class AmenityModel extends AmenityEntity {
  const AmenityModel({required super.id, required super.name});
  factory AmenityModel.fromJson(Map<String, dynamic> json) {
    return AmenityModel(id: json['id'] ?? '', name: json['name'] ?? '');
  }
}

class RoomImageModel extends RoomImageEntity {
  const RoomImageModel({
    required super.imageUrl,
    required super.publicId,
    required super.isThumbnail,
  });

  factory RoomImageModel.fromJson(Map<String, dynamic> json) {
    return RoomImageModel(
      imageUrl: json['image_url'] ?? '',
      publicId: json['public_id'] ?? '',
      isThumbnail: json['is_thumbnail'] ?? false,
    );
  }

  factory RoomImageModel.fromEntity(RoomImageEntity entity) {
    return RoomImageModel(
      imageUrl: entity.imageUrl,
      publicId: entity.publicId,
      isThumbnail: entity.isThumbnail,
    );
  }

  Map<String, dynamic> toJson() => {
    'image_url': imageUrl,
    'public_id': publicId,
    'is_thumbnail': isThumbnail,
  };
}

class LandlordInfoModel extends LandlordInfoEntity {
  const LandlordInfoModel({
    super.accountId,
    required super.fullName,
    required super.gender,
    super.avatar,
    required super.isVerify,
  });

  factory LandlordInfoModel.fromJson(Map<String, dynamic> json) {
    return LandlordInfoModel(
      // Both API spellings refer to Account.id, never the Landlord profile ID.
      accountId: ((json['account_id'] ?? json['id_account']) as String?)
          ?.trim(),
      fullName: json['full_name'] ?? '',
      gender: json['gender'] ?? '',
      avatar: json['avatar'],
      isVerify: json['is_verify'] ?? false,
    );
  }
}

class LocationSuggestionModelResponse extends LocationSuggestion {
  const LocationSuggestionModelResponse({
    required super.locationId,
    required super.nameDistrict,
  });

  factory LocationSuggestionModelResponse.fromJson(Map<String, dynamic> json) {
    return LocationSuggestionModelResponse(
      locationId: json['location_id'] ?? '',
      nameDistrict: json['name_district'] ?? '',
    );
  }
}


class ListLocationSuggestionModelResponse {
  final List<LocationSuggestionModelResponse> data;

  const ListLocationSuggestionModelResponse({
    required this.data,
  });

  factory ListLocationSuggestionModelResponse.fromJson(
    Map<String, dynamic> json,
  ) {
    return ListLocationSuggestionModelResponse(
      data: (json['data'] as List)
          .map(
            (item) => LocationSuggestionModelResponse.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList(),
    );
  }
}
