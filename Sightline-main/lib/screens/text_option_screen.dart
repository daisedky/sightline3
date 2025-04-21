import 'package:flutter/material.dart';
//import 'package:flutter_tts/flutter_tts.dart';
//import 'package:google_fonts/google_fonts.dart';

class TextOptionsScreen extends StatefulWidget {
  final String? extractedText;

  const TextOptionsScreen({super.key, this.extractedText});

  @override
  _TextOptionsScreenState createState() => _TextOptionsScreenState();
}

class _TextOptionsScreenState extends State<TextOptionsScreen> {
  bool _useDyslexiaFont = false;
  //final FlutterTts _flutterTts = FlutterTts();

  void _toggleFont() {
    setState(() {
      _useDyslexiaFont = !_useDyslexiaFont;
    });
  }

  void _speakText() async {
    if (widget.extractedText != null) {
      // await _flutterTts.setLanguage("en-US");
      //await _flutterTts.setPitch(1.0);
      //await _flutterTts.speak(widget.extractedText!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(16.0),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                widget.extractedText ?? 'No text loaded',
                // style: _useDyslexiaFont
                //       ? GoogleFonts.lexend(fontSize: 18)
                //  : TextStyle(fontSize: 18),
              ),
            ),
          ),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: _toggleFont,
            child: Text('Toggle Dyslexia Font'),
          ),
          ElevatedButton(
            onPressed: _speakText,
            child: Text('Text to Speech'),
          ),
        ],
      ),
    );
  }
}
