class LedgerTx {
  final String id;
  final String bossId;

  final int dateMs; // chosen date (00:00) in ms
  final int seqNo; // per boss: 1,2,3...

  final String description; // အကြောင်းအရာ
  final String personName; // နာမည်

  final String type; // "deposit" | "withdraw"

  final int amountKs;
  final int commissionKs;
  final int totalKs; // amount + commission

  final bool deleted;

  const LedgerTx({
    required this.id,
    required this.bossId,
    required this.dateMs,
    required this.seqNo,
    required this.description,
    required this.personName,
    required this.type,
    required this.amountKs,
    required this.commissionKs,
    required this.totalKs,
    required this.deleted,
  });

  LedgerTx copyWith({
    String? id,
    String? bossId,
    int? dateMs,
    int? seqNo,
    String? description,
    String? personName,
    String? type,
    int? amountKs,
    int? commissionKs,
    int? totalKs,
    bool? deleted,
  }) {
    return LedgerTx(
      id: id ?? this.id,
      bossId: bossId ?? this.bossId,
      dateMs: dateMs ?? this.dateMs,
      seqNo: seqNo ?? this.seqNo,
      description: description ?? this.description,
      personName: personName ?? this.personName,
      type: type ?? this.type,
      amountKs: amountKs ?? this.amountKs,
      commissionKs: commissionKs ?? this.commissionKs,
      totalKs: totalKs ?? this.totalKs,
      deleted: deleted ?? this.deleted,
    );
  }

  Map<String, dynamic> toJson() => {
    "id": id,
    "bossId": bossId,
    "dateMs": dateMs,
    "seqNo": seqNo,
    "description": description,
    "personName": personName,
    "type": type,
    "amountKs": amountKs,
    "commissionKs": commissionKs,
    "totalKs": totalKs,
    "deleted": deleted,
  };

  static LedgerTx fromJson(Map<String, dynamic> j) {
    return LedgerTx(
      id: (j["id"] ?? "") as String,
      bossId: (j["bossId"] ?? "") as String,
      dateMs: (j["dateMs"] ?? 0) as int,
      seqNo: (j["seqNo"] ?? 0) as int,
      description: (j["description"] ?? "") as String,
      personName: (j["personName"] ?? "") as String,
      type: (j["type"] ?? "deposit") as String,
      amountKs: (j["amountKs"] ?? 0) as int,
      commissionKs: (j["commissionKs"] ?? 0) as int,
      totalKs: (j["totalKs"] ?? 0) as int,
      deleted: (j["deleted"] ?? false) as bool,
    );
  }
}
