import 'app_language_service.dart';

/// Translations for the languages that are not Albanian or English.
///
/// Keys are the exact English strings passed to `AppLanguageService.t(sq, en)`,
/// so adding a language means adding a map here — call sites never change.
/// A phrase with no entry falls back to English.
abstract final class AppTranslations {
  static String? lookup(AppLanguage language, String english) =>
      switch (language) {
        AppLanguage.french => _fr[english],
        AppLanguage.italian => _it[english],
        AppLanguage.german => _de[english],
        AppLanguage.swissGerman => _deCh[english] ?? _de[english],
        _ => null,
      };

  // ── Navigation / section titles ───────────────────────────────────────────
  static const Map<String, String> _fr = {
    // Nav rail + section headings
    'Overview': 'Aperçu',
    'Shift': 'Service',
    'Shift status': 'État du service',
    'Waiters': 'Serveurs',
    'Managers': 'Gestionnaires',
    'Expenses': 'Dépenses',
    'Profits': 'Bénéfices',
    'Sales': 'Ventes',
    'Top employee': 'Meilleur employé',
    'Menu': 'Menu',
    'Tables': 'Tables',
    'Settings': 'Paramètres',
    'Payroll': 'Salaires',
    'Payroll & advances': 'Salaires et avances',
    'Refunds': 'Remboursements',
    'History': 'Historique',
    'Sales history': 'Historique des ventes',
    'Audit log': 'Journal d\'audit',
    'Log out': 'Déconnexion',

    // Settings — language & appearance
    'Language': 'Langue',
    'Language used across manager and staff screens.':
        'Langue utilisée sur les écrans gestionnaire et personnel.',
    'Albanian': 'Albanais',
    'English': 'Anglais',
    'Application appearance': 'Apparence de l\'application',
    'Dark appearance is active.': 'L\'apparence sombre est active.',
    'Choose dark appearance for more comfortable use.':
        'Choisissez l\'apparence sombre pour un confort accru.',
    'Dark mode': 'Mode sombre',
    'Light mode': 'Mode clair',

    // Login / waiter selection
    'Manager Dashboard · POS System':
        'Tableau de bord gestionnaire · Système de caisse',
    'Developer access': 'Accès développeur',
    'A fast and simple restaurant management system':
        'Un système de gestion de restaurant simple et rapide',
    'Administrator login': 'Connexion administrateur',
    'Enter PIN': 'Saisir le code PIN',
    '👤 Waiters: Click the button below to choose your name':
        '👤 Serveurs : cliquez sur le bouton ci-dessous pour choisir votre nom',
    'Configure administrator PIN': 'Configurer le code PIN administrateur',
    'No administrator PIN is configured.\nWould you like to use this PIN as the administrator PIN?':
        'Aucun code PIN administrateur n\'est configuré.\nVoulez-vous utiliser ce code comme PIN administrateur ?',
    'Cancel': 'Annuler',
    'Confirm': 'Confirmer',
    'Select waiter': 'Choisir un serveur',
    'Welcome! Please select your name':
        'Bienvenue ! Veuillez choisir votre nom',
    'No waiters found': 'Aucun serveur trouvé',
  };

  static const Map<String, String> _it = {
    'Overview': 'Panoramica',
    'Shift': 'Turno',
    'Shift status': 'Stato del turno',
    'Waiters': 'Camerieri',
    'Managers': 'Manager',
    'Expenses': 'Spese',
    'Profits': 'Profitti',
    'Sales': 'Vendite',
    'Top employee': 'Miglior dipendente',
    'Menu': 'Menu',
    'Tables': 'Tavoli',
    'Settings': 'Impostazioni',
    'Payroll': 'Stipendi',
    'Payroll & advances': 'Stipendi e anticipi',
    'Refunds': 'Rimborsi',
    'History': 'Cronologia',
    'Sales history': 'Cronologia vendite',
    'Audit log': 'Registro di controllo',
    'Log out': 'Esci',

    'Language': 'Lingua',
    'Language used across manager and staff screens.':
        'Lingua usata nelle schermate manager e personale.',
    'Albanian': 'Albanese',
    'English': 'Inglese',
    'Application appearance': 'Aspetto dell\'applicazione',
    'Dark appearance is active.': 'L\'aspetto scuro è attivo.',
    'Choose dark appearance for more comfortable use.':
        'Scegli l\'aspetto scuro per un uso più confortevole.',
    'Dark mode': 'Modalità scura',
    'Light mode': 'Modalità chiara',

    'Manager Dashboard · POS System': 'Dashboard manager · Sistema POS',
    'Developer access': 'Accesso sviluppatore',
    'A fast and simple restaurant management system':
        'Un sistema di gestione ristorante semplice e veloce',
    'Administrator login': 'Accesso amministratore',
    'Enter PIN': 'Inserisci il PIN',
    '👤 Waiters: Click the button below to choose your name':
        '👤 Camerieri: clicca il pulsante qui sotto per scegliere il tuo nome',
    'Configure administrator PIN': 'Configura il PIN amministratore',
    'No administrator PIN is configured.\nWould you like to use this PIN as the administrator PIN?':
        'Nessun PIN amministratore è configurato.\nVuoi usare questo PIN come PIN amministratore?',
    'Cancel': 'Annulla',
    'Confirm': 'Conferma',
    'Select waiter': 'Seleziona cameriere',
    'Welcome! Please select your name':
        'Benvenuto! Seleziona il tuo nome',
    'No waiters found': 'Nessun cameriere trovato',
  };

  static const Map<String, String> _de = {
    'Overview': 'Übersicht',
    'Shift': 'Schicht',
    'Shift status': 'Schichtstatus',
    'Waiters': 'Kellner',
    'Managers': 'Manager',
    'Expenses': 'Ausgaben',
    'Profits': 'Gewinne',
    'Sales': 'Verkäufe',
    'Top employee': 'Bester Mitarbeiter',
    'Menu': 'Menü',
    'Tables': 'Tische',
    'Settings': 'Einstellungen',
    'Payroll': 'Löhne',
    'Payroll & advances': 'Löhne und Vorschüsse',
    'Refunds': 'Rückerstattungen',
    'History': 'Verlauf',
    'Sales history': 'Verkaufsverlauf',
    'Audit log': 'Auditprotokoll',
    'Log out': 'Abmelden',

    'Language': 'Sprache',
    'Language used across manager and staff screens.':
        'Sprache für Manager- und Personalbildschirme.',
    'Albanian': 'Albanisch',
    'English': 'Englisch',
    'Application appearance': 'Erscheinungsbild der App',
    'Dark appearance is active.': 'Das dunkle Design ist aktiv.',
    'Choose dark appearance for more comfortable use.':
        'Wählen Sie das dunkle Design für angenehmeres Arbeiten.',
    'Dark mode': 'Dunkelmodus',
    'Light mode': 'Hellmodus',

    'Manager Dashboard · POS System': 'Manager-Dashboard · Kassensystem',
    'Developer access': 'Entwicklerzugang',
    'A fast and simple restaurant management system':
        'Ein schnelles und einfaches Restaurant-Managementsystem',
    'Administrator login': 'Administrator-Anmeldung',
    'Enter PIN': 'PIN eingeben',
    '👤 Waiters: Click the button below to choose your name':
        '👤 Kellner: Klicken Sie unten, um Ihren Namen zu wählen',
    'Configure administrator PIN': 'Administrator-PIN einrichten',
    'No administrator PIN is configured.\nWould you like to use this PIN as the administrator PIN?':
        'Es ist keine Administrator-PIN eingerichtet.\nMöchten Sie diese PIN als Administrator-PIN verwenden?',
    'Cancel': 'Abbrechen',
    'Confirm': 'Bestätigen',
    'Select waiter': 'Kellner auswählen',
    'Welcome! Please select your name':
        'Willkommen! Bitte wählen Sie Ihren Namen',
    'No waiters found': 'Keine Kellner gefunden',
  };

  /// Swiss German. Only the entries that genuinely differ from standard German
  /// are listed — everything else falls through to [_de], which is what Swiss
  /// users expect for written UI text (no ß, Swiss vocabulary where it matters).
  static const Map<String, String> _deCh = {
    'Log out': 'Abmälde',
    'Language': 'Sprach',
    'Language used across manager and staff screens.':
        'Sprach für Manager- und Personal-Bildschirm.',
    'Application appearance': 'Erschiinigsbild vo de App',
    'Dark appearance is active.': 'S dunkle Design isch aktiv.',
    'Choose dark appearance for more comfortable use.':
        'Wähl s dunkle Design für aagnehmers Schaffe.',
    'Dark mode': 'Dunkelmodus',
    'Light mode': 'Hellmodus',
    'Enter PIN': 'PIN iigäh',
    'Administrator login': 'Administrator-Aamäldig',
    'Cancel': 'Abbräche',
    'Confirm': 'Bestätige',
    'Select waiter': 'Kellner uswähle',
    'Welcome! Please select your name':
        'Willkomme! Bitte wähl din Name',
    'No waiters found': 'Kei Kellner gfunde',
    'Configure administrator PIN': 'Administrator-PIN iirichte',
    'No administrator PIN is configured.\nWould you like to use this PIN as the administrator PIN?':
        'Es isch kei Administrator-PIN iigrichtet.\nWottsch die PIN as Administrator-PIN bruuche?',
    '👤 Waiters: Click the button below to choose your name':
        '👤 Kellner: Klick unde druf, zum din Name z wähle',
    'A fast and simple restaurant management system':
        'Es schnells und eifachs Restaurant-Managementsystem',
  };
}
