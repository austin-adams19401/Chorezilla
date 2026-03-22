import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';

/// Downloads sprite sheet PNGs from Firebase Storage and caches them to disk.
/// Call [init] once at startup, then [downloadAll] on first launch before
/// showing any mascot animations.
class SpriteSheetCacheService {
  /// All sprite sheet filenames used by the app.
  static const List<String> allFilenames = [
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
