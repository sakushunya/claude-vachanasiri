// voice_search_screen.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter/services.dart';

class VoiceSearchScreen extends StatefulWidget {
  const VoiceSearchScreen({super.key});

  @override
  State<VoiceSearchScreen> createState() => _VoiceSearchScreenState();
}

class _VoiceSearchScreenState extends State<VoiceSearchScreen>
    with SingleTickerProviderStateMixin {
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _text = 'Press mic and start speaking';
  String _finalText = '';
  final TextEditingController _searchController = TextEditingController();
  double _soundLevel = 0.0;
  bool _permissionDenied = false;
  late AnimationController _animationController;
  List<double> _barHeights = [];
  final int _barCount = 7;
  final Random _random = Random();
  bool _speechInitialized = false;
  FocusNode _focusNode = FocusNode();
  String _selectedLanguage = 'kn_IN'; // Default to Kannada
  bool _isProcessing = false;
  Timer? _barAnimationTimer;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _initializeBars();
    _initSpeech();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.unfocus();
    });
  }

  void _initializeBars() {
    _barHeights = List.generate(_barCount, (index) => 10.0);
  }

  void _startBarAnimation() {
    _barAnimationTimer?.cancel();
    _barAnimationTimer =
        Timer.periodic(const Duration(milliseconds: 100), (timer) {
      setState(() {
        for (int i = 0; i < _barCount; i++) {
          _barHeights[i] = 10.0 + (_random.nextDouble() * 40.0);
        }
      });
    });
  }

  void _stopBarAnimation() {
    _barAnimationTimer?.cancel();
    setState(() {
      _barHeights = List.generate(_barCount, (index) => 10.0);
    });
  }

  Future<void> _initSpeech() async {
    try {
      final available = await _speech.initialize(
        onStatus: (status) {
          if (status == 'done') {
            _stopListening();
          } else if (status == 'notListening') {
            setState(() {
              _isListening = false;
              _isProcessing = false;
            });
            _stopBarAnimation();
          }
        },
        onError: (error) {
          _stopListening();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${error.errorMsg}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        },
      );

      setState(() {
        _speechInitialized = (available == true);
        if (!_speechInitialized) {
          _permissionDenied = true;
        }
      });
    } catch (e) {
      setState(() {
        _permissionDenied = true;
        _speechInitialized = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Initialization error: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<bool> _checkMicrophonePermission() async {
    try {
      final status = await Permission.microphone.status;
      if (status.isGranted) return true;

      final result = await Permission.microphone.request();
      if (!result.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Microphone permission is required for voice search'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return result.isGranted;
    } catch (e) {
      setState(() => _permissionDenied = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error checking microphone permission: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
      return false;
    }
  }

  void _startListening() async {
    if (!_speechInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Speech recognition not ready. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isListening = true;
      _isProcessing = true;
      _text = 'Listening...';
      _permissionDenied = false;
    });

    try {
      if (await _checkMicrophonePermission()) {
        final locales = await _speech.locales();

        // Try to find the selected language, fallback to English if not found
        final preferredLocale = locales.firstWhere(
          (locale) => locale.localeId == _selectedLanguage,
          orElse: () => locales.firstWhere(
            (locale) => locale.localeId.startsWith('en_'),
            orElse: () => locales.first,
          ),
        );

        final started = await _speech.listen(
          onResult: (result) {
            setState(() {
              _text = result.recognizedWords;
              _searchController.text = _text;
              if (result.finalResult) {
                _finalText = result.recognizedWords;
                _isProcessing = false;
              }
            });
          },
          onSoundLevelChange: (level) {
            setState(() => _soundLevel = level);
          },
          localeId: preferredLocale.localeId,
          listenFor: const Duration(minutes: 2),
          pauseFor: const Duration(seconds: 5),
          partialResults: true,
          onDevice: true,
          cancelOnError: true,
        );

        if (started != true) {
          setState(() {
            _isListening = false;
            _isProcessing = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to start listening. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        } else {
          _startBarAnimation();
        }
      } else {
        setState(() {
          _isListening = false;
          _isProcessing = false;
          _permissionDenied = true;
        });
      }
    } catch (e) {
      setState(() {
        _isListening = false;
        _isProcessing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _stopListening() {
    if (_isListening) {
      _speech.stop().then((_) {
        setState(() {
          _isListening = false;
          _isProcessing = false;
          if (_text.isNotEmpty && _text != 'Listening...') {
            _finalText = _text;
            _searchController.text = _finalText;
          }
        });
        _stopBarAnimation();
      }).catchError((e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Stop error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      });
    }
  }

  @override
  void dispose() {
    _speech.stop();
    _animationController.dispose();
    _searchController.dispose();
    _focusNode.dispose();
    _barAnimationTimer?.cancel();
    super.dispose();
  }

  Widget _buildLanguageSelector() {
    return DropdownButton<String>(
      value: _selectedLanguage,
      items: const [
        DropdownMenuItem(
          value: 'kn_IN',
          child: Text('ಕನ್ನಡ (Kannada)'),
        ),
        DropdownMenuItem(
          value: 'en_US',
          child: Text('English'),
        ),
      ],
      onChanged: (String? newValue) {
        if (newValue != null) {
          setState(() {
            _selectedLanguage = newValue;
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice Search'),
        actions: [
          _buildLanguageSelector(),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            TextField(
              focusNode: _focusNode,
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _text = 'Press mic and start speaking';
                      _finalText = '';
                    });
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              onSubmitted: (value) {
                Navigator.pop(context, value);
              },
            ),
            const SizedBox(height: 30),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isProcessing) const CircularProgressIndicator(),
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: _isListening ? _stopListening : _startListening,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: _isListening
                            ? _buildCustomVisualizer()
                            : const Icon(Icons.mic,
                                size: 80, color: Colors.blue),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _text,
                      style: const TextStyle(fontSize: 18),
                      textAlign: TextAlign.center,
                    ),
                    if (_permissionDenied)
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          'Microphone permission denied. Please enable it in settings.',
                          style: TextStyle(color: Colors.red[700]),
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomVisualizer() {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            _barCount,
            (index) => Container(
              width: 4,
              height: _barHeights[index],
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class VoiceSearchOverlay extends StatefulWidget {
  const VoiceSearchOverlay({Key? key}) : super(key: key);

  @override
  State<VoiceSearchOverlay> createState() => _VoiceSearchOverlayState();
}

class _VoiceSearchOverlayState extends State<VoiceSearchOverlay> {
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _recognizedText = '';
  String _displayText = 'Listening...';
  double _soundLevel = 0.0;
  bool _permissionDenied = false;
  bool _speechInitialized = false;
  bool _isProcessing = false;
  bool _isStopping = false;
  Timer? _autoStopTimer;
  Timer? _barAnimationTimer;
  List<double> _barHeights = [];
  final int _barCount = 7;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _initializeBars();
    _initSpeech();
  }

  void _initializeBars() {
    _barHeights = List.generate(_barCount, (index) => 10.0);
  }

  void _startBarAnimation() {
    _barAnimationTimer?.cancel();
    _barAnimationTimer =
        Timer.periodic(const Duration(milliseconds: 100), (timer) {
      setState(() {
        for (int i = 0; i < _barCount; i++) {
          _barHeights[i] = 10.0 + (_random.nextDouble() * 40.0);
        }
      });
    });
  }

  void _stopBarAnimation() {
    _barAnimationTimer?.cancel();
    setState(() {
      _barHeights = List.generate(_barCount, (index) => 10.0);
    });
  }

  Future<void> _initSpeech() async {
    try {
      final available = await _speech.initialize(
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            _stopListening();
          }
        },
        onError: (error) {
          _stopListening();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${error.errorMsg}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        },
      );
      setState(() {
        _speechInitialized = (available == true);
        if (!_speechInitialized) {
          _permissionDenied = true;
        }
      });
      if (_speechInitialized) {
        _startListening();
      }
    } catch (e) {
      setState(() {
        _permissionDenied = true;
        _speechInitialized = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Initialization error: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<bool> _checkMicrophonePermission() async {
    try {
      final status = await Permission.microphone.status;
      if (status.isGranted) return true;
      final result = await Permission.microphone.request();
      if (!result.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Microphone permission is required for voice search'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return result.isGranted;
    } catch (e) {
      setState(() => _permissionDenied = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error checking microphone permission: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
      return false;
    }
  }

  void _startListening() async {
    if (!_speechInitialized) return;
    setState(() {
      _isListening = true;
      _isProcessing = true;
      _isStopping = false;
      _displayText = 'Listening...';
      _permissionDenied = false;
      _recognizedText = '';
    });
    _startBarAnimation();
    _autoStopTimer?.cancel();
    _autoStopTimer = Timer(const Duration(seconds: 5), () {
      if (_isListening) _stopListening();
    });
    try {
      if (await _checkMicrophonePermission()) {
        final started = await _speech.listen(
          onResult: (result) {
            setState(() {
              _displayText = result.recognizedWords;
              if (result.finalResult) {
                _recognizedText = result.recognizedWords;
                _isProcessing = false;
              }
            });
          },
          onSoundLevelChange: (level) {
            setState(() => _soundLevel = level);
          },
          localeId: 'en_US',
          listenFor: const Duration(seconds: 5),
          pauseFor: const Duration(seconds: 2),
          partialResults: true,
          onDevice: true,
          cancelOnError: true,
        );
        if (started != true) {
          setState(() {
            _isListening = false;
            _isProcessing = false;
            _isStopping = false;
          });
          _stopBarAnimation();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to listen, please try again'),
              backgroundColor: Colors.red,
            ),
          );
          Navigator.of(context).pop('');
        }
      } else {
        setState(() {
          _isListening = false;
          _isProcessing = false;
          _isStopping = false;
          _permissionDenied = true;
        });
        _stopBarAnimation();
        Navigator.of(context).pop('');
      }
    } catch (e) {
      setState(() {
        _isListening = false;
        _isProcessing = false;
        _isStopping = false;
      });
      _stopBarAnimation();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
      Navigator.of(context).pop('');
    }
  }

  void _stopListening() {
    if (_isListening && !_isStopping) {
      setState(() {
        _isStopping = true;
      });
      _speech.stop().then((_) {
        setState(() {
          _isListening = false;
          _isProcessing = false;
        });
        _stopBarAnimation();
        _autoStopTimer?.cancel();
        Navigator.of(context).pop(_displayText.trim());
      }).catchError((e) {
        _stopBarAnimation();
        _autoStopTimer?.cancel();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Stop error: $e'),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.of(context).pop('');
      });
    }
  }

  @override
  void dispose() {
    _speech.stop();
    _barAnimationTimer?.cancel();
    _autoStopTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Voice Search',
                  style:
                      theme.textTheme.titleLarge?.copyWith(color: Colors.white),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(''),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _isListening
                ? _buildCustomVisualizer()
                : const Icon(Icons.mic, size: 60, color: Colors.blue),
            const SizedBox(height: 16),
            Text(
              _displayText,
              style: const TextStyle(color: Colors.white, fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _isStopping ? Colors.grey : Colors.blue[800],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  icon: Icon(_isListening ? Icons.stop : Icons.mic),
                  label: Text(_isListening
                      ? (_isStopping ? 'Stopping...' : 'Stop Listening')
                      : 'Start'),
                  onPressed:
                      (_isListening && !_isStopping) ? _stopListening : null,
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_isStopping)
              const Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: Text(
                  'Finishing up... Please wait.',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomVisualizer() {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            _barCount,
            (index) => Container(
              width: 4,
              height: _barHeights[index],
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
