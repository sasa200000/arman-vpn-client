import 'dart:io';

import 'package:material_ui/material_ui.dart';

import '../app_settings.dart';
import '../core/android_core.dart';
import '../core/core_api.dart';
import '../core/core_controller.dart';
import '../core/models.dart';
import '../l10n/app_localizations.dart';
import 'about_page.dart';
import 'announcement_panel.dart';
import 'dance.dart';
import 'accounts_page.dart';
import 'focus_ring.dart';
import 'format.dart';
import 'logs_page.dart';
import 'mobile_shell.dart';
import 'overview_page.dart';
import 'port_dialog.dart';
import 'servers_page.dart';
import 'settings_page.dart';
import 'welcome_page.dart';
import 'widgets.dart';

ThemeData _theme(Brightness brightness, Locale locale) {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF5B5BD6),
    brightness: brightness,
  );
  final dark = brightness == Brightness.dark;
  // Bundled Inter for English, Vazirmatn for Persian and Arabic, and the
  // platform's typography for the remaining languages.
  final font = languageFont(locale.languageCode);
  final theme = ThemeData(
    colorScheme: scheme,
    fontFamily: font,
    scaffoldBackgroundColor: dark
        ? const Color(0xFF111218)
        : const Color(0xFFF5F5FA),
    cardTheme: CardThemeData(
      elevation: 0,
      color: dark ? const Color(0xFF1A1B23) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
    ),
  );
  return theme.copyWith(
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: dark ? const Color(0xFF15161D) : const Color(0xFFECECF4),
      // NavigationRail replaces DefaultTextStyle, so retain the resolved
      // platform font instead of letting a null family choose a fallback.
      selectedLabelTextStyle: theme.textTheme.labelLarge!.copyWith(
        fontSize: 15.5,
        fontWeight: FontWeight.w700,
        color: scheme.onSurface,
      ),
      unselectedLabelTextStyle: theme.textTheme.labelLarge!.copyWith(
        fontSize: 15.5,
        fontWeight: FontWeight.w600,
        color: scheme.onSurfaceVariant,
      ),
      selectedIconTheme: IconThemeData(
        size: 24,
        color: scheme.onSecondaryContainer,
      ),
      unselectedIconTheme: IconThemeData(
        size: 24,
        color: scheme.onSurfaceVariant,
      ),
    ),
  );
}

class VpnApp extends StatefulWidget {
  const VpnApp({
    super.key,
    required this.core,
    required this.settings,
    this.navigatorKey,
  });

  final CoreController core;
  final AppSettings settings;
  final GlobalKey<NavigatorState>? navigatorKey;

  static const localizationsDelegates = [
    AppLocalizations.delegate,
    ...GlobalMaterialLocalizations.delegates,
  ];

  @override
  State<VpnApp> createState() => _VpnAppState();
}

class _VpnAppState extends State<VpnApp> {
  /// The dance's beat, one for the whole app, so every ring changes color in
  /// step. It runs only while the dance is on (Settings > Light dance). In a
  /// test nothing ticks: a repeating timer would leave the test's own clock
  /// unsettled, and a still first frame has everything a test checks.
  late final DanceClock _dance = DanceClock(
    enabled: widget.settings.lightDance && !_testing,
    speed: widget.settings.danceSpeed,
  )..start();

  static final bool _testing = Platform.environment['FLUTTER_TEST'] == 'true';

  @override
  void initState() {
    super.initState();
    widget.settings.addListener(_syncDance);
  }

  void _syncDance() {
    _dance.setEnabled(widget.settings.lightDance && !_testing);
    _dance.setSpeed(widget.settings.danceSpeed);
  }

  @override
  void dispose() {
    widget.settings.removeListener(_syncDance);
    _dance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.settings,
    builder: (context, _) => DanceScope(
      clock: _dance,
      settings: widget.settings,
      child: MaterialApp(
        navigatorKey: widget.navigatorKey,
        onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
        debugShowCheckedModeBanner: false,
        locale: widget.settings.locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localeListResolutionCallback: (locales, _) =>
            AppSettings.localeOf(AppSettings.languageForList(locales)),
        localizationsDelegates: VpnApp.localizationsDelegates,
        // The theme depends on the resolved language for its font.
        builder: (context, child) {
          final locale = Localizations.localeOf(context);
          final dark = switch (widget.settings.themeMode) {
            ThemeMode.dark => true,
            ThemeMode.light => false,
            ThemeMode.system =>
              MediaQuery.platformBrightnessOf(context) == Brightness.dark,
          };
          return Theme(
            data: _theme(dark ? Brightness.dark : Brightness.light, locale),
            // A clear ring around what a remote or the keyboard chose.
            child: FocusRing(
              atStart: Platform.isAndroid && AndroidCore.isTv,
              child: child!,
            ),
          );
        },
        home: Shell(core: widget.core, settings: widget.settings),
      ),
    ),
  );
}

/// Whether this run is a Dart VM test. `flutter test` sets
/// FLUTTER_TEST=true; a plain `dart test` does not.
const bool _dartVmTest =
    bool.fromEnvironment('dart.vm.product') == false && _inTest;

/// Platform.environment is not available in a web build; the test bundle
/// marks itself with a define instead, and every other build passes false.
const bool _inTest = bool.fromEnvironment('V2RVPN_TEST');

class Shell extends StatefulWidget {
  const Shell({super.key, required this.core, required this.settings});

  final CoreController core;
  final AppSettings settings;

  @override
  State<Shell> createState() => _ShellState();
}

enum _Page { overview, servers, accounts, settings, logs, about }

class _ShellState extends State<Shell> {
  _Page _page = _Page.overview;

  /// The settings section the home page opened (Connection), until another
  /// page is chosen.
  SettingsSection? _settingsOpening;

  @override
  void initState() {
    super.initState();
    AndroidCore.homeRequests.addListener(_openHome);
  }

  void _openHome() {
    Navigator.of(context).popUntil((route) => route.isFirst);
    setState(() {
      _page = _Page.overview;
      _settingsOpening = null;
    });
  }

  @override
  void dispose() {
    AndroidCore.homeRequests.removeListener(_openHome);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.core,
    builder: (context, _) {
      final l = AppLocalizations.of(context);
      final core = widget.core;
      final status = core.status;
      final needsAttention = (core.accounts?.accounts ?? const [])
          .where((a) => a.enabled && a.needsSignIn)
          .length;
      if (widget.settings.firstRun && status != null) {
        return WelcomePage(core: core, settings: widget.settings);
      }
      final pages = [
        _Page.overview,
        _Page.servers,
        _Page.accounts,
        _Page.settings,
        _Page.logs,
        _Page.about,
      ];
      final page = pages.contains(_page) ? _page : _Page.overview;
      Widget accountsIcon(IconData icon) => Badge(
        isLabelVisible: needsAttention > 0,
        label: Text('$needsAttention'),
        child: Icon(icon),
      );
      // Each page's icons and name, for the side menu and the bottom bar.
      final items = [
        for (final page in pages)
          switch (page) {
            _Page.overview => (
              const Icon(Icons.dashboard_outlined),
              const Icon(Icons.dashboard_rounded),
              l.navOverview,
            ),
            _Page.servers => (
              const Icon(Icons.public_outlined),
              const Icon(Icons.public_rounded),
              l.navServers,
            ),
            _Page.accounts => (
              accountsIcon(Icons.people_outline_rounded),
              accountsIcon(Icons.people_rounded),
              l.navAccounts,
            ),
            _Page.settings => (
              const Icon(Icons.settings_outlined),
              const Icon(Icons.settings_rounded),
              l.navSettings,
            ),
            _Page.logs => (
              const Icon(Icons.receipt_long_outlined),
              const Icon(Icons.receipt_long_rounded),
              l.navLogs,
            ),
            _Page.about => (
              const Icon(Icons.info_outline_rounded),
              const Icon(Icons.info_rounded),
              l.navAbout,
            ),
          },
      ];
      final content = Column(
        children: [
          if (core.unavailable != null && status != null) const _LostBanner(),
          Expanded(
            child: status == null
                ? _NoCore(core: core)
                : switch (page) {
                    // Its cards open the pages beside it.
                    _Page.overview => OverviewPage(
                      core: core,
                      settings: widget.settings,
                      onOpenServers: () =>
                          setState(() => _page = _Page.servers),
                      onOpenAccounts: () =>
                          setState(() => _page = _Page.accounts),
                      onOpenConnection: () => setState(() {
                        _page = _Page.settings;
                        _settingsOpening = SettingsSection.connection;
                      }),
                      onOpenUpstreamProxy: () => setState(() {
                        _page = _Page.settings;
                        _settingsOpening = SettingsSection.upstreamProxy;
                      }),
                    ),
                    _Page.servers => ServersPage(
                      core: core,
                      settings: widget.settings,
                    ),
                    _Page.accounts => AccountsPage(
                      core: core,
                      settings: widget.settings,
                    ),
                    _Page.settings => SettingsPage(
                      key: ValueKey(_settingsOpening),
                      core: core,
                      settings: widget.settings,
                      opening: _settingsOpening,
                      onOpenLogs: () => setState(() => _page = _Page.logs),
                    ),
                    _Page.logs => LogsPage(
                      core: core,
                      settings: widget.settings,
                    ),
                    _Page.about => AboutPage(core: core),
                  },
          ),
        ],
      );
      void select(int i) => setState(() {
        _page = pages[i];
        _settingsOpening = null;
      });
      // Android (a phone, or a tablet in either orientation) and a narrow
      // window: the phone layout, Home and Settings. The computer layout
      // offers computer-only choices, such as Windows' system proxy.
      if (Platform.isAndroid || MediaQuery.sizeOf(context).width < 640) {
        return MobileShell(
          core: core,
          settings: widget.settings,
          banner: core.unavailable != null && status != null
              ? const _LostBanner()
              : null,
          noCore: status == null ? _NoCore(core: core) : null,
        );
      }
      return Scaffold(
        body: AnnouncementOverlay(
          settings: widget.settings,
          onOpenUpdates: () => setState(() => _page = _Page.about),
          child: Row(
            children: [
              NavigationRail(
                selectedIndex: pages.indexOf(page),
                onDestinationSelected: select,
                // Icons with their names beside them.
                extended: true,
                minExtendedWidth: 190,
                leading: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                  child: Row(
                    children: [
                      const AppLogo(size: 34),
                      const SizedBox(width: 10),
                      Text(
                        l.appTitle,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                destinations: [
                  for (final (icon, selected, label) in items)
                    NavigationRailDestination(
                      icon: icon,
                      selectedIcon: selected,
                      label: Text(label),
                    ),
                ],
                // The traffic at the bottom of the menu; in a short window the
                // pages above it scroll rather than run under it.
                trailing: _TrafficPanel(traffic: status?.traffic),
                trailingAtBottom: true,
                scrollable: true,
              ),
              // A maximized window: the pages stay as wide as reads well; the
              // home page, centered by itself, keeps its colors to the edges.
              Expanded(
                child: page == _Page.overview || status == null
                    ? content
                    : Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1000),
                          child: content,
                        ),
                      ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// The side menu's traffic: the speed now and the total since the core
/// started, through Mozilla, up and down.
class _TrafficPanel extends StatelessWidget {
  const _TrafficPanel({required this.traffic});

  final Traffic? traffic;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = traffic;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      child: SizedBox(
        width: 166,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _TrafficCard(
              title: l.liveTraffic,
              up: formatRate(t?.upRate ?? 0),
              down: formatRate(t?.downRate ?? 0),
              live: true,
            ),
            const SizedBox(height: 8),
            _TrafficCard(
              title: l.totalTraffic,
              up: formatBytes(t?.up ?? 0),
              down: formatBytes(t?.down ?? 0),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrafficCard extends StatelessWidget {
  const _TrafficCard({
    required this.title,
    required this.up,
    required this.down,
    this.live = false,
  });

  final String title;
  final String up;
  final String down;

  /// Whether the speed is the live one: its rings dance with the beat, one
  /// around the up arrow and one around the down.
  final bool live;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dance = DanceScope.of(context);
    final value = theme.textTheme.bodySmall?.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    Widget line(IconData icon, Color color, String text) => Row(
      children: [
        Icon(icon, size: 14, color: color),
        const Spacer(),
        Text(text, style: value),
      ],
    );
    Widget content() => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.labelMedium),
        const SizedBox(height: 4),
        live && dance.on
            ? _DancedLine(
                tick: dance.clock.tick,
                shape: dance.shape,
                color: ringColor(live: true, tick: dance.clock.tick),
                icon: Icons.arrow_upward_rounded,
                text: up,
                style: value,
              )
            : line(Icons.arrow_upward_rounded, StatusColors.good, up),
        live && dance.on
            ? _DancedLine(
                tick: dance.clock.tick,
                shape: dance.shape,
                color: ringColor(live: true, tick: dance.clock.tick),
                icon: Icons.arrow_downward_rounded,
                text: down,
                style: value,
              )
            : line(
                Icons.arrow_downward_rounded,
                theme.colorScheme.primary,
                down,
              ),
      ],
    );
    final card = Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: content(),
    );
    if (!live || !dance.on) return card;
    // The live traffic card has the dance's ring around it, changing color
    // with the speed it shows.
    return ListenableBuilder(
      listenable: dance.clock,
      builder: (context, _) => DanceRingBox(
        pad: 5,
        ring: DanceRing(
          radius: 0,
          stroke: 1.8,
          tick: dance.clock.tick,
          color: ringColor(live: true, tick: dance.clock.tick),
          phase: (dance.clock.tick % 3) / 3,
          spokes: dance.shape.spokes,
        ),
        child: card,
      ),
    );
  }
}

/// One line of the live traffic card with a small dancing ring around its
/// arrow, so the download and the upload each pulse too.
class _DancedLine extends StatelessWidget {
  const _DancedLine({
    required this.tick,
    required this.shape,
    required this.color,
    required this.icon,
    required this.text,
    this.style,
  });

  final int tick;
  final DanceShape shape;
  final Color color;
  final IconData icon;
  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox.square(
        dimension: 22,
        child: DanceRingBox(
          pad: 3,
          ring: DanceRing(
            radius: 0,
            stroke: 1.3,
            tick: tick,
            color: color,
            phase: (tick % 3) / 3,
            spokes: shape.spokes,
          ),
          child: Center(child: Icon(icon, size: 12, color: color)),
        ),
      ),
      const Spacer(),
      Text(text, style: style),
    ],
  );
}

class _LostBanner extends StatelessWidget {
  const _LostBanner();

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    color: StatusColors.bad.withValues(alpha: 0.14),
    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
    child: Row(
      children: [
        const Icon(Icons.link_off_rounded, size: 18, color: StatusColors.bad),
        const SizedBox(width: 10),
        Expanded(child: Text(AppLocalizations.of(context).coreLost)),
      ],
    ),
  );
}

class _NoCore extends StatelessWidget {
  const _NoCore({required this.core});

  final CoreController core;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final problem = core.unavailable;
    final portTaken =
        problem != null &&
        (problem.problem == CoreProblem.portInUse ||
            problem.problem == CoreProblem.refused);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (problem == null || problem.problem == CoreProblem.starting) ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(l.startingCore, style: theme.textTheme.titleMedium),
            ] else ...[
              Icon(
                Icons.power_off_rounded,
                size: 48,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(l.cantReachCore, style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                describeProblem(l, problem),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  if (portTaken && core.moveStoppedCore != null)
                    FilledButton.icon(
                      onPressed: () async {
                        final port = await showPortDialog(
                          context,
                          taken: problem.detail,
                        );
                        if (port != null && context.mounted) {
                          await runShowingErrors(
                            context,
                            () => core.setAppPort(port),
                          );
                        }
                      },
                      icon: const Icon(Icons.settings_ethernet_rounded),
                      label: Text(l.changePort),
                    ),
                  FilledButton.tonalIcon(
                    onPressed: core.retry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(l.retry),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
