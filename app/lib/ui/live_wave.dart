import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'dance.dart';

/// The live wave: the app's traffic as a sea.
///
/// A row of gentle waves scrolls to the left, filled to the height the speed
/// reaches, and the whole sea changes color with the dance's beat, so a
/// connected app moves like water instead of reading as a still chart. Two
/// ridges: the download nearer the viewer, the upload behind it, each at its
/// own height and its own shade of the beat's color.
///
/// Where it shows:
/// - the home page, under the connect button, when the user turned it on
///   (Settings > Light dance > Live wave);
/// - Settings > Light dance, as the sample beside its look.
///
/// It draws only what it needs: one path per ridge, a gradient fill, no blur,
/// and it repaints on the dance's beat or (with [animate]) on its own clock.
class LiveWave extends StatefulWidget {
  const LiveWave({
    super.key,
    required this.down,
    required this.up,
    required this.tick,
    this.dark = true,
    this.height = 92,
    this.animate = false,
    this.shape = DanceShape.chase,
    this.enabled = true,
    this.labels = true,
    this.maxDown = 0,
    this.maxUp = 0,
  });

  /// The speed now, in bytes a second: how high the nearer ridge stands.
  final int down;
  final int up;

  /// The dance's beat, from the DanceClock: the sea's color.
  final int tick;
  final bool dark;
  final double height;

  /// Whether the water moves on its own clock. The home page already
  /// repaints on the beat; the settings sample passes false too, since the
  /// clock it is given changes once a second by itself.
  final bool animate;

  /// The dance's shape, which bends the ridges differently: a chase rolls,
  /// a comet leans, stars ripple.
  final DanceShape shape;

  /// Off draws a flat still sea (one frame, no motion).
  final bool enabled;

  /// The small speed labels on the two ridges.
  final bool labels;

  /// The busiest speed seen, to scale the ridges when the page has one; 0
  /// scales to a fixed ceiling that keeps a quiet stream visible.
  final int maxDown;
  final int maxUp;

  @override
  State<LiveWave> createState() => _LiveWaveState();
}

class _LiveWaveState extends State<LiveWave>
    with SingleTickerProviderStateMixin {
  /// The swim: a slow drift of the water's own, on top of the beat's color.
  late final AnimationController _swim = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  );

  /// The history of both speeds, newest last, one point a beat: the ridge's
  /// height over time, so the sea's profile is the traffic's, not a sine.
  final List<double> _down = [];
  final List<double> _up = [];

  @override
  void initState() {
    super.initState();
    if (widget.animate && widget.enabled) _swim.repeat();
  }

  @override
  void didUpdateWidget(LiveWave old) {
    super.didUpdateWidget(old);
    if (widget.animate && widget.enabled) {
      if (!_swim.isAnimating) _swim.repeat();
    } else if (_swim.isAnimating) {
      _swim.stop();
    }
    if (old.tick != widget.tick) {
      _down.add(_level(widget.down, widget.maxDown));
      _up.add(_level(widget.up, widget.maxUp));
      // A minute of history at a beat a second.
      if (_down.length > 60) _down.removeAt(0);
      if (_up.length > 60) _up.removeAt(0);
    }
  }

  @override
  void dispose() {
    _swim.dispose();
    super.dispose();
  }

  /// A speed as the 0 to 1 height of its ridge. A fixed ceiling when there is
  /// no history to scale to, in a curve that keeps small speeds visible: the
  /// square root of the share.
  double _level(int speed, int max) {
    if (speed <= 0) return 0;
    final ceiling = max > 0 ? max * 1.25 : 4 << 20;
    return math.sqrt((speed / ceiling).clamp(0.0, 1.0));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = widget.enabled ? danceColor(widget.tick) : canary;
    final second = widget.enabled
        ? _shift(danceColor(widget.tick + 3))
        : _shift(canary);
    final label = theme.textTheme.labelSmall?.copyWith(
      color: widget.dark
          ? Colors.white.withValues(alpha: 0.75)
          : const Color(0xFF2A2F45).withValues(alpha: 0.8),
      fontWeight: FontWeight.w600,
    );
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: Stack(
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _swim,
                builder: (context, _) => CustomPaint(
                  painter: _WavePainter(
                    down: _down,
                    up: _up,
                    hour: widget.enabled ? _swim.value : 0,
                    color: color,
                    second: second,
                    dark: widget.dark,
                    shape: widget.shape,
                  ),
                ),
              ),
            ),
          ),
          if (widget.labels)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _WaveLabel(
                    icon: Icons.arrow_downward_rounded,
                    color: color,
                    text: _rate(widget.down),
                    style: label,
                  ),
                  _WaveLabel(
                    icon: Icons.arrow_upward_rounded,
                    color: second,
                    text: _rate(widget.up),
                    style: label,
                    reverse: true,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static Color _shift(Color c) =>
      HSLColor.fromColor(c)
          .withHue((HSLColor.fromColor(c).hue + 32) % 360)
          .toColor();

  /// A speed in the app's own units, short: "1.2 MB/s", "0 B/s".
  static String _rate(int bytes) {
    if (bytes <= 0) return '0 B/s';
    const units = ['B/s', 'KB/s', 'MB/s', 'GB/s'];
    var value = bytes.toDouble();
    var unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit++;
    }
    final text = value >= 100
        ? value.round().toString()
        : value.toStringAsFixed(1);
    return '$text ${units[unit]}';
  }
}

class _WaveLabel extends StatelessWidget {
  const _WaveLabel({
    required this.icon,
    required this.color,
    required this.text,
    this.style,
    this.reverse = false,
  });

  final IconData icon;
  final Color color;
  final String text;
  final TextStyle? style;
  final bool reverse;

  @override
  Widget build(BuildContext context) {
    // Speed figures read left to right in every language.
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Text(text, style: style, textDirection: TextDirection.ltr),
      ],
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 2),
      child: reverse
          ? Directionality(textDirection: TextDirection.ltr, child: row)
          : row,
    );
  }
}

class _WavePainter extends CustomPainter {
  const _WavePainter({
    required this.down,
    required this.up,
    required this.hour,
    required this.color,
    required this.second,
    required this.dark,
    required this.shape,
  });

  /// The two speeds' history, oldest first, each 0 to 1.
  final List<double> down;
  final List<double> up;

  /// 0 to 1: the water's own slow drift.
  final double hour;
  final Color color;
  final Color second;
  final bool dark;
  final DanceShape shape;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.height < 8 || size.width < 8) return;
    final floor = size.height * 0.18;
    _ridge(
      canvas,
      size,
      values: up,
      base: floor,
      amplitude: size.height * 0.34,
      color: second,
      alpha: 0.30,
      drift: hour * 2 * math.pi,
      lead: 1.7,
    );
    _ridge(
      canvas,
      size,
      values: down,
      base: floor,
      amplitude: size.height * 0.52,
      color: color,
      alpha: 0.46,
      drift: hour * 2 * math.pi + math.pi / 3,
      lead: 0,
    );
  }

  /// One ridge: the speed's history as crest heights, with a rolling swell
  /// between the points so it reads as water, filled down to the bottom.
  void _ridge(
    Canvas canvas,
    Size size, {
    required List<double> values,
    required double base,
    required double amplitude,
    required Color color,
    required double alpha,
    required double drift,
    required double lead,
  }) {
    final path = Path()..moveTo(0, size.height);
    final steps = math.max(28, (size.width / 6).round());
    // The tallest any crest may stand: the space above the floor, minus the
    // labels' band at the bottom.
    final top = math.max(2.0, size.height * 0.30);
    for (var i = 0; i <= steps; i++) {
      final t = i / steps;
      final x = t * size.width;
      // The history's value at t, smoothed between the one-second points.
      final v = _sample(values, t);
      // The swell: a slow sine the shape bends, so the sea breathes even in
      // a still stream.
      final k = switch (shape) {
        DanceShape.chase => 1.0,
        DanceShape.triple => 1.7,
        DanceShape.duet => 1.3,
        DanceShape.comet => 2.4,
        DanceShape.stars => 2.9,
      };
      final swell = math.sin(t * math.pi * 2 * k + drift + lead) * 0.14;
      final lean = switch (shape) {
        DanceShape.comet => t * 0.22,
        _ => 0.0,
      };
      final h = (v * (1 + swell) + swell * 0.35 + lean).clamp(0.0, 1.0);
      final y = size.height - base - h * (size.height - base - top);
      path.lineTo(x, y);
    }
    path
      ..lineTo(size.width, size.height)
      ..close();
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: alpha),
            color.withValues(alpha: alpha * 0.30),
            (dark ? Colors.black : Colors.white).withValues(alpha: 0),
          ],
        ).createShader(rect),
    );
    // The water's line along the crest.
    final line = Path();
    for (var i = 0; i <= steps; i++) {
      final t = i / steps;
      final x = t * size.width;
      final v = _sample(values, t);
      final k = switch (shape) {
        DanceShape.chase => 1.0,
        DanceShape.triple => 1.7,
        DanceShape.duet => 1.3,
        DanceShape.comet => 2.4,
        DanceShape.stars => 2.9,
      };
      final swell = math.sin(t * math.pi * 2 * k + drift + lead) * 0.14;
      final lean = switch (shape) {
        DanceShape.comet => t * 0.22,
        _ => 0.0,
      };
      final h = (v * (1 + swell) + swell * 0.35 + lean).clamp(0.0, 1.0);
      final y = size.height - base - h * (size.height - base - top);
      if (i == 0) {
        line.moveTo(x, y);
      } else {
        line.lineTo(x, y);
      }
    }
    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..color = color.withValues(alpha: (alpha + 0.34).clamp(0.0, 1.0)),
    );
  }

  /// The history's value at [t] (0 at its oldest end, 1 at now), straight
  /// lines between the points.
  double _sample(List<double> values, double t) {
    if (values.isEmpty) return 0;
    if (values.length == 1) return values.first;
    final at = t * (values.length - 1);
    final i = at.floor().clamp(0, values.length - 2);
    final f = at - i;
    return values[i] * (1 - f) + values[i + 1] * f;
  }

  @override
  bool shouldRepaint(_WavePainter old) =>
      old.hour != hour ||
      old.color != color ||
      old.second != second ||
      old.shape != shape ||
      old.down.length != down.length ||
      old.up.length != up.length ||
      (down.isNotEmpty && old.down.isNotEmpty && old.down.last != down.last);
}
