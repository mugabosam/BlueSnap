// Generates attractive abstract gradient images used to seed the demo feed
// and stories so the UI can be evaluated with real content.
//
// Run with: dart run tool/gen_seed_images.dart
import 'dart:io';
import 'dart:math';
import 'package:image/image.dart' as img;

// Pleasant gradient color pairs [from, to] as RGB.
const pairs = <List<List<int>>>[
  [[191, 90, 242], [10, 132, 255]], // purple -> blue
  [[255, 159, 10], [255, 69, 58]], // orange -> red
  [[48, 209, 88], [0, 229, 255]], // green -> cyan
  [[10, 132, 255], [0, 229, 255]], // brand blue -> cyan
  [[243, 104, 224], [95, 39, 205]], // pink -> purple
  [[1, 163, 164], [84, 160, 255]], // teal -> blue
];

void main() {
  Directory('assets/images').createSync(recursive: true);
  const w = 1080, h = 1080;

  for (var idx = 0; idx < pairs.length; idx++) {
    final from = pairs[idx][0];
    final to = pairs[idx][1];
    final im = img.Image(width: w, height: h, numChannels: 4);

    // Diagonal gradient.
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final t = (x + y) / (w + h);
        final r = (from[0] + (to[0] - from[0]) * t).round();
        final g = (from[1] + (to[1] - from[1]) * t).round();
        final b = (from[2] + (to[2] - from[2]) * t).round();
        im.setPixelRgba(x, y, r, g, b, 255);
      }
    }

    // A few translucent circles for depth/interest.
    final rnd = Random(idx + 7);
    for (var c = 0; c < 4; c++) {
      final cx = rnd.nextInt(w);
      final cy = rnd.nextInt(h);
      final rad = 120 + rnd.nextInt(260);
      final white = rnd.nextBool();
      final col = img.ColorRgba8(
        white ? 255 : 0,
        white ? 255 : 0,
        white ? 255 : 0,
        rnd.nextInt(22) + 8,
      );
      img.fillCircle(im, x: cx, y: cy, radius: rad, color: col, antialias: true);
    }

    File('assets/images/seed_${idx + 1}.jpg')
        .writeAsBytesSync(img.encodeJpg(im, quality: 88));
  }
  stdout.writeln('Generated ${pairs.length} seed images in assets/images/');
}
