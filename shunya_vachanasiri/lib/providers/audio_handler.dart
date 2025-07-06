// /lib/providers/audio_handler.dart

import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shunya_vachanasiri/providers/app_state.dart' as constants;
import 'package:shunya_vachanasiri/models/vachana_model.dart';
import 'package:shunya_vachanasiri/services/auth_service.dart';
import 'package:rxdart/rxdart.dart';

const CustomMediaAction shuffleAction = CustomMediaAction(name: 'shuffle');
const CustomMediaAction repeatAction = CustomMediaAction(name: 'repeat');

class AudioPlayerHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  late final BehaviorSubject<MediaItem?> mediaItem;
  late final BehaviorSubject<List<MediaItem>> queue;
  late final BehaviorSubject<PlaybackState> playbackState;
  late final ValueNotifier<int> currentIndex;

  final AudioPlayer _player = AudioPlayer();
  final List<Vachana> _originalPlaylist = [];
  List<Vachana> _currentPlaylist = [];

  final currentVachanaNotifier = ValueNotifier<Vachana?>(null);

  final StreamController<bool> _playingController =
      StreamController.broadcast();

  // State notifiers
  final ValueNotifier<bool> isShuffledNotifier = ValueNotifier(false);
  final ValueNotifier<bool> isRepeatingNotifier = ValueNotifier(false);
  final ValueNotifier<bool> isPlayingNotifier = ValueNotifier(false);

  final ValueNotifier<Duration> positionNotifier = ValueNotifier(Duration.zero);
  final ValueNotifier<Duration> durationNotifier = ValueNotifier(Duration.zero);
  final ValueNotifier<ProcessingState> processingStateNotifier =
      ValueNotifier(ProcessingState.idle);

  // Stream subscriptions for proper cleanup
  late final StreamSubscription _playerStateSubscription;
  late final StreamSubscription _positionSubscription;
  late final StreamSubscription _durationSubscription;
  late final StreamSubscription _bufferedPositionSubscription;

  // Public accessors
  bool get isLoading =>
      processingStateNotifier.value == ProcessingState.loading;
  bool get isBuffering =>
      processingStateNotifier.value == ProcessingState.buffering;
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<bool> get playingStream => _player.playingStream;
  ValueListenable<Vachana?> get vachanaListenable => currentVachanaNotifier;

  // Safe position stream
  Stream<Duration> get safePositionStream => _player.positionStream
      .where((_) => _player.processingState == ProcessingState.ready);

  // Processing state check
  bool get isProcessingStateReady =>
      _player.processingState == ProcessingState.ready;

  bool isCurrentPlaylist(List<Vachana> playlist) {
    if (_currentPlaylist.length != playlist.length) return false;
    for (int i = 0; i < _currentPlaylist.length; i++) {
      if (_currentPlaylist[i].vachanaId != playlist[i].vachanaId) {
        return false;
      }
    }
    return true;
  }

  AudioPlayerHandler() {
    // Initialize all streams with default values
    mediaItem = BehaviorSubject<MediaItem?>.seeded(null);
    queue = BehaviorSubject<List<MediaItem>>.seeded([]);
    playbackState = BehaviorSubject<PlaybackState>.seeded(
      PlaybackState(
        controls: [MediaControl.play, MediaControl.stop],
        processingState: AudioProcessingState.idle,
        playing: false,
      ),
    );

    // Initialize currentIndex with a default value
    currentIndex = ValueNotifier<int>(-1);

    // Set up listeners AFTER initialization
    _setupListeners();
  }

  void _setupListeners() {
    // Listen to player state changes with proper subscription management
    _playerStateSubscription = _player.playerStateStream.listen((state) {
      try {
        // Update local notifiers
        isPlayingNotifier.value = state.playing;
        processingStateNotifier.value = state.processingState;

        // CRITICAL: Handle track completion for auto-next
        if (state.processingState == ProcessingState.completed) {
          _onTrackCompleted();
        }

        // Broadcast state changes
        _broadcastState();
      } catch (e) {
        debugPrint('Error in playerStateStream listener: $e');
      }
    });

    // Listen to position changes
    _positionSubscription = _player.positionStream.listen((position) {
      try {
        positionNotifier.value = position;
        _broadcastState();
      } catch (e) {
        debugPrint('Error in positionStream listener: $e');
      }
    });

    // Listen to duration changes
    _durationSubscription = _player.durationStream.listen((duration) {
      try {
        if (duration != null) {
          durationNotifier.value = duration;
          // Update current MediaItem with duration
          _updateCurrentMediaItemDuration(duration);
        }
      } catch (e) {
        debugPrint('Error in durationStream listener: $e');
      }
    });

    // Listen to buffered position changes
    _bufferedPositionSubscription =
        _player.bufferedPositionStream.listen((bufferedPosition) {
      try {
        _broadcastState();
      } catch (e) {
        debugPrint('Error in bufferedPositionStream listener: $e');
      }
    });
  }

  // NEW: Handle track completion for auto-next functionality
  void _onTrackCompleted() async {
    try {
      debugPrint('Track completed, processing auto-next...');

      if (_currentPlaylist.isEmpty) {
        debugPrint('No playlist available for auto-next');
        return;
      }

      // If repeat is enabled, replay current track
      if (isRepeatingNotifier.value) {
        debugPrint('Repeat enabled, replaying current track');
        await _player.seek(Duration.zero);
        await _player.play();
        return;
      }

      final nextIndex = (currentIndex.value + 1) % _currentPlaylist.length;
      debugPrint(
          'Current index: ${currentIndex.value}, Next index: $nextIndex');

      // If we've reached the end and not repeating playlist, stop
      if (nextIndex == 0 && !isRepeatingNotifier.value) {
        debugPrint('Reached end of playlist, stopping...');
        await stop();
        return;
      }

      // Otherwise, automatically play next track
      debugPrint('Auto-playing next track...');
      await skipToNext();
    } catch (e) {
      debugPrint('Error in _onTrackCompleted: $e');
    }
  }

  void _updateCurrentMediaItemDuration(Duration duration) {
    try {
      if (currentVachanaNotifier.value != null &&
          (!mediaItem.isClosed && mediaItem.hasValue)) {
        final currentItem = mediaItem.value;
        if (currentItem != null) {
          final updatedItem = currentItem.copyWith(duration: duration);
          mediaItem.add(updatedItem);
        }
      }
    } catch (e) {
      debugPrint('Error updating MediaItem duration: $e');
    }
  }

  void updateMetadataForCurrentTrack() {
    try {
      if (currentVachanaNotifier.value != null) {
        final item = _buildMediaItem(currentVachanaNotifier.value!);
        debugPrint('Setting MediaItem: ${item.title}');

        if (!mediaItem.isClosed) {
          mediaItem.add(item);
        }
      } else {
        debugPrint('Setting MediaItem to NULL');
        if (!mediaItem.isClosed) {
          mediaItem.add(null);
        }
      }
    } catch (e) {
      debugPrint('Error in updateMetadataForCurrentTrack: $e');
    }
  }

  MediaItem _buildMediaItem(Vachana vachana) {
    try {
      return MediaItem(
        id: vachana.vachanaId.toString(),
        album: vachana.sharanaNameKannada ?? 'Unknown',
        title: vachana.vachanaNameKannada ?? 'Unknown Title',
        artist: vachana.sharanaNameKannada ?? 'Unknown Artist',
        duration: _player.duration ?? Duration.zero,
        artUri: vachana.vachanaId != null
            ? Uri.parse(constants.AppConstants.getSharanaImageUrl(
                vachana.sharanaId,
                'mini',
              ))
            : null,
        displayTitle: vachana.vachanaNameKannada ?? 'Unknown Title',
        displaySubtitle: vachana.sharanaNameKannada ?? 'Unknown Artist',
        displayDescription: vachana.sharanaNameKannada ?? '',
        extras: {
          'sharanaId': vachana.sharanaId,
          'vachanaId': vachana.vachanaId,
          'audioUrl': constants.AppConstants.getVachanaAudioTrackUrl(
            vachana.sharanaId,
            vachana.vachanaNameEnglish,
          ),
        },
      );
    } catch (e) {
      debugPrint('Error creating MediaItem: $e');
      // Return a basic MediaItem as fallback
      return MediaItem(
        id: vachana.vachanaId?.toString() ?? '0',
        title: 'Unknown Title',
        artist: 'Unknown Artist',
      );
    }
  }

  void _updatePlaylistMetadata() {
    try {
      final items = _currentPlaylist.map((v) => _buildMediaItem(v)).toList();
      if (!queue.isClosed) {
        queue.add(items);
      }
      updateMetadataForCurrentTrack();
    } catch (e) {
      debugPrint('Error in _updatePlaylistMetadata: $e');
    }
  }

  void _updateControls() {
    try {
      if (!playbackState.isClosed && playbackState.hasValue) {
        playbackState.add(playbackState.value.copyWith(
          controls: _buildControls(),
          shuffleMode: isShuffledNotifier.value
              ? AudioServiceShuffleMode.all
              : AudioServiceShuffleMode.none,
          repeatMode: isRepeatingNotifier.value
              ? AudioServiceRepeatMode.one
              : AudioServiceRepeatMode.none,
        ));
      }
    } catch (e) {
      debugPrint('Error in _updateControls: $e');
    }
  }

  List<MediaControl> _buildControls() {
    try {
      final playerState = _player.playerState;
      final hasPlaylist = _currentPlaylist.isNotEmpty;
      final hasMultipleItems = _currentPlaylist.length > 1;
      final currentIdx = currentIndex.value;

      List<MediaControl> controls = [];

      // Add previous control if we have multiple items
      if (hasMultipleItems && currentIdx > 0) {
        controls.add(MediaControl.skipToPrevious);
      }

      // Add play/pause control based on current state
      if (playerState.playing) {
        controls.add(MediaControl.pause);
      } else {
        controls.add(MediaControl.play);
      }

      // Add next control if we have multiple items
      if (hasMultipleItems && currentIdx < _currentPlaylist.length - 1) {
        controls.add(MediaControl.skipToNext);
      }

      // Add stop control if we have content
      if (hasPlaylist) {
        controls.add(MediaControl.stop);
      }

      return controls;
    } catch (e) {
      debugPrint('Error in _buildControls: $e');
      return [MediaControl.play, MediaControl.stop];
    }
  }

  void _broadcastState() {
    try {
      final playerState = _player.playerState;
      final position = _player.position;
      final duration = _player.duration;
      final bufferedPosition = _player.bufferedPosition;
      final currentIdx = currentIndex.value;

      // Convert ProcessingState to AudioProcessingState
      AudioProcessingState audioProcessingState;
      switch (playerState.processingState) {
        case ProcessingState.idle:
          audioProcessingState = AudioProcessingState.idle;
          break;
        case ProcessingState.loading:
          audioProcessingState = AudioProcessingState.loading;
          break;
        case ProcessingState.buffering:
          audioProcessingState = AudioProcessingState.buffering;
          break;
        case ProcessingState.ready:
          audioProcessingState = AudioProcessingState.ready;
          break;
        case ProcessingState.completed:
          audioProcessingState = AudioProcessingState.completed;
          break;
      }

      final newPlaybackState = PlaybackState(
        controls: _buildControls(),
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
          MediaAction.skipToNext,
          MediaAction.skipToPrevious,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: audioProcessingState,
        playing: playerState.playing,
        updatePosition: position,
        bufferedPosition: bufferedPosition,
        speed: _player.speed,
        queueIndex: currentIdx >= 0 && currentIdx < _currentPlaylist.length
            ? currentIdx
            : null,
        shuffleMode: isShuffledNotifier.value
            ? AudioServiceShuffleMode.all
            : AudioServiceShuffleMode.none,
        repeatMode: isRepeatingNotifier.value
            ? AudioServiceRepeatMode.one
            : AudioServiceRepeatMode.none,
      );

      if (!playbackState.isClosed) {
        playbackState.add(newPlaybackState);
      }
    } catch (e) {
      debugPrint('Error in _broadcastState: $e');
      // Broadcast a safe fallback state
      if (!playbackState.isClosed) {
        playbackState.add(PlaybackState(
          controls: [MediaControl.play, MediaControl.stop],
          processingState: AudioProcessingState.idle,
          playing: false,
        ));
      }
    }
  }

  // ===== Playlist Management =====
  void setPlaylist(List<Vachana> playlist) {
    try {
      _originalPlaylist
        ..clear()
        ..addAll(playlist);
      _currentPlaylist
        ..clear()
        ..addAll(playlist);

      _updatePlaylistMetadata();
      currentIndex.value = -1;
    } catch (e) {
      debugPrint('Error in setPlaylist: $e');
    }
  }

  Future<void> setPlaylistAndPlay(
      List<Vachana> playlist, int startIndex) async {
    try {
      setPlaylist(playlist);
      if (startIndex >= 0 && startIndex < playlist.length) {
        currentIndex.value = startIndex;
        await playVachana(_currentPlaylist[startIndex]);
      }
    } catch (e) {
      debugPrint('Error in setPlaylistAndPlay: $e');
    }
  }

  // NEW: Enhanced skipToQueueItem implementation
  @override
  Future<void> skipToQueueItem(int index) async {
    try {
      if (index < 0 || index >= _currentPlaylist.length) {
        debugPrint('Invalid queue index: $index');
        return;
      }

      debugPrint('Skipping to queue item at index: $index');

      currentIndex.value = index;
      updateCurrentVachana(_currentPlaylist[index]);

      // Update the queue index in playback state
      _broadcastState();

      await playVachana(_currentPlaylist[index]);
    } catch (e) {
      debugPrint('Error in skipToQueueItem: $e');
    }
  }

  List<MediaItem> _buildQueueItems() {
    try {
      return _currentPlaylist.map((vachana) {
        return MediaItem(
          id: vachana.vachanaId.toString(),
          title: vachana.vachanaNameKannada ?? 'Unknown Title',
          artist: vachana.sharanaNameKannada ?? 'Unknown Artist',
          artUri: Uri.parse(constants.AppConstants.getSharanaImageUrl(
            vachana.sharanaId,
            'mini',
          )),
          extras: {
            'sharanaId': vachana.sharanaId,
            'vachanaId': vachana.vachanaId,
          },
        );
      }).toList();
    } catch (e) {
      debugPrint('Error in _buildQueueItems: $e');
      return [];
    }
  }

  void updateCurrentVachana(Vachana vachana) {
    try {
      currentVachanaNotifier.value = vachana;
      updateMetadataForCurrentTrack();
    } catch (e) {
      debugPrint('Error in updateCurrentVachana: $e');
    }
  }

  // ===== Playback Controls =====
  @override
  Future<void> play() async {
    try {
      if (currentIndex.value == -1 && _currentPlaylist.isNotEmpty) {
        currentIndex.value = 0;
        updateCurrentVachana(_currentPlaylist[0]);
      }

      if (currentVachanaNotifier.value != null) {
        await playVachana(currentVachanaNotifier.value!);
      } else {
        await _player.play();
      }

      if (!_playingController.isClosed) {
        _playingController.add(true);
      }
      isPlayingNotifier.value = true;
    } catch (e) {
      debugPrint('Error in play: $e');
    }
  }

  @override
  Future<void> pause() async {
    try {
      await _player.pause();
      if (!_playingController.isClosed) {
        _playingController.add(false);
      }
      isPlayingNotifier.value = false;
    } catch (e) {
      debugPrint('Error in pause: $e');
    }
  }

  @override
  Future<void> seek(Duration position) async {
    try {
      if (_player.processingState == ProcessingState.ready) {
        await _player.seek(position);
      }
    } catch (e) {
      debugPrint('Error in seek: $e');
    }
  }

  @override
  Future<void> skipToNext() async {
    try {
      if (_currentPlaylist.isEmpty) {
        debugPrint('No playlist available for skip to next');
        return;
      }

      final nextIndex = (currentIndex.value + 1) % _currentPlaylist.length;
      debugPrint('Skipping to next: current=$currentIndex, next=$nextIndex');

      if (nextIndex == 0 && !isRepeatingNotifier.value) {
        debugPrint('Reached end of playlist, stopping...');
        await stop();
        return;
      }

      currentIndex.value = nextIndex;
      updateCurrentVachana(_currentPlaylist[nextIndex]);

      // Update queue index before playing
      await skipToQueueItem(nextIndex);
    } catch (e) {
      debugPrint('Error in skipToNext: $e');
    }
  }

  @override
  Future<void> skipToPrevious() async {
    try {
      if (_currentPlaylist.isEmpty) {
        debugPrint('No playlist available for skip to previous');
        return;
      }

      int prevIndex = currentIndex.value - 1;
      if (prevIndex < 0) {
        prevIndex = isRepeatingNotifier.value ? _currentPlaylist.length - 1 : 0;
      }

      debugPrint(
          'Skipping to previous: current=${currentIndex.value}, previous=$prevIndex');

      currentIndex.value = prevIndex;
      updateCurrentVachana(_currentPlaylist[prevIndex]);

      // Update queue index before playing
      await skipToQueueItem(prevIndex);
    } catch (e) {
      debugPrint('Error in skipToPrevious: $e');
    }
  }

  void dispose() {
    try {
      // Cancel all subscriptions
      _playerStateSubscription.cancel();
      _positionSubscription.cancel();
      _durationSubscription.cancel();
      _bufferedPositionSubscription.cancel();

      // Dispose ValueNotifiers
      currentVachanaNotifier.dispose();
      currentIndex.dispose();
      positionNotifier.dispose();
      durationNotifier.dispose();
      isShuffledNotifier.dispose();
      isRepeatingNotifier.dispose();
      isPlayingNotifier.dispose();
      processingStateNotifier.dispose();

      // Close streams
      _playingController.close();

      // Close BehaviorSubjects
      if (!mediaItem.isClosed) mediaItem.close();
      if (!queue.isClosed) queue.close();
      if (!playbackState.isClosed) playbackState.close();

      // Dispose player
      _player.dispose();
    } catch (e) {
      debugPrint('Error in dispose: $e');
    }
  }

  // ===== Custom Actions =====
  @override
  Future<void> customAction(String name, [Map<String, dynamic>? extras]) async {
    try {
      switch (name) {
        case 'shuffle':
          toggleShuffle();
          break;
        case 'repeat':
          toggleRepeat();
          break;
      }
      _updateControls();
    } catch (e) {
      debugPrint('Error in customAction: $e');
    }
  }

  void toggleShuffle() {
    try {
      isShuffledNotifier.value = !isShuffledNotifier.value;

      if (isShuffledNotifier.value) {
        final current = currentVachanaNotifier.value;
        _currentPlaylist = List.from(_originalPlaylist)..shuffle();

        if (current != null) {
          _currentPlaylist.remove(current);
          _currentPlaylist.insert(0, current);
          currentIndex.value = 0;
        }
      } else {
        final current = currentVachanaNotifier.value;
        _currentPlaylist = List.from(_originalPlaylist);

        if (current != null) {
          currentIndex.value = _currentPlaylist
              .indexWhere((v) => v.vachanaId == current.vachanaId);
        }
      }
      _updatePlaylistMetadata();
    } catch (e) {
      debugPrint('Error in toggleShuffle: $e');
    }
  }

  void toggleRepeat() {
    try {
      isRepeatingNotifier.value = !isRepeatingNotifier.value;
      _player
          .setLoopMode(isRepeatingNotifier.value ? LoopMode.one : LoopMode.off);
      _updateControls();
    } catch (e) {
      debugPrint('Error in toggleRepeat: $e');
    }
  }

  // ===== Core Playback =====
  Future<void> playVachana(Vachana vachana) async {
    try {
      debugPrint('Playing vachana: ${vachana.vachanaNameEnglish}');

      // 1. Update current vachana
      updateCurrentVachana(vachana);

      // 2. Create MediaItem
      final mediaItem = _buildMediaItem(vachana);

      // 3. Update mediaItem stream IMMEDIATELY
      if (!this.mediaItem.isClosed) {
        this.mediaItem.add(mediaItem);
      }

      await AuthService.ensureAuthenticated();
      final baseUrl = constants.AppConstants.getVachanaAudioTrackUrl(
        vachana.sharanaId,
        vachana.vachanaNameEnglish,
      );

      if (baseUrl.isEmpty) {
        throw 'Invalid audio URL for vachana ${vachana.vachanaId}';
      }

      final idToken = await AuthService.getIdToken();
      final audioUrl = idToken != null ? '$baseUrl&token=$idToken' : baseUrl;

      // 4. Playlist management
      if (_currentPlaylist.isEmpty ||
          !_currentPlaylist.any((v) => v.vachanaId == vachana.vachanaId)) {
        setPlaylist([vachana]);
        currentIndex.value = 0;
      } else {
        currentIndex.value = _currentPlaylist
            .indexWhere((v) => v.vachanaId == vachana.vachanaId);
      }

      await _player.stop();

      // 5. Build queue BEFORE setting source
      final queueItems = _buildQueueItems();
      if (!this.queue.isClosed) {
        this.queue.add(queueItems);
      }

      // 6. Set audio source
      await _player.setAudioSource(AudioSource.uri(Uri.parse(audioUrl)));
      await _player.load();
      await _player.play();

      debugPrint('Successfully started playing: ${vachana.vachanaNameEnglish}');
    } catch (e) {
      debugPrint('Error playing vachana: $e');

      // Reset state on error
      if (!mediaItem.isClosed) {
        mediaItem.add(null);
      }

      // Broadcast error state
      _broadcastState();
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _player.stop();
      currentIndex.value = -1;
      currentVachanaNotifier.value = null;

      // Safe mediaItem update
      if (!mediaItem.isClosed) {
        mediaItem.add(null);
      }

      // Clear queue
      if (!queue.isClosed) {
        queue.add([]);
      }

      _broadcastState();
      return super.stop();
    } catch (e) {
      debugPrint('Error in stop: $e');
      return super.stop();
    }
  }

  @override
  Future<void> onTaskRemoved() async {
    try {
      // DON'T stop playback when task is removed - allow background play
      debugPrint('Task removed - maintaining background playback');
      await super.onTaskRemoved();
    } catch (e) {
      debugPrint('Error in onTaskRemoved: $e');
      await super.onTaskRemoved();
    }
  }

  @override
  Future<void> onNotificationDeleted() async {
    try {
      await stop();
      await super.onNotificationDeleted();
    } catch (e) {
      debugPrint('Error in onNotificationDeleted: $e');
      await super.onNotificationDeleted();
    }
  }
}

