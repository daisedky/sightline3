import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../models/text_to_speech_model.dart';
import '../utils/logger.dart';

/// Controller class for Text-to-Speech feature
/// Handles all business logic and operations related to TTS
class TextToSpeechController {
  // TTS engine instance
  final FlutterTts flutterTts = FlutterTts();
  
  // Model containing all state and data
  final TextToSpeechModel model = TextToSpeechModel();
  
  // Flag to track if we should continue speaking chunks
  bool _shouldContinueSpeaking = true;
  
  // Function to initialize TTS
  Future<void> initTts(BuildContext context) async {
    try {
      // Set up TTS engine with model parameters
      await flutterTts.setVolume(model.volume);
      await flutterTts.setPitch(model.pitch);
      await flutterTts.setSpeechRate(model.rate);
      await flutterTts.setLanguage(model.selectedLanguage);
      
      // Set up error and completion handlers
      flutterTts.setErrorHandler((error) {
        AppLogger.error('TTS Error: $error');
        model.setPlaying(false);
        _shouldContinueSpeaking = false;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('TTS Error: $error')),
        );
      });
      
      flutterTts.setStartHandler(() {
        AppLogger.info('TTS Started');
        model.setPlaying(true);
      });
      
      flutterTts.setCompletionHandler(() {
        AppLogger.info('TTS Completed');
        model.setPlaying(false);
      });
      
      flutterTts.setCancelHandler(() {
        AppLogger.info('TTS Cancelled');
        model.setPlaying(false);
        _shouldContinueSpeaking = false;
      });
      
      flutterTts.setPauseHandler(() {
        AppLogger.info('TTS Paused');
        model.setPlaying(false);
        _shouldContinueSpeaking = false;
      });
      
      flutterTts.setContinueHandler(() {
        AppLogger.info('TTS Continued');
        model.setPlaying(true);
      });
      
      // Check available languages
      try {
        List<dynamic>? availableLangs = await flutterTts.getLanguages;
        AppLogger.info('Available languages: $availableLangs');
        
        if (availableLangs != null) {
          List<String> availableLanguages = availableLangs.map((lang) => lang.toString()).toList();
          // Filter our predefined languages to only include available ones
          List<String> filteredLanguages = model.languages.where((lang) => 
            availableLanguages.any((available) => available.toLowerCase().contains(lang.toLowerCase().split('-')[0]))
          ).toList();
          
          if (filteredLanguages.isEmpty) {
            model.languages = ['en-US']; // Fallback to English if no matches
            AppLogger.info('No matching languages found, falling back to en-US');
          } else {
            model.languages = filteredLanguages;
            AppLogger.info('Filtered languages: ${model.languages}');
          }
        }
      } catch (e) {
        AppLogger.error('Error getting languages: $e');
      }
      
      // Check if TTS is available
      bool? isAvailable = await flutterTts.isLanguageAvailable(model.selectedLanguage);
      AppLogger.info('Is language ${model.selectedLanguage} available: $isAvailable');
      
      // Get current engine
      String? engine = await flutterTts.getDefaultEngine;
      AppLogger.info('Current TTS engine: $engine');
      
      // Update model with engine information
      var voices = await flutterTts.getVoices ?? [];
      model.setEngineInfo(engine, voices.map((v) => v.toString()).toList(), isAvailable ?? false);
      
    } catch (e) {
      AppLogger.error('Error initializing TTS: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error initializing TTS: $e')),
      );
    }
  }
  
  // Function to handle text changes for speak-as-you-type
  void onTextChanged() {
    if (model.speakAsYouType && model.textController.text.isNotEmpty) {
      // Get the last word or character
      String currentText = model.textController.text;
      if (currentText != model.lastSpokenText) {
        String textToSpeak = '';
        
        // If there's a space, speak the last word
        if (currentText.contains(' ')) {
          List<String> words = currentText.split(' ');
          String lastWord = words.last;
          
          // Only speak if the last word is complete (followed by a space)
          if (currentText.endsWith(' ') && lastWord.isNotEmpty) {
            textToSpeak = lastWord;
            model.lastSpokenText = currentText;
          }
        } else if (model.lastSpokenText.isEmpty) {
          // First character
          textToSpeak = currentText;
          model.lastSpokenText = currentText;
        } else if (currentText.length > model.lastSpokenText.length) {
          // New character added
          textToSpeak = currentText.substring(model.lastSpokenText.length);
          model.lastSpokenText = currentText;
        }
        
        if (textToSpeak.isNotEmpty) {
          flutterTts.speak(textToSpeak);
        }
      }
    }
  }
  
  // Function to preprocess text for TTS
  String _preprocessText(String text) {
    // Remove any special characters that might cause issues
    String processed = text.replaceAll(RegExp(r'[^\w\s.,;:!?()-]'), ' ');
    
    // Limit text length if too long (some TTS engines have limits)
    if (processed.length > 4000) {
      processed = processed.substring(0, 4000);
      AppLogger.info('Text truncated to 4000 characters for TTS compatibility');
    }
    
    // Ensure there are no extremely long words (can cause issues in some TTS engines)
    List<String> words = processed.split(' ');
    List<String> processedWords = words.map((word) {
      if (word.length > 100) {
        return word.substring(0, 100);
      }
      return word;
    }).toList();
    
    return processedWords.join(' ');
  }
  
  // Function to speak text
  Future<bool> speak(BuildContext context) async {
    AppLogger.info('speak method called');
    AppLogger.info('Text content: "${model.textController.text}"');
    
    if (model.textController.text.isEmpty) {
      AppLogger.info('Text is empty, showing snackbar');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter some text to speak')),
      );
      return false;
    }
    
    if (model.isPlaying) {
      AppLogger.info('Already playing, pausing');
      await pause();
      return false;
    } else {
      AppLogger.info('Starting speech with language: ${model.selectedLanguage}');
      
      try {
        // Reset the continue flag
        _shouldContinueSpeaking = true;
        
        // Preprocess text to avoid common TTS issues
        String textToSpeak = _preprocessText(model.textController.text);
        AppLogger.info('Preprocessed text length: ${textToSpeak.length}');
        
        // Try to speak in smaller chunks if the text is long
        if (textToSpeak.length > 1000) {
          AppLogger.info('Text is long, speaking in chunks');
          
          // Split text into sentences or paragraphs
          List<String> chunks = textToSpeak.split(RegExp(r'(?<=[.!?])\s+'));
          AppLogger.info('Split text into ${chunks.length} chunks');
          
          // Speak the first chunk
          var result = await flutterTts.speak(chunks.first);
          AppLogger.info('First chunk speak result: $result');
          
          if (result == 1) {
            model.setPlaying(true);
            
            // Queue the rest of the chunks
            for (int i = 1; i < chunks.length; i++) {
              // Check if we should continue before each chunk
              if (!_shouldContinueSpeaking) {
                AppLogger.info('Speech interrupted, stopping chunk playback');
                break;
              }
              
              if (chunks[i].trim().isNotEmpty) {
                // Wait for the previous chunk to complete
                await flutterTts.awaitSpeakCompletion(true);
                
                // Check again if we should continue
                if (!_shouldContinueSpeaking) {
                  AppLogger.info('Speech interrupted after completion, stopping chunk playback');
                  break;
                }
                
                // Speak the next chunk
                await flutterTts.speak(chunks[i]);
              }
            }
            return true;
          } else {
            AppLogger.info('TTS speak returned unexpected result: $result');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to start speech. Please check your device settings.')),
            );
            return false;
          }
        } else {
          // Speak the entire text if it's not too long
          AppLogger.info('Attempting to speak text');
          var result = await flutterTts.speak(textToSpeak);
          AppLogger.info('Speak result: $result');
          
          if (result == 1) {
            model.setPlaying(true);
            return true;
          } else {
            AppLogger.info('TTS speak returned unexpected result: $result');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to start speech. Please check your device settings.')),
            );
            return false;
          }
        }
      } catch (e) {
        AppLogger.error('Error during speech: $e');
        model.setPlaying(false);
        _shouldContinueSpeaking = false;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
        return false;
      }
    }
  }
  
  // Function to pause speech
  Future<void> pause() async {
    AppLogger.info('Pause method called');
    _shouldContinueSpeaking = false;
    
    if (model.isPlaying) {
      await flutterTts.pause();
      model.setPlaying(false);
    }
  }
  
  // Function to stop speech
  Future<void> stop() async {
    AppLogger.info('Stop method called');
    _shouldContinueSpeaking = false;
    
    await flutterTts.stop();
    model.setPlaying(false);
  }
  
  // Function to set language
  Future<void> setLanguage(String language) async {
    await flutterTts.setLanguage(language);
    model.setLanguage(language);
  }
  
  // Function to update volume
  Future<void> setVolume(double value) async {
    await flutterTts.setVolume(value);
    model.setVolume(value);
  }
  
  // Function to update pitch
  Future<void> setPitch(double value) async {
    await flutterTts.setPitch(value);
    model.setPitch(value);
  }
  
  // Function to update rate
  Future<void> setRate(double value) async {
    await flutterTts.setSpeechRate(value);
    model.setRate(value);
  }
  
  // Function to build tappable words
  List<Widget> buildTappableWords() {
    // Split text into words and limit to 100 words maximum to prevent overflow
    List<String> words = model.textController.text.split(RegExp(r'\s+'));
    if (words.length > 100) {
      words = words.sublist(0, 100);
    }
    
    return words.where((word) => word.isNotEmpty).map((word) {
      return GestureDetector(
        onTap: () {
          flutterTts.speak(word);
        },
        child: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(word),
        ),
      );
    }).toList();
  }
  
  // Function to test TTS
  Future<void> testTts(BuildContext context) async {
    AppLogger.info('Testing TTS with a simple phrase');
    try {
      // First check TTS engine status
      await checkTtsStatus(context);
      
      // Then try to speak a test phrase
      var result = await flutterTts.speak('Hello, this is a test of the text to speech functionality.');
      AppLogger.info('Test speak result: $result');
      
      if (result == 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('TTS test started successfully')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('TTS test failed with result: $result')),
        );
      }
    } catch (e) {
      AppLogger.error('Error during TTS test: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error during TTS test: $e')),
      );
    }
  }
  
  // Function to check TTS status
  Future<void> checkTtsStatus(BuildContext context) async {
    AppLogger.info('Checking TTS status');
    try {
      // Check if the selected language is available
      bool? isLanguageAvailable = await flutterTts.isLanguageAvailable(model.selectedLanguage);
      AppLogger.info('Is language ${model.selectedLanguage} available: $isLanguageAvailable');
      
      // Get available voices for the selected language
      var voices = await flutterTts.getVoices;
      AppLogger.info('Available voices: $voices');
      
      // Get the default engine
      var engine = await flutterTts.getDefaultEngine;
      AppLogger.info('Default engine: $engine');
      
      // Get available engines
      var engines = await flutterTts.getEngines;
      AppLogger.info('Available engines: $engines');
      
      // Update model with engine information
      model.setEngineInfo(engine, voices?.map((v) => v.toString()).toList() ?? [], isLanguageAvailable ?? false);
      
      // Display TTS status to user
      String statusMessage = 'TTS Status:\n';
      statusMessage += '- Language: ${model.selectedLanguage} (Available: $isLanguageAvailable)\n';
      statusMessage += '- Engine: $engine\n';
      statusMessage += '- Available engines: $engines\n';
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('TTS Status'),
          content: SingleChildScrollView(
            child: Text(statusMessage),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      AppLogger.error('Error checking TTS status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error checking TTS status: $e')),
      );
    }
  }
  
  // Clean up resources
  void dispose() {
    flutterTts.stop();
    model.dispose();
  }
}
