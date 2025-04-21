import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart' as file_picker;
import 'package:syncfusion_flutter_pdf/pdf.dart' as syncfusion_flutter_pdf;
import 'package:pdfx/pdfx.dart';
import 'package:path_provider/path_provider.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class PdfExtractionResult {
  final String text;
  final String? pdfPath;
  final int pageCount;
  final bool usedOcr;

  PdfExtractionResult({
    required this.text,
    this.pdfPath,
    this.pageCount = 0,
    this.usedOcr = false,
  });
}

class PdfExtractionProcessor {
  late final TextRecognizer _textRecognizer;
  
  PdfExtractionProcessor() {
    _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  }
  
  void dispose() {
    _textRecognizer.close();
  }
  
  Future<PdfExtractionResult> extractTextFromPdf({
    required file_picker.PlatformFile file,
    required Function(int current, int total, double progress) onProgress,
  }) async {
    try {
      String extractedText = '';
      bool usedOcr = false;
      
      // Try native text extraction first
      try {
        extractedText = await _extractTextNatively(file, onProgress);
      } catch (e) {
        debugPrint('Native text extraction failed: $e');
        extractedText = '';
      }
      
      // If native extraction failed or returned no text, try OCR
      if (extractedText.isEmpty) {
        debugPrint('Native extraction yielded no text, trying OCR...');
        extractedText = await _extractTextWithOcrMultiPage(file, onProgress);
        usedOcr = true;
      }
      
      // Get page count
      int pageCount = await _getPageCount(file);
      
      return PdfExtractionResult(
        text: extractedText,
        pdfPath: file.path,
        pageCount: pageCount,
        usedOcr: usedOcr,
      );
    } catch (e) {
      debugPrint('Error in extractTextFromPdf: $e');
      rethrow;
    }
  }
  
  Future<String> _extractTextNatively(
    file_picker.PlatformFile file,
    Function(int current, int total, double progress) onProgress,
  ) async {
    try {
      if (file.path == null) {
        throw Exception('File path is null');
      }
      
      // Load the PDF document
      final pdfBytes = await File(file.path!).readAsBytes();
      final document = syncfusion_flutter_pdf.PdfDocument(inputBytes: pdfBytes);
      
      // Get the total page count
      final pageCount = document.pages.count;
      
      // Extract text from each page
      StringBuffer textBuffer = StringBuffer();
      
      for (int i = 0; i < pageCount; i++) {
        // Extract text from the current page
        final pageText = syncfusion_flutter_pdf.PdfTextExtractor(document).extractText(startPageIndex: i);
        
        if (pageText.isNotEmpty) {
          if (i > 0) {
            textBuffer.write('\n\n--- Page ${i + 1} ---\n\n');
          }
          textBuffer.write(pageText);
        }
        
        // Report progress
        onProgress(i + 1, pageCount, (i + 1) / pageCount);
      }
      
      // Dispose of the document
      document.dispose();
      
      return textBuffer.toString();
    } catch (e) {
      debugPrint('Error in _extractTextNatively: $e');
      rethrow;
    }
  }
  
  Future<String> _extractTextWithOcrMultiPage(
    file_picker.PlatformFile file,
    Function(int current, int total, double progress) onProgress,
  ) async {
    try {
      if (file.path == null) {
        throw Exception('File path is null');
      }
      
      // Create a PdfDocument instance
      final pdfDocument = await PdfDocument.openFile(file.path!);
      final pageCount = pdfDocument.pagesCount;
      
      // Create a buffer for the extracted text
      StringBuffer textBuffer = StringBuffer();
      
      // Process each page
      for (int i = 0; i < pageCount; i++) {
        try {
          // Get the current page
          final page = await pdfDocument.getPage(i + 1);
          
          // Render the page to an image
          final pageImage = await page.render(
            width: page.width * 2,  // Higher resolution for better OCR
            height: page.height * 2,
            format: PdfPageImageFormat.jpeg,
            backgroundColor: '#FFFFFF',
          );
          
          if (pageImage == null || pageImage.bytes.isEmpty) {
            debugPrint('Failed to render page ${i + 1}');
            continue;
          }
          
          // Save the image to a temporary file
          final tempDir = await getTemporaryDirectory();
          final tempImagePath = '${tempDir.path}/pdf_page_${i + 1}.jpg';
          await File(tempImagePath).writeAsBytes(pageImage.bytes);
          
          // Process the image with OCR
          final inputImage = InputImage.fromFile(File(tempImagePath));
          final recognizedText = await _textRecognizer.processImage(inputImage);
          
          // Add page header if not the first page
          if (i > 0) {
            textBuffer.write('\n\n--- Page ${i + 1} ---\n\n');
          }
          
          // Add the extracted text
          textBuffer.write(recognizedText.text);
          
          // Clean up the temporary file
          await File(tempImagePath).delete();
          
          // Close the page
          page.close();
          
          // Report progress
          onProgress(i + 1, pageCount, (i + 1) / pageCount);
        } catch (e) {
          debugPrint('Error processing page ${i + 1}: $e');
          // Continue with the next page even if this one fails
        }
      }
      
      // Close the document
      pdfDocument.close();
      
      return textBuffer.toString();
    } catch (e) {
      debugPrint('Error in _extractTextWithOcrMultiPage: $e');
      rethrow;
    }
  }
  
  Future<int> _getPageCount(file_picker.PlatformFile file) async {
    try {
      if (file.path == null) {
        return 0;
      }
      
      final pdfDocument = await PdfDocument.openFile(file.path!);
      final pageCount = pdfDocument.pagesCount;
      pdfDocument.close();
      
      return pageCount;
    } catch (e) {
      debugPrint('Error getting page count: $e');
      return 0;
    }
  }
}
