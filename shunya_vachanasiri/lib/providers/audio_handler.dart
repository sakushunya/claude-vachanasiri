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



/**
// begin as of 2025 07 06, from deepseek and few bits from Claude Sonnet 4 as demarcated at the top of the methods
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

class AudioPlayerHandler extends BaseAudioHandler {
  late final BehaviorSubject<MediaItem?> mediaItem;
  late final BehaviorSubject<List<MediaItem>> queue;
  late final BehaviorSubject<PlaybackState> playbackState;
  late final ValueNotifier<int> currentIndex;

  final AudioPlayer _player = AudioPlayer();
  final List<Vachana> _originalPlaylist = [];
  List<Vachana> _currentPlaylist = [];

  // final ValueNotifier<Vachana?> currentVachanaNotifier = ValueNotifier(null);
  final currentVachanaNotifier = ValueNotifier<Vachana?>(null);

  // final playbackStateNotifier = BehaviorSubject<PlaybackState>();
  // final BehaviorSubject<PlaybackState> playbackState =
  //     BehaviorSubject<PlaybackState>();

  final StreamController<bool> _playingController =
      StreamController.broadcast();

  // State notifiers
  // final ValueNotifier<int> currentIndex = ValueNotifier<int>(-1);
  final ValueNotifier<bool> isShuffledNotifier = ValueNotifier(false);
  final ValueNotifier<bool> isRepeatingNotifier = ValueNotifier(false);
  final ValueNotifier<bool> isPlayingNotifier = ValueNotifier(false);

  final ValueNotifier<Duration> positionNotifier = ValueNotifier(Duration.zero);
  final ValueNotifier<Duration> durationNotifier = ValueNotifier(Duration.zero);
  final ValueNotifier<ProcessingState> processingStateNotifier =
      ValueNotifier(ProcessingState.idle);

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

  // Vachana? get currentVachana =>
  //     (currentIndex.value >= 0 && currentIndex.value < _currentPlaylist.length)
  //         ? _currentPlaylist[currentIndex.value]
  //         : null;

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

  // Claude Sonnet 4
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

  // Claude Sonnet 4
  void _setupListeners() {
    // Listen to player state changes
    _player.playerStateStream.listen((state) {
      _broadcastState();
    });

    // Listen to position changes
    _player.positionStream.listen((position) {
      _broadcastState();
    });

    // Listen to duration changes
    _player.durationStream.listen((duration) {
      _broadcastState();
    });

    // Listen to player events
    _player.playerStateStream.listen((state) {
      _broadcastState();
    });
  }

  //Deepseek
  // AudioPlayerHandler() {
  //   _player.playbackEventStream.listen(_broadcastState);

  //   _player.processingStateStream.listen((state) {
  //     processingStateNotifier.value = state;
  //   });

  //   // Handle playback completion (keep your existing logic)
  //   _player.playerStateStream.listen((state) {
  //     if (state.processingState == ProcessingState.completed) {
  //       if (isRepeatingNotifier.value) {
  //         _player.seek(Duration.zero);
  //         _player.play();
  //       } else {
  //         skipToNext();
  //       }
  //     }
  //   });

  //   // playbackState.add(PlaybackState(
  //   //   controls: [MediaControl.pause, MediaControl.stop],
  //   //   systemActions: const {
  //   //     MediaAction.stop,
  //   //     MediaAction.seek,
  //   //     MediaAction.skipToNext,
  //   //     MediaAction.skipToPrevious,
  //   //     MediaAction.custom,
  //   //   },
  //   //   processingState: AudioProcessingState.idle,
  //   // ));

  //   // Position updates
  //   _player.positionStream.listen((position) {
  //     positionNotifier.value = position;
  //   });

  //   // Duration updates
  //   _player.durationStream.listen((duration) {
  //     durationNotifier.value = duration ?? Duration.zero;
  //   });

  //   // // Update controls when states change
  //   // isShuffledNotifier.addListener(_updateControls);
  //   // isRepeatingNotifier.addListener(_updateControls);

  //   // // Listen to track changes and update metadata
  //   // currentIndex.addListener(updateMetadataForCurrentTrack);

  //   mediaItem.listen((item) => print('MediaItem Updated: ${item?.title}'));
  // }

  // ========== METADATA SYNC SOLUTION ==========
  // void updateMetadataForCurrentTrack() {
  //   if (currentVachana != null) {
  //     mediaItem.add(_buildMediaItem(currentVachana!));
  //   } else {
  //     mediaItem.add(null);
  //   }
  // }

  void updateMetadataForCurrentTrack() {
    if (currentVachanaNotifier.value != null) {
      final item = _buildMediaItem(currentVachanaNotifier.value!);
      // print('Setting MediaItem: ${item.title}');
      // print('ID: ${item.id}');
      // print('Artist: ${item.artist}');
      // print('ArtURI: ${item.artUri}');

      this.mediaItem.add(item);
      print(mediaItem);
    } else {
      print('Setting MediaItem to NULL');
      mediaItem.add(null);
    }
  }

  // Claude Sonnet 4
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
        displayTitle: vachana.vachanaNameEnglish ?? 'Unknown Title',
        displaySubtitle: vachana.sharanaNameEnglish ?? 'Unknown Artist',
        displayDescription: vachana.vachanaLyricsKannada ?? '',
      );
    } catch (e) {
      debugPrint('Error creating MediaItem: $e');
      // Return a basic MediaItem as fallback
      return MediaItem(
        id: vachana.vachanaId.toString(),
        title: 'Unknown Title',
        artist: 'Unknown Artist',
      );
    }
  }

  //Deepseek
  // MediaItem _buildMediaItem(Vachana vachana) {
  //   return MediaItem(
  //     id: '${vachana.sharanaId}_${vachana.vachanaId}', // Unique combo
  //     title: vachana.vachanaNameKannada,
  //     artist: vachana.sharanaNameKannada,
  //     artUri: Uri.parse(constants.AppConstants.getSharanaImageUrl(
  //       vachana.sharanaId,
  //       'mini',
  //     )),
  //     duration: _player.duration ?? Duration.zero,
  //     extras: {
  //       'vachana': vachana,
  //       'sharanaId': vachana.sharanaId,
  //       'vachanaId': vachana.vachanaId,
  //       'lastUpdated': DateTime.now().millisecondsSinceEpoch,
  //     },
  //   );
  // }

  void _updatePlaylistMetadata() {
    final items = _currentPlaylist.map((v) => _buildMediaItem(v)).toList();
    queue.add(items);
    updateMetadataForCurrentTrack(); // Ensure current track is updated
  }

  // ========== END METADATA SYNC SOLUTION ==========

  void _updateControls() {
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

  // Deepseek
  // List<MediaControl> _buildControls() {
  //   return [
  //     MediaControl.skipToPrevious,
  //     playbackState.value.playing ? MediaControl.pause : MediaControl.play,
  //     MediaControl.skipToNext,
  //     MediaControl(
  //       androidIcon: 'shuffle',
  //       label: isShuffledNotifier.value ? 'Shuffle On' : 'Shuffle Off',
  //       action: MediaAction.custom,
  //       customAction: shuffleAction,
  //     ),
  //     MediaControl(
  //       androidIcon: 'repeat',
  //       label: isRepeatingNotifier.value ? 'Repeat On' : 'Repeat Off',
  //       action: MediaAction.custom,
  //       customAction: repeatAction,
  //     ),
  //   ];
  // }

  //Deepseek
  // void _broadcastState(PlaybackEvent event) {
  //   playbackState.add(PlaybackState(
  //     controls: _buildControls(),
  //     systemActions: const {
  //       MediaAction.stop,
  //       MediaAction.seek,
  //       MediaAction.skipToNext,
  //       MediaAction.skipToPrevious,
  //       MediaAction.custom,
  //     },
  //     androidCompactActionIndices: const [0, 1, 2],
  //     processingState: const {
  //       ProcessingState.idle: AudioProcessingState.idle,
  //       ProcessingState.loading: AudioProcessingState.loading,
  //       ProcessingState.buffering: AudioProcessingState.buffering,
  //       ProcessingState.ready: AudioProcessingState.ready,
  //       ProcessingState.completed: AudioProcessingState.completed,
  //     }[_player.processingState]!,
  //     playing: _player.playing,
  //     updatePosition: _player.position,
  //     bufferedPosition: _player.bufferedPosition,
  //     speed: _player.speed,
  //     queueIndex: currentIndex.value,
  //   ));
  // }

  // Claude Sonnet 4
  List<MediaControl> _buildControls() {
    try {
      // Get the current player state directly (not from stream)
      final playerState = _player.playerState;
      final processingState = playerState.processingState;
      final playing = playerState.playing;

      List<MediaControl> controls = [];

      // Add previous control if we have multiple items
      if (_currentPlaylist.length > 1) {
        controls.add(MediaControl.skipToPrevious);
      }

      // Add play/pause control based on current state
      if (playing) {
        controls.add(MediaControl.pause);
      } else {
        controls.add(MediaControl.play);
      }

      // Add next control if we have multiple items
      if (_currentPlaylist.length > 1) {
        controls.add(MediaControl.skipToNext);
      }

      // Add stop control
      controls.add(MediaControl.stop);

      return controls;
    } catch (e) {
      debugPrint('Error in _buildControls: $e');
      // Return basic controls as fallback
      return [MediaControl.play, MediaControl.stop];
    }
  }

  void _broadcastState() {
    try {
      final playerState = _player.playerState;
      final position = _player.position;
      final duration = _player.duration;

      // Convert just_audio ProcessingState to audio_service AudioProcessingState
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

      playbackState.add(PlaybackState(
        controls: _buildControls(),
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: audioProcessingState,
        playing: playerState.playing,
        updatePosition: position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: currentIndex.value >= 0 ? currentIndex.value : null,
      ));
    } catch (e) {
      debugPrint('Error in _broadcastState: $e');
      // Broadcast a basic state as fallback
      playbackState.add(PlaybackState(
        controls: [MediaControl.play, MediaControl.stop],
        processingState: AudioProcessingState.idle,
        playing: false,
      ));
    }
  }

  // ===== Playlist Management =====
  void setPlaylist(List<Vachana> playlist) {
    _originalPlaylist
      ..clear()
      ..addAll(playlist);
    _currentPlaylist
      ..clear()
      ..addAll(playlist);

    _updatePlaylistMetadata(); // Use new method

    currentIndex.value = -1;
  }

  Future<void> setPlaylistAndPlay(
      List<Vachana> playlist, int startIndex) async {
    setPlaylist(playlist);
    currentIndex.value = startIndex;
    await playVachana(
        _currentPlaylist[startIndex]); // Directly play specific track
  }

  List<MediaItem> _buildQueueItems() {
    return _currentPlaylist.map((vachana) {
      return MediaItem(
        id: vachana.vachanaId.toString(),
        title: vachana.vachanaNameKannada,
        artist: vachana.sharanaNameKannada,
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
  }

  void updateCurrentVachana(Vachana vachana) {
    currentVachanaNotifier.value = vachana;
  }

  // ===== Playback Controls =====
  @override
  Future<void> play() async {
    if (currentIndex.value == -1 && _currentPlaylist.isNotEmpty) {
      currentIndex.value = 0;
    }
    if (currentVachanaNotifier.value != null) {
      await playVachana(currentVachanaNotifier.value!);
    }
    _playingController.add(true);
    isPlayingNotifier.value = true;
  }

  @override
  Future<void> pause() async {
    _player.pause();
    _playingController.add(false);
  }

  @override
  Future<void> seek(Duration position) async {
    if (_player.processingState == ProcessingState.ready) {
      await _player.seek(position);
    }
  }

  @override
  Future<void> skipToNext() async {
    if (_currentPlaylist.isEmpty) return;

    final nextIndex = (currentIndex.value + 1) % _currentPlaylist.length;
    updateCurrentVachana(_currentPlaylist[nextIndex]);

    if (nextIndex == 0 && !isRepeatingNotifier.value) {
      await stop();
      return;
    }

    currentIndex.value = nextIndex;
    await play();
  }

  @override
  Future<void> skipToPrevious() async {
    if (_currentPlaylist.isEmpty) return;

    int prevIndex = currentIndex.value - 1;
    if (prevIndex < 0) {
      prevIndex = isRepeatingNotifier.value ? _currentPlaylist.length - 1 : 0;
    }

    currentIndex.value = prevIndex;
    updateCurrentVachana(_currentPlaylist[prevIndex]);

    await play();
  }

  void dispose() {
    currentVachanaNotifier.dispose();
    // Remove: _playingController.close() (since we're keeping original stream)
    // Add disposal for other notifiers:
    currentIndex.dispose();
    positionNotifier.dispose();
    durationNotifier.dispose();
    isShuffledNotifier.dispose();
    isRepeatingNotifier.dispose();
    processingStateNotifier.dispose();

    // Dispose player resources:
    _player.dispose();

    // No super.dispose() needed!
  }

  // ===== Custom Actions =====
  @override
  Future<void> customAction(String name, [Map<String, dynamic>? extras]) async {
    switch (name) {
      case 'shuffle':
        toggleShuffle();
        break;
      case 'repeat':
        toggleRepeat();
        break;
    }
    _updateControls();
  }

  void toggleShuffle() {
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
    _updatePlaylistMetadata(); // Use new method
  }

  void toggleRepeat() {
    isRepeatingNotifier.value = !isRepeatingNotifier.value;
    _player
        .setLoopMode(isRepeatingNotifier.value ? LoopMode.one : LoopMode.off);
  }

  // ===== Core Playback =====
  Future<void> playVachana(Vachana vachana) async {
    try {
      // 1. Update current vachana
      updateCurrentVachana(vachana);

      // 2. Create MediaItem
      final mediaItem = _buildMediaItem(vachana);

      // 3. Update mediaItem stream IMMEDIATELY
      if (this.mediaItem.hasValue || this.mediaItem.isClosed == false) {
        this.mediaItem.add(mediaItem);
      } // updateMetadataForCurrentTrack();

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

      //  3. Playlist management
      if (_currentPlaylist.isEmpty ||
          !_currentPlaylist.any((v) => v.vachanaId == vachana.vachanaId)) {
        setPlaylist([vachana]);
        currentIndex.value = 0;
      } else {
        currentIndex.value = _currentPlaylist
            .indexWhere((v) => v.vachanaId == vachana.vachanaId);
      }

      await _player.stop();

      // 4. Build queue BEFORE setting source
      final queue = _buildQueueItems();
      if (this.queue.hasValue || this.queue.isClosed == false) {
        this.queue.add(queue);
      }

      // // 5. Set media item specifically for THIS track
      // final currentItem = queue.firstWhere(
      //   (item) => item.id == vachana.vachanaId,
      //   orElse: () =>
      //       queue.isNotEmpty ? queue[0] : MediaItem(id: '', title: ''),
      // );
      // // AudioServiceBackground.setMediaItem(currentItem);
      // this.mediaItem.add(currentItem); // Update current item

      // 6. Set audio source
      await _player.setAudioSource(AudioSource.uri(Uri.parse(audioUrl)));
      await _player.load();
      await _player.play();
      print('Successfully started playing: ${vachana.vachanaNameEnglish}');
    } catch (e) {
      debugPrint('Error playing vachana: $e');
      // currentVachanaNotifier.value = null;

      // Reset state on error
      if (mediaItem.hasValue || mediaItem.isClosed == false) {
        mediaItem.add(null);
      }

      // Broadcast error state
      _broadcastState();
    }
  }

  // Claude Sonnet 4
  @override
  Future<void> stop() async {
    try {
      await _player.stop();
      currentIndex.value = -1;

      // Safe mediaItem update
      if (mediaItem.hasValue || mediaItem.isClosed == false) {
        mediaItem.add(null);
      }

      _broadcastState();
      return super.stop();
    } catch (e) {
      debugPrint('Error in stop: $e');
      return super.stop();
    }
  }

  // Claude Sonnet 4
  @override
  Future<void> onTaskRemoved() async {
    try {
      await stop();

      // Dispose of streams
      await mediaItem.close();
      await queue.close();
      await playbackState.close();
      currentIndex.dispose();

      await super.onTaskRemoved();
    } catch (e) {
      debugPrint('Error in onTaskRemoved: $e');
      await super.onTaskRemoved();
    }
  }

  //Deepseek
  // @override
  // Future<void> stop() async {
  //   await _player.stop();
  //   currentIndex.value = -1;
  //   mediaItem.add(null); // Clear metadata
  //   return super.stop();
  // }

  // ===== Lifecycle Management =====
  //Deepseek
  // @override
  // Future<void> onTaskRemoved() async {
  //   await stop();
  //   await super.onTaskRemoved();
  // }

  @override
  Future<void> onNotificationDeleted() async {
    await stop();
    await super.onNotificationDeleted();
  }
}
*/ 
// end as of 20250706

/***

// new impl on 6/30 for background audio playback and lock screen controls
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shunya_vachanasiri/providers/app_state.dart' as constants;
import 'package:shunya_vachanasiri/models/vachana_model.dart';
import 'package:shunya_vachanasiri/services/auth_service.dart';

// Define custom action names
const CustomMediaAction shuffleAction = CustomMediaAction(name: 'shuffle');
const CustomMediaAction repeatAction = CustomMediaAction(name: 'repeat');

class AudioPlayerHandler extends BaseAudioHandler {
  final AudioPlayer _player = AudioPlayer();
  final List<Vachana> _playlist = [];
  final List<Vachana> _originalPlaylist = [];
  List<Vachana> _currentPlaylist = [];

  final ValueNotifier<int> currentIndex = ValueNotifier<int>(-1);
  final ValueNotifier<Duration> positionNotifier = ValueNotifier(Duration.zero);
  final ValueNotifier<Duration> durationNotifier = ValueNotifier(Duration.zero);
  final ValueNotifier<bool> isShuffledNotifier = ValueNotifier(false);
  final ValueNotifier<bool> isRepeatingNotifier = ValueNotifier(false);
  final ValueNotifier<Duration> _tempPosition = ValueNotifier(Duration.zero);
  // ValueListenable<Duration> get tempPosition => _tempPosition;

  // Add public accessors
  bool get isLoading => _player.processingState == ProcessingState.loading;
  bool get isBuffering => _player.processingState == ProcessingState.buffering;
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<bool> get playingStream => _player.playingStream;

  Duration _lastKnownPosition = Duration.zero;
  int _lastKnownIndex = 0;

  bool get isProcessingStateReady =>
      _player.processingState == ProcessingState.ready;

  Vachana? get currentVachana =>
      (currentIndex.value != -1 && _playlist.isNotEmpty)
          ? _playlist[currentIndex.value]
          : null;

  Future<void> setPlaylistAndPlay(
      List<Vachana> playlist, int startIndex) async {
    _playlist.clear();
    _playlist.addAll(playlist);
    currentIndex.value = startIndex;
    await play();
  }

  void _updateAllStates() {
    _updateMediaItem(currentVachana!);

    playbackState.add(playbackState.value.copyWith(
      controls: _buildControls(),
    ));
  }

  void toggleShuffle() {
    if (queue.value.isEmpty) return;
    _preserveCurrentTrackPosition();

    isShuffledNotifier.value = !isShuffledNotifier.value;

    if (isShuffledNotifier.value) {
      // Enable shuffle
      _currentPlaylist = List.from(_originalPlaylist)..shuffle();
      _preserveCurrentTrackPosition();
    } else {
      // Disable shuffle
      _currentPlaylist = List.from(_originalPlaylist);
      _preserveCurrentTrackPosition();
    }

    // Update UI and metadata
    _updateAllStates();
    // _updateMediaItem(currentVachana!);
  }

// Helper to maintain current track position
  // void _preserveCurrentTrackPosition() {
  //   if (currentIndex.value == -1) return;

  //   final currentId = _originalPlaylist[currentIndex.value].vachanaId;
  //   final newIndex =
  //       _currentPlaylist.indexWhere((v) => v.vachanaId == currentId);

  //   if (newIndex != -1) {
  //     currentIndex.value = newIndex;
  //   }
  // }

  void _preserveCurrentTrackPosition() {
    // Add null safety and bounds checking
    if (queue.value.isEmpty || mediaItem.value == null) {
      _lastKnownPosition = Duration.zero;
      _lastKnownIndex = 0;
      return;
    }

    try {
      final currentItem = mediaItem.value!;
      final index = queue.value.indexWhere((item) => item.id == currentItem.id);

      if (index != -1) {
        _lastKnownPosition = _player.position;
        _lastKnownIndex = index;
      } else {
        _lastKnownPosition = Duration.zero;
        _lastKnownIndex = 0;
      }
    } catch (e) {
      debugPrint("Error preserving track position: $e");
      _lastKnownPosition = Duration.zero;
      _lastKnownIndex = 0;
    }
  }

  // Initialize when setting playlist
  void setPlaylist(List<Vachana> vachanas) {
    _originalPlaylist
      ..clear()
      ..addAll(vachanas);
    if (isShuffledNotifier.value) {
      _currentPlaylist
        ..clear()
        ..addAll(_originalPlaylist)
        ..shuffle();
    } else {
      _currentPlaylist
        ..clear()
        ..addAll(_originalPlaylist);
    }
    currentIndex.value = -1;
  }

  void toggleRepeat() {
    isRepeatingNotifier.value = !isRepeatingNotifier.value;

    // Update UI and metadata
    _updateAllStates();
    // _updateMediaItem(currentVachana!);

    _player
        .setLoopMode(isRepeatingNotifier.value ? LoopMode.one : LoopMode.off);
  }

  List<MediaControl> _buildControls() {
    return [
      MediaControl.skipToPrevious,
      playbackState.value.playing ? MediaControl.pause : MediaControl.play,
      MediaControl.skipToNext,
    ];
  }

  // Constructor with combined logic
  AudioPlayerHandler() {
    _player.playbackEventStream.listen(_broadcastState);

    playbackState.add(PlaybackState(
      controls: _buildControls(),
      systemActions: const {
        MediaAction.stop,
        MediaAction.seek,
        MediaAction.custom,
      },
      // androidCompactActionIndices: const [1, 2, 3],
    ));

    _player.playbackEventStream.listen(_broadcastState);
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        if (isRepeatingNotifier.value) {
          // Repeat current track
          _player.seek(Duration.zero);
          _player.play();
        } else {
          // Go to next track
          playNext();
        }
      }
    });

    // NEW: Track position updates
    _player.positionStream.listen((position) {
      positionNotifier.value = position;
    });

    // NEW: Track duration updates
    _player.durationStream.listen((duration) {
      if (duration != null) {
        durationNotifier.value = duration;
      }
    });

    // Shuffle state sync
    isShuffledNotifier.addListener(_updateAllStates);

    // isShuffledNotifier.addListener(() {
    //   playbackState.add(playbackState.value.copyWith(
    //     shuffleMode: isShuffledNotifier.value
    //         ? AudioServiceShuffleMode.all
    //         : AudioServiceShuffleMode.none,
    //   ));

    // _updatePlaybackControls();

    // if (currentVachana != null) {
    //   _updateMediaItem(currentVachana!);
    // }
    // });

    // Repeat state sync
    isRepeatingNotifier.addListener(_updateAllStates);

    // isRepeatingNotifier.addListener(() {
    //   playbackState.add(playbackState.value.copyWith(
    //     repeatMode: isRepeatingNotifier.value
    //         ? AudioServiceRepeatMode.one
    //         : AudioServiceRepeatMode.none,
    //   ));

    //   _updatePlaybackControls();

    //   if (currentVachana != null) {
    //     _updateMediaItem(currentVachana!);
    //   }
    // });
  }

  void _broadcastState(PlaybackEvent event) {
    final playing = _player.playing;
    final processingState = {
      ProcessingState.idle: AudioProcessingState.idle,
      ProcessingState.loading: AudioProcessingState.loading,
      ProcessingState.buffering: AudioProcessingState.buffering,
      ProcessingState.ready: AudioProcessingState.ready,
      ProcessingState.completed: AudioProcessingState.completed,
    }[_player.processingState]!;

    playbackState.add(playbackState.value.copyWith(
      controls: _buildControls(),
      systemActions: const {
        MediaAction.stop,
        MediaAction.seek,
        MediaAction.custom,
        MediaAction.setShuffleMode, // Enable for iOS
        MediaAction.setRepeatMode, // Enable for iOS
      },
      // androidCompactActionIndices: const [0, 1, 2],
      processingState: processingState,
      playing: playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: currentIndex.value,
      // iOS-specific state properties
      shuffleMode: isShuffledNotifier.value
          ? AudioServiceShuffleMode.all
          : AudioServiceShuffleMode.none,
      repeatMode: isRepeatingNotifier.value
          ? AudioServiceRepeatMode.one
          : AudioServiceRepeatMode.none,
    ));
  }

  @override
  Future<void> customAction(String name, [Map<String, dynamic>? extras]) async {
    if (name == shuffleAction.name) {
      toggleShuffle();
    } else if (name == repeatAction.name) {
      toggleRepeat();
    }
  }

  // Future<void> skipToNext() async {
  //   if (currentIndex.value < _playlist.length - 1) {
  //     currentIndex.value++;
  //     await play();
  //   }
  // }

  Future<void> playNext() async {
    if (currentIndex.value >= _playlist.length - 1) {
      // Reached end of playlist
      if (isRepeatingNotifier.value) {
        // Loop back to start if repeating
        currentIndex.value = 0;
        await playVachana(_playlist[0]);
      }
      return;
    }

    currentIndex.value++;
    await playVachana(_playlist[currentIndex.value]);
  }

  Future<void> playPrevious() async {
    if (currentIndex.value <= 0) {
      // Reached start of playlist
      if (isRepeatingNotifier.value) {
        // Loop to end if repeating
        currentIndex.value = _playlist.length - 1;
        await playVachana(_playlist.last);
      }
      return;
    }

    currentIndex.value--;
    await playVachana(_playlist[currentIndex.value]);
  }

  @override
  Future<void> play() async => _player.play();

  @override
  Future<void> pause() async => _player.pause();

  // @override
  // Future<void> seek(Duration position) async => _player.seek(position);

  @override
  Future<void> seek(Duration position) async {
    try {
      if (_player.processingState == ProcessingState.ready) {
        await _player.seek(position);
      }
    } catch (e) {
      debugPrint('Seek failed: $e');
    }
  }

  void updateTempPosition(Duration position) {
    _tempPosition.value = position;
  }

  @override
  Future<void> skipToNext() async => playNext();

  @override
  Future<void> skipToPrevious() async => playPrevious();

  // @override
  // Future<void> shuffle() async => toggleShuffle();

  @override
  Future<void> shuffle() async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      toggleShuffle();
    }
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      isRepeatingNotifier.value = repeatMode != AudioServiceRepeatMode.none;
      _updateAllStates();
    }
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    await _player.dispose();
    return super.stop();
  }

  Future<void> playVachana(Vachana vachana) async {
    try {
      final index =
          _playlist.indexWhere((v) => v.vachanaId == vachana.vachanaId);
      if (index == -1) return;

      currentIndex.value = index;

      await AuthService.ensureAuthenticated();
      final baseUrl = constants.AppConstants.getVachanaAudioTrackUrl(
        vachana.sharanaId,
        vachana.vachanaNameEnglish,
      );

      if (baseUrl.isEmpty) {
        // Handle error: URL generation failed
        debugPrint(
            'Failed while dynamic base URL generation for vachana: [${vachana.sharanaId} --> ${vachana.vachanaNameEnglish}]');
        return;
      }

      final idToken = await AuthService.getIdToken();
      final audioUrl = idToken != null ? '$baseUrl&token=$idToken' : baseUrl;
      if (audioUrl.isEmpty) {
        throw Exception(
            'Failed while dynamic URL generation with token for vachana: [${vachana.sharanaId} --> ${vachana.vachanaNameEnglish}]');
      }

      await _player.stop();

      await _player.setAudioSource(AudioSource.uri(Uri.parse(audioUrl)));
      await _player.load();
      _updateMediaItem(vachana);
      await _player.play();

      // Update UI state
      playbackState.add(playbackState.value.copyWith(
        playing: true,
        processingState: AudioProcessingState.ready,
      ));
    } catch (e) {
      print('Error playing vachana: $e');
    }
  }

  void _updateMediaItem(Vachana vachana) {
    try {
      final sharanaImgUrl = constants.AppConstants.getSharanaImageUrl(
        vachana.sharanaId,
        'mini',
      );

      final mediaItem = MediaItem(
        id: vachana.vachanaId.toString(),
        title: vachana.vachanaNameKannada,
        artist: vachana.sharanaNameKannada,
        artUri: sharanaImgUrl.isNotEmpty ? Uri.parse(sharanaImgUrl) : null,
        duration: _player.duration,
        // Store states for UI synchronization
        extras: {
          'shuffle': isShuffledNotifier.value,
          'repeat': isRepeatingNotifier.value,
          'sharanaId': vachana.sharanaId,
          'vachanaId': vachana.vachanaId,
        },
      );
      // Update both mediaItem and playbackState
      this.mediaItem.add(mediaItem);

      // Update playback state separately (without mediaItem)
      playbackState.add(playbackState.value.copyWith(
        // Keep existing state but update index if needed
        queueIndex: currentIndex.value,
      ));

      // Add debug prints
      print("Updated media item: ${mediaItem.title}");
      print("Current queue index: $currentIndex");
    } catch (e) {
      print("Error updating media item: $e");
    }
  }

  // Add this to prevent seek when not ready
  Stream<Duration> get safePositionStream => _player.positionStream
      .where((_) => _player.processingState == ProcessingState.ready);
}
**/

// as of 2025 06 28 , does not handle background tasks properly
// import 'package:audio_service/audio_service.dart';
// import 'package:just_audio/just_audio.dart';

// class AudioHandler extends BaseAudioHandler {
//   final _player = AudioPlayer();
//   final _playlist = ConcatenatingAudioSource(children: []);

//   AudioHandler() {
//     _player.playbackEventStream.map(_transformEvent).pipe(playbackState);
//   }

//   @override
//   Future<void> play() => _player.play();

//   @override
//   Future<void> pause() => _player.pause();

//   @override
//   Future<void> stop() => _player.stop();

//   @override
//   Future<void> playMediaItem(MediaItem mediaItem) async {
//     await _player.setAudioSource(AudioSource.uri(Uri.parse(mediaItem.id)));
//     this.mediaItem.add(mediaItem); // Fixed line
//     return _player.play();
//   }

//   PlaybackState _transformEvent(PlaybackEvent event) {
//     return PlaybackState(
//       controls: [
//         MediaControl.play,
//         MediaControl.pause,
//         MediaControl.stop,
//       ],
//       systemActions: const {
//         MediaAction.seek,
//         MediaAction.seekForward,
//         MediaAction.seekBackward,
//       },
//       androidCompactActionIndices: const [0, 1, 3],
//       processingState: const {
//         ProcessingState.idle: AudioProcessingState.idle,
//         ProcessingState.loading: AudioProcessingState.loading,
//         ProcessingState.buffering: AudioProcessingState.buffering,
//         ProcessingState.ready: AudioProcessingState.ready,
//         ProcessingState.completed: AudioProcessingState.completed,
//       }[_player.processingState]!,
//       playing: _player.playing,
//       updatePosition: _player.position,
//       bufferedPosition: _player.bufferedPosition,
//       speed: _player.speed,
//       queueIndex: event.currentIndex,
//     );
//   }
// }