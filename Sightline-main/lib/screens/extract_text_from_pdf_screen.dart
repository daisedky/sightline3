import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart' as file_picker;
import 'package:syncfusion_flutter_pdf/pdf.dart' as syncfusion_flutter_pdf;
import 'package:pdfx/pdfx.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:math';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'extracted_text_screen.dart';
import '../controllers/file_upload_controller.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ExtractTextFromPdfScreen extends StatefulWidget {
  final Function(Map<String, dynamic>) onFileUploaded;

  const ExtractTextFromPdfScreen({super.key, required this.onFileUploaded});

  @override
  ExtractTextFromPdfScreenState createState() => ExtractTextFromPdfScreenState();
}

class ExtractTextFromPdfScreenState extends State<ExtractTextFromPdfScreen> {
  bool _isLoading = false;
  String _statusMessage = '';
  double _progressValue = 0.0;
  int _totalPages = 0;
  int _currentPage = 0;
  late final TextRecognizer _textRecognizer;
  late final FileUploadController _fileUploadController;

  @override
  void initState() {
    super.initState();
    _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    _fileUploadController = FileUploadController();
  }

  @override
  void dispose() {
    _textRecognizer.close();
    super.dispose();
  }

  Future<bool> _checkAndRequestPermissions(BuildContext context) async {
    try {
      print('Starting permission check...');

      // Request all potentially needed permissions at once
      Map<Permission, PermissionStatus> statuses = await [
        Permission.storage,
        Permission.photos,
        Permission.videos,
        Permission
            .manageExternalStorage, // Add this for better access on newer Android
      ].request();

      print('Permission request results:');
      statuses.forEach((permission, status) {
        print('$permission: $status');
      });

      // On emulators, we might need to proceed even with limited permissions
      // So we'll return true even if only some permissions are granted
      bool hasAnyPermission = statuses.values.any((status) => status.isGranted);

      if (hasAnyPermission) {
        print('Some essential permissions granted, proceeding');
        return true;
      } else {
        print('All essential permissions denied');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Storage permission is required to access PDF files. Please enable it in app settings.'),
            duration: Duration(seconds: 10),
            action: SnackBarAction(
              label: 'Open Settings',
              onPressed: () {
                openAppSettings();
              },
            ),
          ),
        );
        return false;
      }
    } catch (e) {
      print('Error checking/requesting permissions: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error with permissions: $e')),
      );
      // Return true to allow the operation to proceed even with permission errors
      // This helps with emulator testing
      return true;
    }
  }

  Future<String> _extractTextFromPdf(BuildContext context) async {
    try {
      setState(() {
        _isLoading = true;
        _statusMessage = 'Initializing...';
        _progressValue = 0.1;
      });

      // Check and request permissions first
      bool permissionsGranted = await _checkAndRequestPermissions(context);
      if (!permissionsGranted) {
        setState(() {
          _isLoading = false;
          _statusMessage = 'Permission denied';
          _progressValue = 0.0;
        });
        print('Cannot proceed: Permissions not granted');
        return '';
      }

      setState(() {
        _statusMessage = 'Opening file picker...';
        _progressValue = 0.2;
      });

      print('Opening file picker...');
      // Use a simpler file picker configuration with more options for emulators
      file_picker.FilePickerResult? result =
          await file_picker.FilePicker.platform.pickFiles(
        type: file_picker.FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result == null || result.files.isEmpty) {
        setState(() {
          _isLoading = false;
          _statusMessage = 'No file selected';
          _progressValue = 0.0;
        });
        print('No file selected');
        return '';
      }

      file_picker.PlatformFile file = result.files.first;
      print('Selected file: ${file.name} (${file.size} bytes)');
      print('File path: ${file.path}');

      setState(() {
        _statusMessage = 'Analyzing PDF...';
        _progressValue = 0.3;
      });

      // First, try to extract text directly from the PDF
      String extractedText = '';
      bool hasExtractableText = false;

      try {
        print('Attempting direct text extraction...');
        setState(() {
          _statusMessage = 'Extracting text from PDF...';
          _progressValue = 0.4;
        });

        if (file.path != null) {
          // Use SyncfusionFlutterPdf for direct text extraction
          final syncfusion_flutter_pdf.PdfDocument document =
              syncfusion_flutter_pdf.PdfDocument(
            inputBytes: await File(file.path!).readAsBytes(),
          );

          _totalPages = document.pages.count;
          print('PDF has $_totalPages pages');

          // Extract text from each page
          for (int i = 0; i < document.pages.count; i++) {
            _currentPage = i + 1;
            setState(() {
              _statusMessage =
                  'Extracting text from page $_currentPage of $_totalPages...';
              _progressValue = 0.4 + (0.3 * (_currentPage / _totalPages));
            });

            syncfusion_flutter_pdf.PdfTextExtractor extractor =
                syncfusion_flutter_pdf.PdfTextExtractor(document);
            String pageText = extractor.extractText(startPageIndex: i);

            if (pageText.isNotEmpty && pageText.trim().length > 10) {
              hasExtractableText = true;
              extractedText += '$pageText\n\n';
              print(
                  'Extracted ${pageText.length} characters from page ${i + 1}');
            } else {
              print('Page ${i + 1} has no extractable text');
            }
          }

          document.dispose();
        }
      } catch (e) {
        print('Error during direct text extraction: $e');
        // Continue to OCR if direct extraction fails
      }

      // If direct extraction didn't yield good results, try OCR
      if (!hasExtractableText || extractedText.trim().length < 20) {
        print(
            'Direct text extraction failed or yielded poor results, trying OCR...');
        setState(() {
          _statusMessage = 'PDF appears to be scanned, using OCR...';
          _progressValue = 0.7;
        });

        if (_totalPages > 1) {
          extractedText = await _extractTextWithOcrMultiPage(file);
        } else {
          extractedText = await _extractTextWithOcr(file);
        }
      }

      // Save the extracted text to a file
      if (extractedText.isNotEmpty) {
        setState(() {
          _statusMessage = 'Saving extracted text...';
          _progressValue = 0.9;
        });

        try {
          final directory = await getApplicationDocumentsDirectory();
          final fileName =
              'extracted_${DateTime.now().millisecondsSinceEpoch}.txt';
          final filePath = '${directory.path}/$fileName';

          await File(filePath).writeAsString(extractedText);

          print('Text saved to $filePath');

          final user = FirebaseAuth.instance.currentUser;
          if (user != null) {
            final fileToUpload = File(filePath);

            final downloadUrl =
                await _fileUploadController.uploadFileAndSaveMetadata(
              file: fileToUpload,
              fileName: fileName,
              fileType: 'pdf_extract',
              extractedText: extractedText,
              uid: user.uid,
            );

            widget.onFileUploaded({
              'name': fileName,
              'timestamp': DateTime.now().toString(),
              'type': 'pdf_extract',
              'url': downloadUrl,
            });
          } else {
            print(' User not logged in. Skipping upload.');
          }
        } catch (e) {
          print('Error saving text file: $e');
        }
      }

      setState(() {
        _isLoading = false;
        _statusMessage = '';
        _progressValue = 0.0;
        _totalPages = 0;
        _currentPage = 0;
      });

      return extractedText;
    } catch (e) {
      print('Error during PDF text extraction: $e');
      setState(() {
        _isLoading = false;
        _statusMessage = 'Error: $e';
        _progressValue = 0.0;
      });
      return '';
    }
  }

  Future<String> _extractTextWithOcr(file_picker.PlatformFile file) async {
    try {
      if (file.path == null) {
        print('File path is null');
        return '';
      }

      print('Rendering PDF page as image...');
      final document = await PdfDocument.openFile(file.path!);
      if (document.pagesCount == 0) {
        print('PDF has no pages');
        await document.close();
        return '';
      }

      final page = await document.getPage(1);
      final pageImage = await page.render(
        width: page.width * 2,
        height: page.height * 2,
        format: PdfPageImageFormat.png,
      );
      await page.close();

      if (pageImage == null || pageImage.bytes.isEmpty) {
        print('Failed to render PDF page as image');
        await document.close();
        return '';
      }

      final tempDir = await getTemporaryDirectory();
      final tempImagePath = '${tempDir.path}/temp_page.png';
      final tempFile = File(tempImagePath);
      await tempFile.writeAsBytes(pageImage.bytes);
      print('PDF page rendered and saved to: $tempImagePath');

      print('Performing OCR with Google ML Kit...');
      try {
        // Use Google ML Kit for text recognition
        final inputImage = InputImage.fromFile(tempFile);
        final RecognizedText recognizedText =
            await _textRecognizer.processImage(inputImage);

        String extractedText = recognizedText.text;
        print('OCR extracted ${extractedText.length} characters');

        await document.close();
        return extractedText;
      } catch (e) {
        print('Error during OCR: $e');
        await document.close();
        return '';
      }
    } catch (e) {
      print('Error during OCR: $e');
      return '';
    }
  }

  Future<String> _extractTextWithOcrMultiPage(
      file_picker.PlatformFile file) async {
    try {
      if (file.path == null) {
        print('File path is null');
        return '';
      }

      print('Processing multi-page PDF with OCR...');
      final document = await PdfDocument.openFile(file.path!);
      if (document.pagesCount == 0) {
        print('PDF has no pages');
        await document.close();
        return '';
      }

      _totalPages = document.pagesCount;
      setState(() {
        _statusMessage = 'Processing $_totalPages pages with OCR...';
      });

      String combinedText = '';

      // Process up to 10 pages to avoid excessive processing time
      int pagesToProcess = min(_totalPages, 10);

      for (int i = 1; i <= pagesToProcess; i++) {
        _currentPage = i;
        setState(() {
          _statusMessage =
              'Processing page $_currentPage of $pagesToProcess with OCR...';
          _progressValue = 0.7 + (0.2 * (i / pagesToProcess));
        });

        try {
          final page = await document.getPage(i);
          final pageImage = await page.render(
            width: page.width * 2,
            height: page.height * 2,
            format: PdfPageImageFormat.png,
          );
          await page.close();

          if (pageImage == null || pageImage.bytes.isEmpty) {
            print('Failed to render page $i as image');
            continue;
          }

          final tempDir = await getTemporaryDirectory();
          final tempImagePath = '${tempDir.path}/temp_page_$i.png';
          final tempFile = File(tempImagePath);
          await tempFile.writeAsBytes(pageImage.bytes);
          print('Page $i rendered and saved to: $tempImagePath');

          // Use Google ML Kit for text recognition
          final inputImage = InputImage.fromFile(tempFile);
          final RecognizedText recognizedText =
              await _textRecognizer.processImage(inputImage);

          String pageText = recognizedText.text;
          print('OCR extracted ${pageText.length} characters from page $i');

          if (pageText.isNotEmpty) {
            combinedText += '--- Page $i ---\n$pageText\n\n';
          }

          // Delete the temporary file
          await tempFile.delete();
        } catch (e) {
          print('Error processing page $i: $e');
        }
      }

      await document.close();
      return combinedText;
    } catch (e) {
      print('Error during multi-page OCR: $e');
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Extract Text from PDF'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Permission status card
            Card(
              margin: const EdgeInsets.all(16.0),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: FutureBuilder<Map<Permission, PermissionStatus>>(
                  future: [
                    Permission.storage,
                    Permission.photos,
                    Permission.videos,
                    Permission.manageExternalStorage,
                  ].request(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    Map<Permission, PermissionStatus> statuses = snapshot.data!;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Permission Status',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        _buildPermissionStatus('Storage',
                            statuses[Permission.storage]?.isGranted ?? false),
                        _buildPermissionStatus('Photos',
                            statuses[Permission.photos]?.isGranted ?? false),
                        _buildPermissionStatus('Videos',
                            statuses[Permission.videos]?.isGranted ?? false),
                        _buildPermissionStatus(
                            'Manage Storage',
                            statuses[Permission.manageExternalStorage]
                                    ?.isGranted ??
                                false),
                        SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () {
                            openAppSettings();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                          child: Text('Open Settings'),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            SizedBox(height: 16),

            // Main content
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Extract Text from PDF Files',
                        style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 20),
                      Text(
                        'This tool extracts text from PDF files using both native text extraction and OCR technology for scanned documents.',
                        style: TextStyle(fontSize: 16, color: Colors.black54),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 40),
                      if (_isLoading) ...[
                        LinearProgressIndicator(value: _progressValue),
                        SizedBox(height: 10),
                        Text(
                          _statusMessage,
                          style: TextStyle(fontSize: 16, color: Colors.black87),
                          textAlign: TextAlign.center,
                        ),
                        if (_totalPages > 0) ...[
                          SizedBox(height: 5),
                          Text(
                            'Page $_currentPage of $_totalPages',
                            style:
                                TextStyle(fontSize: 14, color: Colors.black54),
                            textAlign: TextAlign.center,
                          ),
                        ],
                        SizedBox(height: 20),
                      ] else ...[
                        ElevatedButton(
                          onPressed: () async {
                            String extractedText =
                                await _extractTextFromPdf(context);
                            print(
                                'Final navigation check: extractedText.isNotEmpty = ${extractedText.isNotEmpty}');
                            if (extractedText.isNotEmpty) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ExtractedTextScreen(
                                      extractedText: extractedText),
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                                horizontal: 50, vertical: 20),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Text(
                            'Extract Text',
                            style: TextStyle(fontSize: 20),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionStatus(String name, bool isGranted) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(
            isGranted ? Icons.check_circle : Icons.cancel,
            color: isGranted ? Colors.green : Colors.red,
            size: 20,
          ),
          SizedBox(width: 8),
          Text('$name: ${isGranted ? 'Granted' : 'Denied'}'),
        ],
      ),
    );
  }
}
