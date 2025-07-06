import 'package:flutter/material.dart';
import 'package:shunya_vachanasiri/models/vachana_model.dart';

class LyricsOverlay extends StatelessWidget {
  final Vachana vachana;

  const LyricsOverlay({super.key, required this.vachana});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 50),
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Stack(
        children: [
          // Background image with dark overlay
          Positioned.fill(
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              child: ColorFiltered(
                colorFilter: ColorFilter.mode(
                  Colors.black.withOpacity(0.3),
                  BlendMode.darken,
                ),
                child: Image.asset(
                  'assets/svs-lyrics-bg2.jpg', // Update with your actual path
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),

          // Content container
          Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 16,
              right: 16,
              top: 16,
            ),
            child: Stack(
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 40),
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300]!.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Text(
                    //   vachana.vachanaNameKannada ?? 'ವಚನದ ಹೆಸರು',
                    //   textAlign: TextAlign.left,
                    //   style: const TextStyle(
                    //     color: Colors.white,
                    //     fontSize: 20,
                    //     fontWeight: FontWeight.bold,
                    //     shadows: [
                    //       Shadow(
                    //         blurRadius: 6,
                    //         color: Colors.black,
                    //       )
                    //     ],
                    //   ),
                    // ),
                    // const SizedBox(height: 8),
                    // Divider(
                    //     color: const Color.fromARGB(255, 12, 37, 49)!
                    //         .withOpacity(0.5)),
                    // const SizedBox(height: 16),

                    // Scrollable lyrics section
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Kannada Lyrics
                            Text(
                              vachana.vachanaNameKannada ?? 'ವಚನದ ಹೆಸರು',
                              textAlign: TextAlign.left,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                shadows: [
                                  Shadow(
                                    blurRadius: 6,
                                    color: Colors.black,
                                  )
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Divider(
                                color: const Color.fromARGB(255, 12, 37, 49)!
                                    .withOpacity(0.5)),
                            const SizedBox(height: 16),
                            Text(
                              vachana.vachanaLyricsKannada ??
                                  'ವಚನದ ಸಾಹಿತ್ಯ ಲಭ್ಯವಿಲ್ಲ',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 16,
                                height: 1.5,
                                shadows: [
                                  Shadow(
                                    blurRadius: 4,
                                    color: Colors.black,
                                  )
                                ],
                              ),
                            ),

                            const SizedBox(height: 24),

                            // English Lyrics
                            Text(
                              vachana.vachanaNameEnglish ?? 'English Lyrics',
                              textAlign: TextAlign.left,
                              style: TextStyle(
                                color: Colors.grey[100],
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                shadows: [
                                  const Shadow(
                                    blurRadius: 6,
                                    color: Colors.black,
                                  )
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Divider(
                                color: const Color.fromARGB(255, 12, 37, 49)!
                                    .withOpacity(0.5)),

                            Text(
                              vachana.vachanaLyricsEnglish ??
                                  'English lyrics not available',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 16,
                                height: 1.5,
                                shadows: [
                                  Shadow(
                                    blurRadius: 4,
                                    color: Colors.black,
                                  )
                                ],
                              ),
                            ),
                            const SizedBox(height: 30),

                            Center(
                              child: Container(
                                width: 40,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: Colors.grey[300]!.withOpacity(0.7),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                // Close button
                Positioned(
                  top: 0,
                  right: 0,
                  child: IconButton(
                    icon: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withOpacity(0.5),
                      ),
                      padding: const EdgeInsets.all(6),
                      child: const Icon(Icons.close,
                          color: Colors.white, size: 24),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
