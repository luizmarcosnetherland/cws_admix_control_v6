import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

class CwsLocalizations {
  CwsLocalizations(this.locale);

  final Locale locale;

  static const supportedLocales = <Locale>[
    Locale('pt', 'BR'),
    Locale('en'),
    Locale('es'),
  ];

  static const delegate = _CwsLocalizationsDelegate();

  static CwsLocalizations current = CwsLocalizations(const Locale('pt', 'BR'));

  static CwsLocalizations of(BuildContext context) {
    return Localizations.of<CwsLocalizations>(context, CwsLocalizations) ??
        current;
  }

  static Locale resolve(
    Locale? preferredLocale,
    Iterable<Locale> supportedLocales,
  ) {
    final languageCode = preferredLocale?.languageCode.toLowerCase();
    return switch (languageCode) {
      'en' => const Locale('en'),
      'es' => const Locale('es'),
      'pt' => const Locale('pt', 'BR'),
      _ => const Locale('pt', 'BR'),
    };
  }

  String get languageCode {
    final code = locale.languageCode.toLowerCase();
    if (code == 'en' || code == 'es') return code;
    return 'pt';
  }

  String get dateLocale {
    return switch (languageCode) {
      'en' => 'en_US',
      'es' => 'es',
      _ => 'pt_BR',
    };
  }

  String t(String source, {Map<String, Object?> params = const {}}) {
    final localized = _translations[source]?[languageCode] ?? source;

    if (params.isEmpty) return localized;

    return params.entries.fold(localized, (text, entry) {
      return text.replaceAll(
        '{${entry.key}}',
        _formatParam(entry.key, entry.value),
      );
    });
  }

  String _formatParam(String key, Object? value) {
    if (key == 'error') return _friendlyError(value);
    return value.toString();
  }

  String _friendlyError(Object? value) {
    if (value == null) return '';
    var text = value is PlatformException
        ? (value.message?.trim().isNotEmpty ?? false)
              ? value.message!.trim()
              : value.code
        : value.toString().trim();
    final platformText = RegExp(
      r'^PlatformException\([^,]*,\s*([^,\)]*)',
    ).firstMatch(text)?.group(1)?.trim();
    if (platformText != null &&
        platformText.isNotEmpty &&
        platformText.toLowerCase() != 'null') {
      text = platformText;
    }
    text = text
        .replaceFirst(RegExp(r'^Exception:\s*'), '')
        .replaceFirst(RegExp(r'^UnsupportedError:\s*'), '')
        .replaceFirst(RegExp(r'^Unsupported operation:\s*'), '');
    return _translations[text]?[languageCode] ?? text;
  }

  static void activate(CwsLocalizations localizations) {
    current = localizations;
    Intl.defaultLocale = localizations.dateLocale;
  }
}

extension CwsLocalizationsBuildContext on BuildContext {
  CwsLocalizations get l10n => CwsLocalizations.of(this);

  String tr(String source, {Map<String, Object?> params = const {}}) {
    return l10n.t(source, params: params);
  }
}

String tr(String source, {Map<String, Object?> params = const {}}) {
  return CwsLocalizations.current.t(source, params: params);
}

class _CwsLocalizationsDelegate
    extends LocalizationsDelegate<CwsLocalizations> {
  const _CwsLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return const {'pt', 'en', 'es'}.contains(locale.languageCode.toLowerCase());
  }

  @override
  Future<CwsLocalizations> load(Locale locale) async {
    final localizations = CwsLocalizations(
      CwsLocalizations.resolve(locale, []),
    );
    CwsLocalizations.activate(localizations);
    return localizations;
  }

  @override
  bool shouldReload(_CwsLocalizationsDelegate old) => false;
}

const _translations = <String, Map<String, String>>{
  'Netherland Admix Control': {
    'en': 'Netherland Admix Control',
    'es': 'Netherland Admix Control',
  },
  'Netherland Admix': {'en': 'Netherland Admix', 'es': 'Netherland Admix'},
  'CWS Admix Control': {'en': 'CWS Admix Control', 'es': 'CWS Admix Control'},
  'Atualização disponível': {
    'en': 'Update available',
    'es': 'Actualización disponible',
  },
  'Uma nova versão do {appName} está disponível na App Store.': {
    'en': 'A new version of {appName} is available on the App Store.',
    'es': 'Hay una nueva versión de {appName} disponible en App Store.',
  },
  'Uma nova versão do {appName} está disponível na {storeName}.': {
    'en': 'A new version of {appName} is available on {storeName}.',
    'es': 'Hay una nueva versión de {appName} disponible en {storeName}.',
  },
  'Versão instalada: {version} (build {build})': {
    'en': 'Installed version: {version} (build {build})',
    'es': 'Versión instalada: {version} (build {build})',
  },
  'Nova versão: {version}': {
    'en': 'New version: {version}',
    'es': 'Nueva versión: {version}',
  },
  'Novo build: {build}': {
    'en': 'New build: {build}',
    'es': 'Nueva compilación: {build}',
  },
  'Depois': {'en': 'Later', 'es': 'Después'},
  'Atualizar': {'en': 'Update', 'es': 'Actualizar'},
  'Não foi possível abrir a App Store. Tente novamente em instantes.': {
    'en': 'We could not open the App Store. Please try again in a moment.',
    'es': 'No pudimos abrir App Store. Inténtelo nuevamente en unos instantes.',
  },
  'Não foi possível abrir a loja de aplicativos. Tente novamente em instantes.': {
    'en': 'We could not open the app store. Please try again in a moment.',
    'es':
        'No pudimos abrir la tienda de aplicaciones. Inténtelo nuevamente en unos instantes.',
  },
  'Não conseguimos preparar os dados do evento.': {
    'en': 'We could not prepare the event details.',
    'es': 'No pudimos preparar los datos del evento.',
  },
  'Não temos permissão para criar eventos no Calendário.': {
    'en': 'We do not have permission to create Calendar events.',
    'es': 'No tenemos permiso para crear eventos en el Calendario.',
  },
  'Não encontramos um calendário disponível para novos eventos.': {
    'en': 'We could not find a calendar available for new events.',
    'es': 'No encontramos un calendario disponible para nuevos eventos.',
  },
  'Não encontramos um aplicativo de calendário para criar o evento.': {
    'en': 'We could not find a calendar app to create the event.',
    'es': 'No encontramos una app de calendario para crear el evento.',
  },
  'Ative a localizacao do aparelho para continuar.': {
    'pt': 'Ative a localização do aparelho para continuar.',
    'en': 'Turn on device location to continue.',
    'es': 'Active la ubicación del dispositivo para continuar.',
  },
  'Permissao de localizacao negada.': {
    'pt': 'A permissão de localização foi negada.',
    'en': 'Location permission was denied.',
    'es': 'Se denegó el permiso de ubicación.',
  },
  'Permissao de localizacao negada permanentemente. Libere nas configuracoes do aparelho.': {
    'pt':
        'A permissão de localização está bloqueada. Libere o acesso nas configurações do aparelho.',
    'en':
        'Location permission is blocked. Allow access in the device settings.',
    'es':
        'El permiso de ubicación está bloqueado. Habilite el acceso en la configuración del dispositivo.',
  },
  'Nao foi possivel localizar o endereco informado.': {
    'pt':
        'Não conseguimos localizar esse endereço. Revise os dados ou use a localização atual.',
    'en':
        'We could not locate this address. Review the details or use current location.',
    'es':
        'No pudimos ubicar esa dirección. Revise los datos o use la ubicación actual.',
  },
  'Nao foi possivel abrir o app de mapas.': {
    'pt': 'Não conseguimos abrir o app de mapas.',
    'en': 'We could not open the maps app.',
    'es': 'No pudimos abrir la app de mapas.',
  },
  'Plugin de e-mail indisponivel nesta execucao. Reinstale/reinicie o app para carregar o plugin nativo.': {
    'pt':
        'Não conseguimos abrir o e-mail neste momento. Reinicie o app e tente novamente.',
    'en': 'We could not open email right now. Restart the app and try again.',
    'es':
        'No pudimos abrir el email en este momento. Reinicie la app e inténtelo nuevamente.',
  },
  'Falha ao abrir o Mail no macOS.': {
    'pt': 'Não conseguimos abrir o Mail no macOS.',
    'en': 'We could not open Mail on macOS.',
    'es': 'No pudimos abrir Mail en macOS.',
  },
  'OCR de nota fiscal disponivel apenas em Android e iOS.': {
    'pt': 'A leitura da nota fiscal está disponível apenas no Android e iOS.',
    'en': 'Invoice scanning is available only on Android and iOS.',
    'es': 'La lectura de factura está disponible solo en Android e iOS.',
  },
  'Dashboard': {'en': 'Dashboard', 'es': 'Panel'},
  'Obras': {'en': 'Jobsites', 'es': 'Obras'},
  'Calculadora CWS': {'en': 'CWS Calculator', 'es': 'Calculadora CWS'},
  'Literatura técnica': {
    'en': 'Technical Literature',
    'es': 'Literatura técnica',
  },
  'Sobre': {'en': 'About', 'es': 'Acerca de'},
  'Agendamento de Concretagem': {
    'en': 'Concrete Pour Scheduling',
    'es': 'Programación de Hormigonado',
  },
  'Agendamento': {'en': 'Scheduling', 'es': 'Programación'},
  'Sobre e suporte': {'en': 'About and support', 'es': 'Acerca de y soporte'},
  'Pular': {'en': 'Skip', 'es': 'Omitir'},
  'Próximo': {'en': 'Next', 'es': 'Siguiente'},
  'Concluir': {'en': 'Done', 'es': 'Finalizar'},
  'Acessos rápidos': {'en': 'Quick access', 'es': 'Accesos rápidos'},
  'Toque em um card para abrir a área desejada.': {
    'en': 'Tap a card to open the desired area.',
    'es': 'Toque una tarjeta para abrir el área deseada.',
  },
  'Toque para abrir': {'en': 'Tap to open', 'es': 'Toque para abrir'},
  'Calcule a quantidade de aditivo para sua concretagem e solicite uma cotação.': {
    'en':
        'Calculate the admixture quantity for your concrete pour and request a quote.',
    'es':
        'Calcule la cantidad de aditivo para su hormigonado y solicite una cotización.',
  },
  'Consulte documentos técnicos, ficha técnica e orientações de uso.': {
    'en': 'View technical documents, data sheets, and usage guidance.',
    'es': 'Consulte documentos técnicos, ficha técnica y orientaciones de uso.',
  },
  'Dados do sistema, versão e suporte.': {
    'en': 'System details, version, and support.',
    'es': 'Datos del sistema, versión y soporte.',
  },
  'Cadastre obras, acompanhe concretagens e gere relatórios operacionais.': {
    'en': 'Register jobsites, track concrete pours, and generate reports.',
    'es': 'Registre obras, acompañe hormigonados y genere informes operativos.',
  },
  'Planeje a concretagem, gere convite de agenda e compartilhe as informações.': {
    'en':
        'Plan the concrete pour, create a calendar invite, and share the details.',
    'es':
        'Planifique el hormigonado, cree una invitación de calendario y comparta los datos.',
  },
  'Calcule a dosagem do CWS Admix pelo volume da concretagem e siga para a solicitação comercial.': {
    'en':
        'Calculate the CWS Admix dosage from the concrete volume and continue to the commercial request.',
    'es':
        'Calcule la dosificación de CWS Admix según el volumen de hormigón y continúe con la solicitud comercial.',
  },
  'Organize suas obras e registre os lançamentos de concreto aditivado.': {
    'en': 'Organize jobsites and record admixtured concrete placements.',
    'es':
        'Organice sus obras y registre los lanzamientos de hormigón aditivado.',
  },
  'Acesse a ficha técnica e as orientações de aplicação do produto.': {
    'en': 'Access the technical data sheet and product application guidance.',
    'es':
        'Acceda a la ficha técnica y a las orientaciones de aplicación del producto.',
  },
  'Planeje concretagens e compartilhe as informações da programação.': {
    'en': 'Plan concrete pours and share scheduling details.',
    'es': 'Planifique hormigonados y comparta la programación.',
  },
  'Cadastre uma obra, acompanhe concretagens, lançamentos, fotos, notas fiscais e relatórios.': {
    'en':
        'Register a jobsite and track concrete pours, placements, photos, invoices, and reports.',
    'es':
        'Registre una obra y acompañe hormigonados, lanzamientos, fotos, facturas e informes.',
  },
  'Consulte ficha técnica e orientações de cura do concreto sem sair do aplicativo.': {
    'en':
        'View the technical data sheet and concrete curing guidance without leaving the app.',
    'es':
        'Consulte la ficha técnica y orientaciones de curado del hormigón sin salir de la app.',
  },
  'Programe uma concretagem futura e compartilhe o compromisso com quem precisa acompanhar.': {
    'en':
        'Schedule a future concrete pour and share the appointment with the people who need to follow it.',
    'es':
        'Programe un hormigonado futuro y comparta el compromiso con quienes necesitan acompañarlo.',
  },
  'Aqui ficam versão do app, suporte, feedback, avaliação e a opção de rever esta introdução.': {
    'en':
        'Find the app version, support, feedback, rating, and the option to replay this introduction.',
    'es':
        'Aquí están la versión de la app, soporte, feedback, calificación y la opción de rever esta introducción.',
  },
  'Cadastre sua obra, controle sua concretagem e gere relatórios locais em PDF ou CSV.': {
    'en':
        'Register your jobsite, control concrete pours, and create local PDF or CSV reports.',
    'es':
        'Registre su obra, controle su hormigonado y genere informes locales en PDF o CSV.',
  },
  'Acesse ficha técnica e orientações para consulta rápida em campo.': {
    'en': 'Access the data sheet and guidance for quick field reference.',
    'es':
        'Acceda a la ficha técnica y orientaciones para consulta rápida en campo.',
  },
  'Programe concretagens futuras e compartilhe convites de calendário.': {
    'en': 'Schedule future concrete pours and share calendar invites.',
    'es':
        'Programe hormigonados futuros y comparta invitaciones de calendario.',
  },
  'Saiba mais sobre o app, versão, suporte e licenças.': {
    'en': 'Learn about the app, version, support, and licenses.',
    'es': 'Conozca más sobre la app, versión, soporte y licencias.',
  },
  'Sistema para controle e acompanhamento operacional de obras e concretos aditivados com CWS Admix.': {
    'en':
        'System for operational control and tracking of jobsites and concrete with CWS Admix.',
    'es':
        'Sistema para control y seguimiento operativo de obras y hormigones aditivados con CWS Admix.',
  },
  'Versao': {'pt': 'Versão', 'en': 'Version', 'es': 'Versión'},
  'Plataforma': {'en': 'Platform', 'es': 'Plataforma'},
  'Feedback': {'en': 'Feedback', 'es': 'Feedback'},
  'Conte aqui sua sugestao, problema ou melhoria:': {
    'pt': 'Conte aqui sua sugestão, problema ou ideia de melhoria:',
    'en': 'Tell us your suggestion, issue, or improvement:',
    'es': 'Cuéntenos su sugerencia, problema o idea de mejora:',
  },
  'Copyright': {'en': 'Copyright', 'es': 'Copyright'},
  'Suporte': {'en': 'Support', 'es': 'Soporte'},
  'Enviar email': {'en': 'Send email', 'es': 'Enviar email'},
  'Avaliar o app': {'en': 'Rate the app', 'es': 'Calificar la app'},
  'Enviar feedback': {'en': 'Send feedback', 'es': 'Enviar feedback'},
  'Ver introducao novamente': {
    'pt': 'Ver introdução novamente',
    'en': 'View introduction again',
    'es': 'Ver introducción nuevamente',
  },
  'Ver licencas': {
    'pt': 'Ver licenças',
    'en': 'View licenses',
    'es': 'Ver licencias',
  },
  'Carregando...': {'en': 'Loading...', 'es': 'Cargando...'},
  'Nao foi possivel abrir o email de suporte.': {
    'pt':
        'Não conseguimos abrir seu aplicativo de e-mail. Você pode tentar novamente em instantes.',
    'en': 'We could not open your email app. Please try again in a moment.',
    'es':
        'No pudimos abrir su app de email. Inténtelo nuevamente en unos instantes.',
  },
  'Nao foi possivel abrir o email de feedback.': {
    'pt':
        'Não conseguimos abrir seu aplicativo de e-mail para enviar o feedback.',
    'en': 'We could not open your email app to send feedback.',
    'es': 'No pudimos abrir su app de email para enviar el feedback.',
  },
  'A avaliacao pela App Store sera ativada quando o app estiver publicado.': {
    'pt': 'A avaliação pela App Store ficará disponível após a publicação.',
    'en': 'App Store rating will be available after the app is published.',
    'es':
        'La calificación en App Store estará disponible cuando la app esté publicada.',
  },
  'A avaliacao direta esta disponivel no Android e no iOS.': {
    'pt': 'A avaliação direta está disponível no Android e no iOS.',
    'en': 'Direct rating is available on Android and iOS.',
    'es': 'La calificación directa está disponible en Android e iOS.',
  },
  'Nao foi possivel abrir a loja para avaliacao.': {
    'pt': 'Não conseguimos abrir a loja para avaliação agora.',
    'en': 'We could not open the store for rating right now.',
    'es': 'No pudimos abrir la tienda para calificar ahora.',
  },
  'Abra o Dashboard para rever a introducao guiada.': {
    'pt': 'Abra o Dashboard para ver a introdução guiada novamente.',
    'en': 'Open the Dashboard to view the guided introduction again.',
    'es': 'Abra el panel para ver nuevamente la introducción guiada.',
  },
  'Ficha técnica CWS Admix': {
    'en': 'CWS Admix Technical Data Sheet',
    'es': 'Ficha técnica CWS Admix',
  },
  'Materiais de apoio': {
    'en': 'Support materials',
    'es': 'Materiales de apoyo',
  },
  'Abra os documentos tecnicos abaixo para consulta rapida durante visitas e acompanhamento de obra.': {
    'pt':
        'Abra os documentos técnicos abaixo para consultar rapidamente durante visitas e acompanhamento da obra.',
    'en':
        'Open the technical documents below for quick reference during visits and jobsite follow-up.',
    'es':
        'Abra los documentos técnicos abajo para consulta rápida durante visitas y seguimiento de obra.',
  },
  'Informacoes tecnicas, instrucoes para uso, armazenamento e suporte.': {
    'pt': 'Informações técnicas, instruções de uso, armazenamento e suporte.',
    'en': 'Technical information, usage instructions, storage, and support.',
    'es':
        'Información técnica, instrucciones de uso, almacenamiento y soporte.',
  },
  'Orientação técnica para a cura do concreto': {
    'en': 'Technical guidance for concrete curing',
    'es': 'Orientación técnica para el curado del hormigón',
  },
  'Boas praticas e orientacoes de aplicacao.': {
    'pt': 'Boas práticas e orientações de aplicação.',
    'en': 'Best practices and application guidance.',
    'es': 'Buenas prácticas y orientaciones de aplicación.',
  },
  'Orientação técnica': {
    'en': 'Technical guidance',
    'es': 'Orientación técnica',
  },
  'FDS CWS Admix': {'en': 'CWS Admix SDS', 'es': 'FDS CWS Admix'},
  'FDS disponível sob demanda. Solicite via ': {
    'en': 'SDS available on request. Ask via ',
    'es': 'FDS disponible bajo solicitud. Solicite por ',
  },
  'Filtros': {'en': 'Filters', 'es': 'Filtros'},
  'Filtros ({count} ativos)': {
    'en': 'Filters ({count} active)',
    'es': 'Filtros ({count} activos)',
  },
  'Expandir filtros': {'en': 'Expand filters', 'es': 'Expandir filtros'},
  'Recolher filtros': {'en': 'Collapse filters', 'es': 'Contraer filtros'},
  ' ou ': {'en': ' or ', 'es': ' o '},
  'Acesse nosso site': {
    'en': 'Visit our website',
    'es': 'Visite nuestro sitio',
  },
  'Abrir documento': {'en': 'Open document', 'es': 'Abrir documento'},
  'Solicitar FDS': {'en': 'Request SDS', 'es': 'Solicitar FDS'},
  'Abrir site': {'en': 'Open website', 'es': 'Abrir sitio'},
  'Nao foi possivel abrir "{label}".': {
    'pt':
        'Não conseguimos abrir "{label}" agora. Tente novamente em instantes.',
    'en':
        'We could not open "{label}" right now. Please try again in a moment.',
    'es':
        'No pudimos abrir "{label}" ahora. Inténtelo nuevamente en unos instantes.',
  },
  'Maiores informações, outros produtos da Netherland, videos e obras executadas.': {
    'en':
        'More information, CWS Waterproofing products, videos, and completed works.',
    'es':
        'Más información, productos de CWS Waterproofing, videos y obras ejecutadas.',
  },
  'Site Netherland': {'en': 'Netherland website', 'es': 'Sitio Netherland'},
  'Site CWS Waterproofing': {
    'en': 'CWS Waterproofing website',
    'es': 'Sitio CWS Waterproofing',
  },
  'Olá, gostaria de solicitar uma cotação do CWS Admix.': {
    'en': 'Hello, I would like to request a quote for CWS Admix.',
    'es': 'Hola, me gustaría solicitar una cotización de CWS Admix.',
  },
  'Volume de concreto': {'en': 'Concrete volume', 'es': 'Volumen de hormigón'},
  'Consumo de cimento': {
    'en': 'Cement consumption',
    'es': 'Consumo de cemento',
  },
  'Consumo de cimento acima de 450 kg/m³': {
    'en': 'Cement consumption above 450 kg/m³',
    'es': 'Consumo de cemento superior a 450 kg/m³',
  },
  'Dosagem aplicada': {'en': 'Applied dosage', 'es': 'Dosificación aplicada'},
  'Quantidade necessária': {
    'en': 'Required quantity',
    'es': 'Cantidad necesaria',
  },
  'Sacos de 6,4 kg': {'en': '6.4 kg bags', 'es': 'Sacos de 6,4 kg'},
  'Quantidade para compra': {
    'en': 'Purchase quantity',
    'es': 'Cantidad para compra',
  },
  'Endereco de entrega': {
    'pt': 'Endereço de entrega',
    'en': 'Delivery address',
    'es': 'Dirección de entrega',
  },
  'Cidade': {'en': 'City', 'es': 'Ciudad'},
  'Estado': {'en': 'State', 'es': 'Estado'},
  'Empresa': {'en': 'Company', 'es': 'Empresa'},
  'E-mail': {'en': 'Email', 'es': 'Email'},
  'Nao informado': {
    'pt': 'Não informado',
    'en': 'Not provided',
    'es': 'No informado',
  },
  'Solicitação de cotação CWS Admix': {
    'en': 'CWS Admix quote request',
    'es': 'Solicitud de cotización CWS Admix',
  },
  'Solicitar cotação por e-mail': {
    'en': 'Request quote by email',
    'es': 'Solicitar cotización por email',
  },
  'Solicitar cotação por WhatsApp': {
    'en': 'Request quote by WhatsApp',
    'es': 'Solicitar cotización por WhatsApp',
  },
  'Ajuste o volume de concreto da sua concretagem e veja quanto CWS Admix será necessário.': {
    'en':
        'Adjust the concrete volume for your pour and see how much CWS Admix is needed.',
    'es':
        'Ajuste el volumen de hormigón y vea cuánto CWS Admix será necesario.',
  },
  'Volume de concreto (m³)': {
    'en': 'Concrete volume (m³)',
    'es': 'Volumen de hormigón (m³)',
  },
  'Consumo de cimento (kg/m³)': {
    'en': 'Cement consumption (kg/m³)',
    'es': 'Consumo de cemento (kg/m³)',
  },
  'Seu traço tem consumo de cimento acima de 450 kg/m³?': {
    'en': 'Does your concrete mix use more than 450 kg of cement per m³?',
    'es': '¿Su mezcla usa más de 450 kg de cemento por m³?',
  },
  'Cálculo ajustado para consumo de cimento acima de 450 kg/m³.': {
    'en': 'Calculation adjusted for cement consumption above 450 kg/m³.',
    'es': 'Cálculo ajustado para un consumo de cemento superior a 450 kg/m³.',
  },
  'Recalcular com dosagem de 1,0 kg/m³': {
    'en': 'Recalculate using a dosage of 1.0 kg/m³',
    'es': 'Recalcular con una dosificación de 1,0 kg/m³',
  },
  'Usar dosagem padrão de 0,80 kg/m³': {
    'en': 'Use the standard dosage of 0.80 kg/m³',
    'es': 'Usar la dosificación estándar de 0,80 kg/m³',
  },
  'Dosagem': {'en': 'Dosage', 'es': 'Dosificación'},
  'Resultado': {'en': 'Result', 'es': 'Resultado'},
  'Solicitar cotação': {'en': 'Request quote', 'es': 'Solicitar cotización'},
  'WhatsApp': {'en': 'WhatsApp', 'es': 'WhatsApp'},
  'Informe um volume maior que zero.': {
    'pt': 'Informe um volume maior que zero para continuar.',
    'en': 'Enter a volume greater than zero to continue.',
    'es': 'Ingrese un volumen mayor que cero para continuar.',
  },
  'Copiar mensagem': {'en': 'Copy message', 'es': 'Copiar mensaje'},
  'Mensagem copiada.': {'en': 'Message copied.', 'es': 'Mensaje copiado.'},
  'Destino': {'en': 'Destination', 'es': 'Destino'},
  'Mensagem': {'en': 'Message', 'es': 'Mensaje'},
  'OK': {
    'pt': 'Dentro do previsto',
    'en': 'Within range',
    'es': 'Dentro de lo previsto',
  },
  'Data da concretagem *': {
    'en': 'Concrete pour date *',
    'es': 'Fecha de hormigonado *',
  },
  'Horário previsto de início *': {
    'en': 'Planned start time *',
    'es': 'Horario previsto de inicio *',
  },
  'Volume estimado (m³)': {
    'en': 'Estimated volume (m³)',
    'es': 'Volumen estimado (m³)',
  },
  'Estrutura a ser concretada': {
    'en': 'Structure to be poured',
    'es': 'Estructura a hormigonar',
  },
  'Traço do concreto': {
    'en': 'Concrete mix design',
    'es': 'Dosificación del hormigón',
  },
  'Selecione a data.': {
    'pt': 'Selecione a data para continuar.',
    'en': 'Select the date to continue.',
    'es': 'Seleccione la fecha para continuar.',
  },
  'Selecione o horário.': {
    'pt': 'Selecione o horário para continuar.',
    'en': 'Select the time to continue.',
    'es': 'Seleccione el horario para continuar.',
  },
  'Informe um volume válido.': {
    'pt': 'Informe um volume válido para continuar.',
    'en': 'Enter a valid volume to continue.',
    'es': 'Ingrese un volumen válido para continuar.',
  },
  'Haverá adição do CWS Admix ao concreto.': {
    'en': 'CWS Admix will be added to the concrete.',
    'es': 'Se añadirá CWS Admix al hormigón.',
  },
  'Quantidade estimada de CWS Admix': {
    'en': 'Estimated CWS Admix quantity',
    'es': 'Cantidad estimada de CWS Admix',
  },
  'Fazer pedido de CWS Admix': {
    'en': 'Order CWS Admix',
    'es': 'Realizar pedido de CWS Admix',
  },
  'CWS Admix previsto: informe o volume.': {
    'pt': 'Informe o volume para ver o CWS Admix previsto.',
    'en': 'Enter the volume to see the estimated CWS Admix.',
    'es': 'Informe el volumen para ver el CWS Admix previsto.',
  },
  'CWS Admix previsto': {
    'en': 'Estimated CWS Admix',
    'es': 'CWS Admix previsto',
  },
  'Cálculo de produto por volume de concreto': {
    'en': 'Product calculation by concrete volume',
    'es': 'Cálculo de producto por volumen de hormigón',
  },
  'Dados para cotacao': {
    'pt': 'Dados para cotação',
    'en': 'Quote details',
    'es': 'Datos para cotización',
  },
  'Copiar': {'en': 'Copy', 'es': 'Copiar'},
  'Fechar': {'en': 'Close', 'es': 'Cerrar'},
  'Enter': {'en': 'Enter', 'es': 'Enter'},
  'Dados copiados para a área de transferência.': {
    'en': 'Data copied to the clipboard.',
    'es': 'Datos copiados al portapapeles.',
  },
  'AGENDAR': {'en': 'SCHEDULE', 'es': 'PROGRAMAR'},
  'Compartilhar WhatsApp': {
    'en': 'Share via WhatsApp',
    'es': 'Compartir por WhatsApp',
  },
  'Segue o agendamento de concretagem:': {
    'en': 'Here are the concrete pour scheduling details:',
    'es': 'Sigue la programación del hormigonado:',
  },
  'Agendamento criado.': {
    'en': 'Schedule created.',
    'es': 'Programación creada.',
  },
  'Agendamento enviado ao Calendario.': {
    'en': 'Schedule sent to Calendar.',
    'es': 'Programación enviada al Calendario.',
  },
  'Agendamento criado': {'en': 'Schedule created', 'es': 'Programación creada'},
  'Agendamento enviado': {'en': 'Schedule sent', 'es': 'Programación enviada'},
  'Agendamento de concretagem': {
    'en': 'Concrete pour scheduling',
    'es': 'Programación de hormigonado',
  },
  'Deseja compartilhar no WhatsApp?': {
    'en': 'Do you want to share it on WhatsApp?',
    'es': '¿Desea compartirlo por WhatsApp?',
  },
  'Deseja enviar um resumo pelo WhatsApp?': {
    'en': 'Do you want to send a summary via WhatsApp?',
    'es': '¿Desea enviar un resumen por WhatsApp?',
  },
  'Agora não': {'en': 'Not now', 'es': 'Ahora no'},
  'Voltar': {'en': 'Back', 'es': 'Volver'},
  'Voltar ao dashboard': {'en': 'Back to dashboard', 'es': 'Volver al panel'},
  'Dados da concretagem': {
    'en': 'Concrete pour details',
    'es': 'Datos del hormigonado',
  },
  'Informe a data da concretagem.': {
    'pt': 'Informe a data da concretagem para continuar.',
    'en': 'Enter the concrete pour date to continue.',
    'es': 'Informe la fecha del hormigonado para continuar.',
  },
  'Informe o horario previsto.': {
    'pt': 'Informe o horário previsto para continuar.',
    'en': 'Enter the planned time to continue.',
    'es': 'Informe el horario previsto para continuar.',
  },
  'Informe um volume valido.': {
    'pt': 'Informe um volume válido para continuar.',
    'en': 'Enter a valid volume to continue.',
    'es': 'Ingrese un volumen válido para continuar.',
  },
  'Informe uma data e horario futuros.': {
    'pt': 'Escolha uma data e um horário futuros.',
    'en': 'Choose a future date and time.',
    'es': 'Elija una fecha y un horario futuros.',
  },
  'Informe o volume previsto antes de fazer o pedido.': {
    'pt': 'Informe o volume previsto antes de seguir para o pedido.',
    'en': 'Enter the planned volume before continuing to the order.',
    'es': 'Informe el volumen previsto antes de continuar con el pedido.',
  },
  'Erro ao preparar agendamento: {error}': {
    'pt': 'Não foi possível preparar o agendamento. Detalhes: {error}',
    'en': 'We could not prepare the schedule. Details: {error}',
    'es': 'No pudimos preparar la programación. Detalles: {error}',
  },
  'Evento enviado ao Calendario.': {
    'pt': 'Evento enviado ao Calendário.',
    'en': 'Event sent to Calendar.',
    'es': 'Evento enviado al Calendario.',
  },
  'O evento foi enviado ao aplicativo de calendario. Confira e salve para concluir.': {
    'pt':
        'O evento foi enviado ao aplicativo de calendário. Confira os dados e salve para concluir.',
    'en':
        'The event was sent to the calendar app. Review and save it to finish.',
    'es':
        'El evento fue enviado a la aplicación de calendario. Revíselo y guárdelo para concluir.',
  },
  'Convite de calendario preparado. Use o aplicativo escolhido para concluir.': {
    'pt':
        'Convite de calendário preparado. Use o aplicativo escolhido para concluir.',
    'en': 'Calendar invite prepared. Use the selected app to finish.',
    'es':
        'Invitación de calendario preparada. Use la aplicación elegida para concluir.',
  },
  'Concretagem programada': {
    'en': 'Scheduled concrete pour',
    'es': 'Hormigonado programado',
  },
  'Concretagem': {'en': 'Concrete pour', 'es': 'Hormigonado'},
  'Estrutura': {'en': 'Structure', 'es': 'Estructura'},
  'Data e hora previstas': {
    'en': 'Planned date and time',
    'es': 'Fecha y hora previstas',
  },
  'Volume estimado': {'en': 'Estimated volume', 'es': 'Volumen estimado'},
  'Lembrete': {'en': 'Reminder', 'es': 'Recordatorio'},
  'amanha': {'en': 'tomorrow', 'es': 'mañana'},
  'Compartilhar': {'en': 'Share', 'es': 'Compartir'},
  'Cancelar': {'en': 'Cancel', 'es': 'Cancelar'},
  'Permissao para criar evento no Calendario negada.': {
    'pt':
        'Não temos permissão para criar eventos no Calendário. Revise as permissões do app.',
    'en':
        'We do not have permission to create Calendar events. Review the app permissions.',
    'es':
        'No tenemos permiso para crear eventos en el Calendario. Revise los permisos de la app.',
  },
  'Nao foi possivel criar o evento no Calendario.': {
    'pt':
        'Não conseguimos criar o evento no Calendário. Confira as permissões e tente novamente.',
    'en':
        'We could not create the Calendar event. Check permissions and try again.',
    'es':
        'No pudimos crear el evento en el Calendario. Revise los permisos e inténtelo nuevamente.',
  },
  'Evento criado no Calendario.': {
    'pt': 'Evento criado no Calendário.',
    'en': 'Calendar event created.',
    'es': 'Evento creado en el Calendario.',
  },
  'Compartilhamento indisponivel nesta plataforma.': {
    'pt': 'O compartilhamento não está disponível nesta plataforma.',
    'en': 'Sharing is not available on this platform.',
    'es': 'Compartir no está disponible en esta plataforma.',
  },
  ' - ATENÇÃO: acima do limite de 2h30': {
    'pt': ' - revisar: acima do limite de 2h30',
    'en': ' - review: above the 2h30 limit',
    'es': ' - revisar: por encima del límite de 2h30',
  },
  ' - sem marcação': {'en': ' - unmarked', 'es': ' - sin marca'},
  'A planta já foi salva. Agora basta cadastrar o primeiro lançamento desta concretagem para começar a marcação.': {
    'en':
        'The plan has been saved. Now add the first placement for this pour to start marking it.',
    'es':
        'La planta ya fue guardada. Ahora registre el primer lanzamiento de este hormigonado para empezar a marcarla.',
  },
  'Abrir': {'en': 'Open', 'es': 'Abrir'},
  'Abrir configuracoes': {'en': 'Open settings', 'es': 'Abrir configuración'},
  'Abrir no mapa': {'en': 'Open in map', 'es': 'Abrir en el mapa'},
  'Abrir rastreio da planta': {
    'en': 'Open plan tracking',
    'es': 'Abrir rastreo de la planta',
  },
  'Adicionar': {'en': 'Add', 'es': 'Agregar'},
  'Agora nao': {'en': 'Not now', 'es': 'Ahora no'},
  'Ainda resta 1 lançamento sem marcação. Deseja encerrar mesmo assim?': {
    'pt':
        'Ainda resta 1 lançamento sem marcação na planta. Deseja encerrar mesmo assim?',
    'en': 'There is still 1 unmarked placement on the plan. Close anyway?',
    'es': 'Aún queda 1 lanzamiento sin marca. ¿Desea cerrar de todos modos?',
  },
  'Ainda restam {count} lançamentos sem marcação. Deseja encerrar mesmo assim?': {
    'pt':
        'Ainda restam {count} lançamentos sem marcação na planta. Deseja encerrar mesmo assim?',
    'en':
        'There are still {count} unmarked placements on the plan. Close anyway?',
    'es':
        'Aún quedan {count} lanzamientos sin marca. ¿Desea cerrar de todos modos?',
  },
  'Ajuste o período/filtros ou adicione uma nova concretagem.': {
    'pt': 'Ajuste o período ou os filtros, ou adicione uma nova concretagem.',
    'en': 'Adjust the period or filters, or add a new concrete pour.',
    'es': 'Ajuste el período o los filtros, o agregue un nuevo hormigonado.',
  },
  'Alterações pendentes': {'en': 'Pending changes', 'es': 'Cambios pendientes'},
  'Aplicar': {'en': 'Apply', 'es': 'Aplicar'},
  'Arquivada em: {date}': {
    'en': 'Archived on: {date}',
    'es': 'Archivada el: {date}',
  },
  'Arquivadas': {'en': 'Archived', 'es': 'Archivadas'},
  'Arquivar': {'en': 'Archive', 'es': 'Archivar'},
  'Arquivar obra': {'en': 'Archive jobsite', 'es': 'Archivar obra'},
  'Ativas': {'en': 'Active', 'es': 'Activas'},
  'Atualizar localizacao': {
    'en': 'Update location',
    'es': 'Actualizar ubicación',
  },
  'Avaliar': {'en': 'Rate', 'es': 'Calificar'},
  'Betoneira (A→Z)': {
    'en': 'Mixer truck (A-Z)',
    'es': 'Camión mezclador (A-Z)',
  },
  'Betoneira (nº/placa)': {
    'en': 'Mixer truck (no./plate)',
    'es': 'Camión mezclador (n.º/patente)',
  },
  'Betoneira sem identificação': {
    'en': 'Unidentified mixer truck',
    'es': 'Camión mezclador sin identificación',
  },
  'Betoneira: {value}': {
    'en': 'Mixer truck: {value}',
    'es': 'Camión mezclador: {value}',
  },
  'Busca (betoneira, concreteira, NF, obs)': {
    'en': 'Search (truck, supplier, invoice, notes)',
    'es': 'Búsqueda (camión, hormigonera, factura, obs.)',
  },
  'Busca: {value}': {'en': 'Search: {value}', 'es': 'Búsqueda: {value}'},
  'CSV da obra {obra}. Use "Salvar em Arquivos" ou sua nuvem preferida.': {
    'en':
        'CSV for jobsite {obra}. Use "Save to Files" or your preferred cloud.',
    'es':
        'CSV de la obra {obra}. Use "Guardar en Archivos" o su nube preferida.',
  },
  'CSV exportado ({count} linhas): {path}': {
    'en': 'CSV exported ({count} rows): {path}',
    'es': 'CSV exportado ({count} líneas): {path}',
  },
  'CSV pronto para compartilhar ({count} linhas).': {
    'pt': 'CSV pronto para compartilhar ({count} linhas).',
    'en': 'CSV ready to share ({count} rows).',
    'es': 'CSV listo para compartir ({count} líneas).',
  },
  'CSV pronto para exportacao ({count} linhas). Use "Salvar em Arquivos".': {
    'pt':
        'CSV pronto para exportação ({count} linhas). Use "Salvar em Arquivos".',
    'en': 'CSV ready to export ({count} rows). Use "Save to Files".',
    'es':
        'CSV listo para exportar ({count} líneas). Use "Guardar en Archivos".',
  },
  'CWS (maior→menor)': {'en': 'CWS (high-low)', 'es': 'CWS (mayor-menor)'},
  'CWS (menor→maior)': {'en': 'CWS (low-high)', 'es': 'CWS (menor-mayor)'},
  'CWS Total (kg)': {'en': 'CWS total (kg)', 'es': 'CWS total (kg)'},
  'CWS adicionado (kg)': {'en': 'CWS added (kg)', 'es': 'CWS agregado (kg)'},
  'CWS adicionado: {value} kg': {
    'en': 'CWS added: {value} kg',
    'es': 'CWS agregado: {value} kg',
  },
  'CWS total: {value} kg': {
    'en': 'CWS total: {value} kg',
    'es': 'CWS total: {value} kg',
  },
  'CWS: {value} kg': {'en': 'CWS: {value} kg', 'es': 'CWS: {value} kg'},
  'Cadastre o e-mail do engenheiro na obra antes de enviar.': {
    'en': 'Register the engineer email on the jobsite before sending.',
    'es': 'Registre el email del ingeniero en la obra antes de enviar.',
  },
  'Carregamento em {date}. Intervalo de {duration} até o preenchimento.': {
    'pt':
        'Carregamento em {date}. Intervalo de {duration} até o preenchimento.',
    'en': 'Loaded at {date}. Interval of {duration} until entry.',
    'es': 'Carga a las {date}. Intervalo de {duration} hasta el registro.',
  },
  'Carregamento: {date}': {
    'pt': 'Carregamento: {date}',
    'en': 'Loading: {date}',
    'es': 'Carga: {date}',
  },
  'Cliente': {'en': 'Client', 'es': 'Cliente'},
  'Cliente: {value}': {'en': 'Client: {value}', 'es': 'Cliente: {value}'},
  'Como esta sua experiencia?': {
    'en': 'How is your experience?',
    'es': '¿Cómo está siendo su experiencia?',
  },
  'Concretagem sem ID.': {
    'en': 'Concrete pour has no ID.',
    'es': 'Hormigonado sin ID.',
  },
  'Concretagem {id}': {'en': 'Concrete pour {id}', 'es': 'Hormigonado {id}'},
  'Concretagem {index}': {
    'en': 'Concrete pour {index}',
    'es': 'Hormigonado {index}',
  },
  'Concreteira': {'en': 'Concrete supplier', 'es': 'Hormigonera'},
  'Concreteira (A→Z)': {
    'en': 'Concrete supplier (A-Z)',
    'es': 'Hormigonera (A-Z)',
  },
  'Concreteira: {value}': {
    'en': 'Concrete supplier: {value}',
    'es': 'Hormigonera: {value}',
  },
  'Continuar marcando': {'en': 'Keep marking', 'es': 'Continuar marcando'},
  'Controle tecnologico': {
    'en': 'Technical control',
    'es': 'Control tecnológico',
  },
  'Controle tecnológico: {value}': {
    'en': 'Technical control: {value}',
    'es': 'Control tecnológico: {value}',
  },
  'Coordenadas: {value}': {
    'en': 'Coordinates: {value}',
    'es': 'Coordenadas: {value}',
  },
  'Criada em: {date}': {'en': 'Created on: {date}', 'es': 'Creada el: {date}'},
  'DIVERGENTE': {
    'pt': 'Revisar dosagem',
    'en': 'Review dosage',
    'es': 'Revisar dosificación',
  },
  'Dados extraídos da NF por OCR:': {
    'en': 'Invoice data extracted by OCR:',
    'es': 'Datos de la factura extraídos por OCR:',
  },
  'Data (antigo→recente)': {
    'en': 'Date (old-new)',
    'es': 'Fecha (antiguo-reciente)',
  },
  'Data (recente→antigo)': {
    'en': 'Date (new-old)',
    'es': 'Fecha (reciente-antiguo)',
  },
  'Data/Hora': {'en': 'Date/Time', 'es': 'Fecha/Hora'},
  'Data/hora: {date}': {'en': 'Date/time: {date}', 'es': 'Fecha/hora: {date}'},
  'Deseja apagar todas as marcações desta planta?': {
    'pt': 'Deseja apagar todas as marcações desta planta?',
    'en': 'Do you want to clear all markings on this plan?',
    'es': '¿Desea borrar todas las marcas de esta planta?',
  },
  'Deseja arquivar a obra "{nome}"?': {
    'pt': 'Deseja arquivar a obra "{nome}"? Ela sairá da lista de ativas.',
    'en': 'Archive jobsite "{nome}"? It will leave the active list.',
    'es': '¿Desea archivar la obra "{nome}"? Saldrá de la lista de activas.',
  },
  'Deseja excluir o lançamento da betoneira "{betoneira}"?': {
    'pt': 'Deseja excluir o lançamento da betoneira "{betoneira}"?',
    'en': 'Delete the placement from mixer truck "{betoneira}"?',
    'es': '¿Desea eliminar el lanzamiento del camión "{betoneira}"?',
  },
  'Deseja excluir permanentemente a obra "{nome}" e todos os seus lancamentos?': {
    'pt':
        'Deseja excluir permanentemente a obra "{nome}" e todos os seus lançamentos? Esta ação não pode ser desfeita.',
    'en':
        'Permanently delete jobsite "{nome}" and all its placements? This cannot be undone.',
    'es':
        '¿Desea eliminar permanentemente la obra "{nome}" y todos sus lanzamientos? Esta acción no se puede deshacer.',
  },
  'Deseja gerar o PDF da concretagem antes de encerrar?': {
    'pt': 'Deseja gerar o PDF da concretagem antes de encerrar?',
    'en': 'Generate the concrete pour PDF before closing it?',
    'es': '¿Desea generar el PDF del hormigonado antes de cerrarlo?',
  },
  'Deseja restaurar a obra "{nome}" para Ativas?': {
    'pt': 'Deseja restaurar a obra "{nome}" para a lista de ativas?',
    'en': 'Restore jobsite "{nome}" to the active list?',
    'es': '¿Desea restaurar la obra "{nome}" a la lista de activas?',
  },
  'Deseja substituir a planta atual desta concretagem?': {
    'en': 'Replace the current plan for this concrete pour?',
    'es': '¿Desea sustituir la planta actual de este hormigonado?',
  },
  'Desfazer': {'en': 'Undo', 'es': 'Deshacer'},
  'Dosagem (kg/m³)': {'en': 'Dosage (kg/m³)', 'es': 'Dosificación (kg/m³)'},
  'Dosagem de acordo': {
    'en': 'Dosage compliant',
    'es': 'Dosificación conforme',
  },
  'Dosagem deve ser maior que zero': {
    'pt': 'A dosagem deve ser maior que zero.',
    'en': 'Dosage must be greater than zero.',
    'es': 'La dosificación debe ser mayor que cero.',
  },
  'Dosagem: {value} kg/m³': {
    'en': 'Dosage: {value} kg/m³',
    'es': 'Dosificación: {value} kg/m³',
  },
  'E-mail engenheiro: {value}': {
    'en': 'Engineer email: {value}',
    'es': 'Email del ingeniero: {value}',
  },
  'E-mail preparado para {email}': {
    'pt': 'E-mail preparado para {email}. Revise e envie no seu aplicativo.',
    'en': 'Email prepared for {email}. Review and send it in your email app.',
    'es': 'Email preparado para {email}. Revíselo y envíelo en su app.',
  },
  'Editar': {'en': 'Edit', 'es': 'Editar'},
  'Editar Concretagem': {
    'en': 'Edit Concrete Pour',
    'es': 'Editar Hormigonado',
  },
  'Editar Lançamento': {'en': 'Edit Placement', 'es': 'Editar Lanzamiento'},
  'Editar Obra': {'en': 'Edit Jobsite', 'es': 'Editar Obra'},
  'Editar concretagem': {
    'en': 'Edit concrete pour',
    'es': 'Editar hormigonado',
  },
  'Editar obra': {'en': 'Edit jobsite', 'es': 'Editar obra'},
  'Empresa de tecnologia do concreto: {value}': {
    'en': 'Concrete technology company: {value}',
    'es': 'Empresa de tecnología del concreto: {value}',
  },
  'Empresa tecnologia do concreto': {
    'en': 'Concrete technology company',
    'es': 'Empresa de tecnología del concreto',
  },
  'Empresa tecnologia: {value}': {
    'en': 'Technology company: {value}',
    'es': 'Empresa de tecnología: {value}',
  },
  'Encerrar': {'en': 'Close', 'es': 'Cerrar'},
  'Encerrar concretagem': {
    'en': 'Close concrete pour',
    'es': 'Cerrar hormigonado',
  },
  'Encerrar sem PDF': {'en': 'Close without PDF', 'es': 'Cerrar sin PDF'},
  'Entendi': {'en': 'Got it', 'es': 'Entendido'},
  'Enviar por e-mail': {'en': 'Send by email', 'es': 'Enviar por email'},
  'Erro ao abrir mapa: {error}': {
    'pt': 'Não foi possível abrir o mapa. Detalhes: {error}',
    'en': 'We could not open the map. Details: {error}',
    'es': 'No pudimos abrir el mapa. Detalles: {error}',
  },
  'Erro ao adicionar fotos: {error}': {
    'pt': 'Não foi possível adicionar as fotos. Detalhes: {error}',
    'en': 'We could not add the photos. Details: {error}',
    'es': 'No pudimos agregar las fotos. Detalles: {error}',
  },
  'Erro ao atualizar lançamento: {error}': {
    'pt': 'Não foi possível atualizar o lançamento. Detalhes: {error}',
    'en': 'We could not update the placement. Details: {error}',
    'es': 'No pudimos actualizar el lanzamiento. Detalles: {error}',
  },
  'Erro ao atualizar obra: {error}': {
    'pt': 'Não foi possível atualizar a obra. Detalhes: {error}',
    'en': 'We could not update the jobsite. Details: {error}',
    'es': 'No pudimos actualizar la obra. Detalles: {error}',
  },
  'Erro ao carregar lançamentos: {error}': {
    'pt': 'Não foi possível carregar os lançamentos. Detalhes: {error}',
    'en': 'We could not load the placements. Details: {error}',
    'es': 'No pudimos cargar los lanzamientos. Detalles: {error}',
  },
  'Erro ao carregar obras: {error}': {
    'pt': 'Não foi possível carregar as obras. Detalhes: {error}',
    'en': 'We could not load the jobsites. Details: {error}',
    'es': 'No pudimos cargar las obras. Detalles: {error}',
  },
  'Erro ao enviar relatório por e-mail: {error}': {
    'pt': 'Não foi possível enviar o relatório por e-mail. Detalhes: {error}',
    'en': 'We could not send the report by email. Details: {error}',
    'es': 'No pudimos enviar el informe por email. Detalles: {error}',
  },
  'Erro ao escanear nota fiscal: {error}': {
    'pt': 'Não foi possível escanear a nota fiscal. Detalhes: {error}',
    'en': 'We could not scan the invoice. Details: {error}',
    'es': 'No pudimos escanear la factura. Detalles: {error}',
  },
  'Erro ao excluir lançamento: {error}': {
    'pt': 'Não foi possível excluir o lançamento. Detalhes: {error}',
    'en': 'We could not delete the placement. Details: {error}',
    'es': 'No pudimos eliminar el lanzamiento. Detalles: {error}',
  },
  'Erro ao exportar CSV: {error}': {
    'pt': 'Não foi possível exportar o CSV. Detalhes: {error}',
    'en': 'We could not export the CSV. Details: {error}',
    'es': 'No pudimos exportar el CSV. Detalles: {error}',
  },
  'Erro ao gerar relatório da concretagem: {error}': {
    'pt':
        'Não foi possível gerar o relatório da concretagem. Detalhes: {error}',
    'en': 'We could not generate the concrete pour report. Details: {error}',
    'es': 'No pudimos generar el informe del hormigonado. Detalles: {error}',
  },
  'Erro ao localizar endereco: {error}': {
    'pt': 'Não foi possível localizar o endereço. Detalhes: {error}',
    'en': 'We could not locate the address. Details: {error}',
    'es': 'No pudimos ubicar la dirección. Detalles: {error}',
  },
  'Erro ao obter localizacao: {error}': {
    'pt': 'Não foi possível obter a localização. Detalhes: {error}',
    'en': 'We could not get the location. Details: {error}',
    'es': 'No pudimos obtener la ubicación. Detalles: {error}',
  },
  'Erro ao salvar concretagem: {error}': {
    'pt': 'Não foi possível salvar a concretagem. Detalhes: {error}',
    'en': 'We could not save the concrete pour. Details: {error}',
    'es': 'No pudimos guardar el hormigonado. Detalles: {error}',
  },
  'Erro ao salvar lançamento: {error}': {
    'pt': 'Não foi possível salvar o lançamento. Detalhes: {error}',
    'en': 'We could not save the placement. Details: {error}',
    'es': 'No pudimos guardar el lanzamiento. Detalles: {error}',
  },
  'Erro ao salvar obra: {error}': {
    'pt': 'Não foi possível salvar a obra. Detalhes: {error}',
    'en': 'We could not save the jobsite. Details: {error}',
    'es': 'No pudimos guardar la obra. Detalles: {error}',
  },
  'Erro ao salvar rastreio da planta: {error}': {
    'pt': 'Não foi possível salvar o rastreio da planta. Detalhes: {error}',
    'en': 'We could not save the plan tracking. Details: {error}',
    'es': 'No pudimos guardar el rastreo de la planta. Detalles: {error}',
  },
  'Erro ao selecionar a planta: {error}': {
    'pt': 'Não foi possível selecionar a planta. Detalhes: {error}',
    'en': 'We could not select the plan. Details: {error}',
    'es': 'No pudimos seleccionar la planta. Detalles: {error}',
  },
  'Escanear com a câmera': {
    'en': 'Scan with camera',
    'es': 'Escanear con la cámara',
  },
  'Escanear nota fiscal': {'en': 'Scan invoice', 'es': 'Escanear factura'},
  'Escanear ou importar planta': {
    'en': 'Scan or import plan',
    'es': 'Escanear o importar planta',
  },
  'Escanear planta': {'en': 'Scan plan', 'es': 'Escanear planta'},
  'Escaneie ou importe a planta para começar o rastreio.': {
    'en': 'Scan or import the plan to start tracking.',
    'es': 'Escanee o importe la planta para iniciar el rastreo.',
  },
  'Escolher da galeria': {
    'en': 'Choose from gallery',
    'es': 'Elegir de la galería',
  },
  'Estrutura concretada': {
    'en': 'Poured structure',
    'es': 'Estructura hormigonada',
  },
  'Estrutura não informada': {
    'en': 'Structure not provided',
    'es': 'Estructura no informada',
  },
  'Estrutura: {value}': {
    'en': 'Structure: {value}',
    'es': 'Estructura: {value}',
  },
  'Excluir': {'en': 'Delete', 'es': 'Eliminar'},
  'Excluir lançamento': {
    'en': 'Delete placement',
    'es': 'Eliminar lanzamiento',
  },
  'Excluir obra': {'en': 'Delete jobsite', 'es': 'Eliminar obra'},
  'Falha ao renderizar a planta para o PDF.': {
    'pt': 'Não conseguimos preparar a planta para o PDF.',
    'en': 'We could not prepare the plan for the PDF.',
    'es': 'No pudimos preparar la planta para el PDF.',
  },
  'Ferramentas de rastreio': {
    'en': 'Tracking tools',
    'es': 'Herramientas de rastreo',
  },
  'Fotos': {'en': 'Photos', 'es': 'Fotos'},
  'Fotos anexas: {count}': {
    'en': 'Attached photos: {count}',
    'es': 'Fotos adjuntas: {count}',
  },
  'Geracao de arquivo local PDF nao esta disponivel no navegador.': {
    'pt': 'A geração de arquivo PDF local não está disponível no navegador.',
    'en': 'Local PDF file generation is not available in the browser.',
    'es':
        'La generación de archivo PDF local no está disponible en el navegador.',
  },
  'Gerado em {date}': {'en': 'Generated on {date}', 'es': 'Generado el {date}'},
  'Gerando relatório...': {
    'en': 'Generating report...',
    'es': 'Generando informe...',
  },
  'Gerar PDF': {'en': 'Generate PDF', 'es': 'Generar PDF'},
  'Gerar PDF da concretagem': {
    'en': 'Generate concrete pour PDF',
    'es': 'Generar PDF del hormigonado',
  },
  'Gerar pelo endereco': {
    'en': 'Generate from address',
    'es': 'Generar desde la dirección',
  },
  'Gere pelo endereco digitado ou use a localizacao atual': {
    'en': 'Generate from the typed address or use current location',
    'es': 'Genere desde la dirección ingresada o use la ubicación actual',
  },
  'Hoje': {'en': 'Today', 'es': 'Hoy'},
  'Há marcações pendentes nesta planta. Deseja salvar antes de sair?': {
    'en': 'There are pending markings on this plan. Save before leaving?',
    'es':
        'Hay marcas pendientes en esta planta. ¿Desea guardar antes de salir?',
  },
  'Informe a betoneira': {
    'pt': 'Informe a betoneira para continuar.',
    'en': 'Enter the mixer truck to continue.',
    'es': 'Informe el camión mezclador para continuar.',
  },
  'Informe a dosagem': {
    'pt': 'Informe a dosagem para continuar.',
    'en': 'Enter the dosage to continue.',
    'es': 'Informe la dosificación para continuar.',
  },
  'Informe o e-mail do engenheiro': {
    'pt': 'Informe o e-mail do responsável técnico.',
    'en': 'Enter the responsible engineer email.',
    'es': 'Informe el email del responsable técnico.',
  },
  'Informe o endereco da obra para gerar a localizacao.': {
    'pt': 'Informe o endereço da obra para gerar a localização.',
    'en': 'Enter the jobsite address to generate the location.',
    'es': 'Ingrese la dirección de la obra para generar la ubicación.',
  },
  'Informe o nome da obra': {
    'pt': 'Informe o nome da obra para continuar.',
    'en': 'Enter the jobsite name to continue.',
    'es': 'Informe el nombre de la obra para continuar.',
  },
  'Informe o volume': {
    'pt': 'Informe o volume para continuar.',
    'en': 'Enter the volume to continue.',
    'es': 'Informe el volumen para continuar.',
  },
  'Informe um e-mail válido': {
    'pt': 'Informe um e-mail válido.',
    'en': 'Enter a valid email.',
    'es': 'Ingrese un email válido.',
  },
  'Ir para o primeiro lançamento': {
    'en': 'Go to first placement',
    'es': 'Ir al primer lanzamiento',
  },
  'Já existe uma obra ativa com esse nome.': {
    'en': 'An active jobsite with this name already exists.',
    'es': 'Ya existe una obra activa con ese nombre.',
  },
  'Lançamento atualizado com sucesso.': {
    'pt': 'Lançamento atualizado.',
    'en': 'Placement updated.',
    'es': 'Lanzamiento actualizado.',
  },
  'Lançamento salvo com sucesso.': {
    'pt': 'Lançamento salvo.',
    'en': 'Placement saved.',
    'es': 'Lanzamiento guardado.',
  },
  'Lançamento {id}': {'en': 'Placement {id}', 'es': 'Lanzamiento {id}'},
  'Lançamentos desta concretagem': {
    'en': 'Placements for this concrete pour',
    'es': 'Lanzamientos de este hormigonado',
  },
  'Lançamentos para marcar': {
    'en': 'Placements to mark',
    'es': 'Lanzamientos para marcar',
  },
  'Lançamentos: {count}': {
    'en': 'Placements: {count}',
    'es': 'Lanzamientos: {count}',
  },
  'Latitude': {'en': 'Latitude', 'es': 'Latitud'},
  'Lacre: {value}': {'en': 'Seal: {value}', 'es': 'Lacre: {value}'},
  'Legenda dos lançamentos': {
    'en': 'Placement legend',
    'es': 'Leyenda de lanzamientos',
  },
  'Limpar': {'en': 'Clear', 'es': 'Limpiar'},
  'Limpar busca': {'en': 'Clear search', 'es': 'Limpiar búsqueda'},
  'Limpar filtros': {'en': 'Clear filters', 'es': 'Limpiar filtros'},
  'Limpar localizacao': {'en': 'Clear location', 'es': 'Limpiar ubicación'},
  'Limpar marcações': {'en': 'Clear markings', 'es': 'Limpiar marcas'},
  'Local': {'en': 'Location', 'es': 'Lugar'},
  'Local: {value}': {'en': 'Location: {value}', 'es': 'Lugar: {value}'},
  'Localizacao da obra': {
    'en': 'Jobsite location',
    'es': 'Ubicación de la obra',
  },
  'Localizacao da obra: {value}': {
    'en': 'Jobsite location: {value}',
    'es': 'Ubicación de la obra: {value}',
  },
  'Localizacao: {value}': {
    'en': 'Location: {value}',
    'es': 'Ubicación: {value}',
  },
  'Longitude': {'en': 'Longitude', 'es': 'Longitud'},
  'Marcados: {count}': {'en': 'Marked: {count}', 'es': 'Marcados: {count}'},
  'Marcações salvas na concretagem.': {
    'en': 'Markings saved to the concrete pour.',
    'es': 'Marcas guardadas en el hormigonado.',
  },
  'Mistura: {value} min': {
    'en': 'Mixing: {value} min',
    'es': 'Mezcla: {value} min',
  },
  'Modo navegar ativo: use pinça e arraste para ampliar e posicionar a planta. Ao voltar para o spray, esse enquadramento é mantido.': {
    'pt':
        'Modo navegar ativo: use pinça e arraste para ajustar a planta. Ao voltar para o spray, esse enquadramento será mantido.',
    'en':
        'Navigate mode active: pinch and drag to zoom and position the plan. When you return to spray, this framing is kept.',
    'es':
        'Modo navegar activo: use pinza y arrastre para ampliar y posicionar la planta. Al volver al spray, este encuadre se mantiene.',
  },
  'Modo spray ativo: a planta fica travada no enquadramento atual para não se mover durante a marcação. Use Navegar para ajustar o zoom; as marcações são salvas automaticamente.': {
    'pt':
        'Modo spray ativo: a planta fica fixa durante a marcação. Use Navegar para ajustar o zoom; as marcações são salvas automaticamente.',
    'en':
        'Spray mode active: the plan is locked in the current framing so it does not move while marking. Use Navigate to adjust zoom; markings are saved automatically.',
    'es':
        'Modo spray activo: la planta queda fija en el encuadre actual para no moverse durante la marca. Use Navegar para ajustar el zoom; las marcas se guardan automáticamente.',
  },
  'NF': {'en': 'Invoice', 'es': 'Factura'},
  'NF: {value}': {'en': 'Invoice: {value}', 'es': 'Factura: {value}'},
  'Nao foi possivel abrir as configuracoes do aparelho.': {
    'pt': 'Não conseguimos abrir as configurações do aparelho.',
    'en': 'We could not open device settings.',
    'es': 'No pudimos abrir la configuración del dispositivo.',
  },
  'Nao foi possivel gerar a localizacao pelo endereco. Revise o endereco ou use a localizacao atual.': {
    'pt':
        'Não conseguimos gerar a localização pelo endereço. Revise o endereço ou use a localização atual.',
    'en':
        'Could not generate the location from the address. Review the address or use the current location.',
    'es':
        'No se pudo generar la ubicación desde la dirección. Revise la dirección o use la ubicación actual.',
  },
  'Nao informada': {
    'pt': 'Não informada',
    'en': 'Not provided',
    'es': 'No informada',
  },
  'Navegar': {'en': 'Navigate', 'es': 'Navegar'},
  'Nenhum dado estruturado identificado. Conferir a imagem.': {
    'pt': 'Não identificamos os dados principais. Confira a imagem.',
    'en': 'We could not identify the main data. Check the image.',
    'es': 'No identificamos los datos principales. Revise la imagen.',
  },
  'Nenhum lançamento cadastrado nesta concretagem.': {
    'en': 'No placements registered for this concrete pour.',
    'es': 'No hay lanzamientos registrados en este hormigonado.',
  },
  'Nenhuma concretagem com os filtros atuais.': {
    'pt': 'Nenhuma concretagem encontrada com os filtros atuais.',
    'en': 'No concrete pours match the current filters.',
    'es': 'Ningún hormigonado coincide con los filtros actuales.',
  },
  'Nenhuma obra arquivada.': {
    'en': 'No archived jobsites.',
    'es': 'Ninguna obra archivada.',
  },
  'Nenhuma obra cadastrada ainda.\nToque em "+ Nova Obra".': {
    'pt':
        'Nenhuma obra cadastrada ainda.\nToque em "+ Nova Obra" para começar.',
    'en': 'No jobsites registered yet.\nTap "+ New Jobsite".',
    'es': 'Aún no hay obras registradas.\nToque "+ Nueva Obra".',
  },
  'Nenhuma planta carregada': {
    'en': 'No plan loaded',
    'es': 'Ninguna planta cargada',
  },
  'Nota fiscal escaneada. Confira os dados preenchidos.': {
    'pt': 'Nota fiscal escaneada. Confira os dados antes de salvar.',
    'en': 'Invoice scanned. Review the data before saving.',
    'es': 'Factura escaneada. Revise los datos antes de guardar.',
  },
  'Nova Concretagem': {'en': 'New Concrete Pour', 'es': 'Nuevo Hormigonado'},
  'Nova Obra': {'en': 'New Jobsite', 'es': 'Nueva Obra'},
  'Novo Lançamento': {'en': 'New Placement', 'es': 'Nuevo Lanzamiento'},
  'Novo lançamento': {'en': 'New placement', 'es': 'Nuevo lanzamiento'},
  'Novo lançamento pronto para ser marcado na planta.': {
    'en': 'New placement ready to be marked on the plan.',
    'es': 'Nuevo lanzamiento listo para marcar en la planta.',
  },
  'Não': {'en': 'No', 'es': 'No'},
  'Não foi possível abrir a planta': {
    'pt': 'Não conseguimos abrir a planta',
    'en': 'We could not open the plan',
    'es': 'No pudimos abrir la planta',
  },
  'Não informado': {'en': 'Not provided', 'es': 'No informado'},
  'Não pode ser negativo': {
    'pt': 'O valor não pode ser negativo.',
    'en': 'The value cannot be negative.',
    'es': 'El valor no puede ser negativo.',
  },
  'Número inválido': {
    'pt': 'Informe um número válido.',
    'en': 'Enter a valid number.',
    'es': 'Ingrese un número válido.',
  },
  'OCR concluído, mas os dados principais não foram identificados.': {
    'pt':
        'A leitura foi concluída, mas os dados principais não foram identificados. Confira a imagem ou preencha manualmente.',
    'en':
        'The scan finished, but the main data was not identified. Check the image or fill it in manually.',
    'es':
        'La lectura terminó, pero no se identificaron los datos principales. Revise la imagen o complete los datos manualmente.',
  },
  'OCR de nota fiscal disponível apenas em Android/iOS.': {
    'pt': 'A leitura da nota fiscal está disponível apenas no Android e iOS.',
    'en': 'Invoice scanning is available only on Android and iOS.',
    'es': 'La lectura de factura está disponible solo en Android e iOS.',
  },
  'Obra': {'en': 'Jobsite', 'es': 'Obra'},
  'Obra "{nome}" excluida.': {
    'pt': 'Obra "{nome}" excluída.',
    'en': 'Jobsite "{nome}" deleted.',
    'es': 'Obra "{nome}" eliminada.',
  },
  'Obra atualizada com sucesso.': {
    'pt': 'Obra atualizada.',
    'en': 'Jobsite updated.',
    'es': 'Obra actualizada.',
  },
  'Obra criada com sucesso.': {
    'pt': 'Obra criada.',
    'en': 'Jobsite created.',
    'es': 'Obra creada.',
  },
  'Obra sem ID (não persistida).': {
    'pt': 'Salve a obra antes de continuar.',
    'en': 'Save the jobsite before continuing.',
    'es': 'Guarde la obra antes de continuar.',
  },
  'Obra: {value}': {'en': 'Jobsite: {value}', 'es': 'Obra: {value}'},
  'Obs.: {value}': {'en': 'Notes: {value}', 'es': 'Obs.: {value}'},
  'Observações': {'en': 'Notes', 'es': 'Observaciones'},
  'Observações do lançamento': {
    'en': 'Placement notes',
    'es': 'Observaciones del lanzamiento',
  },
  'Observações: {value}': {
    'en': 'Notes: {value}',
    'es': 'Observaciones: {value}',
  },
  'Ordem: {value}': {'en': 'Order: {value}', 'es': 'Orden: {value}'},
  'Ordenação': {'en': 'Sorting', 'es': 'Ordenación'},
  'Permissao de localizacao': {
    'pt': 'Permissão de localização',
    'en': 'Location permission',
    'es': 'Permiso de ubicación',
  },
  'Período': {'en': 'Period', 'es': 'Período'},
  'Período: {value}': {'en': 'Period: {value}', 'es': 'Período: {value}'},
  'Planta ainda não cadastrada para esta concretagem.': {
    'en': 'No plan registered for this concrete pour yet.',
    'es': 'Aún no hay planta registrada para este hormigonado.',
  },
  'Planta ampliada com as marcações realizadas nesta concretagem.': {
    'en': 'Plan enlarged with the markings made for this concrete pour.',
    'es': 'Planta ampliada con las marcas realizadas en este hormigonado.',
  },
  'Planta de rastreio da concretagem': {
    'en': 'Concrete pour tracking plan',
    'es': 'Planta de rastreo del hormigonado',
  },
  'Planta escaneada sem marcações registradas.': {
    'en': 'Scanned plan with no registered markings.',
    'es': 'Planta escaneada sin marcas registradas.',
  },
  'Planta salva': {'en': 'Plan saved', 'es': 'Planta guardada'},
  'Planta salva. Adicione lançamentos para começar as marcações.': {
    'en': 'Plan saved. Add placements to start marking.',
    'es': 'Planta guardada. Agregue lanzamientos para empezar las marcas.',
  },
  'Primeiro lançamento pronto para ser marcado na planta.': {
    'en': 'First placement ready to be marked on the plan.',
    'es': 'Primer lanzamiento listo para marcar en la planta.',
  },
  'Pré-visualização indisponível': {
    'en': 'Preview unavailable',
    'es': 'Vista previa no disponible',
  },
  'Página {page} de {pages}': {
    'en': 'Page {page} of {pages}',
    'es': 'Página {page} de {pages}',
  },
  'Rastreio da Planta': {'en': 'Plan Tracking', 'es': 'Rastreo de la Planta'},
  'Rastreio na planta': {'en': 'Plan tracking', 'es': 'Rastreo en la planta'},
  'Rastreio na planta: marcado': {
    'en': 'Plan tracking: marked',
    'es': 'Rastreo en la planta: marcado',
  },
  'Relatório CSV da obra {obra}': {
    'en': 'CSV report for jobsite {obra}',
    'es': 'Informe CSV de la obra {obra}',
  },
  'Relatório CSV da obra {obra}. Toque em "Salvar em Arquivos" para escolher onde guardar.': {
    'en':
        'CSV report for jobsite {obra}. Tap "Save to Files" to choose where to store it.',
    'es':
        'Informe CSV de la obra {obra}. Toque "Guardar en Archivos" para elegir dónde guardarlo.',
  },
  'Relatório da concretagem': {
    'en': 'Concrete pour report',
    'es': 'Informe del hormigonado',
  },
  'Relatório da concretagem - {concretagem}': {
    'en': 'Concrete pour report - {concretagem}',
    'es': 'Informe del hormigonado - {concretagem}',
  },
  'Relatório da concretagem {concretagem}': {
    'en': 'Concrete pour report {concretagem}',
    'es': 'Informe del hormigonado {concretagem}',
  },
  'Relatório da obra {obra}': {
    'en': 'Jobsite report {obra}',
    'es': 'Informe de la obra {obra}',
  },
  'Relatório em PDF da obra {obra}': {
    'en': 'PDF report for jobsite {obra}',
    'es': 'Informe PDF de la obra {obra}',
  },
  'Relatório gerado em {date}': {
    'en': 'Report generated on {date}',
    'es': 'Informe generado el {date}',
  },
  'Responsável': {'en': 'Responsible person', 'es': 'Responsable'},
  'Responsável: {value}': {
    'en': 'Responsible person: {value}',
    'es': 'Responsable: {value}',
  },
  'Restaurar': {'en': 'Restore', 'es': 'Restaurar'},
  'Restaurar obra': {'en': 'Restore jobsite', 'es': 'Restaurar obra'},
  'Sair sem salvar': {'en': 'Leave without saving', 'es': 'Salir sin guardar'},
  'Salvar': {'en': 'Save', 'es': 'Guardar'},
  'Salvar alterações': {'en': 'Save changes', 'es': 'Guardar cambios'},
  'Salvar concretagem': {
    'en': 'Save concrete pour',
    'es': 'Guardar hormigonado',
  },
  'Salvar lançamento': {'en': 'Save placement', 'es': 'Guardar lanzamiento'},
  'Salvar marcações': {'en': 'Save markings', 'es': 'Guardar marcas'},
  'Salvar obra': {'en': 'Save jobsite', 'es': 'Guardar obra'},
  'Salvar ou compartilhar CSV': {
    'en': 'Save or share CSV',
    'es': 'Guardar o compartir CSV',
  },
  'Segue em anexo o relatório da concretagem {concretagem} da obra {obra}.': {
    'en':
        'Attached is the report for concrete pour {concretagem} at jobsite {obra}.',
    'es':
        'Adjunto se encuentra el informe del hormigonado {concretagem} de la obra {obra}.',
  },
  'Selecionado: {value}': {
    'en': 'Selected: {value}',
    'es': 'Seleccionado: {value}',
  },
  'Selecionar período': {'en': 'Select period', 'es': 'Seleccionar período'},
  'Sem planta': {'en': 'No plan', 'es': 'Sin planta'},
  'Sim': {'en': 'Yes', 'es': 'Sí'},
  'Slump antes (cm)': {'en': 'Slump before (cm)', 'es': 'Slump antes (cm)'},
  'Slump antes: {value} cm': {
    'en': 'Slump before: {value} cm',
    'es': 'Slump antes: {value} cm',
  },
  'Slump depois (cm)': {'en': 'Slump after (cm)', 'es': 'Slump después (cm)'},
  'Slump depois: {value} cm': {
    'en': 'Slump after: {value} cm',
    'es': 'Slump después: {value} cm',
  },
  'Spray': {'en': 'Spray', 'es': 'Spray'},
  'Sua avaliacao ajuda outros profissionais a encontrarem o CWS Admix Control. Se preferir, envie um feedback direto para a equipe.': {
    'pt':
        'Sua avaliação ajuda outros profissionais a encontrarem o CWS Admix Control. Se preferir, envie um feedback direto para a equipe.',
    'en':
        'Your rating helps other professionals find CWS Admix Control. If you prefer, send direct feedback to the team.',
    'es':
        'Su calificación ayuda a otros profesionales a encontrar CWS Admix Control. Si lo prefiere, envíe feedback directo al equipo.',
  },
  'Substituir': {'en': 'Replace', 'es': 'Sustituir'},
  'Substituir a planta vai limpar as marcações já feitas. Deseja continuar?': {
    'pt':
        'Substituir a planta vai limpar as marcações já feitas. Deseja continuar?',
    'en': 'Replacing the plan will clear existing markings. Continue?',
    'es': 'Sustituir la planta borrará las marcas ya hechas. ¿Desea continuar?',
  },
  'Substituir planta': {'en': 'Replace plan', 'es': 'Sustituir planta'},
  'Tempo carga-descarga: {duration}': {
    'pt': 'Tempo carga-descarga: {duration}',
    'en': 'Load-discharge time: {duration}',
    'es': 'Tiempo carga-descarga: {duration}',
  },
  'Tempo de carregamento acima do limite': {
    'pt': 'Revisar tempo de carregamento',
    'en': 'Review loading time',
    'es': 'Revisar tiempo de carga',
  },
  'Tempo de mistura: {value} min': {
    'en': 'Mixing time: {value} min',
    'es': 'Tiempo de mezcla: {value} min',
  },
  'Tempo mistura (min)': {
    'en': 'Mixing time (min)',
    'es': 'Tiempo de mezcla (min)',
  },
  'Tirar foto': {'en': 'Take photo', 'es': 'Tomar foto'},
  'Todas': {'en': 'All', 'es': 'Todas'},
  'Todos': {'en': 'All', 'es': 'Todos'},
  'Traço: {value}': {
    'en': 'Mix design: {value}',
    'es': 'Dosificación: {value}',
  },
  'Tudo salvo': {'en': 'All saved', 'es': 'Todo guardado'},
  'Usar imagem da galeria': {
    'en': 'Use image from gallery',
    'es': 'Usar imagen de la galería',
  },
  'Usar localizacao atual': {
    'en': 'Use current location',
    'es': 'Usar ubicación actual',
  },
  'Use a câmera para fotografar a planta ou escolha uma imagem já escaneada da galeria.': {
    'en':
        'Use the camera to photograph the plan or choose a scanned image from the gallery.',
    'es':
        'Use la cámara para fotografiar la planta o elija una imagen ya escaneada de la galería.',
  },
  'Use o botão abaixo para ir ao primeiro lançamento e depois volte para marcar a planta.': {
    'en':
        'Use the button below to go to the first placement, then return to mark the plan.',
    'es':
        'Use el botón abajo para ir al primer lanzamiento y luego vuelva para marcar la planta.',
  },
  'Use pelo menos 3 caracteres': {
    'pt': 'Use pelo menos 3 caracteres.',
    'en': 'Use at least 3 characters.',
    'es': 'Use al menos 3 caracteres.',
  },
  'Volume (maior→menor)': {
    'en': 'Volume (high-low)',
    'es': 'Volumen (mayor-menor)',
  },
  'Volume (menor→maior)': {
    'en': 'Volume (low-high)',
    'es': 'Volumen (menor-mayor)',
  },
  'Volume (m³)': {'en': 'Volume (m³)', 'es': 'Volumen (m³)'},
  'Volume de concreto: {value} m³': {
    'en': 'Concrete volume: {value} m³',
    'es': 'Volumen de hormigón: {value} m³',
  },
  'Volume deve ser maior que zero': {
    'pt': 'O volume deve ser maior que zero.',
    'en': 'Volume must be greater than zero.',
    'es': 'El volumen debe ser mayor que cero.',
  },
  'Volume total: {value} m3': {
    'en': 'Total volume: {value} m3',
    'es': 'Volumen total: {value} m3',
  },
  'Volume: {value} m³': {
    'en': 'Volume: {value} m³',
    'es': 'Volumen: {value} m³',
  },
  'nao informada': {'en': 'not provided', 'es': 'no informada'},
  'nao informado': {'en': 'not provided', 'es': 'no informado'},
  'não informada': {'en': 'not provided', 'es': 'no informada'},
  'não informado': {'en': 'not provided', 'es': 'no informado'},
  '{marked} de {total} lançamentos já foram marcados na planta.': {
    'en': '{marked} of {total} placements have been marked on the plan.',
    'es': '{marked} de {total} lanzamientos ya fueron marcados en la planta.',
  },
  '{marked} de {total} lançamentos já foram marcados.': {
    'en': '{marked} of {total} placements have been marked.',
    'es': '{marked} de {total} lanzamientos ya fueron marcados.',
  },
  '{subject} - obra {obra}': {
    'en': '{subject} - jobsite {obra}',
    'es': '{subject} - obra {obra}',
  },
  '{warning}\n\nO limite configurado é 2h30. Confira a nota fiscal e o horário do lançamento.': {
    'en':
        '{warning}\n\nThe configured limit is 2h30. Check the invoice and placement time.',
    'es':
        '{warning}\n\nEl límite configurado es 2h30. Revise la factura y el horario del lanzamiento.',
  },
  'Último lançamento: {date}': {
    'en': 'Last placement: {date}',
    'es': 'Último lanzamiento: {date}',
  },
  'Nome': {'en': 'Name', 'es': 'Nombre'},
  'Coordenadas': {'en': 'Coordinates', 'es': 'Coordenadas'},
  'Responsavel': {'en': 'Person in charge', 'es': 'Responsable'},
  'E-mail engenheiro': {
    'en': 'Responsible email',
    'es': 'Email del responsable',
  },
  'Empresa tecnologia': {
    'en': 'Quality control company',
    'es': 'Empresa de control de calidad',
  },
  'Lancamentos': {'en': 'Pours', 'es': 'Lanzamientos'},
  'Volume total': {'en': 'Total volume', 'es': 'Volumen total'},
  'CWS total': {'en': 'Total CWS', 'es': 'CWS total'},
  'Primeiro lancamento': {'en': '1st pour', 'es': 'Primer lanzamiento'},
  'Ultimo lancamento': {'en': 'Last pour', 'es': 'Último lanzamiento'},
  'Cura umida recomendada ate': {
    'en': 'Wet cure recommended until',
    'es': 'Curado húmedo recomendado hasta',
  },
  'Lançamentos da concretagem': {
    'en': 'Pour batches',
    'es': 'Lanzamientos del hormigonado',
  },
  'Betoneira * (nº/placa)': {
    'en': 'Mixer truck * (no./plate)',
    'es': 'Camión mezclador * (n.º/patente)',
  },
  'Concretagens': {'en': 'Concrete pours', 'es': 'Hormigonados'},
  'Concretagens e lançamentos': {
    'en': 'Concrete pours and placements',
    'es': 'Hormigonados y lanzamientos',
  },
  'Controle tecnológico?': {
    'en': 'Technical control?',
    'es': '¿Control tecnológico?',
  },
  'Dosagem (kg/m³) *': {
    'en': 'Dosage (kg/m³) *',
    'es': 'Dosificación (kg/m³) *',
  },
  'E-mail do engenheiro *': {
    'pt': 'E-mail do responsável técnico *',
    'en': 'Responsible email *',
    'es': 'Email del responsable *',
  },
  'Empresa de tecnologia do concreto': {
    'en': 'Concrete technology company',
    'es': 'Empresa de tecnología del concreto',
  },
  'Endereco da obra': {
    'pt': 'Endereço da obra',
    'en': 'Jobsite address',
    'es': 'Dirección de la obra',
  },
  'Nenhuma concretagem cadastrada.': {
    'en': 'No concrete pours registered.',
    'es': 'No hay hormigonados registrados.',
  },
  'Nome da obra *': {'en': 'Jobsite name *', 'es': 'Nombre de la obra *'},
  'Nota fiscal (NF)': {'en': 'Invoice (NF)', 'es': 'Factura (NF)'},
  'Quantidade adicionada (kg)': {
    'en': 'Added quantity (kg)',
    'es': 'Cantidad agregada (kg)',
  },
  'Resumo': {'en': 'Summary', 'es': 'Resumen'},
  'Tempo de mistura (min)': {
    'en': 'Mixing time (min)',
    'es': 'Tiempo de mezcla (min)',
  },
  'Volume (m³) *': {'en': 'Volume (m³) *', 'es': 'Volumen (m³) *'},
};
