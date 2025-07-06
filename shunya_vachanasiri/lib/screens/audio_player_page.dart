// /lib/screens/audio_player_page.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shunya_vachanasiri/models/vachana_model.dart';
import 'package:shunya_vachanasiri/providers/app_state.dart';
import 'package:shunya_vachanasiri/screens/sharanas_page.dart';
import 'package:shunya_vachanasiri/screens/about_vachanasiri.dart';
import 'package:shunya_vachanasiri/screens/all_vachanas_page.dart';
import 'package:shunya_vachanasiri/widgets/lyrics_overlay.dart';
import 'package:shunya_vachanasiri/widgets/firebase_image.dart';
import 'package:marquee/marquee.dart';
import 'package:shunya_vachanasiri/providers/audio_handler.dart';

class AudioPlayerPage extends StatelessWidget {
  const AudioPlayerPage({Key? key}) : super(key: key);

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final audioHandler = Provider.of<AudioPlayerHandler>(context);
    final appState = Provider.of<AppState>(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: ValueListenableBuilder<Vachana?>(
        valueListenable: audioHandler.currentVachanaNotifier,
        builder: (context, current, _) {
          // Debug print to track state changes
          print(
              'AudioPlayerPage - Current Vachana: ${current?.vachanaNameKannada}');
          print(
              'AudioPlayerPage - IsLoading: ${audioHandler.isLoading}, IsBuffering: ${audioHandler.isBuffering}');

          // Primary null check - if no current track, show appropriate message
          if (current == null) {
            return Scaffold(
              backgroundColor: Colors.black,
              appBar: _buildAppBar(context, 'No Track'),
              bottomNavigationBar: _buildBottomNavigation(context, appState),
              body: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.music_note, size: 80, color: Colors.white70),
                    SizedBox(height: 16),
                    Text(
                      'No track playing',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  ],
                ),
              ),
            );
          }

          // Only show loading if we have a track but it's in initial loading state
          // This prevents the stuck loading state issue
          if (audioHandler.isLoading && current != null) {
            // Show loading overlay on top of the UI instead of replacing it
            return Stack(
              children: [
                _buildMainContent(context, current, audioHandler, appState),
                if (audioHandler.isLoading)
                  Container(
                    color: Colors.black.withOpacity(0.7),
                    child: const Center(
                      child: CircularProgressIndicator(color: Colors.blue),
                    ),
                  ),
              ],
            );
          }

          // Normal state - show the full player
          return _buildMainContent(context, current, audioHandler, appState);
        },
      ),
    );
  }

  Widget _buildMainContent(BuildContext context, Vachana current,
      AudioPlayerHandler audioHandler, AppState appState) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _buildAppBar(context, current.sharanaNameKannada),
      bottomNavigationBar: _buildBottomNavigation(context, appState),
      body: Stack(
        children: [
          // Blurred background
          Positioned.fill(
            child: Stack(
              children: [
                FirebaseImage(
                  sharanaId: current.sharanaId,
                  imageType: 'mini',
                  size: double.infinity,
                  placeholder: Container(color: Colors.black),
                  errorWidget: Container(color: Colors.black),
                ),
                BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
                  child: Container(color: Colors.transparent),
                ),
              ],
            ),
          ),

          // Dark overlay
          Container(color: Colors.black.withOpacity(0.7)),

          SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Album Art
                    Container(
                      width: 250,
                      height: 250,
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 10,
                            spreadRadius: 2,
                          )
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: FirebaseImage(
                          sharanaId: current.sharanaId,
                          imageType: 'coverart',
                          size: 300,
                          placeholder: Container(
                            color: Colors.grey[900],
                            child: Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.grey[700]!,
                                ),
                              ),
                            ),
                          ),
                          errorWidget: Icon(
                            Icons.music_note,
                            size: 100,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Vachana Title
                    if (current.vachanaNameKannada.length <= 25)
                      SizedBox(
                        height: 38,
                        child: Text(
                          current.vachanaNameKannada,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      )
                    else
                      SizedBox(
                        height: 38,
                        child: Marquee(
                          text: current.vachanaNameKannada,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                          blankSpace: 50.0,
                          velocity: 25.0,
                          pauseAfterRound: const Duration(seconds: 1),
                        ),
                      ),
                    const SizedBox(height: 10),

                    // Vachana Dhwani
                    const Text(
                      "ಧ್ವನಿ : ಶ್ರೀ. ಮ. ನಿ. ಪ್ರ. ಡಾ|| ಮಹಾಂತಪ್ರಭು ಸ್ವಾಮೀಜಿ",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.normal,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                    ),
                    const SizedBox(height: 20),

                    // Action Icons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          icon: Icon(
                            appState.favorites.contains(current.vachanaId)
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color:
                                appState.favorites.contains(current.vachanaId)
                                    ? Colors.red
                                    : Colors.grey,
                          ),
                          onPressed: () {},
                        ),
                        IconButton(
                          icon: const Icon(Icons.share, color: Colors.grey),
                          onPressed: () {},
                        ),
                        IconButton(
                          icon: const Icon(Icons.download, color: Colors.grey),
                          onPressed: () {},
                        ),
                        IconButton(
                          icon: const Icon(Icons.lyrics, color: Colors.white),
                          onPressed: () {
                            showModalBottomSheet(
                              context: context,
                              backgroundColor: Colors.transparent,
                              isScrollControlled: true,
                              builder: (context) =>
                                  LyricsOverlay(vachana: current),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Progress bar
                    StreamBuilder<Duration>(
                      stream: audioHandler.safePositionStream,
                      builder: (context, positionSnapshot) {
                        final position = positionSnapshot.data ?? Duration.zero;
                        return StreamBuilder<Duration?>(
                          stream: audioHandler.durationStream,
                          builder: (context, durationSnapshot) {
                            final duration =
                                durationSnapshot.data ?? Duration.zero;
                            double maxValue = duration.inSeconds > 0
                                ? duration.inSeconds.toDouble()
                                : 1.0;
                            double currentValue = position.inSeconds.toDouble();
                            if (currentValue > maxValue)
                              currentValue = maxValue;

                            return Slider(
                              value: currentValue,
                              min: 0,
                              max: maxValue,
                              activeColor: Colors.blue,
                              inactiveColor: Colors.grey[700],
                              onChanged: (value) async {
                                if (audioHandler.isProcessingStateReady) {
                                  await audioHandler
                                      .seek(Duration(seconds: value.toInt()));
                                }
                              },
                            );
                          },
                        );
                      },
                    ),

                    // Position indicators
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: StreamBuilder<Duration>(
                        stream: audioHandler.positionStream,
                        builder: (context, positionSnapshot) {
                          final position =
                              positionSnapshot.data ?? Duration.zero;
                          return StreamBuilder<Duration?>(
                            stream: audioHandler.durationStream,
                            builder: (context, durationSnapshot) {
                              final duration =
                                  durationSnapshot.data ?? Duration.zero;
                              return Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _formatDuration(position),
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  Text(
                                    _formatDuration(duration),
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 15),

                    // Player Controls
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Shuffle Button
                        ValueListenableBuilder<bool>(
                          valueListenable: audioHandler.isShuffledNotifier,
                          builder: (context, isShuffled, child) {
                            return IconButton(
                              icon: Icon(
                                Icons.shuffle,
                                color: isShuffled ? Colors.blue : Colors.white,
                              ),
                              onPressed: audioHandler.toggleShuffle,
                            );
                          },
                        ),
                        const Spacer(),

                        // Previous Track
                        IconButton(
                          icon: const Icon(Icons.skip_previous,
                              size: 40, color: Colors.white),
                          onPressed: audioHandler.skipToPrevious,
                        ),
                        const SizedBox(width: 20),

                        // Play/Pause
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.blue[800],
                            shape: BoxShape.circle,
                          ),
                          child: StreamBuilder<bool>(
                            stream: audioHandler.playingStream,
                            builder: (context, snapshot) {
                              final isPlaying = snapshot.data ?? false;
                              return IconButton(
                                icon: Icon(
                                  isPlaying ? Icons.pause : Icons.play_arrow,
                                  color: Colors.white,
                                ),
                                onPressed: () {
                                  if (isPlaying) {
                                    audioHandler.pause();
                                  } else {
                                    audioHandler.play();
                                  }
                                },
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 20),

                        // Next Track
                        IconButton(
                          icon: const Icon(Icons.skip_next,
                              size: 40, color: Colors.white),
                          onPressed: audioHandler.skipToNext,
                        ),
                        const Spacer(),

                        // Repeat Button
                        ValueListenableBuilder<bool>(
                          valueListenable: audioHandler.isRepeatingNotifier,
                          builder: (context, isRepeating, child) {
                            return IconButton(
                              icon: Icon(
                                isRepeating ? Icons.repeat_one : Icons.repeat,
                                color: isRepeating ? Colors.blue : Colors.white,
                              ),
                              onPressed: audioHandler.toggleRepeat,
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context, String title) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_drop_down_circle_outlined,
            color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      centerTitle: true,
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    );
  }

  Widget _buildBottomNavigation(BuildContext context, AppState appState) {
    return Container(
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
        onTap: (index) {
          switch (index) {
            case 0:
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SharanasPage()));
              break;
            case 1:
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AllVachanasPage()));
              break;
            case 4:
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AboutPage()));
              break;
          }
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
    );
  }
}



/** as of 20250706, from Deepseek
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shunya_vachanasiri/models/vachana_model.dart';
import 'package:shunya_vachanasiri/providers/app_state.dart';
import 'package:shunya_vachanasiri/screens/sharanas_page.dart';
import 'package:shunya_vachanasiri/screens/about_vachanasiri.dart';
import 'package:shunya_vachanasiri/screens/all_vachanas_page.dart';
import 'package:shunya_vachanasiri/widgets/lyrics_overlay.dart';
import 'package:shunya_vachanasiri/widgets/firebase_image.dart';
import 'package:marquee/marquee.dart';
import 'package:shunya_vachanasiri/providers/audio_handler.dart';

class AudioPlayerPage extends StatelessWidget {
  const AudioPlayerPage({Key? key}) : super(key: key);

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final audioHandler = Provider.of<AudioPlayerHandler>(context);
    // final current = audioHandler.currentVachanaNotifier.value;
    final appState = Provider.of<AppState>(context);

    // // Guard clauses
    // if (audioHandler.isLoading || audioHandler.isBuffering) {
    //   return const Scaffold(
    //     backgroundColor: Colors.black,
    //     body: Center(child: CircularProgressIndicator()),
    //   );
    // }

    // if (current == null) {
    //   return Scaffold(
    //     backgroundColor: Colors.black,
    //     body: const Center(
    //       child:
    //           Text('No track playing', style: TextStyle(color: Colors.white)),
    //     ),
    //   );
    // }

    return Scaffold(
      backgroundColor: Colors.black,
      body: ValueListenableBuilder<Vachana?>(
          valueListenable: audioHandler.currentVachanaNotifier,
          builder: (context, current, _) {
            // Guard clauses
            if (audioHandler.isLoading || audioHandler.isBuffering) {
              return const Center(child: CircularProgressIndicator());
            }

            if (current == null) {
              return const Center(
                child: Text('No track playing',
                    style: TextStyle(color: Colors.white)),
              );
            }

            return Stack(
              children: [
                // Blurred background
                Positioned.fill(
                  child: Stack(
                    children: [
                      FirebaseImage(
                        sharanaId: current.sharanaId,
                        imageType: 'mini',
                        size: double.infinity,
                        placeholder: Container(color: Colors.black),
                        errorWidget: Container(color: Colors.black),
                      ),
                      BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
                        child: Container(color: Colors.transparent),
                      ),
                    ],
                  ),
                ),

                // Dark overlay
                Container(color: Colors.black.withOpacity(0.7)),

                SafeArea(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Album Art
                          Container(
                            width: 250,
                            height: 250,
                            decoration: BoxDecoration(
                              color: Colors.grey[900],
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                )
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: FirebaseImage(
                                sharanaId: current.sharanaId,
                                imageType: 'coverart',
                                size: 300,
                                placeholder: Container(
                                  color: Colors.grey[900],
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.grey[700]!),
                                    ),
                                  ),
                                ),
                                errorWidget: Icon(
                                  Icons.music_note,
                                  size: 100,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Vachana Title
                          if (current.vachanaNameKannada.length <= 25)
                            SizedBox(
                              height: 38,
                              child: Text(
                                current.vachanaNameKannada,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            )
                          else
                            SizedBox(
                              height: 38,
                              child: Marquee(
                                text: current.vachanaNameKannada,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                                blankSpace: 50.0,
                                velocity: 25.0,
                                pauseAfterRound: const Duration(seconds: 1),
                              ),
                            ),
                          const SizedBox(height: 10),

                          // Vachana Dhwani
                          Text(
                            "ಧ್ವನಿ : ಶ್ರೀ. ಮ. ನಿ. ಪ್ರ. ಡಾ|| ಮಹಾಂತಪ್ರಭು ಸ್ವಾಮೀಜಿ",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.normal,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                          ),
                          const SizedBox(height: 20),

                          // Action Icons
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              IconButton(
                                icon: Icon(
                                  appState.favorites.contains(current.vachanaId)
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  color: appState.favorites
                                          .contains(current.vachanaId)
                                      ? Colors.red
                                      : Colors.grey,
                                ),
                                onPressed: () {},
                              ),
                              IconButton(
                                icon:
                                    const Icon(Icons.share, color: Colors.grey),
                                onPressed: () {},
                              ),
                              IconButton(
                                icon: const Icon(Icons.download,
                                    color: Colors.grey),
                                onPressed: () {},
                              ),
                              IconButton(
                                icon: const Icon(Icons.lyrics,
                                    color: Colors.white),
                                onPressed: () {
                                  showModalBottomSheet(
                                    context: context,
                                    backgroundColor: Colors.transparent,
                                    isScrollControlled: true,
                                    builder: (context) =>
                                        LyricsOverlay(vachana: current),
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Progress bar
                          StreamBuilder<Duration>(
                            stream: audioHandler.safePositionStream,
                            builder: (context, positionSnapshot) {
                              final position =
                                  positionSnapshot.data ?? Duration.zero;
                              return StreamBuilder<Duration?>(
                                stream: audioHandler.durationStream,
                                builder: (context, durationSnapshot) {
                                  final duration =
                                      durationSnapshot.data ?? Duration.zero;
                                  double maxValue = duration.inSeconds > 0
                                      ? duration.inSeconds.toDouble()
                                      : 1.0;
                                  double currentValue =
                                      position.inSeconds.toDouble();
                                  if (currentValue > maxValue)
                                    currentValue = maxValue;

                                  return Slider(
                                    value: currentValue,
                                    min: 0,
                                    max: maxValue,
                                    activeColor: Colors.blue,
                                    inactiveColor: Colors.grey[700],
                                    onChanged: (value) async {
                                      if (audioHandler.isProcessingStateReady) {
                                        await audioHandler.seek(
                                            Duration(seconds: value.toInt()));
                                      }
                                    },
                                  );
                                },
                              );
                            },
                          ),

                          // Position indicators
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16.0),
                            child: StreamBuilder<Duration>(
                              stream: audioHandler.positionStream,
                              builder: (context, positionSnapshot) {
                                final position =
                                    positionSnapshot.data ?? Duration.zero;
                                return StreamBuilder<Duration?>(
                                  stream: audioHandler.durationStream,
                                  builder: (context, durationSnapshot) {
                                    final duration =
                                        durationSnapshot.data ?? Duration.zero;
                                    return Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          _formatDuration(position),
                                          style: const TextStyle(
                                              color: Colors.white),
                                        ),
                                        Text(
                                          _formatDuration(duration),
                                          style: const TextStyle(
                                              color: Colors.white),
                                        ),
                                      ],
                                    );
                                  },
                                );
                              },
                            ),
                          ),

                          const SizedBox(height: 15),

                          // Player Controls
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Shuffle Button
                              ValueListenableBuilder<bool>(
                                valueListenable:
                                    audioHandler.isShuffledNotifier,
                                builder: (context, isShuffled, child) {
                                  return IconButton(
                                    icon: Icon(
                                      Icons.shuffle,
                                      color: isShuffled
                                          ? Colors.blue
                                          : Colors.white,
                                    ),
                                    onPressed: audioHandler.toggleShuffle,
                                  );
                                },
                              ),
                              const Spacer(),

                              // Previous Track
                              IconButton(
                                icon: const Icon(Icons.skip_previous,
                                    size: 40, color: Colors.white),
                                onPressed: audioHandler.skipToPrevious,
                              ),
                              const SizedBox(width: 20),

                              // Play/Pause
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.blue[800],
                                  shape: BoxShape.circle,
                                ),
                                child: StreamBuilder<bool>(
                                  stream: audioHandler.playingStream,
                                  builder: (context, snapshot) {
                                    final isPlaying = snapshot.data ?? false;
                                    return IconButton(
                                      icon: Icon(
                                        isPlaying
                                            ? Icons.pause
                                            : Icons.play_arrow,
                                        color: Colors.white,
                                      ),
                                      onPressed: () {
                                        if (isPlaying) {
                                          audioHandler.pause();
                                        } else {
                                          audioHandler.play();
                                        }
                                      },
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 20),

                              // Next Track
                              IconButton(
                                icon: const Icon(Icons.skip_next,
                                    size: 40, color: Colors.white),
                                onPressed: audioHandler.skipToNext,
                              ),
                              const Spacer(),

                              // Repeat Button
                              ValueListenableBuilder<bool>(
                                valueListenable:
                                    audioHandler.isRepeatingNotifier,
                                builder: (context, isRepeating, child) {
                                  return IconButton(
                                    icon: Icon(
                                      isRepeating
                                          ? Icons.repeat_one
                                          : Icons.repeat,
                                      color: isRepeating
                                          ? Colors.blue
                                          : Colors.white,
                                    ),
                                    onPressed: audioHandler.toggleRepeat,
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          }),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_drop_down_circle_outlined,
              color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text(
          // current.sharanaNameKannada,
          'XYZ',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
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
          onTap: (index) {
            switch (index) {
              case 0:
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const SharanasPage()));
                break;
              case 1:
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const AllVachanasPage()));
                break;
              case 4:
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const AboutPage()));
                break;
            }
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
}
*/


// as of 2025 07 02 1.00 AM, using steam builder, 
//but audio plyer screen was not coming up
// nor the mini player
// only thing on audio player screen was "No track playing" message
// as mediaItem == null was getting satisfied
// hence trying with different route consumer stream based access 


// import 'dart:ui';
// import 'dart:developer' as developer;
// import 'package:audio_service/audio_service.dart';
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:shunya_vachanasiri/providers/app_state.dart';
// import 'package:shunya_vachanasiri/screens/sharanas_page.dart';
// import 'package:shunya_vachanasiri/screens/about_vachanasiri.dart';
// import 'package:shunya_vachanasiri/screens/all_vachanas_page.dart';
// import 'package:shunya_vachanasiri/widgets/lyrics_overlay.dart';
// import 'package:shunya_vachanasiri/widgets/firebase_image.dart';
// import 'package:marquee/marquee.dart';
// import 'package:shunya_vachanasiri/providers/audio_handler.dart';
// import 'package:just_audio/just_audio.dart';

// class AudioPlayerPage extends StatefulWidget {
//   const AudioPlayerPage({super.key});

//   @override
//   State<AudioPlayerPage> createState() => _AudioPlayerPageState();
// }

// class _AudioPlayerPageState extends State<AudioPlayerPage> {
//   @override
//   Widget build(BuildContext context) {
//     final appState = Provider.of<AppState>(context);
//     final audioHandler = Provider.of<AudioPlayerHandler>(context);

//     developer.log('Building AudioPlayerPage', name: 'UIAudioPlayer');

//     return StreamBuilder<MediaItem?>(
//         stream: AudioService.currentMediaItemStream,
//         builder: (context, mediaSnapshot) {
//           developer.log('MediaItemStream snapshot: ${mediaSnapshot.data}',
//               name: 'UIAudioPlayer');

//           final mediaItem = mediaSnapshot.data;

//           return StreamBuilder<PlaybackState>(
//             stream: AudioService.playbackStateStream,
//             builder: (context, playbackSnapshot) {
//               final playbackState = playbackSnapshot.data;
//               developer.log('PlaybackState: ${playbackState?.processingState}',
//                   name: 'UIAudioPlayer');

//               final isPlaying = playbackState?.playing ?? false;
//               final processingState =
//                   playbackState?.processingState ?? AudioProcessingState.idle;

//               // Handle loading/buffering states
//               if (processingState == AudioProcessingState.loading ||
//                   processingState == AudioProcessingState.buffering) {
//                 return const Center(child: CircularProgressIndicator());
//               }

//               // Handle no media item
//               // if (mediaItem == null) {
//               //   return Scaffold(
//               //       backgroundColor: Colors.black,
//               //       body: const Center(
//               //         child: Text('No track playing',
//               //             style: TextStyle(color: Colors.white)),
//               //       ));
//               // }

//               // Extract sharanaId from mediaItem extras
//               final sharanaId = mediaItem?.extras?['sharanaId'] as int? ?? 0;
//               final vachanaId = mediaItem?.extras?['vachanaId'] as int? ?? 0;

//               return Scaffold(
//                 backgroundColor: Colors.black,
//                 body: Stack(
//                   children: [
//                     // Blurred background with artist image
//                     _buildBlurredBackground(sharanaId),

//                     // Dark overlay for better text readability
//                     Container(color: Colors.black.withOpacity(0.7)),

//                     SafeArea(
//                       child: SingleChildScrollView(
//                         child: Padding(
//                           padding: const EdgeInsets.all(24.0),
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.center,
//                             children: [
//                               // Album Art
//                               Container(
//                                 width: 250,
//                                 height: 250,
//                                 decoration: BoxDecoration(
//                                   color: Colors.grey[900],
//                                   borderRadius: BorderRadius.circular(12),
//                                   // boxShadow: [
//                                   //   BoxShadow(
//                                   //     color: Colors.black.withOpacity(0.3),
//                                   //     blurRadius: 10,
//                                   //     spreadRadius: 2,
//                                   //   )
//                                   // ],
//                                 ),
//                                 child: ClipRRect(
//                                   borderRadius: BorderRadius.circular(12),
//                                   // child: _buildVachanaCoverArt(mediaItem),
//                                 ),
//                               ),

//                               const SizedBox(height: 20),

//                               // Vachana Title
//                               // if (mediaItem.title.length <= 25)
//                               if (true)
//                                 SizedBox(
//                                   height: 38,
//                                   child: Text(
//                                     mediaItem!.title,
//                                     style: const TextStyle(
//                                       color: Colors.white,
//                                       fontSize: 24,
//                                       fontWeight: FontWeight.bold,
//                                     ),
//                                     textAlign: TextAlign.center,
//                                     maxLines: 1,
//                                     overflow: TextOverflow.ellipsis,
//                                   ),
//                                 )
//                               else
//                                 SizedBox(
//                                   height: 38,
//                                   child: Marquee(
//                                     text: mediaItem!.title,
//                                     style: const TextStyle(
//                                       color: Colors.white,
//                                       fontSize: 24,
//                                       fontWeight: FontWeight.bold,
//                                     ),
//                                     blankSpace: 50.0,
//                                     velocity: 25.0,
//                                     pauseAfterRound: const Duration(seconds: 1),
//                                   ),
//                                 ),
//                               const SizedBox(height: 10),
//                               // Vachana Dhwani
//                               Text(
//                                 "ಧ್ವನಿ : ಶ್ರೀ. ಮ. ನಿ. ಪ್ರ. ಡಾ|| ಮಹಾಂತಪ್ರಭು ಸ್ವಾಮೀಜಿ",
//                                 style: const TextStyle(
//                                   color: Colors.white,
//                                   fontSize: 12,
//                                   fontWeight: FontWeight.normal,
//                                 ),
//                                 textAlign: TextAlign.center,
//                                 maxLines: 1,
//                               ),
//                               const SizedBox(height: 20),

//                               // Action Icons Row
//                               Row(
//                                 mainAxisAlignment:
//                                     MainAxisAlignment.spaceEvenly,
//                                 children: [
//                                   // Favorite
//                                   IconButton(
//                                     icon: Icon(
//                                       appState.favorites.contains(vachanaId)
//                                           ? Icons.favorite
//                                           : Icons.favorite_border,
//                                       color:
//                                           appState.favorites.contains(vachanaId)
//                                               ? Colors.red
//                                               : Colors.grey,
//                                     ),
//                                     tooltip: 'N/A',
//                                     onPressed: () {},
//                                   ),
//                                   // Share
//                                   IconButton(
//                                     icon: const Icon(Icons.share,
//                                         color: Colors.grey),
//                                     tooltip: 'N/A',
//                                     onPressed: () {},
//                                   ),
//                                   // Download
//                                   IconButton(
//                                     icon: const Icon(Icons.download,
//                                         color: Colors.grey),
//                                     tooltip: 'N/A',
//                                     onPressed: () {},
//                                   ),
//                                   // Lyrics
//                                   IconButton(
//                                     icon: const Icon(Icons.lyrics,
//                                         color: Colors.grey),
//                                     onPressed: () {},
//                                     // {
//                                     //   showModalBottomSheet(
//                                     //     context: context,
//                                     //     backgroundColor: Colors.transparent,
//                                     //     isScrollControlled: true,
//                                     //     builder: (context) =>
//                                     //         LyricsOverlay(vachana: current),
//                                     //   );
//                                     // },
//                                   ),
//                                 ],
//                               ),

//                               const SizedBox(height: 10),

//                               // Progress bar
//                               StreamBuilder<Duration>(
//                                 stream: audioHandler.safePositionStream,
//                                 builder: (context, positionSnapshot) {
//                                   final position =
//                                       positionSnapshot.data ?? Duration.zero;
//                                   return StreamBuilder<Duration?>(
//                                     stream: audioHandler.durationStream,
//                                     builder: (context, durationSnapshot) {
//                                       final duration = durationSnapshot.data ??
//                                           Duration.zero;
//                                       double maxValue = duration.inSeconds > 0
//                                           ? duration.inSeconds.toDouble()
//                                           : 1.0;
//                                       double currentValue =
//                                           position.inSeconds.toDouble();
//                                       if (currentValue > maxValue)
//                                         currentValue = maxValue;

//                                       return GestureDetector(
//                                         onTapDown: (details) async {
//                                           try {
//                                             // Handle tap-based seeking
//                                             final renderBox =
//                                                 context.findRenderObject()
//                                                     as RenderBox;
//                                             final localPosition =
//                                                 renderBox.globalToLocal(
//                                                     details.globalPosition);
//                                             final sliderWidth =
//                                                 renderBox.size.width;
//                                             final percent =
//                                                 localPosition.dx / sliderWidth;
//                                             final newPosition = Duration(
//                                                 seconds: (maxValue * percent)
//                                                     .toInt());

//                                             await audioHandler
//                                                 .seek(newPosition);
//                                           } catch (e) {
//                                             debugPrint(
//                                                 'GestureDectector : Seek failed: $e');
//                                           }
//                                         },
//                                         child: Slider(
//                                           value: currentValue,
//                                           min: 0,
//                                           max: maxValue,
//                                           activeColor: Colors.blue,
//                                           inactiveColor: Colors.grey[700],
//                                           // onChangeStart: (value) {
//                                           //   try {
//                                           //    await audioHandler.startSeeking();
//                                           //   } catch (e) {
//                                           //     debugPrint(
//                                           //         'sliderOnChangeStart : Seek failed: $e');
//                                           //   }
//                                           // },
//                                           onChanged: (value) async {
//                                             if (audioHandler
//                                                 .isProcessingStateReady) {
//                                               try {
//                                                 await audioHandler.seek(
//                                                     Duration(
//                                                         seconds:
//                                                             value.toInt()));
//                                               } catch (e) {
//                                                 debugPrint(
//                                                     'sliderOnChanged : Seek failed: $e');
//                                               }
//                                             }
//                                           },
//                                           // onChangeEnd: (value) async {
//                                           //   if (audioHandler.isProcessingStateReady) {
//                                           //     try {
//                                           //       await audioHandler.seek(
//                                           //           Duration(seconds: value.toInt()));
//                                           //     } catch (e) {
//                                           //       debugPrint(
//                                           //           'sliderOnChangeEnd : Seek failed: $e');
//                                           //     }
//                                           //   }
//                                           // },
//                                         ),
//                                       );
//                                     },
//                                   );
//                                 },
//                               ),

//                               Padding(
//                                 padding: const EdgeInsets.symmetric(
//                                     horizontal: 16.0),
//                                 child: StreamBuilder<Duration>(
//                                   stream: audioHandler.positionStream,
//                                   builder: (context, positionSnapshot) {
//                                     final position =
//                                         positionSnapshot.data ?? Duration.zero;
//                                     return StreamBuilder<Duration?>(
//                                       stream: audioHandler.durationStream,
//                                       builder: (context, durationSnapshot) {
//                                         final duration =
//                                             durationSnapshot.data ??
//                                                 Duration.zero;
//                                         return Row(
//                                           mainAxisAlignment:
//                                               MainAxisAlignment.spaceBetween,
//                                           children: [
//                                             Text(
//                                               _formatDuration(position),
//                                               style: const TextStyle(
//                                                   color: Colors.white),
//                                             ),
//                                             Text(
//                                               _formatDuration(duration),
//                                               style: const TextStyle(
//                                                   color: Colors.white),
//                                             ),
//                                           ],
//                                         );
//                                       },
//                                     );
//                                   },
//                                 ),
//                               ),

//                               // For the error handling section, add this after the progress bar:
//                               StreamBuilder<PlayerState>(
//                                 stream: audioHandler.playerStateStream,
//                                 builder: (context, snapshot) {
//                                   if (snapshot.hasError) {
//                                     return Padding(
//                                       padding: const EdgeInsets.symmetric(
//                                           horizontal: 16.0),
//                                       child: Text(
//                                         'Playback error: ${snapshot.error}',
//                                         style:
//                                             const TextStyle(color: Colors.red),
//                                         textAlign: TextAlign.center,
//                                       ),
//                                     );
//                                   }
//                                   return const SizedBox.shrink();
//                                 },
//                               ),

//                               const SizedBox(height: 15),

//                               // Player Controls
//                               Row(
//                                 mainAxisAlignment: MainAxisAlignment.center,
//                                 children: [
//                                   // Shuffle Button
//                                   IconButton(
//                                     icon: Icon(
//                                       Icons.shuffle,
//                                       color: playbackState?.shuffleMode ==
//                                               AudioServiceShuffleMode.all
//                                           ? Colors.blue
//                                           : Colors.white,
//                                     ),
//                                     onPressed: audioHandler.toggleShuffle,
//                                   ),

//                                   const Spacer(),

//                                   // Previous Track
//                                   IconButton(
//                                     icon: const Icon(Icons.skip_previous,
//                                         size: 40, color: Colors.white),
//                                     onPressed: audioHandler.skipToPrevious,
//                                   ),
//                                   const SizedBox(width: 20),

//                                   // Play/Pause
//                                   Container(
//                                     decoration: BoxDecoration(
//                                       color: Colors.blue[800],
//                                       shape: BoxShape.circle,
//                                     ),
//                                     child: IconButton(
//                                       icon: Icon(
//                                         isPlaying
//                                             ? Icons.pause
//                                             : Icons.play_arrow,
//                                         color: Colors.white,
//                                       ),
//                                       onPressed: () {
//                                         if (isPlaying) {
//                                           audioHandler.pause();
//                                         } else {
//                                           audioHandler.play();
//                                         }
//                                       },
//                                     ),
//                                   ),

//                                   const SizedBox(width: 20),

//                                   // Next Track
//                                   IconButton(
//                                     icon: const Icon(Icons.skip_next,
//                                         size: 40, color: Colors.white),
//                                     onPressed: audioHandler.skipToNext,
//                                   ),

//                                   const Spacer(),

//                                   // Repeat Button
//                                   IconButton(
//                                     icon: Icon(
//                                       playbackState?.repeatMode ==
//                                               AudioServiceRepeatMode.one
//                                           ? Icons.repeat_one
//                                           : Icons.repeat,
//                                       color: playbackState?.repeatMode ==
//                                               AudioServiceRepeatMode.one
//                                           ? Colors.blue
//                                           : Colors.white,
//                                     ),
//                                     onPressed: audioHandler.toggleRepeat,
//                                   ),
//                                 ],
//                               ),
//                             ],
//                           ),
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//                 appBar: AppBar(
//                   backgroundColor: Colors.transparent,
//                   elevation: 0,
//                   leading: IconButton(
//                     icon: const Icon(Icons.arrow_drop_down_circle_outlined,
//                         color: Colors.white),
//                     onPressed: () => Navigator.pop(context),
//                   ),
//                   centerTitle: true,
//                   title: Text(
//                     mediaItem?.artist ?? 'Unknown Artist',
//                     style: const TextStyle(
//                       color: Colors.white,
//                       fontSize: 24,
//                       fontWeight: FontWeight.bold,
//                     ),
//                     overflow: TextOverflow.ellipsis,
//                     maxLines: 1,
//                   ),
//                 ),
//                 bottomNavigationBar: Container(
//                   decoration: BoxDecoration(
//                     color: Colors.grey[900],
//                     border: const Border(
//                         top: BorderSide(color: Colors.grey, width: 0.5)),
//                   ),
//                   child: BottomNavigationBar(
//                     backgroundColor: Colors.transparent,
//                     selectedItemColor: Colors.blue[300],
//                     unselectedItemColor: Colors.white,
//                     type: BottomNavigationBarType.fixed,
//                     currentIndex: 0,
//                     onTap: _onBottomNavTap,
//                     items: [
//                       const BottomNavigationBarItem(
//                         icon: Icon(Icons.account_circle),
//                         label: 'Sharanas',
//                       ),
//                       const BottomNavigationBarItem(
//                         icon: Icon(Icons.library_books),
//                         label: 'All Vachanas',
//                       ),
//                       BottomNavigationBarItem(
//                         icon: Container(
//                           width: 50,
//                           height: 50,
//                           decoration: BoxDecoration(
//                             color: Colors.blue[800],
//                             shape: BoxShape.circle,
//                           ),
//                           child: const Icon(Icons.keyboard_command_key_rounded,
//                               color: Colors.white),
//                         ),
//                         label: '',
//                       ),
//                       BottomNavigationBarItem(
//                         icon: Icon(
//                           Icons.favorite,
//                           color: appState.isLoggedIn
//                               ? Colors.white70
//                               : Colors.grey[600],
//                         ),
//                         label: 'Favorites',
//                       ),
//                       const BottomNavigationBarItem(
//                         icon: Icon(Icons.info),
//                         label: 'About',
//                       ),
//                     ],
//                   ),
//                 ),
//               );
//             },
//           );
//         });
//   }

//   Widget _buildBlurredBackground(int sharanaId) {
//     return Positioned.fill(
//       child: Stack(
//         children: [
//           FirebaseImage(
//             sharanaId: sharanaId,
//             imageType: 'mini',
//             size: double.infinity,
//             placeholder: Container(color: Colors.black),
//             errorWidget: Container(color: Colors.black),
//           ),
//           BackdropFilter(
//             filter: ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
//             child: Container(color: Colors.transparent),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildVachanaCoverArt(MediaItem mediaItem) {
//     return FirebaseImage(
//       sharanaId: mediaItem.extras?['sharanaId'] as int? ?? 0,
//       imageType: 'coverart',
//       size: 300,
//       placeholder: _buildLoadingPlaceholder(),
//       errorWidget: _buildPlaceholderIcon(),
//     );
//   }

//   // Widget _buildVachanaCoverArt(AudioPlayerHandler audioHandler) {
//   //   final current = audioHandler.currentVachana;
//   //   return FirebaseImage(
//   //     sharanaId: current?.sharanaId ?? 0,
//   //     imageType: 'coverart',
//   //     size: 300,
//   //     placeholder: _buildLoadingPlaceholder(),
//   //     errorWidget: _buildPlaceholderIcon(),
//   //   );
//   // }

//   Widget _buildPlaceholderIcon() => Icon(
//         Icons.music_note,
//         size: 100,
//         color: Colors.grey[700],
//       );

//   Widget _buildLoadingPlaceholder() => Container(
//         color: Colors.grey[900],
//         child: Center(
//           child: CircularProgressIndicator(
//             valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[700]!),
//           ),
//         ),
//       );

//   void _onBottomNavTap(int index) {
//     switch (index) {
//       case 0:
//         Navigator.push(
//             context, MaterialPageRoute(builder: (_) => const SharanasPage()));
//         break;
//       case 1:
//         Navigator.push(context,
//             MaterialPageRoute(builder: (_) => const AllVachanasPage()));
//         break;
//       case 4:
//         Navigator.push(
//             context, MaterialPageRoute(builder: (_) => const AboutPage()));
//         break;
//     }
//   }

//   String _formatDuration(Duration duration) {
//     String twoDigits(int n) => n.toString().padLeft(2, '0');
//     final minutes = twoDigits(duration.inMinutes.remainder(60));
//     final seconds = twoDigits(duration.inSeconds.remainder(60));
//     return '$minutes:$seconds';
//   }
// }


// as. of 2025 06 30 3PM, as the new impl will replace audio_service with handler
// import 'dart:ui';
// import 'package:audio_service/audio_service.dart';
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:shunya_vachanasiri/providers/app_state.dart';
// import 'package:shunya_vachanasiri/screens/sharanas_page.dart';
// import 'package:shunya_vachanasiri/screens/about_vachanasiri.dart';
// import 'package:shunya_vachanasiri/screens/all_vachanas_page.dart';
// import 'package:shunya_vachanasiri/widgets/lyrics_overlay.dart';
// import 'package:shunya_vachanasiri/widgets/firebase_image.dart';
// import 'package:marquee/marquee.dart';
// import 'package:shunya_vachanasiri/providers/audio_handler.dart';
// import 'package:shunya_vachanasiri/providers/audio_service_manager.dart';

// class AudioPlayerPage extends StatefulWidget {
//   const AudioPlayerPage({super.key});

//   @override
//   State<AudioPlayerPage> createState() => _AudioPlayerPageState();
// }

// class _AudioPlayerPageState extends State<AudioPlayerPage> {
//   late AudioPlayerHandler _audioService;
//   bool _isRepeating = false;

//   @override
//   void initState() {
//     super.initState();
//     _audioService = Provider.of<AudioPlayerHandler>(context, listen: false);
//   }

//   @override
//   Widget build(BuildContext context) {
//     final appState = Provider.of<AppState>(context);
//     final audioService =
//         Provider.of<AudioPlayerHandler>(context, listen: false);

//     return Consumer<AudioPlayerHandler>(
//       builder: (context, audioService, child) {
//         final current = audioService.currentVachana;
//         // final currentPlayingSharanaId = current?.sharanaId;

//         if (current == null) {
//           return Scaffold(
//               backgroundColor: Colors.black,
//               body: Center(
//                   child: Text('No track playing',
//                       style: TextStyle(color: Colors.white))));
//         }
//         return Scaffold(
//           backgroundColor: Colors.black,
//           body: Stack(
//             children: [
//               // Blurred background with artist image
//               _buildBlurredBackground(current.sharanaId),

//               // Dark overlay for better text readability
//               Container(
//                 color: Colors.black.withOpacity(0.7),
//               ),

//               SafeArea(
//                 child: SingleChildScrollView(
//                   child: Padding(
//                     padding: const EdgeInsets.all(24.0),
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.center,
//                       children: [
//                         // Album Art
//                         Container(
//                           width: 250,
//                           height: 250,
//                           decoration: BoxDecoration(
//                             color: Colors.grey[900],
//                             borderRadius: BorderRadius.circular(12),
//                             boxShadow: [
//                               BoxShadow(
//                                 color: Colors.black.withOpacity(0.3),
//                                 blurRadius: 10,
//                                 spreadRadius: 2,
//                               )
//                             ],
//                           ),
//                           child: ClipRRect(
//                             borderRadius: BorderRadius.circular(12),
//                             // child: _buildVachanaCoverArt(currentPlayingSharanaId),
//                             child: _buildVachanaCoverArt(),
//                           ),
//                         ),

//                         const SizedBox(height: 20),

//                         // Vachana Title
//                         if (current.vachanaNameKannada.length <= 25)
//                           SizedBox(
//                             height: 38,
//                             child: Text(
//                               current.vachanaNameKannada,
//                               style: const TextStyle(
//                                 color: Colors.white,
//                                 fontSize: 24,
//                                 fontWeight: FontWeight.bold,
//                               ),
//                               textAlign: TextAlign.center,
//                               maxLines: 1,
//                               overflow: TextOverflow.ellipsis,
//                             ),
//                           )
//                         else
//                           SizedBox(
//                             height: 38,
//                             child: Marquee(
//                               text: current.vachanaNameKannada,
//                               style: const TextStyle(
//                                 color: Colors.white,
//                                 fontSize: 24,
//                                 fontWeight: FontWeight.bold,
//                               ),
//                               blankSpace: 50.0,
//                               velocity: 25.0,
//                               pauseAfterRound: const Duration(seconds: 1),
//                             ),
//                           ),
//                         const SizedBox(height: 10),
//                         // Vachana Dhwani
//                         Text(
//                           "ಧ್ವನಿ : ಶ್ರೀ. ಮ. ನಿ. ಪ್ರ. ಡಾ|| ಮಹಾಂತಪ್ರಭು ಸ್ವಾಮೀಜಿ",
//                           style: const TextStyle(
//                             color: Colors.white,
//                             fontSize: 12,
//                             fontWeight: FontWeight.normal,
//                           ),
//                           textAlign: TextAlign.center,
//                           maxLines: 1,
//                           // overflow: TextOverflow.ellipsis,
//                         ),
//                         const SizedBox(height: 20),

//                         // Action Icons Row
//                         Row(
//                           mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                           children: [
//                             // Favorite
//                             IconButton(
//                               icon: Icon(
//                                 appState.favorites.contains(current.vachanaId)
//                                     ? Icons.favorite
//                                     : Icons.favorite_border,
//                                 color: appState.favorites
//                                         .contains(current.vachanaId)
//                                     ? Colors.red
//                                     : Colors.grey,
//                               ),
//                               tooltip: 'N/A',
//                               onPressed: () {},
//                               //=> appState.toggleFavorite(current.vachanaId),
//                             ),
//                             // Share
//                             IconButton(
//                               icon: const Icon(Icons.share, color: Colors.grey),
//                               tooltip: 'N/A',
//                               onPressed: () {
//                                 // Implement share functionality
//                               },
//                             ),
//                             // Download
//                             IconButton(
//                               icon: const Icon(Icons.download,
//                                   color: Colors.grey),
//                               tooltip: 'N/A',
//                               onPressed: () {
//                                 // Implement download functionality
//                               },
//                             ),
//                             // Lyrics
//                             IconButton(
//                               icon:
//                                   const Icon(Icons.lyrics, color: Colors.white),
//                               onPressed: () {
//                                 final current = audioService.currentVachana;
//                                 if (current != null) {
//                                   showModalBottomSheet(
//                                     context: context,
//                                     backgroundColor: Colors.transparent,
//                                     isScrollControlled: true,
//                                     builder: (context) =>
//                                         LyricsOverlay(vachana: current),
//                                   );
//                                 }
//                               },
//                             ),
//                           ],
//                         ),

//                         const SizedBox(height: 10),

//                         // Progress bar that needs frequent updates
//                         Selector<AudioPlayerHandler, Duration>(
//                           selector: (_, service) => service.position,
//                           builder: (context, position, __) {
//                             final service =
//                                 Provider.of<AudioPlayerHandler>(context);
//                             final duration = service.duration;

//                             double maxValue = duration.inSeconds > 0
//                                 ? duration.inSeconds.toDouble()
//                                 : 1.0;
//                             double currentValue = position.inSeconds.toDouble();
//                             if (currentValue > maxValue)
//                               currentValue = maxValue;

//                             return GestureDetector(
//                               onTapDown: (details) {
//                                 // Handle tap-based seeking
//                                 final renderBox =
//                                     context.findRenderObject() as RenderBox;
//                                 final localPosition = renderBox
//                                     .globalToLocal(details.globalPosition);
//                                 final sliderWidth = renderBox.size.width;
//                                 final percent = localPosition.dx / sliderWidth;
//                                 final newPosition = Duration(
//                                     seconds: (maxValue * percent).toInt());

//                                 service.seek(newPosition);
//                               },
//                               child: Slider(
//                                 value: currentValue,
//                                 min: 0,
//                                 max: maxValue,
//                                 onChangeStart: (value) {
//                                   service.startSeeking();
//                                 },
//                                 onChanged: (value) {
//                                   service.updateTempPosition(
//                                       Duration(seconds: value.toInt()));
//                                 },
//                                 onChangeEnd: (value) async {
//                                   await service
//                                       .seek(Duration(seconds: value.toInt()));
//                                 },
//                                 activeColor: Colors.blue,
//                                 inactiveColor: Colors.grey[700],
//                               ),
//                             );
//                           },
//                         ),

//                         // // Time indicators
//                         // Selector<AudioPlayerService, Duration>(
//                         //   selector: (_, service) => service.position,
//                         //   builder: (context, position, __) {
//                         //     final service =
//                         //         Provider.of<AudioPlayerService>(context);
//                         //     return Row(
//                         //       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                         //       children: [
//                         //         Text(
//                         //             '${position.inMinutes}:${(position.inSeconds % 60).toString().padLeft(2, '0')}'),
//                         //         Text(
//                         //             '${service.duration.inMinutes}:${(service.duration.inSeconds % 60).toString().padLeft(2, '0')}'),
//                         //       ],
//                         //     );
//                         //   },
//                         // ),

//                         // Progress Bar as on 2025 06 25
//                         // Slider(
//                         //   value: audioService.position.inSeconds.toDouble(),
//                         //   min: 0.0,
//                         //   max: audioService.duration.inSeconds.toDouble(),
//                         //   onChanged: (value) async {
//                         //     await audioService
//                         //         .seek(Duration(seconds: value.toInt()));
//                         //   },
//                         //   activeColor: Colors.blue,
//                         //   inactiveColor: Colors.grey[700],
//                         // ),

//                         Padding(
//                           padding: const EdgeInsets.symmetric(horizontal: 16.0),
//                           child: Row(
//                             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                             children: [
//                               Text(
//                                 _formatDuration(audioService.position),
//                                 style: const TextStyle(color: Colors.white),
//                               ),
//                               Text(
//                                 _formatDuration(audioService.duration),
//                                 style: const TextStyle(color: Colors.white),
//                               ),
//                             ],
//                           ),
//                         ),

//                         const SizedBox(height: 15),

//                         // Player Controls
//                         Row(
//                           mainAxisAlignment: MainAxisAlignment.center,
//                           children: [
//                             // Shuffle Button
//                             IconButton(
//                               icon: Icon(
//                                 Icons.shuffle,
//                                 color: audioService.isShuffled
//                                     ? Colors.blue
//                                     : Colors.white,
//                               ),
//                               onPressed: audioService.toggleShuffle,
//                             ),

//                             const Spacer(),

//                             // Previous Track
//                             IconButton(
//                               icon: const Icon(Icons.skip_previous,
//                                   size: 40, color: Colors.white),
//                               onPressed: audioService.playPrevious,
//                             ),
//                             const SizedBox(width: 20),
//                             // Play/Pause
//                             Container(
//                                 decoration: BoxDecoration(
//                                   color: Colors.blue[800],
//                                   shape: BoxShape.circle,
//                                 ),
//                                 child: StreamBuilder<PlaybackState>(
//                                     stream:
//                                         AudioServiceManager.playbackStateStream,
//                                     builder: (context, snapshot) {
//                                       final isPlaying =
//                                           snapshot.data?.playing ?? false;

//                                       return IconButton(
//                                         icon: isPlaying
//                                             ? Icon(Icons.pause)
//                                             : Icon(Icons.play_arrow),
//                                         onPressed: () {
//                                           if (isPlaying) {
//                                             AudioServiceManager.pause();
//                                           } else {
//                                             AudioServiceManager.play();
//                                           }
//                                         },
//                                       );
//                                     })
//                                 // child: IconButton(
//                                 //   icon: Icon(
//                                 //     audioService.isPlaying
//                                 //         ? Icons.pause
//                                 //         : Icons.play_arrow,
//                                 //     size: 40,
//                                 //     color: Colors.white,
//                                 //   ),
//                                 //   onPressed: audioService.togglePlayPause,
//                                 // ),
//                                 ),
//                             const SizedBox(width: 20),
//                             // Next Track
//                             IconButton(
//                               icon: const Icon(Icons.skip_next,
//                                   size: 40, color: Colors.white),
//                               onPressed: audioService.playNext,
//                             ),

//                             const Spacer(),

//                             // Repeat Button
//                             IconButton(
//                               icon: Icon(
//                                 audioService.isRepeating
//                                     ? Icons.repeat_one
//                                     : Icons.repeat,
//                                 color: audioService.isRepeating
//                                     ? Colors.blue
//                                     : Colors.white,
//                               ),
//                               onPressed: audioService
//                                   .toggleRepeat, // Connect to service directly
//                             ),
//                           ],
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//           appBar: AppBar(
//             backgroundColor: Colors.transparent, // Make appbar transparent
//             elevation: 0,
//             leading: IconButton(
//               icon: const Icon(Icons.arrow_drop_down_circle_outlined,
//                   color: Colors.white),
//               onPressed: () => Navigator.pop(context),
//             ),
//             centerTitle: true,
//             title: Text(
//               current.sharanaNameKannada,
//               style: const TextStyle(
//                 color: Colors.white,
//                 fontSize: 24,
//                 fontWeight: FontWeight.bold,
//               ),
//               overflow: TextOverflow.ellipsis,
//               maxLines: 1,
//             ),
//           ),
//           bottomNavigationBar: Container(
//             decoration: BoxDecoration(
//               color: Colors.grey[900],
//               border:
//                   const Border(top: BorderSide(color: Colors.grey, width: 0.5)),
//             ),
//             child: BottomNavigationBar(
//               backgroundColor: Colors.transparent,
//               selectedItemColor: Colors.blue[300],
//               unselectedItemColor: Colors.white,
//               type: BottomNavigationBarType.fixed,
//               currentIndex: 0,
//               onTap: _onBottomNavTap,
//               items: [
//                 const BottomNavigationBarItem(
//                   icon: Icon(Icons.account_circle),
//                   label: 'Sharanas',
//                 ),
//                 const BottomNavigationBarItem(
//                   icon: Icon(Icons.library_books),
//                   label: 'All Vachanas',
//                 ),
//                 BottomNavigationBarItem(
//                   icon: Container(
//                     width: 50,
//                     height: 50,
//                     decoration: BoxDecoration(
//                       color: Colors.blue[800],
//                       shape: BoxShape.circle,
//                     ),
//                     child: const Icon(Icons.keyboard_command_key_rounded,
//                         color: Colors.white),
//                   ),
//                   label: '',
//                 ),
//                 BottomNavigationBarItem(
//                   icon: Icon(
//                     Icons.favorite,
//                     color:
//                         appState.isLoggedIn ? Colors.white70 : Colors.grey[600],
//                   ),
//                   label: 'Favorites',
//                 ),
//                 const BottomNavigationBarItem(
//                   icon: Icon(Icons.info),
//                   label: 'About',
//                 ),
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }

//   Widget _buildBlurredBackground(int sharanaId) {
//     return Positioned.fill(
//       child: Stack(
//         children: [
//           // Artist image
//           FirebaseImage(
//             sharanaId: sharanaId,
//             imageType: 'mini',
//             size: double.infinity,
//             placeholder: Container(color: Colors.black),
//             errorWidget: Container(color: Colors.black),
//           ),

//           // Blur effect
//           BackdropFilter(
//             filter: ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
//             child: Container(
//               color: Colors.transparent,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildVachanaCoverArt() {
//     final audioService = Provider.of<AudioPlayerHandler>(context);
//     final current = audioService.currentVachana;

//     return FirebaseImage(
//       sharanaId: current?.sharanaId ?? 0,
//       imageType: 'coverart',
//       size: 300,
//       placeholder: _buildLoadingPlaceholder(),
//       errorWidget: _buildPlaceholderIcon(),
//     );
//   }

//   Widget _buildPlaceholderIcon() => Icon(
//         Icons.music_note,
//         size: 100,
//         color: Colors.grey[700],
//       );

//   Widget _buildLoadingPlaceholder() => Container(
//         color: Colors.grey[900],
//         child: Center(
//           child: CircularProgressIndicator(
//             valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[700]!),
//           ),
//         ),
//       );

//   void _onBottomNavTap(int index) {
//     switch (index) {
//       case 0:
//         Navigator.push(
//           context,
//           MaterialPageRoute(
//             builder: (context) => const SharanasPage(),
//           ),
//         );
//         break;
//       case 1:
//         Navigator.push(
//           context,
//           MaterialPageRoute(
//             builder: (context) => const AllVachanasPage(),
//           ),
//         );
//         break;
//       case 4:
//         Navigator.push(
//           context,
//           MaterialPageRoute(
//             builder: (context) => const AboutPage(),
//           ),
//         );
//         break;
//     }
//   }

//   String _formatDuration(Duration duration) {
//     String twoDigits(int n) => n.toString().padLeft(2, '0');
//     final minutes = twoDigits(duration.inMinutes.remainder(60));
//     final seconds = twoDigits(duration.inSeconds.remainder(60));
//     return '$minutes:$seconds';
//   }
// }

  // as of 2025 06 26 12 Noon
  // Widget _buildVachanaCoverArt(int? currentPlayingSharanaId) {
  //   if (currentPlayingSharanaId == null) return _buildPlaceholderIcon();

  //   // final audioService = Provider.of<AudioPlayerService>(context);
  //   // final current = audioService.currentVachana;

  //   // Only fetch new art when sharana changes
  //   if (_currentPlayingSharanaId != currentPlayingSharanaId) {
  //     _currentPlayingSharanaId = currentPlayingSharanaId;
  //     _cachedVachanaCoverArtUrl = null;
  //     _preloadVachanaCoverArt(currentPlayingSharanaId);
  //   }

  //   if (_imageCache.containsKey(currentPlayingSharanaId)) {
  //     // Use cached image if available
  //     return Image(
  //       image: _imageCache[currentPlayingSharanaId]!,
  //       fit: BoxFit.cover,
  //     );
  //   }

  //   return _cachedVachanaCoverArtUrl == null
  //       ? _buildLoadingPlaceholder()
  //       : CachedNetworkImage(
  //           imageUrl: _cachedVachanaCoverArtUrl!,
  //           fit: BoxFit.cover,
  //           errorWidget: (context, url, error) => _buildPlaceholderIcon(),
  //         );
  // }

  // Future<void> _preloadVachanaCoverArt(int sharanaId) async {
  //   try {
  //     const images = ['a.png'];

  //     // Try images in priority order
  //     for (final image in images) {
  //       try {
  //         final path = '${AppConstants.vachanaArtCoverFSDir}/$sharanaId/$image';
  //         final ref = FirebaseStorage.instance.ref(path);
  //         final url = await ref.getDownloadURL();

  //         // Pre-cache the image
  //         final provider = NetworkImage(url);
  //         final cacheResult = await provider.evict();
  //         if (cacheResult) {
  //           await precacheImage(provider, context);
  //         }

  //         // Store in cache
  //         _imageCache[sharanaId] = provider;

  //         // Check if still needed (artist hasn't changed)
  //         if (_currentPlayingSharanaId == sharanaId) {
  //           setState(() => _cachedVachanaCoverArtUrl = url);
  //           return;
  //         }
  //       } catch (_) {
  //         // Try next image
  //       }
  //     }

  //     // If no images found, use placeholder
  //     if (_currentPlayingSharanaId == sharanaId) {
  //       setState(() => _cachedVachanaCoverArtUrl = '');
  //     }
  //   } catch (e) {
  //     if (_currentPlayingSharanaId == sharanaId) {
  //       setState(() => _cachedVachanaCoverArtUrl = '');
  //     }
  //   }
  // }

  // as on 2025 06 25

  // Widget _buildVachanaCoverArt() {
  //   final audioService = Provider.of<AudioPlayerService>(context);
  //   final current = audioService.currentVachana;

  //   if (current == null) {
  //     return const Icon(
  //       Icons.music_note,
  //       size: 100,
  //       color: Colors.grey,
  //     );
  //   }

  //   if (current.vachanaArtUrl == null || current.vachanaArtUrl!.isEmpty) {
  //     return Icon(
  //       Icons.music_note,
  //       size: 100,
  //       color: Colors.grey[700],
  //     );
  //   }

  //   return CachedNetworkImage(
  //     imageUrl: current.vachanaArtUrl!,
  //     fit: BoxFit.cover,
  //     placeholder: (context, url) => Container(
  //       color: Colors.grey[900],
  //       child: Center(
  //         child: CircularProgressIndicator(
  //           valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[700]!),
  //         ),
  //       ),
  //     ),
  //     errorWidget: (context, url, error) => Icon(
  //       Icons.broken_image,
  //       size: 100,
  //       color: Colors.grey[700],
  //     ),
  //   );
  // }

  // void _toggleShuffle() {
  //   _audioService.toggleShuffle();
  // }

  // void _toggleRepeat() {
  //   setState(() {
  //     _isRepeating = !_isRepeating;
  //   });
  // }
// }
