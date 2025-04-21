import 'package:cloud_firestore/cloud_firestore.dart';

class DocumentModel {
  final String id;
  final String uid;
  final String fileName;
  final String fileType;
  final String url;
  final String originalFilePath;
  final String? processedText;
  final String? audioPath;
  final String? styledPath;
  final String status;
  final DateTime uploadedAt;

  DocumentModel({
    required this.id,
    required this.uid,
    required this.fileName,
    required this.fileType,
    required this.url,
    required this.originalFilePath,
    this.processedText,
    this.audioPath,
    this.styledPath,
    required this.status,
    required this.uploadedAt,
  });

  factory DocumentModel.fromMap(Map<String, dynamic> map, String id) {
    return DocumentModel(
      id: id,
      uid: map['uid'] ?? '',
      fileName: map['fileName'] ?? '',
      fileType: map['fileType'] ?? '',
      url: map['url'] ?? '',
      originalFilePath: map['originalFilePath'] ?? '',
      processedText: map['processedText'],
      audioPath: map['audioPath'],
      styledPath: map['styledPath'],
      status: map['status'] ?? 'pending',
      uploadedAt: (map['uploadTimestamp'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'fileName': fileName,
      'fileType': fileType,
      'url': url,
      'originalFilePath': originalFilePath,
      'processedText': processedText,
      'audioPath': audioPath,
      'styledPath': styledPath,
      'status': status,
      'uploadTimestamp': Timestamp.fromDate(uploadedAt),
    };
  }

  @override
  String toString() {
    return 'DocumentModel(fileName: $fileName, type: $fileType, status: $status, uploadedAt: $uploadedAt)';
  }
}
