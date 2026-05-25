import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:printing/printing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:url_launcher/url_launcher.dart';

import 'core/services/app_review_service.dart';
import 'core/services/app_update_service.dart';
import 'core/services/onboarding_service.dart';
import 'features/agendamento/pages/agendamento_concretagem_page.dart';
import 'features/obras/pages/obras_page.dart';
import 'cws_calculator_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _configureDatabaseFactory();
  Intl.defaultLocale = 'pt_BR';
  await initializeDateFormatting('pt_BR', null);
  runApp(const NetherlandApp());
}

Future<void> _configureDatabaseFactory() async {
  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
    return;
  }

  switch (defaultTargetPlatform) {
    case TargetPlatform.windows:
    case TargetPlatform.linux:
    case TargetPlatform.macOS:
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      return;
    case TargetPlatform.android:
    case TargetPlatform.iOS:
    case TargetPlatform.fuchsia:
      return;
  }
}

Future<String> _loadAppVersionLabel() async {
  final packageInfo = await PackageInfo.fromPlatform();
  return '${packageInfo.version} (build ${packageInfo.buildNumber})';
}

class NetherlandApp extends StatelessWidget {
  const NetherlandApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Netherland Admix Control',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('pt', 'BR')],
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF1E3A5F),
        scaffoldBackgroundColor: Colors.transparent,
      ),
      builder: (context, child) {
        return Actions(
          actions: <Type, Action<Intent>>{
            EditableTextTapOutsideIntent:
                CallbackAction<EditableTextTapOutsideIntent>(
                  onInvoke: (intent) {
                    intent.focusNode.unfocus();
                    return null;
                  },
                ),
          },
          child: _AppWatermarkBackground(
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
      home: const AppGate(),
    );
  }
}

class _AppWatermarkBackground extends StatelessWidget {
  final Widget child;

  const _AppWatermarkBackground({required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: Color(0xFFF3F5F7)),
      child: Stack(
        fit: StackFit.expand,
        children: [
          IgnorePointer(
            child: Align(
              alignment: const Alignment(0, 0.55),
              child: Opacity(
                opacity: 0.045,
                child: Image.asset(
                  'assets/logos/netherland.png',
                  width: 360,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class AppGate extends StatefulWidget {
  static const String _previewPage = String.fromEnvironment(
    'SCREENSHOT_PAGE',
    defaultValue: '',
  );

  const AppGate({super.key});

  @override
  State<AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<AppGate> {
  bool _showSplash = true;
  bool _updateCheckStarted = false;
  final _homePageKey = GlobalKey<_HomePageState>();
  late final AppUpdateService _appUpdateService;

  @override
  void initState() {
    super.initState();
    _appUpdateService = AppUpdateService();
    _bootstrap();
  }

  @override
  void dispose() {
    _appUpdateService.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await Future<void>.delayed(const Duration(milliseconds: 1800));

    if (!mounted) return;

    await Future<void>.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;

    setState(() {
      _showSplash = false;
    });

    await Future<void>.delayed(const Duration(milliseconds: 950));
    if (!mounted) return;

    await _homePageKey.currentState?._showHomeOnboardingIfNeeded();
    if (!mounted) return;

    unawaited(_maybeShowUpdateDialog());
  }

  Future<void> _maybeShowUpdateDialog() async {
    if (_updateCheckStarted || AppGate._previewPage.isNotEmpty) return;
    _updateCheckStarted = true;

    AppUpdateInfo? updateInfo;
    try {
      updateInfo = await _appUpdateService.checkForUpdate();
    } catch (_) {
      return;
    }

    if (!mounted || updateInfo == null) return;
    final update = updateInfo;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Atualizacao disponivel'),
        content: Text(
          'Ha uma nova versao do ${update.appName} disponivel na App Store.\n\n'
          'Instalada: ${update.installedVersion} '
          '(build ${update.installedBuildNumber})\n'
          'Disponivel: ${update.storeVersion}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Depois'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              unawaited(_openAppStore(update));
            },
            icon: const Icon(Icons.open_in_new),
            label: const Text('Atualizar'),
          ),
        ],
      ),
    );
  }

  Future<void> _openAppStore(AppUpdateInfo updateInfo) async {
    if (await launchUrl(
      updateInfo.storeUri,
      mode: LaunchMode.externalApplication,
    )) {
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Nao foi possivel abrir a App Store.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (AppGate._previewPage.isNotEmpty) {
      return _previewPage(AppGate._previewPage);
    }

    return Stack(
      children: [
        HomePage(key: _homePageKey),
        IgnorePointer(
          ignoring: !_showSplash,
          child: AnimatedOpacity(
            opacity: _showSplash ? 1 : 0,
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOut,
            child: const _SplashScreen(),
          ),
        ),
      ],
    );
  }

  Widget _previewPage(String previewPage) {
    switch (previewPage) {
      case 'calculator':
        return const CwsCalculatorPage();
      case 'obras':
        return const ObrasPage();
      case 'literatura':
        return const LiteraturaTecnicaPage();
      case 'agendamento':
        return AgendamentoConcretagemPage(
          onBackFallback: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const HomePage()),
            );
          },
        );
      case 'about':
        return const AboutPage();
      case 'dashboard':
      default:
        return const HomePage();
    }
  }
}

class _SplashScreen extends StatefulWidget {
  const _SplashScreen();

  @override
  State<_SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<_SplashScreen> {
  late final Future<String> _versionLabelFuture;

  @override
  void initState() {
    super.initState();
    _versionLabelFuture = _loadAppVersionLabel();
  }

  @override
  Widget build(BuildContext context) {
    const brandBlue = Color(0xFF1E3A5F);
    const titleStyle = TextStyle(
      fontSize: 30,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.2,
      color: brandBlue,
      height: 1.0,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F7),
      body: FutureBuilder<String>(
        future: _versionLabelFuture,
        builder: (context, snapshot) {
          final versionLabel = snapshot.data ?? 'Carregando...';

          return SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 390;
                final logoHeight = isCompact ? 78.0 : 96.0;
                final dividerHeight = isCompact ? 58.0 : 72.0;
                final spacing = isCompact ? 14.0 : 18.0;
                final topSpacing = isCompact
                    ? constraints.maxHeight * 0.22
                    : constraints.maxHeight * 0.18;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      SizedBox(height: topSpacing.clamp(96.0, 180.0)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Image.asset(
                              'assets/logos/netherland.png',
                              height: logoHeight,
                              fit: BoxFit.contain,
                            ),
                          ),
                          SizedBox(width: spacing),
                          Container(
                            width: 1,
                            height: dividerHeight,
                            color: const Color(0xFF1E3A5F),
                          ),
                          SizedBox(width: spacing),
                          Flexible(
                            child: Image.asset(
                              'assets/logos/cwsadmix.jpg',
                              height: logoHeight,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: isCompact ? 24 : 28),
                      const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Netherland Admix',
                          style: titleStyle,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 1100),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, child) {
                          final clampedValue = value.clamp(0.0, 1.0);

                          return Opacity(
                            opacity: clampedValue,
                            child: Transform.translate(
                              offset: Offset(18 * (1 - clampedValue), 0),
                              child: child,
                            ),
                          );
                        },
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              'Control',
                              softWrap: false,
                              style: GoogleFonts.caveat(
                                fontSize: isCompact ? 29 : 31,
                                fontWeight: FontWeight.w700,
                                fontStyle: FontStyle.italic,
                                color: brandBlue,
                                height: 1.0,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const Spacer(flex: 2),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: Text(
                          versionLabel,
                          style: TextStyle(
                            fontSize: isCompact ? 12 : 13,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                            color: brandBlue.withValues(alpha: 0.75),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _onboardingService = OnboardingService();
  final _scrollController = ScrollController();
  final _calculatorKey = GlobalKey();
  final _obrasKey = GlobalKey();
  final _literaturaKey = GlobalKey();
  final _agendamentoKey = GlobalKey();
  final _aboutKey = GlobalKey();
  final _obrasShortcutKey = GlobalKey();

  bool _tutorialShowing = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _openObras(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ObrasPage()));
  }

  void _openCalculator(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const CwsCalculatorPage()));
  }

  void _openLiteraturaTecnica(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const LiteraturaTecnicaPage()));
  }

  void _openAgendamentoConcretagem(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AgendamentoConcretagemPage()),
    );
  }

  Future<void> _openAbout(BuildContext context) async {
    final replayOnboarding = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const AboutPage()));
    if (!mounted || replayOnboarding != true) return;

    await _onboardingService.resetHomeOnboarding();
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;
    await _showHomeOnboarding(force: true);
  }

  Future<void> _showHomeOnboardingIfNeeded() async {
    if (AppGate._previewPage.isNotEmpty) return;
    final shouldShow = await _onboardingService.shouldShowHomeOnboarding();
    if (!shouldShow || !mounted) return;
    await _showHomeOnboarding();
  }

  Future<void> _showHomeOnboarding({bool force = false}) async {
    if (_tutorialShowing) return;
    if (!force) {
      final shouldShow = await _onboardingService.shouldShowHomeOnboarding();
      if (!shouldShow) return;
    }
    if (!mounted) return;

    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;

    _tutorialShowing = true;
    final completer = Completer<void>();

    void closeTutorial() {
      _finishHomeOnboarding();
      if (!completer.isCompleted) completer.complete();
    }

    TutorialCoachMark(
      targets: _homeOnboardingTargets(),
      colorShadow: const Color(0xFF0F172A),
      opacityShadow: 0.82,
      paddingFocus: 8,
      pulseEnable: false,
      textSkip: 'Pular',
      textStyleSkip: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w800,
      ),
      alignSkip: Alignment.topRight,
      showSkipInLastTarget: false,
      beforeFocus: _scrollToOnboardingTarget,
      onFinish: closeTutorial,
      onSkip: () {
        closeTutorial();
        return true;
      },
    ).show(context: context);

    return completer.future;
  }

  Future<void> _scrollToOnboardingTarget(TargetFocus target) async {
    final key = switch (target.identify) {
      'calculator' => _calculatorKey,
      'obras' => _obrasKey,
      'literatura' => _literaturaKey,
      'agendamento' => _agendamentoKey,
      'about' => _aboutKey,
      'obras_shortcut' => _obrasShortcutKey,
      _ => null,
    };
    final targetContext = key?.currentContext;
    if (targetContext == null) return;

    await Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      alignment: 0.24,
    );
    await Future<void>.delayed(const Duration(milliseconds: 80));
  }

  void _finishHomeOnboarding() {
    _tutorialShowing = false;
    unawaited(_onboardingService.markHomeOnboardingSeen());
  }

  List<TargetFocus> _homeOnboardingTargets() {
    return [
      _homeOnboardingTarget(
        identify: 'calculator',
        key: _calculatorKey,
        title: 'Calculadora CWS',
        body:
            'Calcule a dosagem do CWS Admix pelo volume da concretagem e siga para a solicitação comercial.',
        align: ContentAlign.bottom,
      ),
      _homeOnboardingTarget(
        identify: 'obras',
        key: _obrasKey,
        title: 'Obras',
        body:
            'Cadastre uma obra, acompanhe concretagens, lançamentos, fotos, notas fiscais e relatórios.',
        align: ContentAlign.bottom,
      ),
      _homeOnboardingTarget(
        identify: 'literatura',
        key: _literaturaKey,
        title: 'Literatura técnica',
        body:
            'Consulte ficha técnica e orientações de cura do concreto sem sair do aplicativo.',
        align: ContentAlign.top,
      ),
      _homeOnboardingTarget(
        identify: 'agendamento',
        key: _agendamentoKey,
        title: 'Agendamento',
        body:
            'Programe uma concretagem futura e compartilhe o compromisso com quem precisa acompanhar.',
        align: ContentAlign.top,
      ),
      _homeOnboardingTarget(
        identify: 'about',
        key: _aboutKey,
        title: 'Sobre e suporte',
        body:
            'Aqui ficam versão do app, suporte, feedback, avaliação e a opção de rever esta introdução.',
        align: ContentAlign.bottom,
        radius: 28,
      ),
    ];
  }

  TargetFocus _homeOnboardingTarget({
    required String identify,
    required GlobalKey key,
    required String title,
    required String body,
    required ContentAlign align,
    double radius = 20,
  }) {
    final isLast = identify == 'about';
    return TargetFocus(
      identify: identify,
      keyTarget: key,
      shape: ShapeLightFocus.RRect,
      radius: radius,
      paddingFocus: 8,
      enableOverlayTab: true,
      contents: [
        TargetContent(
          align: align,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          builder: (context, controller) {
            return _OnboardingTipCard(
              title: title,
              body: body,
              actionLabel: isLast ? 'Concluir' : 'Próximo',
              onPressed: controller.next,
            );
          },
        ),
      ],
    );
  }

  Widget _quickAccessIntro({bool compact = false}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(4, 0, 4, compact ? 8 : 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Acessos rápidos',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
              color: Color(0xFF1E3A5F),
            ),
          ),
          SizedBox(height: compact ? 2 : 4),
          Text(
            'Toque em um card para abrir a área desejada.',
            style: TextStyle(
              fontSize: 13,
              height: compact ? 1.25 : 1.35,
              color: const Color(0xFF5A6878),
            ),
          ),
        ],
      ),
    );
  }

  List<String> _menuTitleLines(String title) {
    final words = title.trim().split(RegExp(r'\s+'));
    if (words.length <= 1) return [title.trim()];
    if (words.length == 2) return words;
    return [words.first, words.skip(1).join(' ')];
  }

  Widget _menuButtonTitle({
    required BuildContext context,
    required String title,
    required Color color,
  }) {
    final style = Theme.of(context).textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w800,
      color: color,
      letterSpacing: 0,
    );
    final lines = _menuTitleLines(title);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < lines.length; index++) ...[
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                lines[index],
                maxLines: 1,
                overflow: TextOverflow.visible,
                softWrap: false,
                style: style,
              ),
            ),
          ),
          if (index < lines.length - 1) const SizedBox(height: 2),
        ],
      ],
    );
  }

  Widget _menuButton({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required VoidCallback onTap,
    GlobalKey? targetKey,
    bool compact = false,
    double? bottomSpacing,
  }) {
    const surfaceColor = Color(0xFFFFFFFF);
    const textColor = Color(0xFF1C2430);
    const subtitleColor = Color(0xFF556273);

    return Padding(
      padding: EdgeInsets.only(bottom: bottomSpacing ?? (compact ? 10 : 12)),
      child: Semantics(
        button: true,
        label: '$title. $subtitle',
        hint: 'Toque para abrir',
        child: Material(
          key: targetKey,
          color: surfaceColor,
          elevation: 2,
          shadowColor: const Color(0xFF1E3A5F).withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(22),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: accentColor.withValues(alpha: 0.15)),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [surfaceColor, accentColor.withValues(alpha: 0.07)],
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: -14,
                    right: -12,
                    child: IgnorePointer(
                      child: Container(
                        width: 92,
                        height: 92,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: accentColor.withValues(alpha: 0.08),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(compact ? 14 : 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: compact ? 52 : 56,
                              height: compact ? 52 : 56,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    accentColor.withValues(alpha: 0.15),
                                    accentColor.withValues(alpha: 0.26),
                                  ],
                                ),
                              ),
                              child: Icon(icon, size: 28, color: accentColor),
                            ),
                            const Spacer(),
                            Container(
                              width: compact ? 38 : 40,
                              height: compact ? 38 : 40,
                              decoration: BoxDecoration(
                                color: accentColor,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.arrow_forward_rounded,
                                size: 18,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: compact ? 10 : 12),
                        _menuButtonTitle(
                          context: context,
                          title: title,
                          color: textColor,
                        ),
                        SizedBox(height: compact ? 3 : 4),
                        Text(
                          subtitle,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: subtitleColor,
                                height: compact ? 1.22 : 1.3,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _primaryQuickAccessRow({
    required BuildContext context,
    required bool compact,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useTwoColumns = constraints.maxWidth >= 360;
        final rowSpacing = compact ? 10.0 : 12.0;
        final cardCompact = compact || constraints.maxWidth < 560;

        if (!useTwoColumns) {
          return Column(
            children: [
              _menuButton(
                context: context,
                title: 'Calculadora CWS',
                subtitle:
                    'Calcule a quantidade de aditivo para sua concretagem e solicite uma cotação.',
                icon: Icons.calculate,
                accentColor: const Color(0xFF2B63A7),
                onTap: () => _openCalculator(context),
                targetKey: _calculatorKey,
                compact: compact,
              ),
              _menuButton(
                context: context,
                title: 'Obras',
                subtitle:
                    'Cadastre sua obra, controle sua concretagem e gere relatórios locais em PDF ou CSV.',
                icon: Icons.apartment,
                accentColor: const Color(0xFF1B7A73),
                onTap: () => _openObras(context),
                targetKey: _obrasKey,
                compact: compact,
              ),
            ],
          );
        }

        return Padding(
          padding: EdgeInsets.only(bottom: rowSpacing),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _menuButton(
                    context: context,
                    title: 'Calculadora CWS',
                    subtitle:
                        'Calcule a quantidade de aditivo para sua concretagem e solicite uma cotação.',
                    icon: Icons.calculate,
                    accentColor: const Color(0xFF2B63A7),
                    onTap: () => _openCalculator(context),
                    targetKey: _calculatorKey,
                    compact: cardCompact,
                    bottomSpacing: 0,
                  ),
                ),
                SizedBox(width: rowSpacing),
                Expanded(
                  child: _menuButton(
                    context: context,
                    title: 'Obras',
                    subtitle:
                        'Cadastre sua obra, controle sua concretagem e gere relatórios locais em PDF ou CSV.',
                    icon: Icons.apartment,
                    accentColor: const Color(0xFF1B7A73),
                    onTap: () => _openObras(context),
                    targetKey: _obrasKey,
                    compact: cardCompact,
                    bottomSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _secondaryQuickAccessRow({
    required BuildContext context,
    required bool compact,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useTwoColumns = constraints.maxWidth >= 360;
        final rowSpacing = compact ? 10.0 : 12.0;
        final cardCompact = compact || constraints.maxWidth < 560;

        if (!useTwoColumns) {
          return Column(
            children: [
              _menuButton(
                context: context,
                title: 'Literatura técnica',
                subtitle:
                    'Acesse ficha técnica e orientações para consulta rápida em campo.',
                icon: Icons.menu_book_outlined,
                accentColor: const Color(0xFF9A621A),
                onTap: () => _openLiteraturaTecnica(context),
                targetKey: _literaturaKey,
                compact: compact,
              ),
              _menuButton(
                context: context,
                title: 'Agendamento de Concretagem',
                subtitle:
                    'Programe concretagens futuras e compartilhe convites de calendário.',
                icon: Icons.event_note_outlined,
                accentColor: const Color(0xFF5F4CA8),
                onTap: () => _openAgendamentoConcretagem(context),
                targetKey: _agendamentoKey,
                compact: compact,
              ),
            ],
          );
        }

        return Padding(
          padding: EdgeInsets.only(bottom: rowSpacing),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _menuButton(
                    context: context,
                    title: 'Literatura técnica',
                    subtitle:
                        'Acesse ficha técnica e orientações para consulta rápida em campo.',
                    icon: Icons.menu_book_outlined,
                    accentColor: const Color(0xFF9A621A),
                    onTap: () => _openLiteraturaTecnica(context),
                    targetKey: _literaturaKey,
                    compact: cardCompact,
                    bottomSpacing: 0,
                  ),
                ),
                SizedBox(width: rowSpacing),
                Expanded(
                  child: _menuButton(
                    context: context,
                    title: 'Agendamento de Concretagem',
                    subtitle:
                        'Programe concretagens futuras e compartilhe convites de calendário.',
                    icon: Icons.event_note_outlined,
                    accentColor: const Color(0xFF5F4CA8),
                    onTap: () => _openAgendamentoConcretagem(context),
                    targetKey: _agendamentoKey,
                    compact: cardCompact,
                    bottomSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _brandingWatermark({bool compact = false}) {
    final cardHeight = compact ? 118.0 : 141.0;
    final logoHeight = compact ? 56.0 : 62.0;
    final dividerHeight = compact ? 42.0 : 48.0;
    final horizontalSpacing = compact ? 18.0 : 22.0;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: SizedBox(
        height: cardHeight,
        child: Center(
          child: Opacity(
            opacity: 0.9,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('assets/logos/netherland.png', height: logoHeight),
                SizedBox(width: horizontalSpacing),
                Container(
                  width: 1,
                  height: dividerHeight,
                  color: const Color(0xFF1E3A5F),
                ),
                SizedBox(width: horizontalSpacing),
                Image.asset('assets/logos/cwsadmix.jpg', height: logoHeight),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _literaturaBanner() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 168,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ShaderMask(
              shaderCallback: (bounds) {
                return const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.white,
                    Colors.white,
                    Colors.transparent,
                  ],
                  stops: [0.0, 0.16, 0.84, 1.0],
                ).createShader(bounds);
              },
              blendMode: BlendMode.dstIn,
              child: Opacity(
                opacity: 0.75,
                child: Image.asset(
                  'assets/marketing/cws_dashboard_banner.jpg',
                  fit: BoxFit.cover,
                  alignment: const Alignment(-0.08, -0.52),
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    const Color(0xFFF3F5F7),
                    const Color(0xFFF3F5F7).withValues(alpha: 0.35),
                    const Color(0xFFF3F5F7),
                  ],
                  stops: const [0.0, 0.52, 1.0],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCompactDashboard = MediaQuery.sizeOf(context).height < 860;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F7),
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            key: _aboutKey,
            tooltip: 'Sobre',
            icon: const Icon(Icons.info_outline),
            onPressed: () => _openAbout(context),
          ),
          IconButton(
            key: _obrasShortcutKey,
            tooltip: 'Obras',
            icon: const Icon(Icons.apartment),
            onPressed: () => _openObras(context),
          ),
        ],
      ),
      body: ListView(
        controller: _scrollController,
        padding: EdgeInsets.fromLTRB(16, isCompactDashboard ? 8 : 16, 16, 16),
        children: [
          _brandingWatermark(compact: isCompactDashboard),
          SizedBox(height: isCompactDashboard ? 12 : 18),
          _quickAccessIntro(compact: isCompactDashboard),
          _primaryQuickAccessRow(context: context, compact: isCompactDashboard),
          _secondaryQuickAccessRow(
            context: context,
            compact: isCompactDashboard,
          ),
          const SizedBox(height: 4),
          _literaturaBanner(),
        ],
      ),
    );
  }
}

class _OnboardingTipCard extends StatelessWidget {
  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback onPressed;

  const _OnboardingTipCard({
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF1E3A5F),
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  body,
                  style: const TextStyle(
                    color: Color(0xFF3F4C5A),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: onPressed,
                    child: Text(actionLabel),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  late final Future<String> _versionLabelFuture;
  final _reviewService = AppReviewService();

  static final Uri _supportEmailUri = Uri.parse(
    'mailto:netherland@netherland.com.br?subject=Suporte%20-%20CWS%20Admix%20Control',
  );

  @override
  void initState() {
    super.initState();
    _versionLabelFuture = _loadVersionLabel();
  }

  Future<String> _loadVersionLabel() async {
    return _loadAppVersionLabel();
  }

  Future<void> _openSupportEmail(BuildContext context) async {
    if (await launchUrl(_supportEmailUri)) return;
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Nao foi possivel abrir o email de suporte.'),
      ),
    );
  }

  Future<void> _openFeedbackEmail(
    BuildContext context, {
    required String versionLabel,
  }) async {
    final opened = await _reviewService.openFeedbackEmail(
      versionLabel: versionLabel,
    );
    if (!context.mounted || opened) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Nao foi possivel abrir o email de feedback.'),
      ),
    );
  }

  Future<void> _openAppReview(BuildContext context) async {
    final result = await _reviewService.openStoreListing();
    if (!context.mounted) return;

    final message = switch (result) {
      AppReviewRequestResult.openedStore => null,
      AppReviewRequestResult.requested => null,
      AppReviewRequestResult.missingAppStoreId =>
        'A avaliacao pela App Store sera ativada quando o app estiver publicado.',
      AppReviewRequestResult.unsupportedPlatform =>
        'A avaliacao direta esta disponivel no Android e no iOS.',
      AppReviewRequestResult.failed =>
        'Nao foi possivel abrir a loja para avaliacao.',
    };

    if (message == null) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _replayOnboarding(BuildContext context) {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop(true);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Abra o Dashboard para rever a introducao guiada.'),
      ),
    );
  }

  Widget _infoTile({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: const Color(0xFFD8E3F8),
        child: Icon(icon, color: const Color(0xFF1E3A5F)),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(value),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F7),
      appBar: AppBar(title: const Text('Sobre')),
      body: FutureBuilder<String>(
        future: _versionLabelFuture,
        builder: (context, snapshot) {
          final versionLabel = snapshot.data ?? 'Carregando...';

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Image.asset(
                            'assets/logos/netherland.png',
                            height: 32,
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'CWS Admix Control',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1E3A5F),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Sistema para controle e acompanhamento operacional de obras e concretos aditivados com CWS Admix.',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      _infoTile(
                        icon: Icons.verified_outlined,
                        title: 'Versao',
                        value: versionLabel,
                      ),
                      const Divider(height: 18),
                      _infoTile(
                        icon: Icons.business_outlined,
                        title: 'Copyright',
                        value: '2026 Netherland Engenharia e Comercio Ltda.',
                      ),
                      const Divider(height: 18),
                      _infoTile(
                        icon: Icons.support_agent_outlined,
                        title: 'Suporte',
                        value: 'netherland@netherland.com.br',
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _openSupportEmail(context),
                              icon: const Icon(Icons.email_outlined),
                              label: const Text('Enviar email'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _openAppReview(context),
                              icon: const Icon(Icons.star_outline),
                              label: const Text('Avaliar o app'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _openFeedbackEmail(
                                context,
                                versionLabel: versionLabel,
                              ),
                              icon: const Icon(Icons.rate_review_outlined),
                              label: const Text('Enviar feedback'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton.icon(
                              onPressed: () => _replayOnboarding(context),
                              icon: const Icon(Icons.tips_and_updates_outlined),
                              label: const Text('Ver introducao novamente'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: snapshot.hasData
                                  ? () => showLicensePage(
                                      context: context,
                                      applicationName: 'CWS Admix Control',
                                      applicationVersion: versionLabel,
                                    )
                                  : null,
                              child: const Text('Ver licencas'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class LiteraturaTecnicaPage extends StatelessWidget {
  const LiteraturaTecnicaPage({super.key});

  static const String _fichaTecnicaAsset =
      'assets/docs/ficha_tecnica_cws_admix_2026.pdf';
  static const String _curaConcretoAsset =
      'assets/docs/orientacao_tecnica_cura_do_concreto.pdf';
  static final Uri _whatsAppUri = Uri.parse(
    'https://wa.me/5541999731741?text=Ol%C3%A1%2C%20gostaria%20de%20solicitar%20a%20FDS%20do%20CWS%20Admix.',
  );
  static final Uri _emailUri = Uri.parse(
    'mailto:luizmarcos@netherland.com.br?subject=Solicita%C3%A7%C3%A3o%20de%20FDS%20CWS%20Admix',
  );
  static final Uri _siteUri = Uri.parse('https://www.netherland.com.br');

  Future<void> _abrirLink(
    BuildContext context, {
    required Uri uri,
    required String label,
  }) async {
    if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Nao foi possivel abrir "$label".')));
  }

  TextSpan _linkSpan(
    BuildContext context, {
    required String label,
    required Uri uri,
  }) {
    return TextSpan(
      text: label,
      style: const TextStyle(
        color: Color(0xFF355C96),
        decoration: TextDecoration.underline,
        fontWeight: FontWeight.w600,
      ),
      recognizer: (TapGestureRecognizer()
        ..onTap = () {
          _abrirLink(context, uri: uri, label: label);
        }),
    );
  }

  Widget _docCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback primaryAction,
    required String primaryLabel,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFFD8E3F8),
                  child: Icon(icon, color: const Color(0xFF1E3A5F)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(subtitle),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: primaryAction,
                  icon: const Icon(Icons.open_in_new),
                  label: Text(primaryLabel),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _abrirPdf(
    BuildContext context, {
    required String assetPath,
    required String title,
  }) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final pdfBytes = await rootBundle.load(assetPath);
      if (!context.mounted) return;
      await navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => DocumentoPdfPage(
            title: title,
            bytes: pdfBytes.buffer.asUint8List(),
          ),
        ),
      );
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(content: Text('Nao foi possivel abrir "$title".')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F7),
      appBar: AppBar(title: const Text('Literatura técnica')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Padding(
              padding: EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Materiais de apoio',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Abra os documentos tecnicos abaixo para consulta rapida durante visitas e acompanhamento de obra.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          _docCard(
            context,
            title: 'Ficha técnica CWS Admix',
            subtitle:
                'Informacoes tecnicas, instrucoes para uso, armazenamento e suporte.',
            icon: Icons.description_outlined,
            primaryLabel: 'Abrir documento',
            primaryAction: () => _abrirPdf(
              context,
              assetPath: _fichaTecnicaAsset,
              title: 'Ficha técnica CWS Admix',
            ),
          ),
          _docCard(
            context,
            title: 'Orientação técnica para a cura do concreto',
            subtitle: 'Boas praticas e orientacoes de aplicacao.',
            icon: Icons.fact_check_outlined,
            primaryLabel: 'Abrir documento',
            primaryAction: () => _abrirPdf(
              context,
              assetPath: _curaConcretoAsset,
              title: 'Orientação técnica para a cura do concreto',
            ),
          ),
          const SizedBox(height: 10),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const CircleAvatar(
                        backgroundColor: Color(0xFFD8E3F8),
                        child: Icon(
                          Icons.support_agent_outlined,
                          color: Color(0xFF1E3A5F),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'FDS CWS Admix',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text.rich(
                              TextSpan(
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: Colors.black.withValues(
                                        alpha: 0.6,
                                      ),
                                    ),
                                children: [
                                  const TextSpan(
                                    text:
                                        'FDS disponível sob demanda. Solicite via ',
                                  ),
                                  _linkSpan(
                                    context,
                                    label: 'WhatsApp',
                                    uri: _whatsAppUri,
                                  ),
                                  const TextSpan(text: ' ou '),
                                  _linkSpan(
                                    context,
                                    label: 'email',
                                    uri: _emailUri,
                                  ),
                                  const TextSpan(text: '.'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          _docCard(
            context,
            title: 'Acesse nosso site',
            subtitle:
                'Maiores informações, outros produtos da Netherland, videos e obras executadas.',
            icon: Icons.language_outlined,
            primaryLabel: 'Abrir site',
            primaryAction: () =>
                _abrirLink(context, uri: _siteUri, label: 'Site Netherland'),
          ),
        ],
      ),
    );
  }
}

class DocumentoPdfPage extends StatelessWidget {
  final String title;
  final Uint8List bytes;

  const DocumentoPdfPage({super.key, required this.title, required this.bytes});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: PdfPreview(
        build: (_) async => bytes,
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
        allowPrinting: false,
        allowSharing: true,
        pdfFileName: title,
      ),
    );
  }
}
