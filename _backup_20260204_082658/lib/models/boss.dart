class Boss {
  final String id;
  final String name;
  final String country;
  final String phone; // optional
  final String address; // optional
  final int openingBalanceMmk; // required
  final int createdAtMs;

  Boss({
    required this.id,
    required this.name,
    required this.country,
    required this.openingBalanceMmk,
    required this.createdAtMs,
    this.phone = '',
    this.address = '',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'country': country,
    'phone': phone,
    'address': address,
    'openingBalanceMmk': openingBalanceMmk,
    'createdAtMs': createdAtMs,
  };

  static Boss fromJson(Map<String, dynamic> j) => Boss(
    id: (j['id'] ?? '').toString(),
    name: (j['name'] ?? '').toString(),
    country: (j['country'] ?? '').toString(),
    phone: (j['phone'] ?? '').toString(),
    address: (j['address'] ?? '').toString(),
    openingBalanceMmk: (j['openingBalanceMmk'] ?? 0) is int
        ? (j['openingBalanceMmk'] as int)
        : int.tryParse((j['openingBalanceMmk'] ?? '0').toString()) ?? 0,
    createdAtMs: (j['createdAtMs'] ?? 0) is int
        ? (j['createdAtMs'] as int)
        : int.tryParse((j['createdAtMs'] ?? '0').toString()) ?? 0,
  );
}
