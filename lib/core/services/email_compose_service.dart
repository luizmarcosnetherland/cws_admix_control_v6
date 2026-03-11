import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:share_plus/share_plus.dart';

class EmailComposeService {
  Future<void> composeEmail({
    required List<String> recipients,
    required String subject,
    required String body,
    List<String> attachmentPaths = const [],
    Rect? sharePositionOrigin,
  }) async {
    if (!_supportsFlutterEmailSender()) {
      await _composeOnMacos(
        recipients: recipients,
        subject: subject,
        body: body,
        attachmentPaths: attachmentPaths,
      );
      return;
    }

    final email = Email(
      recipients: recipients,
      subject: subject,
      body: body,
      attachmentPaths: attachmentPaths,
      isHTML: false,
    );
    try {
      await FlutterEmailSender.send(email);
    } on MissingPluginException {
      if (Platform.isMacOS) {
        await _composeOnMacos(
          recipients: recipients,
          subject: subject,
          body: body,
          attachmentPaths: attachmentPaths,
        );
        return;
      }

      throw Exception(
        'Plugin de e-mail indisponivel nesta execucao. '
        'Reinstale/reinicie o app para carregar o plugin nativo.',
      );
    } on PlatformException catch (e) {
      if (e.code == 'not_available') {
        await Share.shareXFiles(
          attachmentPaths.map(XFile.new).toList(),
          subject: subject,
          text: body,
          sharePositionOrigin: sharePositionOrigin,
        );
        return;
      }
      rethrow;
    }
  }

  bool _supportsFlutterEmailSender() {
    return Platform.isAndroid || Platform.isIOS;
  }

  Future<void> _composeOnMacos({
    required List<String> recipients,
    required String subject,
    required String body,
    required List<String> attachmentPaths,
  }) async {
    final recipientCommands = recipients
        .where((e) => e.trim().isNotEmpty)
        .map(
          (email) =>
              'make new to recipient at end of to recipients with properties {address:"${_escapeAppleScript(email)}"}',
        )
        .join('\n');

    final attachmentCommands = attachmentPaths
        .where((p) => p.trim().isNotEmpty)
        .map(
          (path) =>
              'make new attachment with properties {file name:(POSIX file "${_escapeAppleScript(path)}")} at after the last paragraph',
        )
        .join('\n');

    final script = '''
tell application "Mail"
  set newMessage to make new outgoing message with properties {visible:true, subject:"${_escapeAppleScript(subject)}", content:"${_escapeAppleScript(body)}"}
  tell newMessage
    $recipientCommands
    $attachmentCommands
  end tell
  activate
end tell
''';

    final result = await Process.run('osascript', ['-e', script]);
    if (result.exitCode != 0) {
      throw Exception(result.stderr.toString().trim().isEmpty
          ? 'Falha ao abrir o Mail no macOS.'
          : result.stderr.toString().trim());
    }
  }

  String _escapeAppleScript(String value) {
    return value
        .replaceAll(r'\', r'\\')
        .replaceAll('"', r'\"')
        .replaceAll('\n', r'\n');
  }
}
