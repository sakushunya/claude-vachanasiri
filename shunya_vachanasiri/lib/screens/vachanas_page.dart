// lib/screens/vachanas_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:marquee/marquee.dart';
import 'package:provider/provider.dart';
import 'package:shunya_vachanasiri/providers/audio_service_manager.dart';
import 'package:shunya_vachanasiri/utils/main_layout.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:shunya_vachanasiri/screens/audio_player_page.dart';
import 'package:shunya_vachanasiri/screens/sharanas_page.dart';
import 'package:shunya_vachanasiri/screens/all_vachanas_page.dart';
import 'package:shunya_vachanasiri/screens/about_vachanasiri.dart';
import 'package:shunya_vachanasiri/widgets/vachana_card.dart';
import 'package:shunya_vachanasiri/models/vachana_model.dart';
import 'package:shunya_vachanasiri/providers/audio_handler.dart';

class VachanasPage extends StatefulWidget {
  final int sharanaId;
  final String artistNameKannada;

  const VachanasPage({
    super.key,
    required this.sharanaId,
    required this.artistNameKannada,
  });

  @override
  State<VachanasPage> createState() => _VachanasPageState();
}

class _VachanasPageState extends State<VachanasPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String _searchQuery = '';
  bool _isSearching = false;
  final ScrollController _scrollController = ScrollController();
  List<Vachana> vachanas = []; // Changed to Vachana model

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  void _initSpeech() async {
    await _speech.initialize();
    setState(() {});
  }

  @override
  void dispose() {
    // Stop speech recognition when widget is disposed
    _speech.stop();
    _scrollController.dispose();
    super.dispose();
  }

  void _playVachana(Vachana vachana) {
    final audioHandler = context.read<AudioPlayerHandler>();
    audioHandler.playVachana(vachana);
  }

  void _startListening() async {
    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available && mounted) {
        // Check if widget is still mounted
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (result) {
            // Only update state if widget is still mounted
            if (mounted) {
              setState(() => _searchQuery = result.recognizedWords);
            }
          },
        );
      }
    } else {
      if (mounted) {
        setState(() => _isListening = false);
      }
      _speech.stop();
    }
  }
  // void _startListening() async {
  //   if (!_isListening) {
  //     bool available = await _speech.initialize();
  //     if (available) {
  //       setState(() => _isListening = true);
  //       _speech.listen(
  //         onResult: (result) => setState(() {
  //           _searchQuery = result.recognizedWords;
  //         }),
  //       );
  //     }
  //   } else {
  //     setState(() => _isListening = false);
  //     _speech.stop();
  //   }
  // }

  void _clearSearch() {
    setState(() {
      _searchQuery = '';
      _isSearching = false;
    });
  }

  Widget _buildTitleWidget() {
    final fullTitle = '${widget.artistNameKannada} ವಚನಗಳು';
    final bool needsMarquee = widget.artistNameKannada.length > 10;

    return SizedBox(
      height: kToolbarHeight, // Constrain height to AppBar size
      child: needsMarquee
          ? Marquee(
              text: fullTitle,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              blankSpace: 50.0,
              velocity: 25.0,
              pauseAfterRound: const Duration(seconds: 1),
            )
          : Center(
              // Wrap in Center for vertical alignment
              child: Text(
                fullTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final audioService =
        Provider.of<AudioPlayerHandler>(context, listen: false);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const SharanasPage(),
              ),
            );
          },
        ),
        centerTitle: true,
        title: _isSearching
            ? TextField(
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search vachanas...',
                  hintStyle: const TextStyle(color: Colors.grey),
                  border: InputBorder.none,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: _clearSearch,
                  ),
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              )
            : _buildTitleWidget(), // Extracted title logic to a builder function
        actions: [
          if (!_isSearching)
            IconButton(
              icon: const Icon(Icons.search, color: Colors.white),
              onPressed: () => setState(() => _isSearching = true),
            ),
          IconButton(
            icon: Icon(_isListening ? Icons.mic_off : Icons.mic),
            color: _isListening ? Colors.red : Colors.white,
            onPressed: _startListening,
          ),
        ],
      ),
      body: MainLayout(
        child: StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('colVachana')
              // .orderBy('vachanaNameEnglish')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: SizedBox(
                width: 50,
                height: 50,
                child: CircularProgressIndicator(strokeWidth: 3),
              ));
            }

            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(child: Text('No vachanas found'));
            }

            // Convert documents to Vachana models
            vachanas = snapshot.data!.docs
                .where((doc) => doc['sharanaId'] == widget.sharanaId)
                .map((doc) => Vachana.fromFirestore(doc)) // Convert to model
                .toList();
            vachanas.sort((a, b) {
              // Handle null values safely
              final aName = a.vachanaNameEnglish ?? '';
              final bName = b.vachanaNameEnglish ?? '';
              return aName.compareTo(bName);
            });

            // Apply search filter
            if (_searchQuery.isNotEmpty) {
              final query = _searchQuery.toLowerCase();
              vachanas = vachanas.where((vachana) {
                return (vachana.vachanaNameEnglish
                            ?.toLowerCase()
                            .contains(query) ??
                        false) ||
                    (vachana.vachanaNameKannada
                            ?.toLowerCase()
                            .contains(query) ??
                        false) ||
                    (vachana.vachanaLyricsEnglish
                            ?.toLowerCase()
                            .contains(query) ??
                        false) ||
                    (vachana.vachanaLyricsKannada
                            ?.toLowerCase()
                            .contains(query) ??
                        false);
              }).toList();
            }

            return ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.only(bottom: 80),
              itemCount: vachanas.length,
              itemBuilder: (context, index) {
                final vachana = vachanas[index];
                return VachanaCard(
                  vachana: vachana, // Pass the model directly
                  showArtist: false,
                  onCardTapped: () {
                    // final audioService =
                    //     Provider.of<AudioPlayerHandler>(context);
                    // final index = vachanas
                    //     .indexWhere((v) => v.vachanaId == vachana.vachanaId);
                    // audioService.setPlaylistAndPlay(vachanas, index);
                    // final audioHandler = context.read<AudioPlayerHandler>();
                    // audioHandler.setPlaylistAndPlay(
                    //     vachanas, vachanas.indexOf(vachana));

                    AudioServiceManager.handler
                        .setPlaylistAndPlay(vachanas, index);

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AudioPlayerPage(),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.grey[900],
          border: const Border(top: BorderSide(color: Colors.grey, width: 0.5)),
        ),
        child: BottomNavigationBar(
          backgroundColor: Colors.transparent,
          selectedItemColor: Colors.blue[300],
          unselectedItemColor: Colors.white,
          type: BottomNavigationBarType.fixed,
          currentIndex: 0,
          onTap: _onBottomNavTap,
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.account_circle),
              label: 'Sharanas',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.library_books),
              label: 'All Vachanas',
            ),
            BottomNavigationBarItem(
              icon: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.blue[800],
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.keyboard_command_key_rounded,
                    color: Colors.white),
              ),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.favorite, color: Colors.grey[600]),
              label: 'Favorites',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.info),
              label: 'About',
            ),
          ],
        ),
      ),
    );
  }

  void _onBottomNavTap(int index) {
    switch (index) {
      case 0:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const SharanasPage(),
          ),
        );
        break;
      case 1:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const AllVachanasPage(),
          ),
        );
        break;
      case 4:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const AboutPage(),
          ),
        );
        break;
    }
  }
}
