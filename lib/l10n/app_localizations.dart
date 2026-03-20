import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('pt')
  ];

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @historico.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get historico;

  /// No description provided for @configuracoes.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get configuracoes;

  /// No description provided for @assinatura.
  ///
  /// In en, this message translates to:
  /// **'Subscription'**
  String get assinatura;

  /// No description provided for @idioma.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get idioma;

  /// No description provided for @salvar.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get salvar;

  /// No description provided for @nome.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get nome;

  /// No description provided for @trocarFoto.
  ///
  /// In en, this message translates to:
  /// **'Change photo'**
  String get trocarFoto;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @cancelarAssinatura.
  ///
  /// In en, this message translates to:
  /// **'Cancel subscription'**
  String get cancelarAssinatura;

  /// No description provided for @editarPerfil.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get editarPerfil;

  /// No description provided for @confirmar.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirmar;

  /// No description provided for @atividade.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get atividade;

  /// No description provided for @adicionarAtividade.
  ///
  /// In en, this message translates to:
  /// **'Add Activity'**
  String get adicionarAtividade;

  /// No description provided for @editarAtividade.
  ///
  /// In en, this message translates to:
  /// **'Edit Activity'**
  String get editarAtividade;

  /// No description provided for @descricao.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get descricao;

  /// No description provided for @horarioInicio.
  ///
  /// In en, this message translates to:
  /// **'Start time'**
  String get horarioInicio;

  /// No description provided for @horarioFim.
  ///
  /// In en, this message translates to:
  /// **'End time'**
  String get horarioFim;

  /// No description provided for @participantes.
  ///
  /// In en, this message translates to:
  /// **'Participants'**
  String get participantes;

  /// No description provided for @status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// No description provided for @aceito.
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get aceito;

  /// No description provided for @recusado.
  ///
  /// In en, this message translates to:
  /// **'Declined'**
  String get recusado;

  /// No description provided for @pendente.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pendente;

  /// No description provided for @concluida.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get concluida;

  /// No description provided for @emAndamento.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get emAndamento;

  /// No description provided for @atrasada.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get atrasada;

  /// No description provided for @cancelar.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancelar;

  /// No description provided for @semAtividades.
  ///
  /// In en, this message translates to:
  /// **'No activities for today'**
  String get semAtividades;

  /// No description provided for @notificacoes.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificacoes;

  /// No description provided for @planoAtual.
  ///
  /// In en, this message translates to:
  /// **'Current plan'**
  String get planoAtual;

  /// No description provided for @planoAlteradoPara.
  ///
  /// In en, this message translates to:
  /// **'Plan changed to'**
  String get planoAlteradoPara;

  /// No description provided for @trocarPlano.
  ///
  /// In en, this message translates to:
  /// **'Change plan'**
  String get trocarPlano;

  /// No description provided for @planoCancelado.
  ///
  /// In en, this message translates to:
  /// **'Subscription cancelled. Reverted to free plan.'**
  String get planoCancelado;

  /// No description provided for @atividadeReutilizadaParaHoje.
  ///
  /// In en, this message translates to:
  /// **'Activity reused for today'**
  String get atividadeReutilizadaParaHoje;

  /// No description provided for @novaAtividade.
  ///
  /// In en, this message translates to:
  /// **'New activity'**
  String get novaAtividade;

  /// No description provided for @atividadeExcluida.
  ///
  /// In en, this message translates to:
  /// **'Activity deleted'**
  String get atividadeExcluida;

  /// No description provided for @statusAceito.
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get statusAceito;

  /// No description provided for @statusPendente.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get statusPendente;

  /// No description provided for @statusRecusado.
  ///
  /// In en, this message translates to:
  /// **'Declined'**
  String get statusRecusado;

  /// No description provided for @link.
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get link;

  /// No description provided for @marcarComoConcluida.
  ///
  /// In en, this message translates to:
  /// **'Mark as completed'**
  String get marcarComoConcluida;

  /// No description provided for @editar.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get editar;

  /// No description provided for @excluir.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get excluir;

  /// No description provided for @assinar.
  ///
  /// In en, this message translates to:
  /// **'Subscribe'**
  String get assinar;

  /// No description provided for @sair.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get sair;

  /// No description provided for @deletarConta.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get deletarConta;

  /// No description provided for @confirmarDelecao.
  ///
  /// In en, this message translates to:
  /// **'Confirm deletion'**
  String get confirmarDelecao;

  /// No description provided for @delecaoIrreversivel.
  ///
  /// In en, this message translates to:
  /// **'This action is irreversible. Do you want to continue?'**
  String get delecaoIrreversivel;

  /// No description provided for @bemVindo.
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get bemVindo;

  /// No description provided for @senha.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get senha;

  /// No description provided for @entrar.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get entrar;

  /// No description provided for @naoTemConta.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get naoTemConta;

  /// No description provided for @criarConta.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get criarConta;

  /// No description provided for @esqueceuSenha.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get esqueceuSenha;

  /// No description provided for @continuarComGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get continuarComGoogle;

  /// No description provided for @continuarComApple.
  ///
  /// In en, this message translates to:
  /// **'Continue with Apple'**
  String get continuarComApple;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'pt'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
    case 'pt': return AppLocalizationsPt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
