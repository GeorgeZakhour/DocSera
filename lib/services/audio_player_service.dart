import 'package:audioplayers/audioplayers.dart';

class AudioPlayerService {
  final AudioPlayer _audioPlayer = AudioPlayer();

  Stream<Duration> get positionStream => _audioPlayer.onPositionChanged;
  Stream<Duration> get durationStream => _audioPlayer.onDurationChanged;
  Stream<PlayerState> get playerStateStream => _audioPlayer.onPlayerStateChanged;

  Future<void> setSource(String url) async {
    if (url.startsWith('http')) {
      await _audioPlayer.setSource(UrlSource(url));
    } else {
      await _audioPlayer.setSource(DeviceFileSource(url));
    }
  }

  Future<void> play(String url) async {
    // If source already set, just resume. But for simplicity and safety, we re-set or resume.
    // Ideally we track state.
    if (_audioPlayer.state == PlayerState.paused) {
      await _audioPlayer.resume();
    } else {
        if (url.startsWith('http')) {
            await _audioPlayer.play(UrlSource(url));
        } else {
            await _audioPlayer.play(DeviceFileSource(url));
        }
    }
  }

  Future<void> pause() async {
    await _audioPlayer.pause();
  }

  Future<void> stop() async {
    await _audioPlayer.stop();
  }

  Future<void> seek(Duration position) async {
    await _audioPlayer.seek(position);
  }

  Future<void> dispose() async {
    await _audioPlayer.dispose();
  }
}
