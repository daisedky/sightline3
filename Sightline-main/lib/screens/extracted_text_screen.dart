import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'text_to_speech_screen.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';

class ExtractedTextScreen extends StatefulWidget {
  final String extractedText;
  final String? pdfPath;
  final String? pdfFileName;

  const ExtractedTextScreen(
      {super.key, required this.extractedText, this.pdfPath, this.pdfFileName});

  @override
  _ExtractedTextScreenState createState() => _ExtractedTextScreenState();
}

class _ExtractedTextScreenState extends State<ExtractedTextScreen> {
  late TextEditingController _textController;
  bool _isSaving = false;
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.extractedText);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _copyToClipboard() async {
    await Clipboard.setData(ClipboardData(text: _textController.text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Text copied to clipboard')),
    );
  }

  Future<void> _saveToFile() async {
    setState(() {
      _isSaving = true;
      _statusMessage = 'Checking permissions...';
    });

    try {
      // Check storage permission
      var status = await Permission.storage.status;
      if (!status.isGranted) {
        status = await Permission.storage.request();
        if (!status.isGranted) {
          setState(() {
            _isSaving = false;
            _statusMessage = 'Storage permission denied';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Storage permission is required to save files')),
          );
          return;
        }
      }

      setState(() {
        _statusMessage = 'Saving file...';
      });

      // Get the documents directory
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = '${directory.path}/extracted_text_$timestamp.txt';

      // Write the text to a file
      final file = File(path);
      await file.writeAsString(_textController.text);

      setState(() {
        _isSaving = false;
        _statusMessage = '';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Text saved to: $path'),
          duration: Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Share',
            onPressed: () => _shareFile(path),
          ),
        ),
      );
    } catch (e) {
      setState(() {
        _isSaving = false;
        _statusMessage = 'Error: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving file: $e')),
      );
    }
  }

  Future<void> _shareText() async {
    try {
      await Share.share(_textController.text, subject: 'Extracted Text');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sharing text: $e')),
      );
    }
  }

  Future<void> _shareFile(String filePath) async {
    try {
      await Share.shareXFiles([XFile(filePath)], text: 'Extracted Text');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sharing file: $e')),
      );
    }
  }

  Future<void> _sharePdf() async {
    try {
      await Share.shareXFiles([XFile(widget.pdfPath!)],
          text: widget.pdfFileName);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sharing PDF: $e')),
      );
    }
  }

  void _speakText() {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => TextToSpeechScreen(
                extractedText: _textController.text,
              )),
    );
  }

  Future<void> _viewPdf() async {
    if (widget.pdfPath != null && widget.pdfPath!.isNotEmpty) {
      try {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => Scaffold(
              appBar: AppBar(
                title: Text(widget.pdfFileName ?? 'PDF Viewer'),
                backgroundColor: Theme.of(context).primaryColor,
              ),
              body: PDFView(
                filePath: widget.pdfPath!,
                enableSwipe: true,
                swipeHorizontal: true,
                autoSpacing: false,
                pageFling: false,
                onError: (error) {
                  print('Error loading PDF: $error');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error loading PDF: $error')),
                  );
                },
                onPageError: (page, error) {
                  print('Error loading page $page: $error');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error loading page $page: $error')),
                  );
                },
              ),
            ),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening PDF: $e')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No PDF file available to view')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Extracted Text'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.copy),
            tooltip: 'Copy to Clipboard',
            onPressed: _copyToClipboard,
          ),
          IconButton(
            icon: Icon(Icons.save),
            tooltip: 'Save to File',
            onPressed: _isSaving ? null : _saveToFile,
          ),
          IconButton(
            icon: Icon(Icons.share),
            tooltip: 'Share Text',
            onPressed: _shareText,
          ),
          if (widget.pdfPath != null && widget.pdfPath!.isNotEmpty)
            IconButton(
              icon: Icon(Icons.picture_as_pdf),
              tooltip: 'View PDF',
              onPressed: _viewPdf,
            ),
          IconButton(
            icon: Icon(Icons.volume_up),
            tooltip: 'Speak',
            onPressed: _speakText,
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Edit Extracted Text',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            if (_isSaving) ...[
              LinearProgressIndicator(),
              SizedBox(height: 10),
              Text(
                _statusMessage,
                style: TextStyle(fontSize: 16, color: Colors.black87),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 10),
            ],
            Expanded(
              child: Container(
                padding: EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  border: Border.all(color: Color(0xFFADD8E6)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TextFormField(
                  controller: _textController,
                  maxLines: null,
                  expands: true,
                  decoration: InputDecoration(
                    hintText: 'Extracted text will appear here...',
                    border: InputBorder.none,
                  ),
                  style: TextStyle(fontSize: 18, color: Colors.black87),
                ),
              ),
            ),
            SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _copyToClipboard,
                  icon: Icon(Icons.copy, size: 16),
                  label: Text('Copy', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: Size(80, 36),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveToFile,
                  icon: Icon(Icons.save, size: 16),
                  label: Text('Save', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: Size(80, 36),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    disabledBackgroundColor: Colors.grey,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _shareText,
                  icon: Icon(Icons.share, size: 16),
                  label: Text('Share Text', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: Size(80, 36),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                if (widget.pdfPath != null && widget.pdfPath!.isNotEmpty)
                  ElevatedButton.icon(
                    onPressed: _viewPdf,
                    icon: Icon(Icons.visibility, size: 16),
                    label: Text('View PDF', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      padding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      minimumSize: Size(80, 36),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                if (widget.pdfPath != null && widget.pdfPath!.isNotEmpty)
                  ElevatedButton.icon(
                    onPressed: _sharePdf,
                    icon: Icon(Icons.picture_as_pdf, size: 16),
                    label: Text('Share PDF', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      padding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      minimumSize: Size(80, 36),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ElevatedButton.icon(
                  onPressed: _speakText,
                  icon: Icon(Icons.volume_up, size: 16),
                  label: Text('Speak', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: Size(80, 36),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
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
