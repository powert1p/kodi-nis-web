import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

/// Renders text with inline math expressions.
/// Converts plain-text math notation to LaTeX and renders mixed text+math.
class MathText extends StatelessWidget {
  const MathText(this.text, {super.key, this.style, this.mathStyle});
  final String text;
  final TextStyle? style;
  final MathStyle? mathStyle;

  @override
  Widget build(BuildContext context) {
    final defaultStyle = style ??
        const TextStyle(fontSize: 17, height: 1.6, color: Color(0xFF1E293B));

    final segments = _parse(text);

    if (segments.length == 1 && !segments[0].isMath) {
      return Text(text, style: defaultStyle);
    }

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 2,
      runSpacing: 8,
      children: segments.map((s) {
        if (s.isMath) {
          return Math.tex(
            s.content,
            textStyle: defaultStyle.copyWith(height: 1),
            mathStyle: mathStyle ?? MathStyle.text,
          );
        }
        return Text(s.content, style: defaultStyle);
      }).toList(),
    );
  }

  /// Parse text into segments of plain text and math
  static List<_Segment> _parse(String text) {
    final result = <_Segment>[];
    // Pre-process: convert plain-text math to LaTeX
    final processed = _convertToLatex(text);

    // Split on $...$ delimiters
    final parts = processed.split(r'$');
    for (var i = 0; i < parts.length; i++) {
      if (parts[i].isEmpty) continue;
      result.add(_Segment(parts[i], isMath: i.isOdd));
    }

    return result.isEmpty ? [_Segment(text, isMath: false)] : result;
  }

  /// Convert plain-text math notation to LaTeX with $ delimiters
  static String _convertToLatex(String text) {
    var result = text;

    // Pattern: standalone fractions like "1/3", "2/5", "17/5", "1 3/4" (mixed numbers)
    // Mixed numbers: "2 3/4" → "$2\frac{3}{4}$"
    result = result.replaceAllMapped(
      RegExp(r'(\d+)\s+(\d+)/(\d+)'),
      (m) => r'$' '${m[1]}\\frac{${m[2]}}{${m[3]}}' r'$',
    );

    // Simple fractions in context: "1/3" → "$\frac{1}{3}$"
    // But not dates like 22/02 or paths
    result = result.replaceAllMapped(
      RegExp(r'(?<!\d{2})(?<!\w)(\d{1,4})/(\d{1,4})(?!\w)(?!/\d)'),
      (m) => r'$' '\\frac{${m[1]}}{${m[2]}}' r'$',
    );

    // Powers: "x^2", "8^2", "(−2)^3", "1028^1785"
    result = result.replaceAllMapped(
      RegExp(r'(\w+|\))\^(\d+|\{[^}]+\})'),
      (m) {
        final base = m[1]!;
        final exp = m[2]!;
        final expClean = exp.startsWith('{') ? exp : '{$exp}';
        return '\$$base^$expClean\$';
      },
    );

    // Square root symbol: "√25" → "$\sqrt{25}$"
    result = result.replaceAllMapped(
      RegExp(r'√(\d+)'),
      (m) => r'$' '\\sqrt{${m[1]}}' r'$',
    );

    // Multiplication dot: "⋅" → "$\cdot$"
    result = result.replaceAll('⋅', r'$\cdot$');

    // Fix double $$ from adjacent conversions
    result = result.replaceAll(r'$$', ' ');

    return result;
  }
}

class _Segment {
  _Segment(this.content, {required this.isMath});
  final String content;
  final bool isMath;
}
