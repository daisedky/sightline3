import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart' as file_picker;
import 'package:permission_handler/permission_handler.dart';

import 'pdf_extraction_processor.dart';
import '../extracted_text_screen.dart';

class PdfExtractionHomeScreen extends StatefulWidget {
  final Function(Map<String, dynamic>) onFileUploaded;

  const PdfExtractionHomeScreen({super.key, required this.onFileUploaded});

  @override
  PdfExtractionHomeScreenState createState() => PdfExtractionHomeScreenState();
}

class PdfExtractionHomeScreenState extends State<PdfExtractionHomeScreen> {
  bool _isLoading = false;
  String _statusMessage = '';
  double _progressValue = 0.0;
  int _totalPages = 0;
  int _currentPage = 0;

  // Permission status tracking
  final Map<Permission, bool> _permissionStatus = {
    Permission.storage: false,
    Permission.photos: false,
    Permission.manageExternalStorage: false,
  };

  @override
  void initState() {
    super.initState();
    _checkPermissionStatus();
  }

  Future<void> _checkPermissionStatus() async {
    try {
      Map<Permission, PermissionStatus> statuses = await [
        Permission.storage,
        Permission.photos,
        Permission.manageExternalStorage,
      ].request();

      setState(() {
        statuses.forEach((permission, status) {
          _permissionStatus[permission] = status.isGranted;
        });
      });
    } catch (e) {
      print('Error checking permission status: $e');
    }
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
        if (_permissionStatus.containsKey(permission)) {
          _permissionStatus[permission] = status.isGranted;
        }
      });

      // Update UI with new permission statuses
      setState(() {});

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

  Future<void> _extractTextFromPdf(BuildContext context) async {
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
        return;
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
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        setState(() {
          _isLoading = false;
          _statusMessage = 'No file selected';
          _progressValue = 0.0;
        });
        print('No file selected');
        return;
      }

      file_picker.PlatformFile file = result.files.first;
      print('Selected file: ${file.name} (${file.size} bytes)');
      print('File path: ${file.path}');

      setState(() {
        _statusMessage = 'Processing PDF file...';
        _progressValue = 0.3;
      });

      // Create processor instance
      final processor = PdfExtractionProcessor();

      // Set up progress callback
      void progressCallback(int current, int total, double progress) {
        if (!mounted) return;
        setState(() {
          _currentPage = current;
          _totalPages = total;
          _progressValue = 0.3 + (progress * 0.6); // Scale to 30-90%
          _statusMessage = 'Processing page $current of $total...';
        });
      }

      // Process the PDF
      final extractionResult = await processor.extractTextFromPdf(
        file: file,
        onProgress: progressCallback,
      );

      setState(() {
        _statusMessage = 'Finalizing...';
        _progressValue = 0.95;
      });

      // Check if we have text to display
      if (extractionResult.text.isEmpty) {
        setState(() {
          _isLoading = false;
          _statusMessage = 'No text found in PDF';
          _progressValue = 0.0;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No text could be extracted from this PDF')),
        );
        return;
      }

      setState(() {
        _isLoading = false;
        _statusMessage = '';
        _progressValue = 0.0;
      });

      // Navigate to the extracted text screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ExtractedTextScreen(
            extractedText: extractionResult.text,
            pdfPath: extractionResult.pdfPath,
            pdfFileName: file.name,
          ),
        ),
      );
    } catch (e) {
      print('Error extracting text: $e');
      setState(() {
        _isLoading = false;
        _statusMessage = 'Error: $e';
        _progressValue = 0.0;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error extracting text: $e')),
      );
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Extract Text from PDF'),
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () {
              openAppSettings();
            },
          ),
        ],
      ),
      body: Container(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Permission status card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Permission Status',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    _buildPermissionStatus('Storage',
                        _permissionStatus[Permission.storage] ?? false),
                    _buildPermissionStatus('Photos',
                        _permissionStatus[Permission.photos] ?? false),
                    _buildPermissionStatus(
                        'Manage Storage',
                        _permissionStatus[Permission.manageExternalStorage] ??
                            false),
                    SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          icon: Icon(Icons.refresh),
                          label: Text('Refresh'),
                          onPressed: _checkPermissionStatus,
                        ),
                        TextButton.icon(
                          icon: Icon(Icons.settings),
                          label: Text('Open Settings'),
                          onPressed: () {
                            openAppSettings();
                          },
                        ),
                      ],
                    ),
                  ],
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
                          onPressed: () => _extractTextFromPdf(context),
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
}
