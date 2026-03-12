import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'dropbox_auth.dart';
import 'core/services/local_dropbox_storage_service.dart';

import 'features/dropbox/connect_dropbox_page.dart';
import 'features/obras/pages/obras_page.dart';
import 'cws_calculator_page.dart';

enum AppMode { dropbox, local }

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
  final DropboxAuth _auth = DropboxAuth();
  late final Future<String?> _tokenFuture = _auth.getAccessToken();
  bool _showSplash = true;
  bool _connected = false;
  AppMode? _mode;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final tokenFuture = _tokenFuture;
    final results = await Future.wait<dynamic>([
      tokenFuture,
      Future<void>.delayed(const Duration(milliseconds: 1800)),
    ]);

    final token = results.first as String?;

    if (!mounted) return;

    setState(() {
      _connected = token != null && token.isNotEmpty;
    });

    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;

    setState(() {
      _showSplash = false;
    });
  }

  Future<void> _selecionarModoDropbox() async {
    if (_connected) {
      setState(() => _mode = AppMode.dropbox);
      return;
    }

    final ok = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const ConnectDropboxPage()));
    final token = await _auth.getAccessToken();
    final connected = (ok == true) && token != null && token.isNotEmpty;

    if (!mounted) return;
    setState(() {
      _connected = connected;
      if (connected) _mode = AppMode.dropbox;
    });
  }

  void _selecionarModoLocal() {
    setState(() {
      _mode = AppMode.local;
      _connected = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final Widget baseChild = _mode == null
        ? _ModeSelectionScreen(
            dropboxConnected: _connected,
            onConnectDropbox: _selecionarModoDropbox,
            onContinueLocal: _selecionarModoLocal,
          )
        : HomePage(dropboxConnected: _connected, appMode: _mode!);

    return Stack(
      children: [
        baseChild,
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
              const Text(
                'Netherland Admix Control',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                  color: Color(0xFF1E3A5F),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeSelectionScreen extends StatelessWidget {
  final bool dropboxConnected;
  final Future<void> Function() onConnectDropbox;
  final VoidCallback onContinueLocal;

  const _ModeSelectionScreen({
    required this.dropboxConnected,
    required this.onConnectDropbox,
    required this.onContinueLocal,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F7),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Como deseja usar o aplicativo?',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    dropboxConnected
                        ? 'Sua conta Dropbox já está conectada. Você pode entrar direto com sync ou seguir apenas localmente.'
                        : 'Escolha entre conectar ao Dropbox ou continuar em modo local.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.black.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 28),
                  _ModeOptionCard(
                    icon: dropboxConnected
                        ? Icons.cloud_done
                        : Icons.cloud_sync,
                    title: dropboxConnected
                        ? 'Entrar com Dropbox'
                        : 'Conectar ao Dropbox',
                    subtitle:
                        'Abre o login do Dropbox e habilita sync, CSV e pasta local integrada.',
                    actionLabel: dropboxConnected
                        ? 'Usar Dropbox'
                        : 'Fazer login',
                    onTap: onConnectDropbox,
                  ),
                  const SizedBox(height: 16),
                  _ModeOptionCard(
                    icon: Icons.phone_iphone,
                    title: 'Seguir sem Dropbox',
                    subtitle:
                        'Usa o app localmente e gera relatórios em PDF para compartilhar no WhatsApp.',
                    actionLabel: 'Usar modo local',
                    onTap: () async {
                      onContinueLocal();
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeOptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final Future<void> Function() onTap;

  const _ModeOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFFD8E3F8),
                  child: Icon(icon, size: 24, color: const Color(0xFF1E3A5F)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.black.withValues(alpha: 0.68),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onTap,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(actionLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  final bool dropboxConnected;
  final AppMode appMode;

  const HomePage({
    super.key,
    required this.dropboxConnected,
    required this.appMode,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final DropboxAuth _auth = DropboxAuth();
  final LocalDropboxStorageService _storage = LocalDropboxStorageService();
  bool _syncingFolders = false;
  late bool _connected;

  bool get _localMode => !_connected && widget.appMode == AppMode.local;

  @override
  void initState() {
    super.initState();
    _connected = widget.dropboxConnected;
  }

  Future<bool> _connectDropboxIfNeeded() async {
    final token = await _auth.getAccessToken();
    if (token != null && token.isNotEmpty) {
      setState(() => _connected = true);
      return true;
    }

    if (!mounted) return false;

    final ok = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const ConnectDropboxPage()));

    final token2 = await _auth.getAccessToken();
    final connected = (ok == true) && token2 != null && token2.isNotEmpty;

    if (mounted) setState(() => _connected = connected);
    return connected;
  }

  Future<void> _logoutDropbox() async {
    await _auth.signOut();
    if (!mounted) return;
    setState(() => _connected = false);
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..clearSnackBars()
      ..showSnackBar(const SnackBar(content: Text('Dropbox desconectado.')));
  }

  Future<void> _syncDropboxFolders() async {
    setState(() => _syncingFolders = true);
    try {
      final rootPath = await _storage.ensureBaseStructure();

      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text('Pastas locais OK: $rootPath')));
    } catch (e) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(content: Text('Erro ao sincronizar pastas: $e')),
        );
    } finally {
      if (mounted) setState(() => _syncingFolders = false);
    }
  }

  void _openObras() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ObrasPage(localMode: _localMode),
      ),
    );
  }

  void _openCalculator() {
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

  Widget _modoOperacaoCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Modo de operação',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              _localMode
                  ? '• Modo local ativo ✅'
                  : (_connected
                        ? '• Dropbox: conectado ✅'
                        : '• Dropbox: não conectado'),
            ),
            const SizedBox(height: 4),
            if (_localMode) ...[
              const Text('• Dados ficam salvos apenas localmente'),
              const Text('• Relatórios das obras saem em PDF para WhatsApp'),
              const Text('• Sem login ou sincronização com Dropbox'),
            ] else ...[
              const Text(
                '• Dados e arquivos ficam salvos localmente no Dropbox',
              ),
              const Text('• Relatórios: Dropbox/Downloads/CWSadmixControl'),
              const Text('• Dados internos: Dropbox/CWSadmixControl'),
              const Text('• CSV funciona sem Dropbox'),
            ],
          ],
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
            onPressed: _openObras,
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'connect') await _connectDropboxIfNeeded();
              if (v == 'folders') await _syncDropboxFolders();
              if (v == 'logout') await _logoutDropbox();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'connect',
                child: Row(
                  children: [
                    Icon(_connected ? Icons.cloud_done : Icons.cloud_off),
                    const SizedBox(width: 10),
                    Text(_connected ? 'Dropbox conectado' : 'Conectar Dropbox'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'folders',
                child: Row(
                  children: [
                    _syncingFolders
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.folder),
                    const SizedBox(width: 10),
                    const Text('Validar pastas do Dropbox'),
                  ],
                ),
              ),
              if (_connected)
                const PopupMenuItem(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout),
                      SizedBox(width: 10),
                      Text('Desconectar Dropbox'),
                    ],
                  ),
                ),
            ],
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
            onTap: _openCalculator,
          ),
          _menuButton(
            title: 'Obras',
            subtitle:
                'Cadastre sua obra, controle sua concretagem e gere relatórios em PDF para e-mail ou WhatsApp.',
            icon: Icons.apartment,
            onTap: _openObras,
          ),
          _menuButton(
            title: 'Dropbox: pastas',
            subtitle: 'Cria/valida a pasta local do Dropbox',
            icon: Icons.folder,
            onTap: _syncDropboxFolders,
            trailing: _syncingFolders
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
          ),
          const SizedBox(height: 10),
          _modoOperacaoCard(),
        ],
      ),
    );
  }
}
