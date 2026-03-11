import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'core/services/local_dropbox_storage_service.dart';

class CwsCalculatorPage extends StatefulWidget {
  const CwsCalculatorPage({super.key});

  @override
  State<CwsCalculatorPage> createState() => _CwsCalculatorPageState();
}

class _CwsCalculatorPageState extends State<CwsCalculatorPage> {
  final _volumeCtrl = TextEditingController(text: '10');
  final _cementCtrl = TextEditingController(text: '350');

  final _jobNameCtrl = TextEditingController();
  final _concreteSupplierCtrl = TextEditingController();
  final _engineerEmailCtrl = TextEditingController();

  double get volume => double.tryParse(_volumeCtrl.text.replaceAll(',', '.')) ?? 0.0;
  double get cementKgM3 => double.tryParse(_cementCtrl.text.replaceAll(',', '.')) ?? 0.0;

  double get dosageKgM3 => (cementKgM3 > 450) ? 1.0 : 0.8;
  double get totalKg => volume * dosageKgM3;

  int get bags => (totalKg <= 0) ? 0 : (totalKg / 6.4).ceil();
  double get providedKg => bags * 6.4;

  String fmt(double v) => NumberFormat("#,##0.00", "pt_BR").format(v);

  Future<pw.Document> _buildPdf() async {
    final now = DateTime.now();
    final dateStr = DateFormat("dd/MM/yyyy HH:mm", "pt_BR").format(now);

    final netherlandBytes =
        (await rootBundle.load('assets/logos/netherland.png')).buffer.asUint8List();

    // Se o seu logo do CWS for PNG, troque aqui pra cwsadmix.png
    final cwsBytes =
        (await rootBundle.load('assets/logos/cwsadmix.jpg')).buffer.asUint8List();

    final netherlandImg = pw.MemoryImage(netherlandBytes);
    final cwsImg = pw.MemoryImage(cwsBytes);

    final doc = pw.Document();

    final regra = cementKgM3 > 450
        ? 'Como o consumo de cimento é > 450 kg/m³, aplica-se 1,00 kg de CWS Admix por m³.'
        : 'Como o consumo de cimento é ≤ 450 kg/m³, aplica-se 0,80 kg de CWS Admix por m³.';

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (_) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Image(netherlandImg, height: 40),
              pw.Image(cwsImg, height: 40),
            ],
          ),
          pw.SizedBox(height: 14),
          pw.Text(
            'Relatório Técnico – Dosagem CWS Admix',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text('Netherland Admix Control • Gerado em: $dateStr',
              style: const pw.TextStyle(fontSize: 10)),
          pw.Divider(),

          pw.Text('Identificação',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          _kv('Obra', _jobNameCtrl.text.trim().isEmpty ? '—' : _jobNameCtrl.text.trim()),
          _kv('Concreteira',
              _concreteSupplierCtrl.text.trim().isEmpty ? '—' : _concreteSupplierCtrl.text.trim()),
          _kv('E-mail do Engenheiro',
              _engineerEmailCtrl.text.trim().isEmpty ? '—' : _engineerEmailCtrl.text.trim()),
          pw.SizedBox(height: 10),

          pw.Text('Parâmetros e Regra',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          _kv('Volume de concretagem', '${fmt(volume)} m³'),
          _kv('Consumo de cimento', '${fmt(cementKgM3)} kg/m³'),
          _kv('Regra', regra),
          pw.SizedBox(height: 10),

          pw.Text('Resultado',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          _kv('Dosagem aplicada', '${fmt(dosageKgM3)} kg/m³'),
          _kv('Quantidade total (teórica)', '${fmt(totalKg)} kg'),
          _kv('Embalagens (6,4 kg) – arredondamento p/ cima', '$bags saco(s)'),
          _kv('Quantidade fornecida (embalagens × 6,4 kg)', '${fmt(providedKg)} kg'),

          pw.SizedBox(height: 14),
          pw.Divider(),
          pw.Text('Observações de Aplicação',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Bullet(text: 'Se dosado no caminhão betoneira: garantir mistura mínima de 10 minutos após adição.'),
          pw.Bullet(text: 'Registrar horário da adição e horário de início de descarga.'),
          pw.Bullet(text: 'Registrar slump para controle tecnológico.'),
        ],
      ),
    );

    return doc;
  }

  pw.Widget _kv(String k, String v) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 185,
            child: pw.Text(k, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          ),
          pw.Expanded(child: pw.Text(v, style: const pw.TextStyle(fontSize: 10))),
        ],
      ),
    );
  }

  Future<void> _savePdfToDropbox() async {
    final doc = await _buildPdf();
    final bytes = await doc.save();

    final ts = DateFormat('yyyyMMdd_HHmm', 'pt_BR').format(DateTime.now());
    final filename = 'Relatorio_CWS_$ts.pdf';
    final storage = LocalDropboxStorageService();
    await storage.ensureBaseStructure();
    final path = storage.exportFilePath(filename);
    await File(path).writeAsBytes(bytes, flush: true);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Salvo em ${p.basename(path)}')),
    );
  }

  @override
  void dispose() {
    _volumeCtrl.dispose();
    _cementCtrl.dispose();
    _jobNameCtrl.dispose();
    _concreteSupplierCtrl.dispose();
    _engineerEmailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final blue = const Color(0xFF1E3A5F);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calculadora CWS + Relatório'),
        backgroundColor: blue,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Dados da Obra', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _field(_jobNameCtrl, 'Nome da obra'),
          _field(_concreteSupplierCtrl, 'Concreteira'),
          _field(_engineerEmailCtrl, 'E-mail do engenheiro'),

          const SizedBox(height: 16),
          const Text('Cálculo de Dosagem', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _field(_volumeCtrl, 'Volume (m³)', keyboard: TextInputType.number),
          _field(_cementCtrl, 'Cimento (kg/m³)', keyboard: TextInputType.number),

          const SizedBox(height: 16),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Dosagem aplicada: ${fmt(dosageKgM3)} kg/m³'),
                  Text('Total teórico: ${fmt(totalKg)} kg'),
                  Text('Sacos (6,4 kg): $bags'),
                  Text('Total fornecido: ${fmt(providedKg)} kg'),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),
          Material(
  color: const Color(0xFF1E3A5F),
  borderRadius: BorderRadius.circular(28),
  child: InkWell(
    borderRadius: BorderRadius.circular(28),
    onTap: () async {
      final rootNav = Navigator.of(context);
      final messenger = ScaffoldMessenger.of(context);
      try {
        final doc = await _buildPdf();
        if (!mounted) return;

        rootNav.push(
          MaterialPageRoute(
            builder: (_) => Scaffold(
              appBar: AppBar(
                title: const Text('Prévia do PDF'),
                backgroundColor: blue,
                foregroundColor: Colors.white,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'Voltar',
                  onPressed: () => rootNav.pop(),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.dashboard_outlined),
                    tooltip: 'Ir para o Dashboard',
                    onPressed: () => rootNav.popUntil((route) => route.isFirst),
                  ),
                ],
              ),
              body: PdfPreview(
                build: (format) async => doc.save(),
                canChangePageFormat: false,
                canChangeOrientation: false,
                allowPrinting: true,
                allowSharing: true,
              ),
            ),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(content: Text('Erro ao gerar PDF: $e')),
        );
      }
    },
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.picture_as_pdf, color: Colors.white),
          SizedBox(width: 10),
          Text('Abrir prévia do PDF',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        ],
      ),
    ),
  ),
),


          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () async {
              final doc = await _buildPdf();
              await Printing.sharePdf(
                bytes: await doc.save(),
                filename: 'Relatorio_CWS.pdf',
              );
            },
            icon: const Icon(Icons.share),
            label: const Text('Compartilhar PDF'),
          ),

          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              try {
                await _savePdfToDropbox();
              } catch (e) {
                if (!mounted) return;
                messenger.showSnackBar(SnackBar(content: Text('Erro: $e')));
              }
            },
            icon: const Icon(Icons.cloud_upload),
            label: const Text('Salvar PDF no Dropbox'),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, {TextInputType? keyboard}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: ctrl,
        keyboardType: keyboard,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }
}
