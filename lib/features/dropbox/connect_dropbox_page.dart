import 'package:flutter/material.dart';

import '../../dropbox_auth.dart';

class ConnectDropboxPage extends StatefulWidget {
  const ConnectDropboxPage({super.key});

  @override
  State<ConnectDropboxPage> createState() => _ConnectDropboxPageState();
}

class _ConnectDropboxPageState extends State<ConnectDropboxPage> {
  final DropboxAuth _auth = DropboxAuth();
  bool _loading = false;
  String _status = 'Conecte sua conta Dropbox para usar Sync/Uploads.';

  @override
  void initState() {
    super.initState();
    if (!_auth.supportsInteractiveSignIn) {
      _status =
          'Login com Dropbox nao esta disponivel no navegador. Use a versao nativa do app para conectar a conta.';
    }
  }

  Future<void> _connect() async {
    if (!_auth.supportsInteractiveSignIn) {
      setState(() {
        _status =
            'Login com Dropbox nao esta disponivel no navegador. Use a versao nativa do app para conectar a conta.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _status = 'Conectando ao Dropbox...';
    });

    try {
      await _auth.signIn();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _status = 'Erro: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Conectar Dropbox')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud, size: 46),
                    const SizedBox(height: 10),
                    Text(_status, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _loading || !_auth.supportsInteractiveSignIn
                                ? null
                                : _connect,
                            icon: _loading
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.link),
                            label: const Text('Conectar Dropbox'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _loading
                          ? null
                          : () => Navigator.of(context).pop(false),
                      child: const Text('Agora não'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
