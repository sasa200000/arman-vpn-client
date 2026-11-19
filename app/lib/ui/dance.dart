import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../app_settings.dart';

/// The light dance: the neon lights that run around the app's controls.
///
/// V2RVPN's look is a running ring of neon light. Before the VPN connects the
/// ring is canary yellow, steady; once it connects the ring changes color every
/// second, so the app breathes while it works. The rings around the download
/// and upload readouts, around the protocol, and the live chart's wave all
/// follow the same beat: [tick] is the app-wide clock, one beat a second, and
/// [color] picks the dance's color for a beat.
///
/// [dance] turns the whole thing off (Settings > Light dance): every painter
/// checks it first and draws nothing while it is false, so a user who wants a
/// still app gets one, and no timer runs.

/// The canary yellow the rings are before the connection: V2RVPN's own light.
const canary = Color(0xFFFFE14D);

/// The colors the dance runs through once connected. They go around the hue
/// circle in the app's own neon family: magenta and violet through cyan,
/// green, and gold, then back.
const danceColors = <Color>[
  Color(0xFFFF4D9D), // magenta
  Color(0xFFB45CFF), // violet
  Color(0xFF6E8CFF), // indigo
  Color(0xFF00D6FF), // cyan
  Color(0xFF19E6A8), // mint
  Color(0xFF9BE84D), // lime
  Color(0xFFFFE14D), // canary
  Color(0xFFFFA24D), // amber
];

/// The dance's colors for a beat: the one [tick] names, so every ring on the
/// screen changes together and the whole app reads as one pulse.
Color danceColor(int tick) => danceColors[tick.abs() % danceColors.length];

/// The color of a ring around a control: [color] once it runs, canary
/// yellow before that, so "not connected yet" is the same everywhere.
Color ringColor({required bool live, required int tick}) =>
    live ? danceColor(tick) : canary;

/// One drawing of a ring of running light, as a painter's own parameters:
/// the ring's radius and its thickness, the colors' phase for the arc's
/// rotation, and how strongly the glow is drawn.
class DanceRing {
  const DanceRing({
    required this.radius,
    required this.stroke,
    required this.tick,
    required this.color,
    this.phase = 0,
    this.glow = 1,
    this.spokes = 3,
  });

  final double radius;
  final double stroke;

  /// The second the dance is on, for its shape's own motion.
  final int tick;
  final Color color;

  /// 0 to 1 around the ring, where the bright segment starts.
  final double phase;

  /// 0 to 1: how much of the soft halo outside the stroke is drawn.
  final double glow;

  /// How many bright segments run around the ring.
  final int spokes;
}

/// Paints a ring of neon light: a faint full circle, then [DanceRing.spokes]
/// bright arcs with a soft halo, all in [DanceRing.color], turning with
/// [DanceRing.phase].
///
/// Kept cheap on purpose: strokes and one blurred copy of the same path, no
/// shader, no saveLayer per frame.
class DanceRingPainter extends CustomPainter {
  const DanceRingPainter(this.ring);

  final DanceRing ring;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: ring.radius);
    // The ring the control sits in, at rest: barely there, so the running
    // light has something to run along.
    canvas.drawCircle(
      center,
      ring.radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = ring.stroke * 0.55
        ..color = ring.color.withValues(alpha: 0.16),
    );
    final sweep = math.pi * 2 / ring.spokes * 0.46;
    for (var i = 0; i < ring.spokes; i++) {
      final start = ring.phase * math.pi * 2 + i * math.pi * 2 / ring.spokes;
      // The halo: the same arc, wide and faint.
      if (ring.glow > 0) {
        canvas.drawArc(
          rect,
          start,
          sweep,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeWidth = ring.stroke * 3.4
            ..color = ring.color.withValues(alpha: 0.16 * ring.glow)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, ring.stroke * 2.2),
        );
      }
      // The light itself, bright in the middle of its arc.
      canvas.drawArc(
        rect,
        start,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = ring.stroke
          ..color = ring.color,
      );
      // A white-hot head where it leads.
      canvas.drawArc(
        rect,
        start + sweep * 0.55,
        sweep * 0.34,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = ring.stroke * 0.72
          ..color = Colors.white.withValues(alpha: 0.55),
      );
    }
  }

  @override
  bool shouldRepaint(DanceRingPainter old) =>
      old.ring.color != ring.color ||
      old.ring.phase != ring.phase ||
      old.ring.radius != ring.radius ||
      old.ring.stroke != ring.stroke ||
      old.ring.glow != ring.glow ||
      old.ring.spokes != ring.spokes;
}

/// A ring around any control, drawn as a box behind it: the control goes in
/// [child], the ring's thickness and the space it keeps from the edge in
/// [pad]. It paints itself only (RepaintBoundary), so the lights' frames
/// repaint nothing else on the page.
class DanceRingBox extends StatelessWidget {
  const DanceRingBox({
    super.key,
    required this.ring,
    required this.child,
    this.pad = 8,
  });

  final DanceRing ring;
  final Widget child;

  /// The room between the control and the ring's stroke.
  final double pad;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(
      foregroundPainter: _InsetRingPainter(ring, pad),
      child: child,
    ),
  );
}

/// The same ring, drawn just inside the box's own edge, for a control that
/// should have the lights around its border (the traffic and protocol cards).
class _InsetRingPainter extends CustomPainter {
  const _InsetRingPainter(this.ring, this.pad);

  final DanceRing ring;
  final double pad;

  @override
  void paint(Canvas canvas, Size size) {
    final half = ring.stroke / 2 + 1;
    final radius = size.shortestSide / 2 - pad;
    final center = Offset(size.width / 2, size.height / 2);
    // A pill, not a circle, when the box is wider than it is tall: the ring
    // hugs the control's own shape.
    if (size.width - size.height > 4) {
      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          half,
          half,
          size.width - 2 * half,
          size.height - 2 * half,
        ),
        Radius.circular(size.height / 2 - pad),
      );
      _paintRingPath(canvas, Path()..addRRect(rrect), center, radius);
      return;
    }
    _paintRingPath(
      canvas,
      Path()..addOval(Rect.fromCircle(center: center, radius: radius)),
      center,
      radius,
    );
  }

  void _paintRingPath(Canvas canvas, Path path, Offset center, double radius) {
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = ring.stroke * 0.55
        ..color = ring.color.withValues(alpha: 0.16),
    );
    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;
    for (final metric in metrics) {
      final len = metric.length;
      final sweep = len / ring.spokes * 0.46;
      for (var i = 0; i < ring.spokes; i++) {
        final start = (ring.phase * len + i * len / ring.spokes) % len;
        final end = start + sweep;
        if (end <= len) {
          _arc(canvas, metric.extractPath(start, end), ring.stroke);
        } else {
          _arc(canvas, metric.extractPath(start, len), ring.stroke);
          _arc(canvas, metric.extractPath(0, end - len), ring.stroke);
        }
      }
    }
  }

  void _arc(Canvas canvas, Path arc, double stroke) {
    if (ring.glow > 0) {
      canvas.drawPath(
        arc,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = stroke * 3.2
          ..color = ring.color.withValues(alpha: 0.15 * ring.glow)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, stroke * 2),
      );
    }
    canvas.drawPath(
      arc,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = stroke
        ..color = ring.color,
    );
  }

  @override
  bool shouldRepaint(_InsetRingPainter old) =>
      old.ring.color != ring.color ||
      old.ring.phase != ring.phase ||
      old.ring.stroke != ring.stroke ||
      old.ring.glow != ring.glow ||
      old.ring.spokes != ring.spokes ||
      old.pad != pad;
}

/// The shapes the dance's ring can take (Settings > Light dance > Shape).
enum DanceShape {
  /// One light chasing itself around the control.
  chase('chase'),

  /// Three lights evenly apart, all turning together.
  triple('triple'),

  /// Two lights opposite each other, meeting and parting.
  duet('duet'),

  /// A comet: a bright head with a long tail behind it.
  comet('comet'),

  /// Stars: short bright dashes all around, blinking in step.
  stars('stars');

  const DanceShape(this.id);

  /// The value kept in app-settings.json.
  final String id;

  static DanceShape of(String id) {
    for (final shape in values) {
      if (shape.id == id) return shape;
    }
    return DanceShape.chase;
  }

  /// How many bright segments this shape draws.
  int get spokes => switch (this) {
    DanceShape.chase => 1,
    DanceShape.triple => 3,
    DanceShape.duet => 2,
    DanceShape.comet => 1,
    DanceShape.stars => 12,
  };

  /// The share of its slot each segment fills; a comet's tail is long, a
  /// star's dash is short.
  double get fill => switch (this) {
    DanceShape.chase => 0.42,
    DanceShape.triple => 0.44,
    DanceShape.duet => 0.36,
    DanceShape.comet => 0.62,
    DanceShape.stars => 0.20,
  };
}

/// The dance's clock: one beat a second, shared by every ring on the screen so
/// they change color together.
///
/// A [ChangeNotifier] rather than a stream: the app already listens to
/// notifiers everywhere, and a ring can read [tick] straight in build. It runs
/// only while something listens, and the app turns it off entirely when the
/// user turns the dance off, so no timer ticks behind a still app.
class DanceClock extends ChangeNotifier {
  DanceClock({this.enabled = true, this.speed = 1});

  /// Off: the clock stops and every ring draws still.
  bool enabled;

  /// Beats a second, 1 to 4 (Settings > Light dance > Beat speed). One is
  /// the plain "a color a second" the design asks for; four runs the
  /// lights briskly.
  int speed;

  int _tick = 0;
  Timer? _timer;

  /// One beat, from [speed].
  Duration get _beat =>
      Duration(microseconds: 1000000 ~/ speed.clamp(1, 4).toInt());

  /// The second the dance is on; it also drives the shapes' own motion.
  int get tick => _tick;

  /// Whether the beat is running: the app's switch turns it, and a test
  /// reads it instead of waiting on a timer it cannot see.
  bool get running => _timer != null;

  /// The phase 0 to 1 the arc has turned after [tick] seconds, for a ring
  /// that should keep moving: a third of a turn a second reads as a run
  /// without blurring into a blur of light.
  double get phase => (_tick % 3) / 3;

  /// The smooth phase, for painters that want a finer step than the beat.
  double phaseAt(double seconds) => (seconds / 3) % 1.0;

  void start() {
    if (_timer != null || !enabled) return;
    _timer = Timer.periodic(_beat, (_) {
      _tick++;
      notifyListeners();
    });
  }

  /// Changes the beat's speed; a running timer takes the new tempo, and
  /// the beat itself does not jump. The rings change color with it.
  void setSpeed(int value) {
    final next = value.clamp(1, 4).toInt();
    if (speed == next) return;
    speed = next;
    if (_timer != null) {
      stop();
      start();
    }
    notifyListeners();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Turns the dance on or off: the timer follows.
  void setEnabled(bool value) {
    if (enabled == value) return;
    enabled = value;
    if (value) {
      start();
    } else {
      stop();
    }
    notifyListeners();
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}

/// The dance, for everything under it: the beat's clock and the user's
/// settings (on or off, the shape, the speed). A page reads it with
/// [DanceScope.of] and, inside a ListenableBuilder on [DanceScope.clock],
/// redraws the rings on each beat.
///
/// Off (Settings > Light dance), the clock does not tick and every ring
/// draws still in its own state's color: the app's look without the motion.
class DanceScope extends InheritedWidget {
  const DanceScope({
    super.key,
    required this.clock,
    required this.settings,
    required super.child,
  });

  final DanceClock clock;
  final AppSettings settings;

  /// Whether the lights run: the user's switch and a tick that can happen.
  bool get on => settings.lightDance;

  /// The shape the rings take.
  DanceShape get shape => DanceShape.of(settings.danceShape);

  static DanceScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DanceScope>();

  /// The dance in this part of the tree; a page built without it (a test of
  /// one page alone) still gets a still, canary-colored dance rather than
  /// failing.
  static DanceScope of(BuildContext context) => maybeOf(context) ?? _fallback;

  static final _fallback = DanceScope._fallback();

  DanceScope._fallback()
    : clock = DanceClock(enabled: false),
      settings = AppSettings(),
      super(child: const SizedBox.shrink());

  @override
  bool updateShouldNotify(DanceScope old) =>
      old.clock != clock ||
      old.settings.lightDance != settings.lightDance ||
      old.settings.danceShape != settings.danceShape ||
      old.settings.danceSpeed != settings.danceSpeed;
}

/// A ring that redraws on the dance's beat: the shape's ring around [child],
/// in the beat's color. The control sits in the middle, unchanged.
class DancingRing extends StatelessWidget {
  const DancingRing({
    super.key,
    required this.child,
    this.live = false,
    this.radius,
    this.stroke = 2.4,
    this.pad = 8,
    this.glow = 1,
  });

  final Widget child;

  /// Whether the connection runs: a running ring dances in the beat's
  /// colors, a still one waits in canary yellow.
  final bool live;

  /// The ring's radius, in the box's own coordinates; the box's half its
  /// shorter side when null.
  final double? radius;
  final double stroke;
  final double pad;
  final double glow;

  @override
  Widget build(BuildContext context) {
    final dance = DanceScope.of(context);
    if (!dance.on) return child;
    return ListenableBuilder(
      listenable: dance.clock,
      builder: (context, _) {
        final tick = dance.clock.tick;
        final color = ringColor(live: live, tick: tick);
        final shape = dance.shape;
        return DanceRingBox(
          pad: pad,
          ring: DanceRing(
            radius: radius ?? 0,
            stroke: stroke,
            tick: tick,
            color: color,
            phase: dance.clock.phase,
            glow: glow,
            spokes: shape.spokes,
          ),
          child: child,
        );
      },
    );
  }
}

/// The turning phase for a ring that animates every frame (the connect ring
/// after a tap, before the core settles): from a repeating
/// [AnimationController], one lap every [seconds].
///
/// A ring showing the dance's beat does not need this: [DanceClock] changes
/// the color once a second, which is the whole point of the dance.
double spinPhase(Animation<double> controller, {double seconds = 3}) =>
    (controller.value * 3 / seconds) % 1.0;
