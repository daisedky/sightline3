import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/document_model.dart';

class DocumentStorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Upload a file to Firebase Storage and save metadata to Firestore
  Future<DocumentModel?> uploadFile({
    required File file,
    required String type,
    String? extractedText,
    String? styledPath,
    String? audioPath,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not logged in");

    try {
      final fileName = file.path.split('/').last;
      final docId = _firestore.collection('documents').doc().id;
      final storagePath = 'uploads/${user.uid}/originals/$fileName';

      // Upload the file
      final ref = _storage.ref().child(storagePath);
      await ref.putFile(file);
      final downloadUrl = await ref.getDownloadURL();

      // Create document metadata
      final document = DocumentModel(
        id: docId,
        uid: user.uid,
        fileName: fileName,
        fileType: type,
        originalFilePath: storagePath,
        url: downloadUrl,
        processedText: extractedText,
        audioPath: audioPath,
        styledPath: styledPath,
        status: extractedText != null ? "processed" : "pending",
        uploadedAt: DateTime.now(),
      );

      // Save metadata to Firestore
      await _firestore.collection('documents').doc(docId).set(document.toMap());
      return document;
    } catch (e) {
      // print("Upload failed: $e"); // TODO: Replace with logging
      return null;
    }
  }

  /// Delete a file and its metadata
  Future<void> deleteFile(DocumentModel doc) async {
    try {
      await _firestore.collection('documents').doc(doc.id).delete();
      await _storage.ref().child(doc.originalFilePath).delete();
    } catch (e) {
      // print('Delete failed: $e'); // TODO: Replace with logging
    }
  }

  /// Get all documents for current user
  Future<List<DocumentModel>> getUserDocuments() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    try {
      final snapshot = await _firestore
          .collection('documents')
          .where('uid', isEqualTo: user.uid)
          .orderBy('uploadedAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        return DocumentModel.fromMap(doc.data(), doc.id);
      }).toList();
    } catch (e) {
      // print('Failed to fetch documents: $e'); // TODO: Replace with logging
      return [];
    }
  }
}
