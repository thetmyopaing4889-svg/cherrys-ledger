class Boss {
  final String id;
  final String name;
  final String country;
  final int openingBalanceMmk;
  final String phone;
  final String address;
  final int createdAtMs;

  const Boss({
    required this.id,
    required this.name,
    required this.country,
    required this.openingBalanceMmk,
    required this.phone,
    required this.address,
    required this.createdAtMs,
  });

  Boss copyWith({
    String? id,
    String? name,
    String? country,
    int? openingBalanceMmk,
    String? phone,
    String? address,
    int? createdAtMs,
  }) {
    return Boss(
      id: id ?? this.id,
      name: name ?? this.name,
      country: country ?? this.country,
      openingBalanceMmk: openingBalanceMmk ?? this.openingBalanceMmk,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      createdAtMs: createdAtMs ?? this.createdAtMs,
    );
  }

  Map<String, dynamic> toJson() => {
    "id": id,
    "name": name,
    "country": country,
    "openingBalanceMmk": openingBalanceMmk,
    "phone": phone,
    "address": address,
    "createdAtMs": createdAtMs,
  };

  static Boss fromJson(Map<String, dynamic> j) {
    return Boss(
      id: (j["id"] ?? "") as String,
      name: (j["name"] ?? "") as String,
      country: (j["country"] ?? "") as String,
      openingBalanceMmk: (j["openingBalanceMmk"] ?? 0) as int,
      phone: (j["phone"] ?? "") as String,
      address: (j["address"] ?? "") as String,
      createdAtMs: (j["createdAtMs"] ?? 0) as int,
    );
  }
}
