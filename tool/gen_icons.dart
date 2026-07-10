// Generates BlueSnap's brand assets as PNGs.
//
// Mark: a bold rounded "B" whose upper bowl carries a person-head cutout
// (two people becoming one letter). The mark itself stays WHITE — like
// Instagram's glyph — and sits on the brand's multi-color "sunset" gradient
// (yellow → orange → crimson/maroon → purple → blue), radiating from the
// bottom-left corner the way Instagram's icon does.
//
// Outputs:
//   assets/icon/app_icon.png      1024  gradient bg + white mark (legacy icon)
//   assets/icon/app_icon_fg.png   1024  transparent bg + white mark (adaptive fg)
//   assets/icon/app_icon_bg.png   1024  gradient only (adaptive bg)
//   assets/icon/splash_logo.png    512  transparent bg + white mark
//   assets/icon/splash_bg.png     1152x2048 gradient (splash background)
//
// Run with: dart run tool/gen_icons.dart
import 'dart:io';
import 'dart:math';
import 'package:image/image.dart' as img;

// Instagram-classic gradient stops, bottom-left → top-right.
const _stops = [
  [254, 218, 117], // #FEDA75 yellow
  [250, 126, 30], // #FA7E1E orange
  [214, 41, 118], // #D62976 crimson / maroon
  [150, 47, 191], // #962FBF purple
  [79, 91, 213], // #4F5BD5 blue
];

List<int> _gradientAt(double t) {
  final clamped = t.clamp(0.0, 1.0);
  final seg = clamped * (_stops.length - 1);
  final i = seg.floor().clamp(0, _stops.length - 2);
  final f = seg - i;
  return List.generate(
      3, (c) => (_stops[i][c] + (_stops[i + 1][c] - _stops[i][c]) * f).round());
}

/// Paint the sunset gradient onto [im], radiating from bottom-left.
void _paintGradient(img.Image im) {
  final w = im.width, h = im.height;
  final maxD = sqrt(pow(w * 0.85, 2) + pow(h * 0.85, 2));
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final d = sqrt(pow(x - w * 0.02, 2) + pow(h * 0.98 - y, 2)) / maxD;
      final c = _gradientAt(d * 1.15);
      im.setPixelRgba(x, y, c[0], c[1], c[2], 255);
    }
  }
}

// ── Mark geometry (signed-distance rasterizer, unit coords, y-down) ──
double _sdCircle(double px, double py, double cx, double cy, double r) =>
    sqrt(pow(px - cx, 2) + pow(py - cy, 2)) - r;

double _sdRoundRect(double px, double py, double x0, double y0, double x1,
    double y1, double r) {
  final cx = (x0 + x1) / 2, cy = (y0 + y1) / 2;
  final hx = (x1 - x0) / 2 - r, hy = (y1 - y0) / 2 - r;
  final qx = (px - cx).abs() - hx, qy = (py - cy).abs() - hy;
  final ox = max(qx, 0.0), oy = max(qy, 0.0);
  return sqrt(ox * ox + oy * oy) + min(max(qx, qy), 0.0) - r;
}

/// Signed distance to the BlueSnap "B" mark. Negative = inside white glyph.
double _markSd(double x, double y) {
  // Solid body of the B: a stem, two bowls, and bridges that keep the top and
  // bottom strokes flowing smoothly from stem to bowl (no silhouette dips).
  // Stem and strokes share the same left edge and corner radius so their
  // rounded corners coincide exactly — no scallops along the silhouette.
  final stem = _sdRoundRect(x, y, 0.19, 0.09, 0.41, 0.91, 0.10);
  final strokeTop = _sdRoundRect(x, y, 0.19, 0.09, 0.56, 0.36, 0.10);
  final strokeBot = _sdRoundRect(x, y, 0.19, 0.64, 0.58, 0.91, 0.10);
  final upper = _sdCircle(x, y, 0.55, 0.315, 0.225);
  final lower = _sdCircle(x, y, 0.57, 0.65, 0.26);
  var d = min(stem, min(strokeTop, min(strokeBot, min(upper, lower))));

  // Cutouts. The upper counter is a person — head + rounded torso with a thin
  // white neck between them — so the negative space reads as someone inside
  // the letter. The lower counter is a classic round bowl, and a small
  // right-edge bite pinches the waist so the silhouette reads "B", not "8".
  final head = _sdCircle(x, y, 0.555, 0.255, 0.080);
  final torso = _sdRoundRect(x, y, 0.455, 0.372, 0.655, 0.478, 0.085);
  final counter = _sdCircle(x, y, 0.585, 0.655, 0.128);
  final waist = _sdCircle(x, y, 0.90, 0.485, 0.085);
  final cut = min(head, min(torso, min(counter, waist)));

  return max(d, -cut); // subtract the cutouts
}

/// Draw the white mark centered on [im], glyph spanning [scale] of the image.
void _drawMark(img.Image im, {double scale = 1.0, int alpha = 255}) {
  final n = im.width;
  final aa = 1.5 / n; // ~1.5px anti-alias band
  for (var y = 0; y < im.height; y++) {
    for (var x = 0; x < n; x++) {
      // Map pixel into the glyph's unit box (centered, scaled).
      final u = ((x / n) - 0.5) / scale + 0.5;
      final v = ((y / im.height) - 0.5) / scale + 0.5;
      final d = _markSd(u, v);
      if (d < aa) {
        final cov = d <= -aa ? 1.0 : (aa - d) / (2 * aa);
        final a = (alpha * cov).round();
        if (a > 0) {
          final p = im.getPixel(x, y);
          // Composite white over whatever is there.
          final na = a / 255.0;
          im.setPixelRgba(
            x,
            y,
            (255 * na + p.r * (1 - na)).round(),
            (255 * na + p.g * (1 - na)).round(),
            (255 * na + p.b * (1 - na)).round(),
            max(a, p.a.toInt()),
          );
        }
      }
    }
  }
}

/// Draw the mark filled with the sunset GRADIENT on transparent — for the
/// white splash screen (Instagram-style: white screen, colorful glyph).
/// Rendered at high resolution with a tight 1px anti-alias edge for crispness.
void _drawGradientMark(img.Image im, {double scale = 0.42}) {
  final n = im.width;
  final aa = 1.0 / n; // tight edge — no soft/blurry halo
  for (var y = 0; y < im.height; y++) {
    for (var x = 0; x < n; x++) {
      final u = ((x / n) - 0.5) / scale + 0.5;
      final v = ((y / im.height) - 0.5) / scale + 0.5;
      final d = _markSd(u, v);
      if (d < aa) {
        final cov = d <= -aa ? 1.0 : (aa - d) / (2 * aa);
        final a = (255 * cov).round();
        if (a > 0) {
          // Gradient sampled diagonally across the glyph box.
          final c = _gradientAt((u + (1 - v)) / 2 * 1.1);
          im.setPixelRgba(x, y, c[0], c[1], c[2], a);
        }
      }
    }
  }
}

void main() {
  Directory('assets/icon').createSync(recursive: true);

  // 1. Launcher icon: gradient + white mark.
  const n = 1024;
  final icon = img.Image(width: n, height: n, numChannels: 4);
  _paintGradient(icon);
  _drawMark(icon, scale: 0.72);
  File('assets/icon/app_icon.png').writeAsBytesSync(img.encodePng(icon));

  // 2. Adaptive foreground: white mark on transparent, inside the safe zone.
  final fg = img.Image(width: n, height: n, numChannels: 4);
  _drawMark(fg, scale: 0.45);
  File('assets/icon/app_icon_fg.png').writeAsBytesSync(img.encodePng(fg));

  // 3. Adaptive background: gradient only.
  final bg = img.Image(width: n, height: n, numChannels: 4);
  _paintGradient(bg);
  File('assets/icon/app_icon_bg.png').writeAsBytesSync(img.encodePng(bg));

  // 4. Splash logo: GRADIENT mark on transparent — for a white splash screen
  //    (Instagram-style: white background, colourful glyph). High-res canvas so
  //    density buckets stay crisp; small glyph fraction so it shows modestly
  //    sized and centered with generous padding.
  const s = 1024;
  final splash = img.Image(width: s, height: s, numChannels: 4);
  _drawGradientMark(splash, scale: 0.42);
  File('assets/icon/splash_logo.png').writeAsBytesSync(img.encodePng(splash));

  stdout.writeln('Generated brand assets in assets/icon/');
}
