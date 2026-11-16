import 'package:intl/intl.dart';
import '../../data/repositories/sales_repository.dart';
import '../../data/repositories/credit_repository.dart';
import '../../data/repositories/product_repository.dart';

/// AssistantReply - Jibu la msaidizi. [suggestions] ni maswali ya kubonyeza.
class AssistantReply {
  final String text;
  const AssistantReply(this.text);
}

/// AssistantService - Msaidizi wa biashara wa Kiswahili, unaofuata KANUNI (rule-based).
///
/// - Hauhitaji huduma ya AI ya kulipia wala intaneti ya ziada.
/// - Kila jibu lenye namba linatoka moja kwa moja kwenye database (Firestore). Hakuna
///   namba inayobuniwa. Ikishindikana kusoma data, msaidizi anasema hivyo wazi.
/// - Anaheshimu ROLE: Cashier anaona mauzo na madeni YAKE mwenyewe tu; taarifa za
///   biashara nzima (mauzo ya wote, mwaka, madeni ya wote) ni za Msimamizi pekee.
class AssistantService {
  final bool isSuperAdmin;
  final String? userId;

  AssistantService({required this.isSuperAdmin, required this.userId});

  final _sales = SalesRepository();
  final _credits = CreditRepository();
  final _products = ProductRepository();
  final _fmt = NumberFormat.currency(locale: 'sw', symbol: 'TZS ', decimalDigits: 0);

  /// Maswali yanayopendekezwa kwa mtumiaji huyu
  List<String> get suggestions => [
        'Mauzo ya leo ni kiasi gani?',
        'Bidhaa gani zimebaki kidogo?',
        'Madeni yote ni kiasi gani?',
        'Nani anadaiwa zaidi?',
        'Mauzo ya wiki hii yakoje?',
        if (isSuperAdmin) 'Mauzo ya mwezi huu ni kiasi gani?',
        'Bidhaa gani zinauzwa zaidi?',
      ];

  /// Cashier huchujwa kwa uid yake; Msimamizi huona yote
  String? get _scope => isSuperAdmin ? null : userId;
  String get _whose => isSuperAdmin ? '' : ' yako';

  static String _normalize(String s) {
    var t = s.toLowerCase();
    t = t.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
    return t.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static bool _has(String t, List<String> words) => words.any((w) => t.contains(w));

  Future<AssistantReply> ask(String question) async {
    final t = _normalize(question);
    if (t.isEmpty) return const AssistantReply('Andika swali lako, mfano: "Mauzo ya leo ni kiasi gani?"');

    try {
      // ---- Madeni ----
      if (t.contains('nani') && _has(t, ['anadaiwa', 'anadai', 'deni', 'madeni', 'mkopo'])) {
        return await _topDebtor();
      }
      if (_has(t, ['deni', 'madeni', 'mkopo', 'wadaiwa'])) {
        return await _totalDebt();
      }

      // ---- Hifadhi ----
      if (_has(t, ['kidogo', 'zimebaki', 'zinapungua', 'zimepungua', 'zinaisha', 'imeisha', 'zimeisha', 'stoo', 'hifadhi'])) {
        return await _lowStock();
      }

      // ---- Bidhaa zinazouzwa zaidi ----
      if (t.contains('zaidi') && _has(t, ['zinauzwa', 'inauzwa', 'maarufu'])) {
        return await _topProducts();
      }

      // ---- Mauzo ----
      if (_has(t, ['mauzo', 'nimeuza', 'tumeuza', 'mapato'])) {
        if (t.contains('mwaka')) return await _salesYear();
        if (t.contains('mwezi')) return await _salesPeriod('mwezi huu', _startOfMonth());
        if (t.contains('wiki')) return await _salesPeriod('wiki hii', _startOfWeek());
        return await _salesPeriod('leo', _startOfDay());
      }

      if (_has(t, ['msaada', 'unaweza', 'habari', 'hujambo', 'mambo', 'salamu'])) {
        return AssistantReply(
            'Habari! Naweza kujibu kuhusu mauzo, hifadhi ya bidhaa na madeni.\n\nJaribu: "Mauzo ya leo ni kiasi gani?" au "Bidhaa gani zimebaki kidogo?"');
      }
    } catch (e) {
      return AssistantReply(
          'Samahani, nimeshindwa kupata taarifa sasa hivi (${e.toString().replaceFirst('Exception: ', '')}). Hakikisha una mtandao kisha ujaribu tena.');
    }

    return const AssistantReply(
        'Sijaelewa swali lako. Naweza kujibu kuhusu mauzo (leo, wiki, mwezi), bidhaa zinazopungua, madeni, na bidhaa zinazouzwa zaidi.');
  }

  DateTime _startOfDay() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  DateTime _startOfWeek() {
    final d = _startOfDay();
    return d.subtract(Duration(days: d.weekday - 1));
  }

  DateTime _startOfMonth() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, 1);
  }

  DateTime get _endOfToday => _startOfDay().add(const Duration(days: 1));

  Future<AssistantReply> _salesPeriod(String label, DateTime start) async {
    final sales = await _sales.getSalesBetween(start, _endOfToday, userId: _scope);
    if (sales.isEmpty) return AssistantReply('Hakuna mauzo$_whose yaliyorekodiwa $label.');
    final total = sales.fold<double>(0, (s, e) => s + e.totalAmount);
    final paid = sales.fold<double>(0, (s, e) => s + e.amountPaid);
    final debt = total - paid;
    final b = StringBuffer('Mauzo$_whose ya $label: ${_fmt.format(total)} (risiti ${sales.length}).');
    b.write('\nKilicholipwa: ${_fmt.format(paid)}');
    if (debt > 0.5) b.write('\nBado kulipwa (deni): ${_fmt.format(debt)}');
    return AssistantReply(b.toString());
  }

  Future<AssistantReply> _salesYear() async {
    if (!isSuperAdmin) {
      return const AssistantReply('Mauzo ya mwaka mzima ni taarifa za Msimamizi pekee. Naweza kukuonyesha mauzo yako ya leo, wiki hii au mwezi huu.');
    }
    final n = DateTime.now();
    final sales = await _sales.getSalesBetween(DateTime(n.year, 1, 1), _endOfToday);
    final total = sales.fold<double>(0, (s, e) => s + e.totalAmount);
    return AssistantReply('Mauzo ya mwaka ${n.year}: ${_fmt.format(total)} (risiti ${sales.length}).');
  }

  Future<AssistantReply> _lowStock() async {
    final low = await _products.getLowStockProducts();
    if (low.isEmpty) return const AssistantReply('Hakuna bidhaa inayopungua kwa sasa. Hifadhi iko vizuri.');
    final b = StringBuffer('Bidhaa ${low.length} zimebaki kidogo:\n');
    for (final p in low.take(15)) {
      if (isSuperAdmin) {
        b.writeln('• ${p.name}: ${_n(p.quantity)} ${p.unit}${p.isOutOfStock ? ' (imekwisha)' : ''}');
      } else {
        // Cashier anaona hali tu (kama ilivyo kwenye skrini ya mauzo)
        b.writeln('• ${p.name}: ${p.isOutOfStock ? 'imekwisha' : 'inapungua'}');
      }
    }
    if (low.length > 15) b.write('...na nyingine ${low.length - 15}.');
    return AssistantReply(b.toString().trimRight());
  }

  Future<AssistantReply> _totalDebt() async {
    final rows = await _credits.getDebtorsRanked(createdBy: _scope);
    if (rows.isEmpty) return AssistantReply('Hakuna madeni$_whose yanayodaiwa kwa sasa.');
    final total = rows.fold<double>(0, (s, r) => s + (r['balance'] as double));
    final who = isSuperAdmin ? 'Madeni yote yanayodaiwa' : 'Madeni uliyoandika yanayodaiwa';
    return AssistantReply('$who: ${_fmt.format(total)} (wateja ${rows.length}).');
  }

  Future<AssistantReply> _topDebtor() async {
    final rows = await _credits.getDebtorsRanked(createdBy: _scope);
    if (rows.isEmpty) return AssistantReply('Hakuna mteja anayedaiwa$_whose kwa sasa.');
    final top = rows.first;
    final b = StringBuffer('Anayedaiwa zaidi: ${top['name'] ?? 'Mteja'} - ${_fmt.format(top['balance'])}');
    if (top['phone'] != null && (top['phone'] as String).isNotEmpty) b.write(' (simu ${top['phone']})');
    b.write('.');
    if (rows.length > 1) {
      b.write('\n\nWafuatao:');
      for (final r in rows.skip(1).take(4)) {
        b.write('\n• ${r['name'] ?? 'Mteja'}: ${_fmt.format(r['balance'])}');
      }
    }
    return AssistantReply(b.toString());
  }

  Future<AssistantReply> _topProducts() async {
    final rows = await _sales.getTopSellingProducts(_startOfMonth(), _endOfToday, limit: 5, userId: _scope);
    if (rows.isEmpty) return AssistantReply('Hakuna mauzo$_whose mwezi huu bado, kwa hiyo sina cha kulinganisha.');
    final b = StringBuffer('Bidhaa zinazouzwa zaidi mwezi huu${isSuperAdmin ? '' : ' (mauzo yako)'}:');
    for (final r in rows) {
      b.write('\n• ${r['productName']}: ${_n(r['quantity'] as double)} - ${_fmt.format(r['revenue'])}');
    }
    return AssistantReply(b.toString());
  }

  static String _n(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}
