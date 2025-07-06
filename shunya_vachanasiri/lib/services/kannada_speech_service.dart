// // lib/services/kannada_speech_service.dart
// import 'package:speech_to_text/speech_to_text.dart';

// class KannadaSpeechService {
//   static final SpeechToText _speech = SpeechToText();
//   static bool _initialized = false;

//   static Future<bool> initialize() async {
//     if (!_initialized) {
//       _initialized = await _speech.initialize();
//     }
//     return _initialized;
//   }

//   static Future<String> recognizeKannada() async {
//     if (!_initialized) await initialize();
//     String recognizedText = '';

//     try {
//       await _speech.listen(
//         onResult: (result) => recognizedText = result.recognizedText,
//         localeId: 'kn-IN',
//         listenFor: const Duration(seconds: 15),
//         pauseFor: const Duration(seconds: 3),
//       );

//       // Wait for speech recognition to complete
//       await Future.delayed(const Duration(seconds: 15));
//       await _speech.stop();
//     } catch (e) {
//       return '';
//     }

//     return recognizedText;
//   }

//   static void close() {
//     _speech.close();
//   }
// }
