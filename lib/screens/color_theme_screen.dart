import 'package:flutter/material.dart';

import '../models/soldier_faction_color_theme.dart';

/// Reference: one row per index **1–5** (dark → light); yellow/blue are **HSL parallels** of red
/// (same S & L per tier, hue from former tier-3 yellow / blue anchors).
class ColorThemeScreen extends StatelessWidget {
  const ColorThemeScreen({super.key});

  static String _hexRgb(Color c) {
    final int r = (c.r * 255.0).round().clamp(0, 255);
    final int g = (c.g * 255.0).round().clamp(0, 255);
    final int b = (c.b * 255.0).round().clamp(0, 255);
    final String h = (r << 16 | g << 8 | b).toRadixString(16).padLeft(6, '0');
    return '#${h.toUpperCase()}';
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextStyle? headerStyle = theme.textTheme.labelLarge?.copyWith(
      color: Colors.white,
      fontWeight: FontWeight.w700,
    );
    final TextStyle? cellHexStyle = theme.textTheme.labelSmall?.copyWith(
      color: Colors.white70,
      fontFamily: 'monospace',
      fontSize: 10,
    );

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color(0xFF0F0D08),
              Color(0xFF2A2314),
              Color(0xFF0C0B06),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                child: Row(
                  children: <Widget>[
                    IconButton.filledTonal(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Color theme',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Fifteen component colors (5 per faction), dark → light by row; index **1–5**. '
                  'Yellow and blue match the red ladder in **HSL** (saturation & lightness per tier; '
                  'hue from the old tier-3 yellow `#FCD87E` and blue `#66ACF1`). '
                  'Source: soldier_faction_color_theme.dart.',
                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Table(
                          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                          columnWidths: const <int, TableColumnWidth>{
                            0: FixedColumnWidth(40),
                            1: FlexColumnWidth(1),
                            2: FlexColumnWidth(1),
                            3: FlexColumnWidth(1),
                            4: FlexColumnWidth(1),
                            5: FlexColumnWidth(1),
                          },
                          border: TableBorder.symmetric(
                            inside: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                          ),
                          children: <TableRow>[
                            TableRow(
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.06),
                              ),
                              children: <Widget>[
                                _th('Idx', headerStyle),
                                _th('Red', headerStyle, const Color(0xFFE57373)),
                                _th('Yellow', headerStyle, const Color(0xFFFFD54F)),
                                _th('Blue', headerStyle, const Color(0xFF64B5F6)),
                              ],
                            ),
                            for (int i = 0; i < 5; i++)
                              TableRow(
                                children: <Widget>[
                                  _td(
                                    Text(
                                      '${i + 1}',
                                      textAlign: TextAlign.center,
                                      style: theme.textTheme.titleSmall?.copyWith(
                                        color: Colors.white54,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  _td(_ColorCell(
                                    color: kRedFactionComponentColors[i],
                                    hex: _hexRgb(kRedFactionComponentColors[i]),
                                    hexStyle: cellHexStyle,
                                  )),
                                  _td(_ColorCell(
                                    color: kYellowFactionComponentColors[i],
                                    hex: _hexRgb(kYellowFactionComponentColors[i]),
                                    hexStyle: cellHexStyle,
                                  )),
                                  _td(_ColorCell(
                                    color: kBlueFactionComponentColors[i],
                                    hex: _hexRgb(kBlueFactionComponentColors[i]),
                                    hexStyle: cellHexStyle,
                                  )),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _th(String text, TextStyle? style, [Color? accent]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: style?.copyWith(color: accent ?? style.color),
      ),
    );
  }

  static Widget _td(Widget child) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      child: child,
    );
  }
}

class _ColorCell extends StatelessWidget {
  const _ColorCell({
    required this.color,
    required this.hex,
    required this.hexStyle,
  });

  final Color color;
  final String hex;
  final TextStyle? hexStyle;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.white30),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(hex, style: hexStyle, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}
