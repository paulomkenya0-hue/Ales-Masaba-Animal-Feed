import 'dart:math';

/// Hutengeneza kitambulisho cha kipekee cha ombi (mauzo / malipo / marekebisho).
/// Kinatumika kama jina la document kwenye Firestore, hivyo ombi lile lile
/// likirudiwa (retry au kubonyeza mara mbili) halirekodiwi mara ya pili.
class IdUtil {
  static final _rng = Random.secure();

  static String newRequestId() {
    final ts = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final r1 = _rng.nextInt(1 << 31).toRadixString(36);
    final r2 = _rng.nextInt(1 << 31).toRadixString(36);
    return '$ts$r1$r2';
  }
}
