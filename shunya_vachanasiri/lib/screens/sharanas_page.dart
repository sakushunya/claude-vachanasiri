// /lib/screens/sharanas_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shunya_vachanasiri/utils/main_layout.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:provider/provider.dart';
import 'package:shunya_vachanasiri/providers/app_state.dart';
import 'package:shunya_vachanasiri/screens/about_vachanasiri.dart';
import 'package:shunya_vachanasiri/screens/login_page.dart';
import 'package:shunya_vachanasiri/screens/vachanas_page.dart';
import 'package:shunya_vachanasiri/screens/all_vachanas_page.dart';
import 'package:shunya_vachanasiri/providers/audio_handler.dart';

class SharanasPage extends StatefulWidget {
  const SharanasPage({super.key});

  @override
  State<SharanasPage> createState() => _SharanasPageState();
}

class _SharanasPageState extends State<SharanasPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String _searchQuery = '';
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  void _initSpeech() async {
    await _speech.initialize();
    setState(() {});
  }

  void _startListening() async {
    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (result) => setState(() {
            _searchQuery = result.recognizedWords;
          }),
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

    final audioHandler =
        Provider.of<AudioPlayerHandler>(context, listen: false);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        automaticallyImplyLeading: false, // Disable default back button
        leading: Consumer<AppState>(
          builder: (context, appState, child) {
            if (!appState.isLoggedIn) {
              return IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () {
                  // Replace with direct navigation to login page
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          const LoginPage(), // Update with your actual login page
                    ),
                  );
                },
              );
            }
            return const SizedBox.shrink();
          },
        ),
        title: _isSearching
            ? TextField(
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Search Sharanas...',
                  hintStyle: TextStyle(color: Colors.grey),
                  border: InputBorder.none,
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              )
            : const Text('ಶರಣರು', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            color: Colors.white,
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchQuery = ''; // Clear search query when closing search
                }
              });
            },
          ),
          IconButton(
            icon: Icon(_isListening ? Icons.mic_off : Icons.mic),
            color: _isListening ? Colors.red : Colors.white,
            onPressed: _startListening,
          ),
        ],
      ),
      body: MainLayout(
        child: FutureBuilder<QuerySnapshot>(
          future:
              _firestore.collection('colSharanas').orderBy('sharanaId').get(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(child: Text('No artists found'));
            }

            List<QueryDocumentSnapshot> artists = snapshot.data!.docs;

            // Apply search filter
            if (_searchQuery.isNotEmpty) {
              artists = artists.where((artist) {
                final nameEng =
                    artist['sharanaNameEnglish']?.toString().toLowerCase() ??
                        '';
                final nameKan =
                    artist['sharanaNameKannada']?.toString().toLowerCase() ??
                        '';
                return nameEng.contains(_searchQuery.toLowerCase()) ||
                    nameKan.contains(_searchQuery.toLowerCase());
              }).toList();
            }

            return ListView.builder(
              itemCount: artists.length,
              itemBuilder: (context, index) {
                final artist = artists[index];
                return _buildArtistCard(artist);
              },
            );
          },
        ),
      ),
      // Bottom Navigation bar
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
          // currentIndex: 0, // Sharanas is first item
          // onTap: _onBottomNavTap,
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
              icon: Icon(
                Icons.favorite,
                color: appState.isLoggedIn ? Colors.white70 : Colors.grey[600],
              ),
              label: 'Favorites',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.info),
              label: 'About',
            ),
          ],
          currentIndex: 0,
          onTap: (index) {
            // Add this to prevent duplicate players
            if (index == 0) return;
            _onBottomNavTap(index);
          },
        ),
      ),
    );
  }

  // _onBottomNavTap
  void _onBottomNavTap(int index) {
    switch (index) {
      case 1:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const AllVachanasPage(),
          ),
        );

      case 4:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const AboutPage(),
          ),
        );
    }
  }

  Widget _buildArtistCard(QueryDocumentSnapshot artist) {
    return Card(
      color: Colors.grey[900],
      margin: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 4), // Reduced vertical margin
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 4), // Reduced padding
        dense: true, // Makes the tile smaller
        minVerticalPadding: 0, // Reduces vertical padding
        leading: CircleAvatar(
            radius: 20, // Smaller avatar
            backgroundColor: Colors.grey[800],
            // backgroundImage: artist['sharanaImg1'] != null
            //     ? CachedNetworkImageProvider(artist['sharanaImg1'])
            //     : null,
            child: const Icon(Icons.account_circle_outlined,
                size: 20, color: Colors.white)
            //     : null,
            ),
        title: Text(
          artist['sharanaNameKannada'] ?? 'ಹೆಸರು ಬೇಕಾಗಿದೆ',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16, // Slightly smaller font
          ),
        ),
        subtitle: Text(
          artist['sharanaNameEnglish'] ?? 'Unknown Artist',
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 14, // Slightly smaller font
          ),
        ),
        trailing:
            const Icon(Icons.chevron_right, color: Colors.white, size: 20),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => VachanasPage(
                sharanaId: artist['sharanaId'],
                artistNameKannada:
                    artist['sharanaNameKannada'] ?? 'ಹೆಸರು ಬೇಕಾಗಿದೆ',
              ),
            ),
          );
        },
      ),
    );
  }
}
