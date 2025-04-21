import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'view_all_screen.dart';
import 'smart_scan/smart_scan_home_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'extract_text_from_pdf_screen.dart';
import 'text_to_speech_screen.dart';
import 'change_pdf_font_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../controllers/document_controller.dart';

class HomeScreen extends StatefulWidget {
  final List<Map<String, dynamic>> recentFiles;
  final Function(List<int>) onFilesDeleted;
  final Function(Map<String, dynamic>) onFileUploaded;

  const HomeScreen({
    super.key,
    required this.recentFiles,
    required this.onFilesDeleted,
    required this.onFileUploaded,
  });

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final Set<int> _selectedIndices = {};
  late TabController _tabController;
  int _currentTabIndex = 0;

  final DocumentController _documentController = DocumentController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _currentTabIndex = _tabController.index;
      });
    });

    _fetchDocuments();
  }

  Future<void> _fetchDocuments() async {
    await _documentController.fetchUserDocuments();
    final files = _documentController.documents
        .map((doc) => {
              'name': doc.fileName,
              'path': doc.url,
              'timestamp': doc.uploadedAt.toString(),
              'type': doc.fileType,
              'text': doc.processedText ?? '',
            })
        .toList();
    for (final file in files) {
      widget.onFileUploaded(file);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Show confirmation dialog before deleting
  Future<bool> _confirmDelete(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Files'),
            content: Text(
                'Are you sure you want to delete ${_selectedIndices.length} file${_selectedIndices.length == 1 ? '' : 's'}?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false), // Cancel
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true), // Confirm
                child:
                    const Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ) ??
        false; // Default to false if dialog is dismissed
  }

  // Handle PDF upload
  Future<void> _pickPDF() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null) {
        File file = File(result.files.single.path!);
        final user = FirebaseAuth.instance.currentUser;

        if (user == null) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('User not logged in')));
          return;
        }

        final uploadedDoc = await _documentController.uploadDocument(
          file: file,
          type: 'pdf',
        );

        if (uploadedDoc != null) {
          Map<String, dynamic> newFile = {
            'name': uploadedDoc.fileName,
            'path': uploadedDoc.url,
            'timestamp': uploadedDoc.uploadedAt.toString(),
            'type': uploadedDoc.fileType,
            'text': '',
          };

          widget.onFileUploaded(newFile);
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Uploaded: ${uploadedDoc.fileName}')));
        } else {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Upload failed')));
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking PDF: $e')),
      );
    }
  }

  // Handle image upload for Smart Scan
  Future<void> _pickImageForSmartScan(ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(source: source);

      if (pickedFile != null) {
        // Navigate to Smart Scan screen with the selected image
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SmartScanHomeScreen(
              onFileUploaded: widget.onFileUploaded,
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  // Show image source selection dialog
  Future<void> _showImageSourceDialog() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Image Source'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Camera'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImageForSmartScan(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImageForSmartScan(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('home'),
        backgroundColor: isDark ? Colors.black : const Color(0xFF1E90FF),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: isDark ? Colors.purple : Colors.white,
          tabs: const [
            Tab(
                icon: Icon(
                  Icons.file_copy,
                ),
                text: 'Files'),
            Tab(
                icon: Icon(
                  Icons.picture_as_pdf,
                ),
                text: 'PDF'),
            Tab(icon: Icon(Icons.image), text: 'Smart Scan'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Home Tab with Recent Files
          _buildRecentFilesTab(),

          // PDF Upload Tab
          _buildPDFUploadTab(),

          // Smart Scan Tab
          _buildSmartScanTab(),
        ],
      ),
    );
  }

  // Tab 1: Recent Files
  Widget _buildRecentFilesTab() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      color: isDark ? Colors.black : Colors.white,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recents',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Row(
                  children: [
                    TextButton(
                      onPressed: () {
                        setState(() {
                          if (_selectedIndices.length ==
                              widget.recentFiles.length) {
                            _selectedIndices.clear(); // Deselect all
                          } else {
                            _selectedIndices.addAll(
                              List.generate(
                                  widget.recentFiles.length, (index) => index),
                            ); // Select all
                          }
                        });
                      },
                      child: Text(
                        _selectedIndices.length == widget.recentFiles.length
                            ? 'Deselect All'
                            : 'Select All',
                        style: TextStyle(
                          fontSize: 16,
                          color:
                              isDark ? Colors.purple : const Color(0xFF1E90FF),
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ViewAllScreen(),
                          ),
                        );
                      },
                      child: Text(
                        'View All >',
                        style: TextStyle(
                          fontSize: 16,
                          color:
                              isDark ? Colors.purple : const Color(0xFF1E90FF),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: widget.recentFiles.isEmpty
                ? Center(
                    child: Text(
                      'No recent files',
                      style: TextStyle(
                          fontSize: 18,
                          color: isDark ? Colors.white70 : Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: widget.recentFiles.length,
                    itemBuilder: (context, index) {
                      final file = widget.recentFiles[index];
                      final bool isSelected = _selectedIndices.contains(index);

                      // Determine icon based on file type
                      IconData fileIcon;
                      Color iconColor;

                      if (file['type'] == 'pdf') {
                        fileIcon = Icons.picture_as_pdf;
                        iconColor = isDark ? Colors.purpleAccent : Colors.red;
                      } else if (file['type'] == 'image' ||
                          file['type'] == 'smart_scan') {
                        fileIcon = Icons.image;
                        iconColor = isDark ? Colors.purple : Colors.blue;
                      } else {
                        fileIcon = Icons.insert_drive_file;
                        iconColor = isDark ? Colors.white70 : Colors.grey;
                      }

                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        elevation: 2,
                        color: isDark ? Colors.black : null,
                        child: ListTile(
                          leading: Icon(fileIcon, color: iconColor, size: 36),
                          title: Text(
                            file['name'],
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white : null,
                            ),
                          ),
                          subtitle: Text(
                            file['timestamp'],
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? Colors.white60 : Colors.grey[600],
                            ),
                          ),
                          trailing: Checkbox(
                            value: isSelected,
                            onChanged: (bool? value) {
                              setState(() {
                                if (value == true) {
                                  _selectedIndices.add(index);
                                } else {
                                  _selectedIndices.remove(index);
                                }
                              });
                            },
                            activeColor: isDark
                                ? Colors.purple
                                : const Color(0xFF1E90FF),
                          ),
                          onTap: () {
                            String message = file.containsKey('text') &&
                                    file['text'].isNotEmpty
                                ? 'Extracted Text: ${file['text'].length > 50 ? file['text'].substring(0, 50) + '...' : file['text']}'
                                : 'File tapped: ${file['name']}';
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(message)),
                            );
                          },
                        ),
                      );
                    },
                  ),
          ),
          if (widget.recentFiles.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      if (_selectedIndices.isNotEmpty) {
                        List<Map<String, dynamic>> selectedFiles =
                            _selectedIndices
                                .map((index) => widget.recentFiles[index])
                                .toList();
                        String shareText =
                            'Selected Files:\n${selectedFiles.map((f) => f['name']).join('\n')}';
                        Share.share(shareText);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  'Please select at least one file to share')),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          isDark ? Colors.purple : const Color(0xFF1E90FF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Share',
                        style: TextStyle(fontSize: 16, color: Colors.white)),
                  ),
                  if (_selectedIndices
                      .isNotEmpty) // Show Delete button only if files are selected
                    ElevatedButton(
                      onPressed: () async {
                        bool confirm = await _confirmDelete(context);
                        if (confirm) {
                          widget.onFilesDeleted(_selectedIndices.toList());
                          setState(() {
                            _selectedIndices
                                .clear(); // Clear selection after deletion
                          });
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Delete',
                          style: TextStyle(fontSize: 16, color: Colors.white)),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // Tab 2: PDF Upload
  Widget _buildPDFUploadTab() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      color: isDark ? Colors.black : Colors.white,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 20),

              // Extract Text from PDF Card
              Card(
                elevation: 3,
                color: isDark ? Colors.black : null,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: isDark
                      ? BorderSide(
                          color: Colors.purple.withOpacity(0.5), width: 1)
                      : BorderSide.none,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Icon(
                        Icons.text_snippet,
                        size: 40,
                        color: isDark ? Colors.purple : Colors.blue,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Extract Text from PDF',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : null,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Extract and save text content from PDF documents',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.white70 : Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 15),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ExtractTextFromPdfScreen(
                                  onFileUploaded: widget.onFileUploaded),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark ? Colors.purple : Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Extract Text'),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Text to Speech Card
              Card(
                elevation: 3,
                color: isDark ? Colors.black : null,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: isDark
                      ? BorderSide(
                          color: Colors.purple.withOpacity(0.5), width: 1)
                      : BorderSide.none,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Icon(
                        Icons.record_voice_over,
                        size: 40,
                        color: isDark ? Colors.purpleAccent : Colors.green,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Text to Speech',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : null,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Convert PDF text to speech for easier comprehension',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.white70 : Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 15),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  TextToSpeechScreen(extractedText: ''),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              isDark ? Colors.purple : Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Text to Speech'),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Change PDF Font Card
              Card(
                elevation: 3,
                color: isDark ? Colors.black : null,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: isDark
                      ? BorderSide(
                          color: Colors.purple.withOpacity(0.5), width: 1)
                      : BorderSide.none,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Icon(
                        Icons.font_download,
                        size: 40,
                        color: isDark ? Colors.purpleAccent : Colors.redAccent,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Change PDF Font',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : null,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Customize PDF fonts for better readability',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.white70 : Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 15),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChangePdfFontScreen(
                                  onFileUploaded: widget.onFileUploaded),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              isDark ? Colors.purple : Colors.redAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Change Font'),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // Tab 3: Smart Scan
  Widget _buildSmartScanTab() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      color: isDark ? Colors.black : Colors.white,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.document_scanner,
              size: 100,
              color: isDark ? Colors.purple : Colors.blue,
            ),
            const SizedBox(height: 20),
            Text(
              'Smart Scan',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Scan documents and extract text with advanced handwriting recognition',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.white70 : Colors.grey,
              ),
            ),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _pickImageForSmartScan(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Camera'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? Colors.purple : Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                ElevatedButton.icon(
                  onPressed: () => _pickImageForSmartScan(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Gallery'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? Colors.purple : Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
