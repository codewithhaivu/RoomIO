const goongAddress = '12 Võ Văn Ngân, Thủ Đức, Hồ Chí Minh';

Map<String, dynamic> get goongAutocompleteJson => {
  'status': 'OK',
  'predictions': [
    {'place_id': 'goong-place-id', 'description': goongAddress},
  ],
};

Map<String, dynamic> get goongDetailJson => {
  'status': 'OK',
  'result': {
    'place_id': 'goong-place-id',
    'formatted_address': goongAddress,
    'geometry': {
      'location': {'lat': 10.85, 'lng': 106.75},
    },
  },
};
