// lib/screens/all_vachanas_page.dart
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shunya_vachanasiri/providers/app_state.dart';
import 'package:shunya_vachanasiri/providers/audio_service_manager.dart';
import 'package:shunya_vachanasiri/screens/audio_player_page.dart';
import 'package:shunya_vachanasiri/screens/about_vachanasiri.dart';
import 'package:shunya_vachanasiri/screens/sharanas_page.dart';
import 'package:shunya_vachanasiri/screens/voice_search_screen.dart';
import 'package:shunya_vachanasiri/utils/main_layout.dart';
import 'package:shunya_vachanasiri/widgets/vachana_card.dart';
import 'package:shunya_vachanasiri/models/vachana_model.dart';
import 'package:shunya_vachanasiri/providers/audio_handler.dart';

class AllVachanasPage extends StatefulWidget {
  const AllVachanasPage({super.key});

  @override
  State<AllVachanasPage> createState() => _AllVachanasPageState();
}

class _AllVachanasPageState extends State<AllVachanasPage> {
  String _searchQuery = '';
  bool _isSearching = false;
  bool _isLoading = true;
  late TextEditingController _searchController;
  FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchFocusNode = FocusNode();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose(); // Dispose focus node
    super.dispose();
  }

  void _playVachana(Vachana vachana) {
    final audioHandler = context.read<AudioPlayerHandler>();
    audioHandler.playVachana(vachana);
  }

  Future<void> _loadData() async {
    final appState = Provider.of<AppState>(context, listen: false);
    if (appState.allVachanas.isEmpty) {
      await appState.loadAllVachanas();
    }
    setState(() => _isLoading = false);
  }

  void _startVoiceSearch() async {
    // Unfocus any existing focus to hide keyboard
    FocusScope.of(context).unfocus();

    final recognizedText = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.55,
        child: VoiceSearchOverlay(),
      ),
    );

    if (recognizedText != null && recognizedText.trim().isNotEmpty) {
      setState(() {
        _searchQuery = recognizedText.trim();
        _searchController.text = recognizedText.trim();
        _isSearching = true;
      });
      // Show a snackbar to confirm the search
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Searching for: "$recognizedText"'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      // Delay focus to prevent keyboard from showing
      Future.delayed(const Duration(milliseconds: 300), () {
        FocusScope.of(context).requestFocus(_searchFocusNode);
      });
    }
  }

  void _clearSearch() {
    setState(() {
      _searchQuery = '';
      _isSearching = false;
      _searchController.clear();
    });
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final audioHandler =
        Provider.of<AudioPlayerHandler>(context, listen: false);
    final filteredVachanas = _getFilteredVachanas(appState);

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: _isSearching
            ? TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search all vachanas...',
                  hintStyle: const TextStyle(color: Colors.grey),
                  border: InputBorder.none,
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_searchQuery.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear, size: 20),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        ),
                      // IconButton(
                      //   icon: const Icon(Icons.close),
                      //   onPressed: _clearSearch,
                      // ),
                    ],
                  ),
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              )
            : const Text(
                'ವಚನಗಳು',
                style: TextStyle(color: Colors.white),
              ),
        actions: [
          if (!_isSearching)
            IconButton(
              icon: const Icon(Icons.search, color: Colors.white),
              onPressed: () {
                setState(() => _isSearching = true);
                Future.delayed(const Duration(milliseconds: 300), () {
                  FocusScope.of(context).requestFocus(_searchFocusNode);
                });
              },
            ),
          IconButton(
            icon: const Icon(Icons.mic, color: Colors.white),
            onPressed: _startVoiceSearch,
          ),
        ],
      ),
      body: MainLayout(
        child: filteredVachanas.isEmpty && _searchQuery.isNotEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.search_off,
                      size: 64,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No results found for "$_searchQuery"',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _clearSearch,
                      child: const Text('Clear Search'),
                    ),
                  ],
                ),
              )
            : StreamBuilder<PlaybackState>(
                stream: audioHandler.playbackState,
                builder: (context, playbackSnapshot) {
                  if (playbackSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(
                        child: SizedBox(
                      width: 50,
                      height: 50,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    ));
                  }
                  // Create a default PlaybackState if none exists
                  final playbackState = playbackSnapshot.data ??
                      PlaybackState(
                        controls: [],
                        systemActions: const {},
                        processingState: AudioProcessingState.idle,
                        playing: false,
                      );

                  return ValueListenableBuilder<int>(
                    valueListenable: audioHandler.currentIndex,
                    builder: (context, currentIndex, _) {
                      final isPlaying =
                          playbackState.playing && currentIndex != -1;

                      return ListView.builder(
                        padding: EdgeInsets.only(
                          bottom: isPlaying ? 70 : 0,
                          left: 16,
                          right: 16,
                        ),
                        itemCount: filteredVachanas.length,
                        itemBuilder: (context, index) {
                          final vachana = filteredVachanas[index];
                          return VachanaCard(
                              vachana: vachana,
                              showArtist: true,
                              onCardTapped: () {
                                // final shuffled =
                                //     List<Vachana>.from(filteredVachanas)
                                //       ..shuffle();
                                // final startIndex = shuffled.indexWhere(
                                //     (v) => v.vachanaId == vachana.vachanaId);
                                // final audioHandler =
                                //     Provider.of<AudioPlayerHandler>(context,
                                //         listen: false);
                                // audioHandler.setPlaylistAndPlay(
                                //     filteredVachanas, index);
                                AudioServiceManager.handler.setPlaylistAndPlay(
                                    filteredVachanas, index);

                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          const AudioPlayerPage()),
                                );
                              });
                        },
                      );
                    },
                  );
                },
              ),

        // : ListView.builder(
        //     padding: EdgeInsets.only(
        //       bottom: audioHandler.currentVachana != null ? 70 : 0,
        //       left: 16,
        //       right: 16,
        //     ),
        //     itemCount: filteredVachanas.length,
        //     itemBuilder: (context, index) {
        //       final vachana = filteredVachanas[index];
        //       return VachanaCard(
        //         vachana: vachana,
        //         showArtist: true,
        //         onCardTapped: () {
        //           final audioHandler =
        //               Provider.of<AudioPlayerHandler>(context);
        //           final shuffled = List<Vachana>.from(filteredVachanas)
        //             ..shuffle();
        //           final index = shuffled
        //               .indexWhere((v) => v.vachanaId == vachana.vachanaId);
        //           audioHandler.setPlaylistAndPlay(shuffled, index);
        //           Navigator.push(
        //             context,
        //             MaterialPageRoute(
        //                 builder: (context) => const AudioPlayerPage()),
        //           );
        //         },
        //       );
        //     },
        //   ),
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
          currentIndex: 1,
          onTap: (index) {
            if (index == 1) return;
            _onBottomNavTap(index);
          },
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
        ),
      ),
    );
  }

  List<Vachana> _getFilteredVachanas(AppState appState) {
    // Create a working copy of the list
    List<Vachana> result = List.from(appState.allVachanas);

    // Apply search filter first
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase().trim();
      final searchTerms =
          query.split(' ').where((term) => term.isNotEmpty).toList();

      result = result.where((v) {
        final searchableTexts = [
          v.vachanaNameEnglish?.toLowerCase() ?? "",
          v.vachanaNameKannada?.toLowerCase() ?? "",
          v.vachanaLyricsEnglish?.toLowerCase() ?? "",
          v.vachanaLyricsKannada?.toLowerCase() ?? "",
          v.sharanaNameEnglish?.toLowerCase() ?? "",
          v.sharanaNameKannada?.toLowerCase() ?? "",
        ].where((text) => text.isNotEmpty).toList();

        return searchTerms.every(
            (term) => searchableTexts.any((text) => text.contains(term)));
      }).toList();
    }

    // Apply sorting - Case-insensitive English name sorting
    result.sort((a, b) {
      final aName = (a.vachanaNameEnglish ?? '').toLowerCase();
      final bName = (b.vachanaNameEnglish ?? '').toLowerCase();
      return aName.compareTo(bName);
    });

    return result;
  }

  // List<Vachana> _getFilteredVachanas(AppState appState) {
  //   if (_searchQuery.isEmpty) return appState.allVachanas;

  //   final query = _searchQuery.toLowerCase().trim();
  //   final searchTerms =
  //       query.split(' ').where((term) => term.isNotEmpty).toList();

  //   return appState.allVachanas.where((v) {
  //     // Create a list of all searchable text fields
  //     final searchableTexts = [
  //       v.vachanaNameEnglish?.toLowerCase() ?? "",
  //       v.vachanaNameKannada?.toLowerCase() ?? "",
  //       v.vachanaLyricsEnglish?.toLowerCase() ?? "",
  //       v.vachanaLyricsKannada?.toLowerCase() ?? "",
  //       v.sharanaNameEnglish?.toLowerCase() ?? "",
  //       v.sharanaNameKannada?.toLowerCase() ?? "",
  //     ].where((text) => text.isNotEmpty).toList();

  //     // Check if all search terms are found in any of the searchable texts
  //     return searchTerms
  //         .every((term) => searchableTexts.any((text) => text.contains(term)));
  //   }).toList();
  // }

  void _onBottomNavTap(int index) {
    switch (index) {
      case 0:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SharanasPage()),
        );
        break;
      case 4:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AboutPage()),
        );
        break;
    }
  }
}
