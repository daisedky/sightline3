import 'dart:io';
import 'package:file_picker/file_picker.dart' as filePicker;
import 'package:flutter/material.dart';

/// A service class that handles file operations for the PDF conversion feature
class FileService {
  /// Picks a PDF file using the file picker
  static Future<filePicker.FilePickerResult?> pickPdfFile() async {
    print('Opening file picker...');
    final filePickerResult = await filePicker.FilePicker.platform.pickFiles(
      type: filePicker.FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: false,
      withData: true,
    );

    if (filePickerResult == null || filePickerResult.files.isEmpty) {
      print('No file selected');
      return null;
    }

    final file = filePickerResult.files.first;
    print('File selected: ${file.name}, Path: ${file.path}, Has bytes: ${file.bytes != null}');
    return filePickerResult;
  }

  /// Gets the bytes from a file picker result
  static Future<List<int>?> getFileBytes(
    filePicker.FilePickerResult filePickerResult, 
    BuildContext context
  ) async {
    final file = filePickerResult.files.first;
    
    // Get file bytes
    if (file.bytes != null) {
      print('Using direct file bytes, size: ${file.bytes!.length}');
      return file.bytes!;
    } else if (file.path != null) {
      final File pdfFile = File(file.path!);
      if (!await pdfFile.exists()) {
        print('Error: File does not exist at path: ${file.path}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('File does not exist')),
        );
        return null;
      }

      final bytes = await pdfFile.readAsBytes();
      print('Read file bytes from path, size: ${bytes.length}');
      return bytes;
    } else {
      print('Error: Neither file bytes nor path available');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invalid file data')),
      );
      return null;
    }
  }

  /// Shares a file with other apps
  static Future<void> shareFile(String filePath, String fileName) async {
    try {
      final File file = File(filePath);
      if (await file.exists()) {
        // Use Share.shareFiles or other sharing mechanism here
        print('Sharing file: $filePath');
      } else {
        print('File does not exist: $filePath');
      }
    } catch (e) {
      print('Error sharing file: $e');
    }
  }
}