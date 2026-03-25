import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';

/// Downloads sprite sheet PNGs from Firebase Storage and caches them to disk.
/// Call [init] once at startup, then [downloadAll] on first launch before
/// showing any mascot animations.
class SpriteSheetCacheService {
  /// All sprite sheet filenames used by the app (body + details per animation).
  static const List<String> allFilenames = [
    // Walking
    'walking_body.png', 'walking_details.png',
    // Idle
    'idle_body.png', 'idle_details.png',
    // Looking (idle2)
    'idle2_body.png', 'idle2_details.png',
    // Going to sleep
    'going-to-sleep_body.png', 'going-to-sleep_details.png',
    // Sleeping
    'sleeping_body.png', 'sleeping_details.png',
    // Wake up
    'wake-up_body.png', 'wake-up_details.png',
    // Wave
    'wave_body.png', 'wave_details.png',
    // Sweeping
    'sweeping_body.png', 'sweeping_details.png',
    // Wiping
    'wiping_body.png', 'wiping_details.png',
    // Dance
    'dance_body.png', 'dance_details.png',
    // Grumpy
    'grumpy_body.png', 'grumpy_details.png',
    // Grrr
    'grrr_body.png', 'grrr_details.png',
    // Celebrate
    'celebrate_body.png', 'celebrate_details.png',
  ];

  /// Legacy single-layer filenames to clean up from existing caches.
  static const _legacyFilenames = [
    'walking.png',
    'idle.png',
    'idle2.png',
    'going-to-sleep.png',
    'sleeping.png',
    'wake-up.png',
    'wave.png',
    'sweeping.png',
    'wiping.png',
    'dance.png',
    'grumpy.png',
    'grrr.png',
    'celebrate.png',
  ];

  static late Directory _cacheDir;

  /// Must be called once in main() after Firebase.initializeApp().
  static Future<void> init() async {
    final appDir = await getApplicationDocumentsDirectory();
    _cacheDir = Directory('${appDir.path}/sprite_sheets');
    await _cacheDir.create(recursive: true);

    // Remove legacy single-layer sprite sheets from existing caches.
    for (final name in _legacyFilenames) {
      final f = File('${_cacheDir.path}/$name');
      if (f.existsSync()) f.deleteSync();
    }
  }

  static bool isDownloaded(String filename) =>
      File('${_cacheDir.path}/$filename').existsSync();

  static bool get allDownloaded => allFilenames.every(isDownloaded);

  /// Downloads any missing sprite sheets from Firebase Storage.
  /// [onProgress] is called after each file completes with (done, total).
  static Future<void> downloadAll({
    void Function(int done, int total)? onProgress,
  }) async {
    final storage = FirebaseStorage.instance;
    var done = 0;
    await Future.wait(
      allFilenames.map((name) async {
        if (!isDownloaded(name)) {
          final ref = storage.ref('sprite-sheets/$name');
          final file = File('${_cacheDir.path}/$name');
          await ref.writeToFile(file);
        }
        onProgress?.call(++done, allFilenames.length);
      }),
    );
  }

  /// Starts downloading missing sprites in the background (fire-and-forget).
  /// Call once at startup without awaiting. The stored future lets [getBytes]
  /// wait for a specific sprite if it hasn't landed yet.
  static void startBackgroundDownload() {
    if (allDownloaded) return;
    _backgroundDownload = downloadAll();
  }

  static Future<void>? _backgroundDownload;

  /// Returns the cached bytes for [filename]. If the file isn't on disk yet
  /// and a background download is in progress, waits for it to finish first.
  static Future<Uint8List> getBytes(String filename) async {
    final file = File('${_cacheDir.path}/$filename');
    if (!file.existsSync() && _backgroundDownload != null) {
      await _backgroundDownload;
    }
    return file.readAsBytes();
  }
}
