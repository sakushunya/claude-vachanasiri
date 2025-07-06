// /lib/providers/audio_service_manager.dart
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shunya_vachanasiri/providers/audio_handler.dart';
import 'package:shunya_vachanasiri/models/vachana_model.dart';

class AudioServiceManager {
  static AudioPlayerHandler? _handler;

  static void setHandler(AudioPlayerHandler handler) {
    _handler = handler;
  }

  static AudioPlayerHandler get handler {
    assert(_handler != null, 'AudioHandler not initialized!');
    return _handler!;
  }

  static Future<void> playVachana(Vachana vachana) async {
    await handler.playVachana(vachana);
  }

  static Future<void> play() async => handler.play();
  static Future<void> pause() async => handler.pause();
  static Future<void> stop() async => handler.stop();
  static Future<void> seek(Duration position) async => handler.seek(position);

  // Media streams
  static Stream<PlaybackState> get playbackStateStream =>
      AudioService.playbackStateStream;

  static Stream<MediaItem?> get mediaItemStream =>
      AudioService.currentMediaItemStream;

  // State notifiers
  static ValueListenable<int> get currentIndexNotifier => handler.currentIndex;
  static ValueListenable<bool> get isShuffledNotifier =>
      handler.isShuffledNotifier;
  static ValueListenable<bool> get isRepeatingNotifier =>
      handler.isRepeatingNotifier;
  static ValueListenable<Duration> get positionNotifier =>
      handler.positionNotifier;
  static ValueListenable<Duration> get durationNotifier =>
      handler.durationNotifier;
  static ValueListenable<bool> get isPlayingNotifier =>
      handler.isPlayingNotifier;
  static ValueListenable<ProcessingState> get processingStateNotifier =>
      handler.processingStateNotifier;

  // Add this for playing state
  static bool get isPlaying => handler.isPlayingNotifier.value;

  // New refresh method (if needed elsewhere)
  static void refreshMetadata() {
    handler.updateMetadataForCurrentTrack();
  }
}
