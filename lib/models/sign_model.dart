import 'dart:convert';

enum SignType { name, signature, date }

enum SignerStatus { Pending, Submitted, Draft }

enum DocumentStatus { Pending, Submitted, Draft }

class SignModel {
  int signId;
  double xOffset;
  double yOffset;
  String? contributorEmail;
  String? signatureText;
  int currentPage;
  SignType type;
  String? signatureId;
  String? status;

  SignModel(
      {required this.signId,
      required this.xOffset,
      required this.yOffset,
      this.contributorEmail,
      this.signatureText,
      required this.currentPage,
      required this.type,
      this.signatureId,
      this.status});
}

class DocsModel {
  String created_file;
  String? userId;
  int? docId;
  List<SignModel> signModelList;

  DocsModel(this.signModelList, this.created_file, this.userId, this.docId);
}

class SignatureData {
  final int id;
  final DateTime createdAt;
  final String creatorEmail;
  final CreatedFile createdFile;
  final List<Signer> signers;
  String? status;

  SignatureData(
      {required this.createdFile,
      required this.signers,
      required this.id,
      required this.createdAt,
      required this.creatorEmail,
      required this.status});

  factory SignatureData.fromJson(Map<String, dynamic> json) {
    return SignatureData(
      id: json['id'],
      createdAt: DateTime.parse(json['created_at']),
      creatorEmail: json['user_id']?['email'] ?? 'Unknown',
      createdFile: json['created_file'] != null
          ? CreatedFile.fromJson(json['created_file'])
          : CreatedFile(
              filename_download: '',
              title: 'Untitled',
              id: '',
            ),
      signers: (json['signer'] as List)
          .map((signer) => Signer.fromJson(signer['signer_id'] ?? {}))
          .toList(),
      status: json['status'] ?? '',
    );
  }
}

class CreatedFile {
  final String title;
  final String id;
  final String filename_download;
  CreatedFile(
      {required this.filename_download, required this.title, required this.id});

  factory CreatedFile.fromJson(Map<String, dynamic> json) {
    return CreatedFile(
      filename_download: json['filename_download'],
      title: json['title'],
      id: json['id'],
    );
  }
}

class Signer {
  final int id;
  double xOffset;
  double yOffset;
  final String contriputerEmail;
  String? sign;
  final String userId;
  final int currentPage;
  final DateTime createdAt;
  final List<int> documents;
  String? signatureId;
  String status;
  final String type;

  Signer({
    required this.id,
    required this.xOffset,
    required this.yOffset,
    required this.contriputerEmail,
    required this.sign,
    required this.userId,
    required this.currentPage,
    required this.createdAt,
    required this.signatureId,
    required this.type,
    required this.documents,
    required this.status,
  });

  factory Signer.fromJson(Map<String, dynamic> json) {
    return Signer(
      id: json['id'],
      xOffset: double.tryParse(json['x_offset'].toString()) ?? 0.0,
      yOffset: double.tryParse(json['y_offset'].toString()) ?? 0.0,
      contriputerEmail: json['contriputer_email'],
      sign: json['sign'] ?? '',
      userId: json['user_id'],
      currentPage: int.parse(("${json['current_page']}")),
      createdAt: DateTime.parse(json['created_at']),
      documents: List<int>.from(json['documents']),
      signatureId: json['signature_id'] ?? null,
      type: json['type'],
      status: json['status'],
    );
  }
}

List<SignatureData> parseSignatureData(String jsonStr) {
  final Map<String, dynamic> jsonData = json.decode(jsonStr);
  return (jsonData['data'] as List)
      .map((item) => SignatureData.fromJson(item))
      .toList();
}
