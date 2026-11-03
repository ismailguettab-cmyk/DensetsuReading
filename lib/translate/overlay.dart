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
      return Stack(
        children: [
          for (final b in bubbles)
            if (b.replace) _bubble(b, w, h),
        ],
      );
    });
  }

  Widget _bubble(Bubble b, double w, double h) {
    final area = Rect.fromLTRB(b.area.left * w, b.area.top * h, b.area.right * w, b.area.bottom * h);
    final round = b.kind == 'speech' || b.kind == 'thought';
    // Original lettering size, so the French text never comes out bigger.
    final originalSize = (b.textBox.height * h / b.lines) / 1.18;
    final inset = round ? EdgeInsets.symmetric(horizontal: area.width * 0.09, vertical: area.height * 0.08) : EdgeInsets.all(area.shortestSide * 0.04);
    return Positioned.fromRect(
      rect: area,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: b.background,
          borderRadius: BorderRadius.circular(round ? area.shortestSide * 0.48 : area.shortestSide * 0.08),
        ),
        child: Padding(
          padding: inset,
          child: _FitText(
            text: b.uppercase ? b.translation.toUpperCase() : b.translation,
            maxSize: originalSize.clamp(6.0, 64.0),
            color: b.textColor,
          ),
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
