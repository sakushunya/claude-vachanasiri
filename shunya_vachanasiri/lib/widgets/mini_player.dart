// /lib/widgets/mini_player.dart

// /lib/widgets/mini_player.dart

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:marquee/marquee.dart';
import 'package:provider/provider.dart';
import 'package:shunya_vachanasiri/models/vachana_model.dart';
import 'package:shunya_vachanasiri/screens/audio_player_page.dart';
import 'package:shunya_vachanasiri/widgets/firebase_image.dart';
import 'package:shunya_vachanasiri/providers/audio_handler.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  String _formatDuration(Duration d) {
    if (d.inSeconds < 0) return "--:--";
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    return "${twoDigits(d.inMinutes)}:${twoDigits(d.inSeconds.remainder(60))}";
  }

  @override
  Widget build(BuildContext context) {
    final audioHandler = Provider.of<AudioPlayerHandler>(context);
    final screenWidth = MediaQuery.of(context).size.width;

    return ValueListenableBuilder<Vachana?>(
      valueListenable: audioHandler.currentVachanaNotifier,
      builder: (context, vachana, _) {
        // Don't show if no vachana
        if (vachana == null) return const SizedBox.shrink();

        // Add debug print to verify updates
        print('MiniPlayer Vachana Update: ${vachana.vachanaNameKannada}');

        return StreamBuilder<PlaybackState>(
          stream: audioHandler.playbackState,
          builder: (context, snapshot) {
            final isPlaying = snapshot.data?.playing ?? false;

            return GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AudioPlayerPage()),
              ),
              child: Container(
                height: 60,
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.blueGrey.withOpacity(0.8),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.5],
                  ),
                  color: Colors.grey[850]!.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.7),
                      blurRadius: 20,
                      spreadRadius: 3,
                      offset: const Offset(0, 5),
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                  border: Border.all(
                    color: Colors.blueAccent.withOpacity(0.5),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    FirebaseImage(
                      sharanaId: vachana.sharanaId,
                      imageType: 'mini',
                      size: 35,
                      borderRadius: 6,
                      placeholder: Container(
                        color: Colors.grey[800],
                        child: const Icon(
                          Icons.music_note,
                          color: Colors.white70,
                          size: 20,
                        ),
                      ),
                      errorWidget: const Icon(
                        Icons.music_note,
                        color: Colors.white70,
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Text content
                    Expanded(
                      flex: 6,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: SizedBox(
                              height: 20,
                              child: Row(
                                children: [
                                  const Text(
                                    'ವಚನ : ',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  if (vachana.vachanaNameKannada.length <= 22)
                                    Flexible(
                                      child: Text(
                                        vachana.vachanaNameKannada,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    )
                                  else
                                    Flexible(
                                      child: Marquee(
                                        text: vachana.vachanaNameKannada,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        blankSpace: 50.0,
                                        velocity: 25.0,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Flexible(
                            child: Text(
                              'ಕರ್ತೃ  : ${vachana.sharanaNameKannada}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Duration and controls
                    SizedBox(
                      width: screenWidth * 0.3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Position and duration
                          Flexible(child: _buildProgress(audioHandler)),
                          const SizedBox(height: 2),
                          // Playback controls
                          Flexible(
                            child: _buildControls(audioHandler, isPlaying),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildProgress(AudioPlayerHandler audioHandler) {
    return StreamBuilder<Duration>(
      stream: audioHandler.positionStream,
      builder: (context, positionSnapshot) {
        final position = positionSnapshot.data ?? Duration.zero;
        return StreamBuilder<Duration?>(
          stream: audioHandler.durationStream,
          builder: (context, durationSnapshot) {
            final duration = durationSnapshot.data ?? Duration.zero;
            return Text(
              '${_formatDuration(position)}/${_formatDuration(duration)}',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            );
          },
        );
      },
    );
  }

  Widget _buildControls(AudioPlayerHandler handler, bool isPlaying) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: const Icon(
              Icons.skip_previous,
              size: 18,
              color: Colors.white,
            ),
            onPressed: handler.skipToPrevious,
          ),
        ),
        const SizedBox(width: 4),
        SizedBox(
          width: 24,
          height: 24,
          child: IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: Icon(
              isPlaying ? Icons.pause : Icons.play_arrow,
              size: 20,
              color: Colors.white,
            ),
            onPressed: () => isPlaying ? handler.pause() : handler.play(),
          ),
        ),
        const SizedBox(width: 4),
        SizedBox(
          width: 24,
          height: 24,
          child: IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: const Icon(Icons.skip_next, size: 18, color: Colors.white),
            onPressed: handler.skipToNext,
          ),
        ),
      ],
    );
  }
}

/** as of 20250706 from Deepeseek
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:marquee/marquee.dart';
import 'package:provider/provider.dart';
import 'package:shunya_vachanasiri/models/vachana_model.dart';
import 'package:shunya_vachanasiri/screens/audio_player_page.dart';
import 'package:shunya_vachanasiri/widgets/firebase_image.dart';
import 'package:shunya_vachanasiri/providers/audio_handler.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  String _formatDuration(Duration d) {
    if (d.inSeconds < 0) return "--:--";
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    return "${twoDigits(d.inMinutes)}:${twoDigits(d.inSeconds.remainder(60))}";
  }

  @override
  Widget build(BuildContext context) {
    final audioHandler = Provider.of<AudioPlayerHandler>(context);
    final screenWidth = MediaQuery.of(context).size.width;

    return ValueListenableBuilder<Vachana?>(
      valueListenable: audioHandler.currentVachanaNotifier,
      builder: (context, vachana, _) {
        // Don't show if no vachana
        if (vachana == null) return const SizedBox.shrink();

        // Add debug print to verify updates
        print('MiniPlayer Vachana Update: ${vachana.vachanaLyricsKannada}');

        return StreamBuilder<PlaybackState>(
          stream: audioHandler.playbackState,
          builder: (context, snapshot) {
            final isPlaying = snapshot.data?.playing ?? false;

            return GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AudioPlayerPage()),
              ),
              child: Container(
                height: 60,
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.blueGrey.withOpacity(0.8),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.5],
                  ),
                  color: Colors.grey[850]!.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.7),
                      blurRadius: 20,
                      spreadRadius: 3,
                      offset: const Offset(0, 5),
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                  border: Border.all(
                    color: Colors.blueAccent.withOpacity(0.5),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    FirebaseImage(
                      sharanaId: vachana.sharanaId,
                      imageType: 'mini',
                      size: 35,
                      borderRadius: 6,
                      placeholder: Container(
                        color: Colors.grey[800],
                        child: const Icon(
                          Icons.music_note,
                          color: Colors.white70,
                          size: 20,
                        ),
                      ),
                      errorWidget: const Icon(
                        Icons.music_note,
                        color: Colors.white70,
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Text content
                    Expanded(
                      flex: 6,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            height: 20,
                            child: Row(
                              children: [
                                const Text(
                                  'ವಚನ : ',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (vachana.vachanaNameKannada.length <= 22)
                                  Flexible(
                                    child: Text(
                                      vachana.vachanaNameKannada,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  )
                                else
                                  Flexible(
                                    child: Marquee(
                                      text: vachana.vachanaNameKannada,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      blankSpace: 50.0,
                                      velocity: 25.0,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'ಕರ್ತೃ  : ${vachana.sharanaNameKannada}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ],
                      ),
                    ),

                    // Duration and controls
                    SizedBox(
                      width: screenWidth * 0.3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Position and duration
                          _buildProgress(audioHandler),
                          // StreamBuilder<Duration>(
                          //   stream: audioHandler.positionStream,
                          //   builder: (context, positionSnapshot) {
                          //     final position =
                          //         positionSnapshot.data ?? Duration.zero;
                          //     return StreamBuilder<Duration?>(
                          //       stream: audioHandler.durationStream,
                          //       builder: (context, durationSnapshot) {
                          //         final duration =
                          //             durationSnapshot.data ?? Duration.zero;
                          //         return Text(
                          //           '${_formatDuration(position)}/${_formatDuration(duration)}',
                          //           style: const TextStyle(
                          //             color: Colors.white70,
                          //             fontSize: 12,
                          //           ),
                          //           overflow: TextOverflow.ellipsis,
                          //           textAlign: TextAlign.center,
                          //         );
                          //       },
                          //     );
                          //   },
                          // ),
                          const SizedBox(height: 4),

                          // Playback controls
                          _buildControls(audioHandler, isPlaying),

                          // StreamBuilder<PlaybackState>(
                          //   stream: audioHandler.playbackState,
                          //   builder: (context, stateSnapshot) {
                          //     final playbackState = stateSnapshot.data;
                          //     final isPlaying = playbackState?.playing ?? false;
                          //     return Row(
                          //       mainAxisAlignment: MainAxisAlignment.end,
                          //       mainAxisSize: MainAxisSize.min,
                          //       children: [
                          //         IconButton(
                          //           icon: const Icon(Icons.skip_previous, size: 22),
                          //           onPressed: audioHandler.skipToPrevious,
                          //         ),
                          //         const SizedBox(width: 6),
                          //         IconButton(
                          //           icon: Icon(
                          //             isPlaying ? Icons.pause : Icons.play_arrow,
                          //             size: 24,
                          //           ),
                          //           onPressed: () => isPlaying
                          //               ? audioHandler.pause()
                          //               : audioHandler.play(),
                          //         ),
                          //         const SizedBox(width: 6),
                          //         IconButton(
                          //           icon: const Icon(Icons.skip_next, size: 22),
                          //           onPressed: audioHandler.skipToNext,
                          //         ),
                          //       ],
                          //     );
                          //   },
                          // ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildProgress(AudioPlayerHandler audioHandler) {
    return StreamBuilder<Duration>(
      stream: audioHandler.positionStream,
      builder: (context, positionSnapshot) {
        final position = positionSnapshot.data ?? Duration.zero;
        return StreamBuilder<Duration?>(
          stream: audioHandler.durationStream,
          builder: (context, durationSnapshot) {
            final duration = durationSnapshot.data ?? Duration.zero;
            return Text(
              '${_formatDuration(position)}/${_formatDuration(duration)}',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            );
          },
        );
      },
    );
  }

  Widget _buildControls(AudioPlayerHandler handler, bool isPlaying) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        IconButton(
          icon: const Icon(Icons.skip_previous, size: 4),
          onPressed: handler.skipToPrevious,
        ),
        const SizedBox(width: 6),
        IconButton(
          icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow, size: 16),
          onPressed: () => isPlaying ? handler.pause() : handler.play(),
        ),
        const SizedBox(width: 6),
        IconButton(
          icon: const Icon(Icons.skip_next, size: 14),
          onPressed: handler.skipToNext,
        ),
      ],
    );
  }
}

// end as of 2025 07 06 from Deepseek
**/ 


// as of 2025 07 02 1.00 AM
// was not at all coming up even after navigating thru diff screens of the app

// import 'package:flutter/material.dart';
// import 'package:marquee/marquee.dart';
// import 'package:provider/provider.dart';
// import 'package:shunya_vachanasiri/providers/audio_handler.dart';
// import 'package:shunya_vachanasiri/screens/audio_player_page.dart';
// import 'package:shunya_vachanasiri/widgets/firebase_image.dart';
// import 'package:audio_service/audio_service.dart';

// class MiniPlayer extends StatelessWidget {
//   const MiniPlayer({super.key});

//   String _formatDuration(Duration d) {
//     if (d.inSeconds < 0) return "--:--";
//     String twoDigits(int n) => n.toString().padLeft(2, "0");
//     final minutes = d.inMinutes.remainder(60);
//     final seconds = d.inSeconds.remainder(60);
//     return "${twoDigits(minutes)}:${twoDigits(seconds)}";
//   }

//   @override
//   Widget build(BuildContext context) {
//     return StreamBuilder<MediaItem?>(
//         stream: AudioService.currentMediaItemStream,
//         builder: (context, mediaSnapshot) {
//           final mediaItem = mediaSnapshot.data;
//           if (mediaItem == null) return const SizedBox.shrink();

//           return StreamBuilder<PlaybackState>(
//               stream: AudioService.playbackStateStream,
//               builder: (context, stateSnapshot) {
//                 final playbackState = stateSnapshot.data;
//                 final audioHandler =
//                     Provider.of<AudioPlayerHandler>(context, listen: false);
//                 final screenWidth = MediaQuery.of(context).size.width;
//                 final isPlaying = playbackState?.playing ?? false;

//                 return GestureDetector(
//                   onTap: () {
//                     Navigator.push(
//                       context,
//                       MaterialPageRoute(
//                           builder: (context) => const AudioPlayerPage()),
//                     );
//                   },
//                   child: Container(
//                     margin:
//                         const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
//                     padding: const EdgeInsets.all(4),
//                     decoration: BoxDecoration(
//                         // ... unchanged decoration ...
//                         ),
//                     child: Row(
//                       children: [
//                         FirebaseImage(
//                           sharanaId:
//                               mediaItem.extras?['sharanaId'] as int? ?? 0,
//                           imageType: 'mini',
//                           size: 35,
//                           borderRadius: 6,
//                           placeholder: Container(
//                             color: Colors.grey[800],
//                             child: const Icon(Icons.music_note,
//                                 color: Colors.white70, size: 20),
//                           ),
//                           errorWidget: const Icon(Icons.music_note,
//                               color: Colors.white70),
//                         ),

//                         const SizedBox(width: 8),

//                         // Text content
//                         Expanded(
//                           flex: 6,
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             mainAxisSize: MainAxisSize.min,
//                             children: [
//                               SizedBox(
//                                 height: 20,
//                                 child: Row(
//                                   children: [
//                                     const Text(
//                                       'ವಚನ : ',
//                                       style: TextStyle(
//                                         color: Colors.white,
//                                         fontSize: 14,
//                                         fontWeight: FontWeight.w500,
//                                       ),
//                                     ),
//                                     if (mediaItem.title.length <= 22)
//                                       Flexible(
//                                         child: Text(
//                                           mediaItem.title,
//                                           style: const TextStyle(
//                                             color: Colors.white,
//                                             fontSize: 14,
//                                             fontWeight: FontWeight.w500,
//                                           ),
//                                           overflow: TextOverflow.ellipsis,
//                                           maxLines: 1,
//                                         ),
//                                       )
//                                     else
//                                       Flexible(
//                                         child: Marquee(
//                                           text: mediaItem.title,
//                                           style: const TextStyle(
//                                             color: Colors.white,
//                                             fontSize: 14,
//                                             fontWeight: FontWeight.w500,
//                                           ),
//                                           blankSpace: 50.0,
//                                           velocity: 25.0,
//                                         ),
//                                       ),
//                                   ],
//                                 ),
//                               ),
//                               const SizedBox(height: 2),
//                               Text(
//                                 'ಕರ್ತೃ  : ${mediaItem.artist ?? 'Unknown Artist'}',
//                                 style: const TextStyle(
//                                   color: Colors.white,
//                                   fontSize: 14,
//                                 ),
//                                 overflow: TextOverflow.ellipsis,
//                                 maxLines: 1,
//                               ),
//                             ],
//                           ),
//                         ),

//                         // Duration and controls
//                         SizedBox(
//                           width: screenWidth * 0.3,
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.end,
//                             mainAxisSize: MainAxisSize.min,
//                             children: [
//                               // Position and duration
//                               StreamBuilder<Duration>(
//                                 stream: audioHandler.positionStream,
//                                 builder: (context, positionSnapshot) {
//                                   final position =
//                                       positionSnapshot.data ?? Duration.zero;
//                                   return StreamBuilder<Duration?>(
//                                     stream: audioHandler.durationStream,
//                                     builder: (context, durationSnapshot) {
//                                       final duration = durationSnapshot.data ??
//                                           Duration.zero;
//                                       return Text(
//                                         '${_formatDuration(position)}/${_formatDuration(duration)}',
//                                         style: const TextStyle(
//                                           color: Colors.white70,
//                                           fontSize: 12,
//                                         ),
//                                         overflow: TextOverflow.ellipsis,
//                                         textAlign: TextAlign.center,
//                                       );
//                                     },
//                                   );
//                                 },
//                               ),
//                               const SizedBox(height: 4),
//                               // Playback controls
//                               Row(
//                                 mainAxisAlignment: MainAxisAlignment.end,
//                                 mainAxisSize: MainAxisSize.min,
//                                 children: [
//                                   // Previous button
//                                   GestureDetector(
//                                     onTap: audioHandler.skipToPrevious,
//                                     child: const Icon(
//                                       Icons.skip_previous,
//                                       size: 22,
//                                       color: Colors.white,
//                                     ),
//                                   ),
//                                   const SizedBox(width: 6),

//                                   // Play/Pause button
//                                   GestureDetector(
//                                     onTap: () {
//                                       if (isPlaying) {
//                                         audioHandler.pause();
//                                       } else {
//                                         audioHandler.play();
//                                       }
//                                     },
//                                     child: Icon(
//                                       isPlaying
//                                           ? Icons.pause
//                                           : Icons.play_arrow,
//                                       size: 24,
//                                       color: Colors.white,
//                                     ),
//                                   ),
//                                   const SizedBox(width: 6),

//                                   // Next button
//                                   GestureDetector(
//                                     onTap: audioHandler.skipToNext,
//                                     child: const Icon(
//                                       Icons.skip_next,
//                                       size: 22,
//                                       color: Colors.white,
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ],
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 );
//               });
//         });
//   }
// }



// as of 2025 07 01 9.30 PM 
//   @override
//   Widget build(BuildContext context) {
//     final audioHandler = context.read<AudioPlayerHandler>();
//     final current = audioHandler.currentVachana;
//     final screenWidth = MediaQuery.of(context).size.width;

//     return current == null
//         ? const SizedBox.shrink()
//         : GestureDetector(
//             onTap: () {
//               Navigator.push(
//                 context,
//                 MaterialPageRoute(
//                   builder: (context) => const AudioPlayerPage(),
//                 ),
//               );
//             },
//             child: Container(
//               margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
//               padding: const EdgeInsets.all(4),
//               decoration: BoxDecoration(
//                 gradient: LinearGradient(
//                   begin: Alignment.topCenter,
//                   end: Alignment.bottomCenter,
//                   colors: [
//                     Colors.blueGrey.withOpacity(0.8),
//                     Colors.transparent,
//                   ],
//                   stops: const [0.0, 0.5],
//                 ),
//                 color: Colors.grey[850]!.withOpacity(0.95),
//                 borderRadius: BorderRadius.circular(12),
//                 boxShadow: [
//                   BoxShadow(
//                     color: Colors.blue.withOpacity(0.7),
//                     blurRadius: 20,
//                     spreadRadius: 3,
//                     offset: const Offset(0, 5),
//                   ),
//                   BoxShadow(
//                     color: Colors.black.withOpacity(0.5),
//                     blurRadius: 10,
//                     spreadRadius: 2,
//                   ),
//                 ],
//                 border: Border.all(
//                   color: Colors.blueAccent.withOpacity(0.5),
//                   width: 1.5,
//                 ),
//               ),
//               child: Row(
//                 children: [
//                   FirebaseImage(
//                     sharanaId: current.sharanaId,
//                     imageType: 'mini',
//                     size: 35,
//                     borderRadius: 6,
//                     placeholder: Container(
//                       color: Colors.grey[800],
//                       child: const Icon(Icons.music_note,
//                           color: Colors.white70, size: 20),
//                     ),
//                     errorWidget:
//                         const Icon(Icons.music_note, color: Colors.white70),
//                   ),

//                   const SizedBox(width: 8),

//                   // Text content (60%)
//                   Expanded(
//                     flex: 6,
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       mainAxisSize: MainAxisSize.min,
//                       children: [
//                         SizedBox(
//                           height: 20,
//                           child: Row(
//                             children: [
//                               const Text(
//                                 'ವಚನ : ',
//                                 style: TextStyle(
//                                   color: Colors.white,
//                                   fontSize: 14,
//                                   fontWeight: FontWeight.w500,
//                                 ),
//                               ),
//                               if (current.vachanaNameKannada.length <= 22)
//                                 Flexible(
//                                   child: Text(
//                                     current.vachanaNameKannada,
//                                     style: const TextStyle(
//                                       color: Colors.white,
//                                       fontSize: 14,
//                                       fontWeight: FontWeight.w500,
//                                     ),
//                                     overflow: TextOverflow.ellipsis,
//                                     maxLines: 1,
//                                   ),
//                                 )
//                               else
//                                 Flexible(
//                                   child: Marquee(
//                                     text: current.vachanaNameKannada,
//                                     style: const TextStyle(
//                                       color: Colors.white,
//                                       fontSize: 14,
//                                       fontWeight: FontWeight.w500,
//                                     ),
//                                     blankSpace: 50.0,
//                                     velocity: 25.0,
//                                   ),
//                                 ),
//                             ],
//                           ),
//                         ),
//                         const SizedBox(height: 2),
//                         Text(
//                           'ಕರ್ತೃ  : ' + current.sharanaNameKannada,
//                           style: const TextStyle(
//                             color: Colors.white,
//                             fontSize: 14,
//                           ),
//                           overflow: TextOverflow.ellipsis,
//                           maxLines: 1,
//                         ),
//                       ],
//                     ),
//                   ),

//                   // Duration and controls (30%)
//                   SizedBox(
//                     width: screenWidth * 0.3,
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.end,
//                       mainAxisSize: MainAxisSize.min,
//                       children: [
//                         // Position and duration
//                         StreamBuilder<Duration>(
//                           stream: audioHandler.positionStream,
//                           builder: (context, positionSnapshot) {
//                             final position =
//                                 positionSnapshot.data ?? Duration.zero;
//                             return StreamBuilder<Duration?>(
//                               stream: audioHandler.durationStream,
//                               builder: (context, durationSnapshot) {
//                                 final duration =
//                                     durationSnapshot.data ?? Duration.zero;
//                                 return Text(
//                                   '${_formatDuration(position)}/${_formatDuration(duration)}',
//                                   style: const TextStyle(
//                                     color: Colors.white70,
//                                     fontSize: 12,
//                                   ),
//                                   overflow: TextOverflow.ellipsis,
//                                   textAlign: TextAlign.center,
//                                 );
//                               },
//                             );
//                           },
//                         ),
//                         const SizedBox(height: 4),
//                         // Playback controls
//                         Row(
//                           mainAxisAlignment: MainAxisAlignment.end,
//                           mainAxisSize: MainAxisSize.min,
//                           children: [
//                             // Previous button
//                             GestureDetector(
//                               onTap: audioHandler.skipToPrevious,
//                               child: const Icon(
//                                 Icons.skip_previous,
//                                 size: 22,
//                                 color: Colors.white,
//                               ),
//                             ),
//                             const SizedBox(width: 6),

//                             // Play/Pause button
//                             StreamBuilder<bool>(
//                               stream: audioHandler.playingStream,
//                               builder: (context, snapshot) {
//                                 final isPlaying = snapshot.data ?? false;
//                                 return GestureDetector(
//                                   onTap: () {
//                                     if (isPlaying) {
//                                       audioHandler.pause();
//                                     } else {
//                                       audioHandler.play();
//                                     }
//                                   },
//                                   child: Icon(
//                                     isPlaying ? Icons.pause : Icons.play_arrow,
//                                     size: 24,
//                                     color: Colors.white,
//                                   ),
//                                 );
//                               },
//                             ),
//                             const SizedBox(width: 6),

//                             // Next button
//                             GestureDetector(
//                               onTap: audioHandler.skipToNext,
//                               child: const Icon(
//                                 Icons.skip_next,
//                                 size: 22,
//                                 color: Colors.white,
//                               ),
//                             ),
//                           ],
//                         ),
//                       ],
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           );
//   }
// }
