// /lib/widgets/vachana_card.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shunya_vachanasiri/providers/app_state.dart';
import 'package:shunya_vachanasiri/models/vachana_model.dart';
import 'package:shunya_vachanasiri/providers/audio_handler.dart';
import 'package:shunya_vachanasiri/widgets/lyrics_overlay.dart';
import 'package:shunya_vachanasiri/providers/audio_service_manager.dart';

class VachanaCard extends StatelessWidget {
  final Vachana vachana;
  final bool showArtist;
  final VoidCallback onCardTapped;

  const VachanaCard({
    super.key,
    required this.vachana,
    required this.showArtist,
    required this.onCardTapped,
  });

  void _showMenu(BuildContext context) {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;

    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero),
        button.localToGlobal(button.size.bottomRight(Offset.zero)),
      ),
      Offset.zero & overlay.size,
    );

    showMenu(
      context: context,
      position: position,
      color: Colors.black,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey[700]!),
      ),
      items: [
        PopupMenuItem(
          value: 'lyrics',
          child: ListTile(
            leading: Icon(Icons.lyrics, color: Colors.white),
            title: Text('Show Lyrics', style: TextStyle(color: Colors.white)),
          ),
        ),
        PopupMenuItem(
          value: 'share',
          child: ListTile(
            leading: Icon(Icons.share, color: Colors.white),
            title: Text('Share', style: TextStyle(color: Colors.white)),
          ),
        ),
        PopupMenuItem(
          value: 'download',
          child: ListTile(
            leading: Icon(Icons.download, color: Colors.white),
            title: Text('Download', style: TextStyle(color: Colors.white)),
          ),
        ),
      ],
    ).then((value) {
      if (value != null) {
        _handleActionSelection(context, value);
      }
    });
  }

  void _showLyricsOverlay(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => LyricsOverlay(vachana: vachana),
    );
  }

  void _handleActionSelection(BuildContext context, String value) {
    switch (value) {
      case 'lyrics':
        _showLyricsOverlay(context);
        break;
      case 'share':
        // Share functionality
        break;
      case 'download':
        // Download functionality
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final audioHandler =
        Provider.of<AudioPlayerHandler>(context, listen: false);

    return Card(
      color: Colors.grey[900],
      margin: const EdgeInsets.only(top: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        title: Text(
          vachana.vachanaNameKannada ?? 'ವಚನದ ಹೆಸರು',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              vachana.vachanaNameEnglish ?? 'Vachana Title',
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (showArtist) ...[
              const SizedBox(height: 4),
              Text(
                vachana.sharanaNameKannada,
                style: TextStyle(
                  color: Colors.blue[300],
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
        trailing: Consumer<AppState>(
          builder: (context, appState, child) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.play_arrow, color: Colors.white),
                  onPressed: () {
                    final audioHandler = AudioServiceManager.handler;
                    final currentPlaylist = [vachana];

                    if (!audioHandler.isCurrentPlaylist(currentPlaylist)) {
                      audioHandler.setPlaylist(currentPlaylist);
                    }

                    audioHandler.playVachana(vachana);
                  },
                ),
                if (appState.isLoggedIn)
                  IconButton(
                    icon: Icon(
                      appState.favorites.contains(vachana.vachanaId)
                          ? Icons.favorite
                          : Icons.favorite_border,
                      color: appState.favorites.contains(vachana.vachanaId)
                          ? Colors.red
                          : Colors.white,
                    ),
                    onPressed: () {},
                    //=> appState.toggleFavorite(current.vachanaId),
                  ),
                IconButton(
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  onPressed: () => _showMenu(context),
                ),
              ],
            );
          },
        ),
        onTap: onCardTapped,
      ),
    );
  }
}
