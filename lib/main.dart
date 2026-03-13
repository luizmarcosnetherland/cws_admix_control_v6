import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

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
        return _AppWatermarkBackground(child: child ?? const SizedBox.shrink());
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
  const AppGate({super.key});

  @override
  State<AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<AppGate> {
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await Future<void>.delayed(const Duration(milliseconds: 1800));

    if (!mounted) return;

    await Future<void>.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;

    setState(() {
      _showSplash = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const HomePage(),
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
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

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
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Image.asset(
                      'assets/logos/netherland.png',
                      height: 96,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(width: 18),
                  Container(
                    width: 1,
                    height: 72,
                    color: const Color(0xFF1E3A5F),
                  ),
                  const SizedBox(width: 18),
                  Flexible(
                    child: Image.asset(
                      'assets/logos/cwsadmix.jpg',
                      height: 96,
                      fit: BoxFit.contain,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.end,
                spacing: 6,
                runSpacing: 4,
                children: [
                  const Text('Netherland Admix', style: titleStyle),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 1100),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) {
                      return Opacity(
                        opacity: value.clamp(0.0, 1.0),
                        child: Transform.translate(
                          offset: Offset(18 * (1 - value), 0),
                          child: SizedBox(
                            width: 116,
                            child: ClipRect(
                              child: Align(
                                alignment: Alignment.centerLeft,
                                widthFactor: value.clamp(0.0, 1.0),
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 10),
                                  child: child,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    child: Text(
                      'Control',
                      style: GoogleFonts.caveat(
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                        fontStyle: FontStyle.italic,
                        color: brandBlue,
                        height: 0.9,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  void _openObras(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ObrasPage(),
      ),
    );
  }

  void _openCalculator(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const CwsCalculatorPage()));
  }

  Widget _menuButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: CircleAvatar(child: Icon(icon)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }

  Widget _brandingWatermark() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: SizedBox(
        height: 128,
        child: Center(
          child: Opacity(
            opacity: 1,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('assets/logos/netherland.png', height: 56),
                const SizedBox(width: 20),
                Container(width: 1, height: 44, color: const Color(0xFF1E3A5F)),
                const SizedBox(width: 20),
                Image.asset('assets/logos/cwsadmix.jpg', height: 56),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F7),
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Obras',
            icon: const Icon(Icons.apartment),
            onPressed: () => _openObras(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _brandingWatermark(),
          const SizedBox(height: 10),
          _menuButton(
            title: 'Calculadora CWS',
            subtitle:
                'Calcule a quantidade de aditivo para sua concretagem e solicite uma cotação.',
            icon: Icons.calculate,
            onTap: () => _openCalculator(context),
          ),
          _menuButton(
            title: 'Obras',
            subtitle:
                'Cadastre sua obra, controle sua concretagem e gere relatórios locais em PDF ou CSV.',
            icon: Icons.apartment,
            onTap: () => _openObras(context),
          ),
        ],
      ),
    );
  }
}
