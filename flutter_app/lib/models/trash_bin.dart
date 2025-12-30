class TrashBin {
  final String id;
  final String name;
  final double lat;
  final double lng;
  final String? photoUrl;
  final DateTime? createdAt;

  TrashBin({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    this.photoUrl,
    this.createdAt,
  });

  factory TrashBin.fromJson(Map<String, dynamic> json) {
    return TrashBin(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      lat: (json['location']?['lat'] ?? 0).toDouble(),
      lng: (json['location']?['lng'] ?? 0).toDouble(),
      photoUrl: json['photoUrl'],
      createdAt: json['createdAt'] != null 
          ? DateTime.tryParse(json['createdAt']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'lat': lat,
    'lng': lng,
    'photoUrl': photoUrl,
  };
}
