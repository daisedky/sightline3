import 'package:flutter/material.dart';

/// Model class for Text-to-Speech feature
/// Contains all data structures and state for TTS functionality
class TextToSpeechModel {
  // Text content
  final TextEditingController textController = TextEditingController();
  String lastSpokenText = '';
  
  // TTS state
  bool isPlaying = false;
  
  // Voice settings
  double volume = 1.0;
  double pitch = 1.0;
  double rate = 0.5;
  String selectedLanguage = 'en-US';
  List<String> languages = ['en-US', 'ar-SA', 'fr-FR', 'de-DE', 'es-ES'];
  
  // Feature toggles
  bool speakAsYouType = false;
  
  // Engine information
  String? engineName;
  List<String> availableVoices = [];
  bool isLanguageAvailable = false;
  
  // Getters for formatted values (useful for UI display)
  String get volumeFormatted => volume.toStringAsFixed(1);
  String get pitchFormatted => pitch.toStringAsFixed(1);
  String get rateFormatted => rate.toStringAsFixed(1);
  
  // Methods to update model state
  void setVolume(double value) {
    volume = value;
  }
  
  void setPitch(double value) {
    pitch = value;
  }
  
  void setRate(double value) {
    rate = value;
  }
  
  void setLanguage(String value) {
    selectedLanguage = value;
  }
  
  void setSpeakAsYouType(bool value) {
    speakAsYouType = value;
  }
  
  void setPlaying(bool value) {
    isPlaying = value;
  }
  
  void setEngineInfo(String? engine, List<String> voices, bool langAvailable) {
    engineName = engine;
    availableVoices = voices.map((v) => v.toString()).toList();
    isLanguageAvailable = langAvailable;
  }
  
  // Helper method to get language display name
  String getLanguageDisplayName(String langCode) {
    switch (langCode) {
      case 'en-US': return 'English';
      case 'ar-SA': return 'Arabic';
      case 'fr-FR': return 'French';
      case 'de-DE': return 'German';
      case 'es-ES': return 'Spanish';
      default: return langCode;
    }
  }
  
  // Clean up resources
  void dispose() {
    textController.dispose();
  }
}
