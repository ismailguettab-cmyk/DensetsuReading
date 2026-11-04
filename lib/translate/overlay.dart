import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'translator.dart';

/// Paints translated text over a page. Must be laid out exactly over the image
/// (same size), since bubble boxes are fractions of the image.
class TranslationOverlay extends StatelessWidget {
  const TranslationOverlay({super.key, required this.bubbles});

  final List<Bubble> bubbles;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth, h = box.maxHeight;
      final visible = bubbles.where((b) => b.replace).toList();
      return Stack(
        children: [
          // 1. Erase only the original lettering, in the balloon's own colour, with soft edges,
          //    so the artist's balloon (outline, shape, tail) stays untouched.
          for (final b in visible) _eraser(b, w, h),
          // 2. Letter the French text on a transparent background inside the balloon.
          for (final b in visible) _text(b, w, h),
        ],
      );
    });
  }

  Widget _eraser(Bubble b, double w, double h) {
    final pad = (b.textBox.height * h * 0.06).clamp(1.5, 6.0);
    final rect = Rect.fromLTRB(b.textBox.left * w, b.textBox.top * h, b.textBox.right * w, b.textBox.bottom * h)
        .inflate(pad)
        .intersect(Rect.fromLTRB(b.area.left * w, b.area.top * h, b.area.right * w, b.area.bottom * h).inflate(pad));
    return Positioned.fromRect(
      rect: rect,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: b.background,
          borderRadius: BorderRadius.circular(pad * 2),
          boxShadow: [BoxShadow(color: b.background, blurRadius: pad * 1.6, spreadRadius: pad * 0.3)],
        ),
      ),
    );
  }

  Widget _text(Bubble b, double w, double h) {
    final area = Rect.fromLTRB(b.area.left * w, b.area.top * h, b.area.right * w, b.area.bottom * h);
    // Original lettering size, so the French text never comes out bigger.
    final originalSize = (b.textBox.height * h / b.lines) / 1.18;
    return Positioned.fromRect(
      rect: area,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: area.width * 0.04, vertical: area.height * 0.03),
        child: _FitText(
          text: b.uppercase ? b.translation.toUpperCase() : b.translation,
          maxSize: originalSize.clamp(6.0, 64.0),
          color: b.textColor,
        ),
      ),
    );
  }
}

/// Largest font size (up to [maxSize]) at which [text] fits the box, centred.
class _FitText extends StatelessWidget {
  const _FitText({required this.text, required this.maxSize, required this.color});

  final String text;
  final double maxSize;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final base = GoogleFonts.comicNeue(fontWeight: FontWeight.w700, color: color, height: 1.1, letterSpacing: 0);
    return LayoutBuilder(builder: (context, box) {
      var size = maxSize;
      while (size > 5) {
        final painter = TextPainter(
          text: TextSpan(text: text, style: base.copyWith(fontSize: size)),
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: box.maxWidth);
        final fits = painter.height <= box.maxHeight && painter.width <= box.maxWidth + 0.5;
        painter.dispose();
        if (fits) break;
        size *= 0.94;
      }
      return Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(
            width: box.maxWidth,
            child: Text(text, textAlign: TextAlign.center, style: base.copyWith(fontSize: size)),
          ),
        ),
      );
    });
  }
}
