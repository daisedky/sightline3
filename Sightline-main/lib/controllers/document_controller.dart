import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/document_model.dart';
import 'file_upload_controller.dart';

class DocumentController with ChangeNotifier {
  final FileUploadController _uploadController = FileUploadController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isUploading = false;
  bool get isUploading => _isUploading;

  List<DocumentModel> _documents = [];
  List<DocumentModel> get documents => _documents;

  Future<DocumentModel?> uploadDocument({
    required File file,
    required String type,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      print('User not logged in.');
      return null;
    }

    _isUploading = true;
    notifyListeners();

    try {
      final uploadedDoc = await _uploadController.uploadFile(
        file: file,
        uid: user.uid,
        type: type,
      );

      if (uploadedDoc != null) {
        _documents.insert(0, uploadedDoc);
        notifyListeners();
      }

      return uploadedDoc;
    } catch (e) {
      print('Document upload failed: $e');
      return null;
    } finally {
      _isUploading = false;
      notifyListeners();
    }
  }

  Future<void> fetchUserDocuments() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final snapshot = await _firestore
          .collection('documents')
          .where('uid', isEqualTo: user.uid)
          .orderBy('uploadTimestamp', descending: true)
          .get();

      _documents = snapshot.docs
          .map((doc) => DocumentModel.fromMap(doc.data(), doc.id))
          .toList();

      notifyListeners();
    } catch (e) {
      print('Failed to fetch documents: $e');
    }
  }

  Future<void> deleteDocument(DocumentModel doc) async {
    try {
      await _firestore.collection('documents').doc(doc.id).delete();
      _documents.removeWhere((d) => d.id == doc.id);
      notifyListeners();
    } catch (e) {
      print('Failed to delete document: $e');
    }
  }
}
