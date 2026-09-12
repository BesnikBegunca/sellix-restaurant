import '../services/app_language_service.dart';

/// UI strings that interpolate values.
///
/// A constant map cannot hold these, so each is a method that takes the values
/// and switches on the active language. Same fallback rule as [trKey]: any
/// language without its own wording uses the English branch.
///
/// Read them through [trf], e.g. `trf.occupiedTables(3)`.
class AppStringsFn {
  const AppStringsFn();

  AppLanguage get _l => AppLanguageService.instance.language;

  // ── Tables ────────────────────────────────────────────────────────────────

  String occupiedTables(int n) => switch (_l) {
    AppLanguage.albanian => '$n tavolina të zëna',
    AppLanguage.french => '$n tables occupées',
    AppLanguage.italian => '$n tavoli occupati',
    AppLanguage.german || AppLanguage.swissGerman => '$n besetzte Tische',
    _ => '$n occupied tables',
  };

  String occupiedShort(int n) => switch (_l) {
    AppLanguage.albanian => '$n të zëna',
    AppLanguage.french => '$n occupées',
    AppLanguage.italian => '$n occupati',
    AppLanguage.german || AppLanguage.swissGerman => '$n besetzt',
    _ => '$n occupied',
  };

  String occupiedAndFree(int occupied, int free) => switch (_l) {
    AppLanguage.albanian => '$occupied të zëna · $free të lira',
    AppLanguage.french => '$occupied occupées · $free libres',
    AppLanguage.italian => '$occupied occupati · $free liberi',
    AppLanguage.german ||
    AppLanguage.swissGerman => '$occupied besetzt · $free frei',
    _ => '$occupied occupied · $free free',
  };

  String occupiedWithPct(int occupied, int pct) => switch (_l) {
    AppLanguage.albanian => '$occupied të zëna · $pct%',
    AppLanguage.french => '$occupied occupées · $pct%',
    AppLanguage.italian => '$occupied occupati · $pct%',
    AppLanguage.german ||
    AppLanguage.swissGerman => '$occupied besetzt · $pct%',
    _ => '$occupied occupied · $pct%',
  };

  String openTablesOrders(int n) => switch (_l) {
    AppLanguage.albanian => n == 1
        ? '1 tavolinë/porosi të hapur'
        : '$n tavolina/porosi të hapura',
    AppLanguage.french => n == 1
        ? '1 table/commande ouverte'
        : '$n tables/commandes ouvertes',
    AppLanguage.italian => n == 1
        ? '1 tavolo/comanda aperta'
        : '$n tavoli/comande aperte',
    AppLanguage.german || AppLanguage.swissGerman => n == 1
        ? '1 offener Tisch / offene Bestellung'
        : '$n offene Tische / Bestellungen',
    _ => n == 1 ? '1 open table/order' : '$n open tables/orders',
  };

  String blockedDeletes(int n) => switch (_l) {
    AppLanguage.albanian => n == 1
        ? '1 tavolinë me porosi të hapur nuk u fshi (fatura e ruajtur).'
        : '$n tavolina me porosi të hapura nuk u fshinë (faturat u ruajtën).',
    AppLanguage.french => n == 1
        ? "1 table avec une commande ouverte n'a pas été supprimée (reçu conservé)."
        : "$n tables avec des commandes ouvertes n'ont pas été supprimées (reçus conservés).",
    AppLanguage.italian => n == 1
        ? '1 tavolo con una comanda aperta non è stato eliminato (ricevuta conservata).'
        : '$n tavoli con comande aperte non sono stati eliminati (ricevute conservate).',
    AppLanguage.german || AppLanguage.swissGerman => n == 1
        ? '1 Tisch mit offener Bestellung wurde nicht gelöscht (Beleg behalten).'
        : '$n Tische mit offenen Bestellungen wurden nicht gelöscht (Belege behalten).',
    _ => n == 1
        ? '1 table with an open order was not deleted (receipt kept).'
        : '$n tables with open orders were not deleted (receipts kept).',
  };

  String tableCountRaised(int target) => switch (_l) {
    AppLanguage.albanian =>
      'Numri u rrit në $target — ka tavolina të hapura që nuk mund të hiqen.',
    AppLanguage.french =>
      "Le nombre a été porté à $target — des tables ouvertes ne peuvent pas être retirées.",
    AppLanguage.italian =>
      'Il numero è stato portato a $target — ci sono tavoli aperti che non possono essere rimossi.',
    AppLanguage.german || AppLanguage.swissGerman =>
      'Die Anzahl wurde auf $target erhöht — offene Tische können nicht entfernt werden.',
    _ =>
      'The count was raised to $target — open tables cannot be removed.',
  };

  String openTablesFound(String countLabel, String totalLabel) => switch (_l) {
    AppLanguage.albanian =>
      'Janë gjetur $countLabel me total $totalLabel €. ',
    AppLanguage.french =>
      'Trouvé : $countLabel pour un total de $totalLabel €. ',
    AppLanguage.italian =>
      'Trovati $countLabel per un totale di $totalLabel €. ',
    AppLanguage.german || AppLanguage.swissGerman =>
      '$countLabel mit insgesamt $totalLabel € gefunden. ',
    _ => 'Found $countLabel totalling $totalLabel €. ',
  };

  String openTablesSummary(int count) => switch (_l) {
    AppLanguage.albanian => '$count tavolina/porosi të hapura',
    AppLanguage.french => '$count tables/commandes ouvertes',
    AppLanguage.italian => '$count tavoli/comande aperte',
    AppLanguage.german ||
    AppLanguage.swissGerman => '$count offene Tische/Bestellungen',
    _ => '$count open tables/orders',
  };

  // ── Menu ──────────────────────────────────────────────────────────────────

  String categoriesCount(int n) => switch (_l) {
    AppLanguage.albanian => '$n kategori',
    AppLanguage.french => '$n catégories',
    AppLanguage.italian => '$n categorie',
    AppLanguage.german || AppLanguage.swissGerman => '$n Kategorien',
    _ => '$n categories',
  };

  String deleteCategoryWithProducts(String name, int count) => switch (_l) {
    AppLanguage.albanian =>
      'Kategoria «$name» dhe $count produkte do të fshihen.',
    AppLanguage.french =>
      'La catégorie « $name » et $count produits seront supprimés.',
    AppLanguage.italian =>
      'La categoria «$name» e $count prodotti verranno eliminati.',
    AppLanguage.german || AppLanguage.swissGerman =>
      'Die Kategorie „$name“ und $count Produkte werden gelöscht.',
    _ => 'The category "$name" and $count products will be deleted.',
  };

  String deleteCategory(String name) => switch (_l) {
    AppLanguage.albanian => 'Kategoria «$name» do të fshihet.',
    AppLanguage.french => 'La catégorie « $name » sera supprimée.',
    AppLanguage.italian => 'La categoria «$name» verrà eliminata.',
    AppLanguage.german ||
    AppLanguage.swissGerman => 'Die Kategorie „$name“ wird gelöscht.',
    _ => 'The category "$name" will be deleted.',
  };

  String photosInAssets(int n) => switch (_l) {
    AppLanguage.albanian => '$n foto në asetat e aplikacionit',
    AppLanguage.french => "$n photos dans les ressources de l'application",
    AppLanguage.italian => "$n foto nelle risorse dell'applicazione",
    AppLanguage.german ||
    AppLanguage.swissGerman => '$n Fotos in den App-Assets',
    _ => '$n photos in the app assets',
  };

  String topProducts(int n) => switch (_l) {
    AppLanguage.albanian => 'Produktet më të shitura (top $n)',
    AppLanguage.french => 'Produits les plus vendus (top $n)',
    AppLanguage.italian => 'Prodotti più venduti (top $n)',
    AppLanguage.german ||
    AppLanguage.swissGerman => 'Meistverkaufte Produkte (Top $n)',
    _ => 'Best-selling products (top $n)',
  };

  // ── Payroll ───────────────────────────────────────────────────────────────

  String ratePerDay(String rate) => switch (_l) {
    AppLanguage.albanian => '$rate€/ditë',
    AppLanguage.french => '$rate €/jour',
    AppLanguage.italian => '$rate €/giorno',
    AppLanguage.german || AppLanguage.swissGerman => '$rate €/Tag',
    _ => '$rate€/day',
  };

  String ratePerDayWorked(String rate, int worked) => switch (_l) {
    AppLanguage.albanian => '$rate€/ditë · $worked ditë',
    AppLanguage.french => '$rate €/jour · $worked jours',
    AppLanguage.italian => '$rate €/giorno · $worked giorni',
    AppLanguage.german ||
    AppLanguage.swissGerman => '$rate €/Tag · $worked Tage',
    _ => '$rate€/day · $worked days',
  };

  String daysWorkedOf(int worked, int total, String month) => switch (_l) {
    AppLanguage.albanian => 'Ditë të punuara: $worked / $total  •  $month',
    AppLanguage.french => 'Jours travaillés : $worked / $total  •  $month',
    AppLanguage.italian => 'Giorni lavorati: $worked / $total  •  $month',
    AppLanguage.german ||
    AppLanguage.swissGerman => 'Gearbeitete Tage: $worked / $total  •  $month',
    _ => 'Days worked: $worked / $total  •  $month',
  };

  // ── Licence / activation ──────────────────────────────────────────────────

  String licenceExpiresInDays(int days) => switch (_l) {
    AppLanguage.albanian => 'Licenca juaj skadon: $days ditë',
    AppLanguage.french => 'Votre licence expire : $days jours',
    AppLanguage.italian => 'La tua licenza scade: $days giorni',
    AppLanguage.german ||
    AppLanguage.swissGerman => 'Ihre Lizenz läuft ab: $days Tage',
    _ => 'Your licence expires: $days days',
  };

  String licenceExtendedUntil(String date) => switch (_l) {
    AppLanguage.albanian => 'Licenca u vazhdua deri më $date.',
    AppLanguage.french => "La licence a été prolongée jusqu'au $date.",
    AppLanguage.italian => 'La licenza è stata prolungata fino al $date.',
    AppLanguage.german ||
    AppLanguage.swissGerman => 'Die Lizenz wurde bis zum $date verlängert.',
    _ => 'The licence was extended until $date.',
  };

  String activationFailedHttp(String status) => switch (_l) {
    AppLanguage.albanian => 'Aktivizimi dështoi (HTTP $status).',
    AppLanguage.french => "L'activation a échoué (HTTP $status).",
    AppLanguage.italian => "L'attivazione è fallita (HTTP $status).",
    AppLanguage.german ||
    AppLanguage.swissGerman => 'Die Aktivierung ist fehlgeschlagen (HTTP $status).',
    _ => 'Activation failed (HTTP $status).',
  };

  String transferRequestFailedHttp(String status) => switch (_l) {
    AppLanguage.albanian => 'Kërkesa për transferim dështoi (HTTP $status).',
    AppLanguage.french => 'La demande de transfert a échoué (HTTP $status).',
    AppLanguage.italian =>
      'La richiesta di trasferimento è fallita (HTTP $status).',
    AppLanguage.german || AppLanguage.swissGerman =>
      'Die Transferanfrage ist fehlgeschlagen (HTTP $status).',
    _ => 'The transfer request failed (HTTP $status).',
  };

  String tenantConflict(String business) => switch (_l) {
    AppLanguage.albanian =>
      'Ky terminal ka të dhëna lokale nga një biznes tjetër ($business).',
    AppLanguage.french =>
      "Ce terminal contient des données locales d'une autre entreprise ($business).",
    AppLanguage.italian =>
      "Questo terminale ha dati locali di un'altra attività ($business).",
    AppLanguage.german || AppLanguage.swissGerman =>
      'Dieses Terminal hat lokale Daten eines anderen Betriebs ($business).',
    _ => 'This terminal holds local data from another business ($business).',
  };

  // ── PIN / lockout ─────────────────────────────────────────────────────────

  String wrongPinAttemptsLeft(int attempts) => switch (_l) {
    AppLanguage.albanian => 'PIN i gabuar. $attempts tentativa të mbetur.',
    AppLanguage.french => 'PIN incorrect. $attempts tentatives restantes.',
    AppLanguage.italian => 'PIN errato. $attempts tentativi rimasti.',
    AppLanguage.german ||
    AppLanguage.swissGerman => 'Falsche PIN. Noch $attempts Versuche.',
    _ => 'Incorrect PIN. $attempts attempts remaining.',
  };

  String wrongAdminPinAttemptsLeft(int attempts) => switch (_l) {
    AppLanguage.albanian =>
      'Admin PIN i gabuar. $attempts tentativa të mbetur.',
    AppLanguage.french =>
      'PIN administrateur incorrect. $attempts tentatives restantes.',
    AppLanguage.italian =>
      'PIN amministratore errato. $attempts tentativi rimasti.',
    AppLanguage.german || AppLanguage.swissGerman =>
      'Falsche Admin-PIN. Noch $attempts Versuche.',
    _ => 'Incorrect admin PIN. $attempts attempts remaining.',
  };

  String tooManyAttemptsRetryIn(int seconds) => switch (_l) {
    AppLanguage.albanian => 'Shumë tentativa. Provo pas ${seconds}s.',
    AppLanguage.french => 'Trop de tentatives. Réessayez dans ${seconds}s.',
    AppLanguage.italian => 'Troppi tentativi. Riprova tra ${seconds}s.',
    AppLanguage.german || AppLanguage.swissGerman =>
      'Zu viele Versuche. Erneut versuchen in ${seconds}s.',
    _ => 'Too many attempts. Try again in ${seconds}s.',
  };

  String tooManyFailedAttemptsRetryIn(int seconds) => switch (_l) {
    AppLanguage.albanian =>
      'Shumë tentativa të gabuara. Provo përsëri pas ${seconds}s.',
    AppLanguage.french =>
      'Trop de tentatives échouées. Réessayez dans ${seconds}s.',
    AppLanguage.italian =>
      'Troppi tentativi falliti. Riprova tra ${seconds}s.',
    AppLanguage.german || AppLanguage.swissGerman =>
      'Zu viele Fehlversuche. Erneut versuchen in ${seconds}s.',
    _ => 'Too many failed attempts. Try again in ${seconds}s.',
  };

  // ── Relative time ─────────────────────────────────────────────────────────

  String minutesAgo(int n) => switch (_l) {
    AppLanguage.albanian => '$n min më parë',
    AppLanguage.french => 'il y a $n min',
    AppLanguage.italian => '$n min fa',
    AppLanguage.german || AppLanguage.swissGerman => 'vor $n Min.',
    _ => '$n min ago',
  };

  String hoursAgo(int n) => switch (_l) {
    AppLanguage.albanian => '$n orë më parë',
    AppLanguage.french => 'il y a $n h',
    AppLanguage.italian => '$n ore fa',
    AppLanguage.german || AppLanguage.swissGerman => 'vor $n Std.',
    _ => '$n hours ago',
  };

  String daysAgo(int n) => switch (_l) {
    AppLanguage.albanian => '$n ditë më parë',
    AppLanguage.french => 'il y a $n jours',
    AppLanguage.italian => '$n giorni fa',
    AppLanguage.german || AppLanguage.swissGerman => 'vor $n Tagen',
    _ => '$n days ago',
  };

  String updatedAt(String time) => switch (_l) {
    AppLanguage.albanian => 'Përditësuar: $time',
    AppLanguage.french => 'Mis à jour : $time',
    AppLanguage.italian => 'Aggiornato: $time',
    AppLanguage.german || AppLanguage.swissGerman => 'Aktualisiert: $time',
    _ => 'Updated: $time',
  };

  // ── Failures with a raw error tail ────────────────────────────────────────

  String _failed(String what, Object e) => '$what: $e';

  String paymentFailed(Object e) => _failed(switch (_l) {
    AppLanguage.albanian => 'Pagesa dështoi',
    AppLanguage.french => 'Le paiement a échoué',
    AppLanguage.italian => 'Il pagamento è fallito',
    AppLanguage.german || AppLanguage.swissGerman => 'Zahlung fehlgeschlagen',
    _ => 'Payment failed',
  }, e);

  String refundFailed(Object e) => _failed(switch (_l) {
    AppLanguage.albanian => 'Rimbursimi dështoi',
    AppLanguage.french => 'Le remboursement a échoué',
    AppLanguage.italian => 'Il rimborso è fallito',
    AppLanguage.german ||
    AppLanguage.swissGerman => 'Rückerstattung fehlgeschlagen',
    _ => 'Refund failed',
  }, e);

  String deleteFailed(Object e) => _failed(switch (_l) {
    AppLanguage.albanian => 'Fshirja dështoi',
    AppLanguage.french => 'La suppression a échoué',
    AppLanguage.italian => "L'eliminazione è fallita",
    AppLanguage.german || AppLanguage.swissGerman => 'Löschen fehlgeschlagen',
    _ => 'Delete failed',
  }, e);

  String loadFailed(Object e) => _failed(switch (_l) {
    AppLanguage.albanian => 'Gabim gjatë ngarkimit',
    AppLanguage.french => 'Erreur lors du chargement',
    AppLanguage.italian => 'Errore durante il caricamento',
    AppLanguage.german || AppLanguage.swissGerman => 'Fehler beim Laden',
    _ => 'Error while loading',
  }, e);

  String pdfExportFailed(Object e) => _failed(switch (_l) {
    AppLanguage.albanian => 'PDF export dështoi',
    AppLanguage.french => "L'export PDF a échoué",
    AppLanguage.italian => "L'esportazione PDF è fallita",
    AppLanguage.german ||
    AppLanguage.swissGerman => 'PDF-Export fehlgeschlagen',
    _ => 'PDF export failed',
  }, e);

  String supportBundleExportFailed(Object e) => _failed(switch (_l) {
    AppLanguage.albanian => 'Eksporti i support bundle dështoi',
    AppLanguage.french => "L'export du support bundle a échoué",
    AppLanguage.italian => "L'esportazione del support bundle è fallita",
    AppLanguage.german ||
    AppLanguage.swissGerman => 'Support-Bundle-Export fehlgeschlagen',
    _ => 'Support bundle export failed',
  }, e);

  String closeTablesFailed(Object e) => _failed(switch (_l) {
    AppLanguage.albanian => 'Mbyllja e tavolinave dështoi',
    AppLanguage.french => 'La clôture des tables a échoué',
    AppLanguage.italian => 'La chiusura dei tavoli è fallita',
    AppLanguage.german ||
    AppLanguage.swissGerman => 'Das Schließen der Tische ist fehlgeschlagen',
    _ => 'Closing the tables failed',
  }, e);

  String shiftCloseFailed(Object e) => _failed(switch (_l) {
    AppLanguage.albanian => 'Mbyllja dështoi (shift-i mbeti aktiv)',
    AppLanguage.french => 'La clôture a échoué (le service reste actif)',
    AppLanguage.italian => 'La chiusura è fallita (il turno resta attivo)',
    AppLanguage.german || AppLanguage.swissGerman =>
      'Das Schließen ist fehlgeschlagen (die Schicht bleibt aktiv)',
    _ => 'Closing failed (the shift stayed open)',
  }, e);

  // ── Diagnostics ───────────────────────────────────────────────────────────

  String outboxRowsRemoved(int n) => switch (_l) {
    AppLanguage.albanian => 'U fshinë $n rreshta outbox të pambështetur.',
    AppLanguage.french =>
      "$n lignes d'outbox non prises en charge ont été supprimées.",
    AppLanguage.italian => 'Sono state rimosse $n righe outbox non supportate.',
    AppLanguage.german || AppLanguage.swissGerman =>
      '$n nicht unterstützte Outbox-Zeilen wurden entfernt.',
    _ => '$n unsupported outbox rows were removed.',
  };

  String copiedJsonEvents(int n) => switch (_l) {
    AppLanguage.albanian => 'U kopjua JSON ($n ngjarje të dështuara).',
    AppLanguage.french => 'JSON copié ($n événements en échec).',
    AppLanguage.italian => 'JSON copiato ($n eventi falliti).',
    AppLanguage.german ||
    AppLanguage.swissGerman => 'JSON kopiert ($n fehlgeschlagene Ereignisse).',
    _ => 'Copied JSON ($n failed events).',
  };

  String exportIdReadOnly(String id) => switch (_l) {
    AppLanguage.albanian => 'Export ID: $id  ·  Vetëm-lexim',
    AppLanguage.french => 'ID export : $id  ·  Lecture seule',
    AppLanguage.italian => 'ID export: $id  ·  Sola lettura',
    AppLanguage.german ||
    AppLanguage.swissGerman => 'Export-ID: $id  ·  Schreibgeschützt',
    _ => 'Export ID: $id  ·  Read-only',
  };

  // ── Refunds ───────────────────────────────────────────────────────────────

  String deleteOnlyThisPrint(String total) => switch (_l) {
    AppLanguage.albanian => 'Fshihet vetëm ky PRINTO ($total€), ',
    AppLanguage.french => 'Seule cette IMPRESSION ($total €) sera supprimée, ',
    AppLanguage.italian => 'Verrà eliminata solo questa STAMPA ($total €), ',
    AppLanguage.german || AppLanguage.swissGerman =>
      'Nur dieser DRUCK ($total €) wird gelöscht, ',
    _ => 'Only this PRINT ($total€) will be deleted, ',
  };

  String noPrintsForWaiter(String waiter) => switch (_l) {
    AppLanguage.albanian => 'Nuk ka printime për $waiter në këtë turn.\n',
    AppLanguage.french =>
      "Aucune impression pour $waiter pendant ce service.\n",
    AppLanguage.italian => 'Nessuna stampa per $waiter in questo turno.\n',
    AppLanguage.german ||
    AppLanguage.swissGerman => 'Keine Drucke für $waiter in dieser Schicht.\n',
    _ => 'No prints for $waiter in this shift.\n',
  };
}

/// The app-wide accessor for parameterised strings.
const AppStringsFn trf = AppStringsFn();
