// /lib/utils/main_layout.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shunya_vachanasiri/providers/audio_handler.dart';
import 'package:shunya_vachanasiri/widgets/mini_player.dart';

class MainLayout extends StatelessWidget {
  final Widget child;

  const MainLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final audioHandler = Provider.of<AudioPlayerHandler>(context);

    return Stack(
      children: [
        // Main content
        child,

        // Global mini player positioned above bottom navigation
        if (audioHandler.currentVachanaNotifier.value != null)
          Positioned(
            bottom: kBottomNavigationBarHeight - 60,
            left: 8,
            right: 8,
            child: MiniPlayer(
                key: ValueKey(
                    audioHandler.currentVachanaNotifier.value?.vachanaId)),
          ),
      ],
    );
  }
}

// as of 2025 07 01 10.00 PM
//   @override
//   Widget build(BuildContext context) {
//     final audioService = Provider.of<AudioPlayerHandler>(context);

//     return Stack(
//       children: [
//         // Main content
//         child,

// // Global mini player positioned above bottom navigation
//         if (audioService.currentVachana != null)
//           Positioned(
//             bottom: kBottomNavigationBarHeight - 60,
//             left: 8, // Changed from -15 to 0 for better alignment
//             right: 8, // Changed from -15 to 0 for better alignment
//             child: const MiniPlayer(),
//           )
//         // Working perfectly
//         // Global mini player positioned above bottom navigation
//         // if (audioService.currentVachana != null)
//         //   Positioned(
//         //     bottom: kBottomNavigationBarHeight - 60,
//         //     left: -15,
//         //     right: -15,
//         //     child: const MiniPlayer(),
//         //   ),
//       ],
//     );
//   }
// }
