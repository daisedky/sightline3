import 'dart:io';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as path;
import '../models/document_model.dart';
import '../services/firebase_service.dart';

class FileUploadController {
  final FirebaseService _firebaseService = FirebaseService();
  final _uuid = Uuid();

  Future<DocumentModel?> uploadFile({
    required File file,
    required String uid,
    required String type,
    String? processedText,
    String? audioPath,
    String? styledPath,
  }) async {
    try {
      final fileName = path.basename(file.path);
      final storagePath =
          'documents/$uid/${_uuid.v4()}${path.extension(file.path)}';

      // Upload file to Firebase Storage
      final url = await _firebaseService.uploadFileToStorage(
        file: file,
        path: storagePath,
      );

      // Generate document ID
      final docId = _firebaseService.firestore.collection('documents').doc().id;

      // Create document model
      final doc = DocumentModel(
        id: docId,
        uid: uid,
        fileName: fileName,
        fileType: type,
        url: url,
        originalFilePath: storagePath,
        processedText: processedText,
        audioPath: audioPath,
        styledPath: styledPath,
        status: processedText != null ? 'processed' : 'pending',
        uploadedAt: DateTime.now(),
      );

      // Save to Firestore
      await _firebaseService.firestore
          .collection('documents')
          .doc(docId)
          .set(doc.toMap());

      return doc;
    } catch (e) {
      print('File upload failed: $e');
      return null;
    }
  }

  // New method for extract_text_from_pdf_screen.dart compatibility
  Future<String?> uploadFileAndSaveMetadata({
    required File file,
    required String fileName,
    required String fileType,
    required String extractedText,
    required String uid,
  }) async {
    try {
      final storagePath = 'documents/$uid/$fileName';
      final url = await _firebaseService.uploadFileToStorage(
        file: file,
        path: storagePath,
      );
      final docId = _firebaseService.firestore.collection('documents').doc().id;
      final doc = DocumentModel(
        id: docId,
        uid: uid,
        fileName: fileName,
        fileType: fileType,
        url: url,
        originalFilePath: storagePath,
        processedText: extractedText,
        audioPath: '',
        styledPath: '',
        status: extractedText.isNotEmpty ? 'processed' : 'pending',
        uploadedAt: DateTime.now(),
      );
      await _firebaseService.firestore
          .collection('documents')
          .doc(docId)
          .set(doc.toMap());
      return url;
    } catch (e) {
      print('File upload and metadata save failed: $e');
      return null;
    }
  }
}
