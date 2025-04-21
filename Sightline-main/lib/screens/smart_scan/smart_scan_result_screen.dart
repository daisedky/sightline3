import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../text_to_speech_screen.dart';

class SmartScanResultScreen extends StatefulWidget {
  final String extractedText;
  final bool isHandwritingMode;

  const SmartScanResultScreen({
    super.key,
    required this.extractedText,
    this.isHandwritingMode = false,
  });

  @override
  _SmartScanResultScreenState createState() => _SmartScanResultScreenState();
}

class _SmartScanResultScreenState extends State<SmartScanResultScreen> {
  late TextEditingController _textController;
  bool _isSaving = false;
  bool _isFormatted = true; // Track if text is formatted
  String _rawText = '';

  @override
  void initState() {
    super.initState();
    _rawText = widget.extractedText;
    _textController = TextEditingController(text: widget.extractedText);

    // Add debug print to check if text is being received
    print('SmartScanResultScreen received text: "${widget.extractedText}"');
    print('Text length: ${widget.extractedText.length}');

    // Show success message
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.extractedText.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.isHandwritingMode
                ? 'Handwriting recognized successfully!'
                : 'Text extracted successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        // Show message if no text was extracted
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'No text was extracted. Try adjusting the image or scan settings.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _copyToClipboard() async {
    await Clipboard.setData(ClipboardData(text: _textController.text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Text copied to clipboard')),
    );
  }

  void _shareText() async {
    await Share.share(_textController.text, subject: 'Scanned Text');
  }

  void _saveToFile() async {
    setState(() {
      _isSaving = true;
    });

    try {
      final directory = await getApplicationDocumentsDirectory();
      final fileName =
          'scanned_text_${DateTime.now().millisecondsSinceEpoch}.txt';
      final file = File('${directory.path}/$fileName');

      await file.writeAsString(_textController.text);

      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Text saved to $fileName')),
      );
    } catch (e) {
      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving text: $e')),
      );
    }
  }

  void _speakText() {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) =>
              TextToSpeechScreen(extractedText: _textController.text)),
    );
  }

  // Toggle between formatted and raw text
  void _toggleFormatting() {
    setState(() {
      if (_isFormatted) {
        // Switch to raw text - preserve all whitespace
        _textController.text = _rawText;
      } else {
        // Switch to formatted text
        _textController.text = _formatText(_rawText);
      }
      _isFormatted = !_isFormatted;
    });
  }

  // Format text for better readability
  String _formatText(String text) {
    if (text.isEmpty) return text;

    // Replace multiple spaces with a single space
    String formatted = text.replaceAll(RegExp(r'\s{2,}'), ' ');

    // Replace multiple newlines with a single newline
    formatted = formatted.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    // Ensure proper spacing after punctuation
    formatted = formatted.replaceAll(RegExp(r'([.!?])([A-Z])'), r'$1 $2');

    // Fix common spacing issues
    formatted = formatted.replaceAll(RegExp(r'(\w)([,.!?:;])(\w)'), r'$1$2 $3');

    return formatted;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Scan Results'),
        actions: [
          // Format toggle button
          IconButton(
            icon: Icon(_isFormatted ? Icons.text_format : Icons.text_fields),
            tooltip: _isFormatted ? 'Show Raw Text' : 'Show Formatted Text',
            onPressed: _toggleFormatting,
          ),
        ],
      ),
      body: Column(
        children: [
          // Header with scan type indicator
          Container(
            padding: EdgeInsets.all(12),
            color: widget.isHandwritingMode
                ? Colors.purple.withOpacity(0.1)
                : Colors.blue.withOpacity(0.1),
            child: Row(
              children: [
                Icon(
                  widget.isHandwritingMode ? Icons.edit : Icons.text_fields,
                  color: widget.isHandwritingMode ? Colors.purple : Colors.blue,
                ),
                SizedBox(width: 8),
                Text(
                  widget.isHandwritingMode
                      ? 'Handwritten Text'
                      : 'Printed Text',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color:
                        widget.isHandwritingMode ? Colors.purple : Colors.blue,
                  ),
                ),
                Spacer(),
                TextButton.icon(
                  icon: Icon(_isFormatted ? Icons.code : Icons.text_format),
                  label: Text(_isFormatted ? 'Raw Text' : 'Format Text'),
                  onPressed: _toggleFormatting,
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.primary,
                    backgroundColor: Theme.of(context)
                        .colorScheme
                        .primaryContainer
                        .withOpacity(0.3),
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
          ),

          // Main text area
          Expanded(
            child: Container(
              padding: EdgeInsets.all(16),
              child: widget.extractedText.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.text_snippet_outlined,
                            size: 72,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No text was detected',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[700],
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Try scanning again with different settings',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : TextField(
                      controller: _textController,
                      maxLines: null,
                      expands: true,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Extracted text will appear here...',
                      ),
                      style: TextStyle(
                        fontSize: 22, // Larger text size
                        height: 1.5,
                        letterSpacing: 0.5,
                        color: Colors.black87,
                        fontFamily: widget.isHandwritingMode ? 'Roboto' : null,
                      ),
                    ),
            ),
          ),

          // Bottom action buttons
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _copyToClipboard,
                  icon: Icon(Icons.copy),
                  label: Text('Copy'),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveToFile,
                  icon: Icon(Icons.save),
                  label: Text('Save'),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    disabledBackgroundColor: Colors.grey,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _shareText,
                  icon: Icon(Icons.share),
                  label: Text('Share'),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _speakText,
                  icon: Icon(Icons.volume_up),
                  label: Text('Speak'),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
