class CreatedAtModel {
  final List<CreatedAtSigner> signers;

  CreatedAtModel({required this.signers});

  factory CreatedAtModel.fromJson(Map<String, dynamic> json) {
    var signersJson = json['signer'] as List;
    List<CreatedAtSigner> signersList = signersJson
        .map((signerJson) => CreatedAtSigner.fromJson(signerJson))
        .toList();
    return CreatedAtModel(signers: signersList);
  }
}

class CreatedAtSigner {
  final String createdAt;

  CreatedAtSigner({required this.createdAt});

  factory CreatedAtSigner.fromJson(Map<String, dynamic> json) {
    return CreatedAtSigner(createdAt: json['signer_id']['created_at']);
  }
}
