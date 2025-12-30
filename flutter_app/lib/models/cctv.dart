/// CCTV Model
class Cctv {
  final String id;
  final String name;
  final String owner;
  final String category;
  final Location location;
  final List<StreamInfo> streams;
  final String status;
  final String thumbnail;

  Cctv({
    required this.id,
    required this.name,
    required this.owner,
    required this.category,
    required this.location,
    required this.streams,
    required this.status,
    required this.thumbnail,
  });

  factory Cctv.fromJson(Map<String, dynamic> json) {
    return Cctv(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      owner: json['owner'] ?? '',
      category: json['category'] ?? '',
      location: Location.fromJson(json['location'] ?? {}),
      streams: (json['streams'] as List<dynamic>?)
              ?.map((s) => StreamInfo.fromJson(s))
              .toList() ??
          [],
      status: json['status'] ?? 'offline',
      thumbnail: json['thumbnail'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'owner': owner,
      'category': category,
      'location': location.toJson(),
      'streams': streams.map((s) => s.toJson()).toList(),
      'status': status,
      'thumbnail': thumbnail,
    };
  }

  bool get isOnline => status == 'online';
}

/// Location Model
class Location {
  final double lat;
  final double lng;

  Location({required this.lat, required this.lng});

  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      lat: (json['lat'] ?? 0).toDouble(),
      lng: (json['lng'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'lat': lat,
      'lng': lng,
    };
  }
}

/// Stream Info Model
class StreamInfo {
  final String quality;
  final String url;
  final String? wsUrl;
  final String? hlsUrl;

  StreamInfo({
    required this.quality,
    required this.url,
    this.wsUrl,
    this.hlsUrl,
  });

  factory StreamInfo.fromJson(Map<String, dynamic> json) {
    return StreamInfo(
      quality: json['quality'] ?? 'preview',
      url: json['url'] ?? '',
      wsUrl: json['wsUrl'],
      hlsUrl: json['hlsUrl'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'quality': quality,
      'url': url,
      'wsUrl': wsUrl,
      'hlsUrl': hlsUrl,
    };
  }
}
