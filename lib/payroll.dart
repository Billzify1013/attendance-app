import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import 'models.dart';
import 'repo.dart';
import 'ui.dart';

String money(num v) => 'Rs ${v.toStringAsFixed(0)}';

int _mins(String hhmm) {
  final p = hhmm.split(':');
  return (int.tryParse(p[0]) ?? 0) * 60 +
      (int.tryParse(p.length > 1 ? p[1] : '0') ?? 0);
}

double _schedMins(Employee e) {
  var s = (_mins(e.shiftEnd) - _mins(e.shiftStart)).toDouble();
  if (s <= 0) s += 24 * 60; // overnight shift (e.g. 22:00 -> 06:00)
  if (s <= 0) s = 8 * 60;
  return s;
}

// Cross-midnight aware day fractions. A session = shiftIn..next shiftOut,
// attributed to the shiftIn's date.
Map<String, double> monthFractions(
    Employee e, int year, int month, List<AttEvent> events) {
  final mKey =
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';
  final emp = events.where((x) => x.empId == e.id).toList()
    ..sort((a, b) => a.ts.compareTo(b.ts));
  final sched = _schedMins(e);
  final res = <String, double>{};

  int? inTs;
  String? inDate;
  int lunchMs = 0;
  int? lunchOutTs;

  void close(int outTs) {
    if (inTs == null) return;
    var worked = (outTs - inTs!) - lunchMs;
    if (worked < 0) worked = 0;
    if (inDate != null && inDate!.startsWith(mKey)) {
      final frac = (worked / 60000.0) >= 0.7 * sched ? 1.0 : 0.5;
      res[inDate!] = ((res[inDate!] ?? 0) + frac).clamp(0.0, 1.0).toDouble();
    }
    inTs = null;
    inDate = null;
    lunchMs = 0;
    lunchOutTs = null;
  }

  for (final ev in emp) {
    switch (ev.type) {
      case PunchType.shiftIn:
        if (inTs != null) close(ev.ts);
        inTs = ev.ts;
        inDate = ev.date;
        break;
      case PunchType.lunchOut:
        if (inTs != null) lunchOutTs = ev.ts;
        break;
      case PunchType.lunchIn:
        if (inTs != null && lunchOutTs != null) {
          lunchMs += ev.ts - lunchOutTs!;
          lunchOutTs = null;
        }
        break;
      case PunchType.shiftOut:
        close(ev.ts);
        break;
    }
  }
  if (inTs != null && inDate != null && inDate!.startsWith(mKey)) {
    res[inDate!] = ((res[inDate!] ?? 0) + 1.0).clamp(0.0, 1.0).toDouble();
  }
  return res;
}

class PayrollResult {
  final int daysInMonth;
  final double presentDays, paidLeave, unpaidLeave, perDay, gross, bonus,
      advance, deduction, salaryPaid, net, pending;
  PayrollResult({
    required this.daysInMonth,
    required this.presentDays,
    required this.paidLeave,
    required this.unpaidLeave,
    required this.perDay,
    required this.gross,
    required this.bonus,
    required this.advance,
    required this.deduction,
    required this.salaryPaid,
    required this.net,
    required this.pending,
  });
}

PayrollResult computePayroll(Employee e, int year, int month,
    List<AttEvent> events, List<LeaveRequest> leaves, List<Payment> pays) {
  final dim = DateTime(year, month + 1, 0).day;
  final mStart = DateTime(year, month, 1);
  final mEnd = DateTime(year, month, dim);
  final mKey =
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';

  final fr = monthFractions(e, year, month, events);
  double present = 0;
  for (final v in fr.values) {
    present += v;
  }

  double paid = 0, unpaid = 0;
  for (final l in leaves) {
    if (l.empId != e.id || l.status != 'approved') continue;
    DateTime f, t;
    try {
      f = DateTime.parse(l.fromDate);
      t = DateTime.parse(l.toDate);
    } catch (_) {
      continue;
    }
    final s = f.isAfter(mStart) ? f : mStart;
    final en = t.isBefore(mEnd) ? t : mEnd;
    if (en.isBefore(s)) continue;
    final d = (f == t && l.days == 0.5)
        ? 0.5
        : (en.difference(s).inDays + 1).toDouble();
    if (l.type == LeaveType.unpaid) {
      unpaid += d;
    } else {
      paid += d;
    }
  }

  final perDay = e.perDaySalary > 0
      ? e.perDaySalary
      : (e.monthlySalary > 0 ? e.monthlySalary / dim : 0);
  final gross = (present + paid) * perDay;

  double bonus = 0, advance = 0, deduction = 0, salaryPaid = 0;
  for (final p in pays) {
    if (p.empId != e.id || !p.date.startsWith(mKey)) continue;
    switch (p.type) {
      case PayType.bonus:
        bonus += p.amount;
        break;
      case PayType.advance:
        advance += p.amount;
        break;
      case PayType.deduction:
        deduction += p.amount;
        break;
      case PayType.salary:
        salaryPaid += p.amount;
        break;
      case PayType.expense:
        break;
    }
  }
  final net = gross + bonus - advance - deduction;
  return PayrollResult(
    daysInMonth: dim,
    presentDays: present,
    paidLeave: paid,
    unpaidLeave: unpaid,
    perDay: perDay.toDouble(),
    gross: gross.toDouble(),
    bonus: bonus,
    advance: advance,
    deduction: deduction,
    salaryPaid: salaryPaid,
    net: net.toDouble(),
    pending: (net - salaryPaid).toDouble(),
  );
}

class PayrollScreen extends StatefulWidget {
  final String ownerId;
  const PayrollScreen({super.key, required this.ownerId});
  @override
  State<PayrollScreen> createState() => _PayrollScreenState();
}

class _PayrollScreenState extends State<PayrollScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  List<Employee> _emps = [];
  List<AttEvent> _events = [];
  List<LeaveRequest> _leaves = [];
  List<Payment> _pays = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _emps = await repo.employees(widget.ownerId);
    _events = await repo.events(widget.ownerId);
    _leaves = await repo.leaves(widget.ownerId);
    _pays = await repo.payments(widget.ownerId);
    if (mounted) setState(() => _loading = false);
  }

  void _shift(int by) =>
      setState(() => _month = DateTime(_month.year, _month.month + by));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payroll')),
      body: _loading
          ? loading()
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                          onPressed: () => _shift(-1),
                          icon: const Icon(Icons.chevron_left)),
                      Text(DateFormat('MMMM yyyy').format(_month),
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700)),
                      IconButton(
                          onPressed: () => _shift(1),
                          icon: const Icon(Icons.chevron_right)),
                    ],
                  ),
                ),
                Expanded(
                  child: _emps.isEmpty
                      ? Center(
                          child: Text('No staff',
                              style: TextStyle(color: Colors.grey[600])))
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          children: _emps.map((e) {
                            final r = computePayroll(e, _month.year,
                                _month.month, _events, _leaves, _pays);
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                title: Text(e.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700)),
                                subtitle: Text(
                                    'Present ${r.presentDays.toStringAsFixed(1)} + Leave ${r.paidLeave.toStringAsFixed(1)} · Net ${money(r.net)}'),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(money(r.pending),
                                        style: TextStyle(
                                            color: r.pending > 0
                                                ? Colors.red
                                                : Colors.green,
                                            fontWeight: FontWeight.w700)),
                                    const Text('pending',
                                        style: TextStyle(fontSize: 11)),
                                  ],
                                ),
                                onTap: () async {
                                  await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) => PayslipScreen(
                                              ownerId: widget.ownerId,
                                              emp: e,
                                              month: _month)));
                                  _load();
                                },
                              ),
                            );
                          }).toList(),
                        ),
                ),
              ],
            ),
    );
  }
}

class PayslipScreen extends StatefulWidget {
  final String ownerId;
  final Employee emp;
  final DateTime month;
  const PayslipScreen(
      {super.key,
      required this.ownerId,
      required this.emp,
      required this.month});
  @override
  State<PayslipScreen> createState() => _PayslipScreenState();
}

class _PayslipScreenState extends State<PayslipScreen> {
  PayrollResult? _r;
  List<Payment> _monthPays = [];

  String get _mKey => DateFormat('yyyy-MM').format(widget.month);

  @override
  void initState() {
    super.initState();
    _calc();
  }

  Future<void> _calc() async {
    final ev = await repo.events(widget.ownerId);
    final lv = await repo.leaves(widget.ownerId);
    final pa = await repo.payments(widget.ownerId);
    if (!mounted) return;
    setState(() {
      _r = computePayroll(
          widget.emp, widget.month.year, widget.month.month, ev, lv, pa);
      _monthPays = pa
          .where((p) => p.empId == widget.emp.id && p.date.startsWith(_mKey))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    });
  }

  Future<void> _addPay(PayType type) async {
    final amount = TextEditingController();
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Add ${payLabel(type)}'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: amount,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Amount')),
          TextField(
              controller: note,
              decoration: const InputDecoration(labelText: 'Note')),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save')),
        ],
      ),
    );
    if (ok != true) return;
    final amt = double.tryParse(amount.text.trim()) ?? 0;
    if (amt <= 0) return;
    final now = DateTime.now();
    await repo.savePayment(Payment(
      id: now.millisecondsSinceEpoch.toString(),
      ownerId: widget.ownerId,
      empId: widget.emp.id,
      type: type,
      amount: amt,
      date: DateFormat('yyyy-MM-dd')
          .format(DateTime(widget.month.year, widget.month.month, 15)),
      note: note.text.trim(),
      createdAt: now.millisecondsSinceEpoch,
    ));
    _calc();
  }

  Future<void> _markPaid() async {
    if (_r == null || _r!.pending <= 0) return;
    final now = DateTime.now();
    await repo.savePayment(Payment(
      id: now.millisecondsSinceEpoch.toString(),
      ownerId: widget.ownerId,
      empId: widget.emp.id,
      type: PayType.salary,
      amount: _r!.pending,
      date: DateFormat('yyyy-MM-dd')
          .format(DateTime(widget.month.year, widget.month.month, 28)),
      note: 'Salary ${DateFormat('MMM yyyy').format(widget.month)}',
      createdAt: now.millisecondsSinceEpoch,
    ));
    _calc();
  }

  String _slipText() {
    final r = _r!;
    return 'Payslip - ${widget.emp.name}\n'
        '${DateFormat('MMMM yyyy').format(widget.month)}\n'
        '-----------------------------\n'
        'Present days: ${r.presentDays.toStringAsFixed(1)}\n'
        'Paid leave: ${r.paidLeave.toStringAsFixed(1)}\n'
        'Per-day: ${money(r.perDay)}\n'
        'Gross: ${money(r.gross)}\n'
        'Bonus: +${money(r.bonus)}\n'
        'Advance: -${money(r.advance)}\n'
        'Deduction: -${money(r.deduction)}\n'
        'Net: ${money(r.net)}\n'
        'Paid: ${money(r.salaryPaid)}\n'
        'Pending: ${money(r.pending)}';
  }

  Future<void> _whatsapp() async {
    var num = widget.emp.phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (num.isEmpty) {
      snack(context, 'No phone number on this employee', Colors.orange);
      return;
    }
    if (num.length == 10) num = '91$num';
    final uri =
        Uri.parse('https://wa.me/$num?text=${Uri.encodeComponent(_slipText())}');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) snack(context, 'WhatsApp not available', Colors.red);
    }
  }

  Future<void> _sharePdf() async {
    final r = _r!;
    final doc = pw.Document();
    pw.Widget row(String k, String v, {bool bold = false}) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 3),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(k,
                  style: pw.TextStyle(
                      fontWeight:
                          bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
              pw.Text(v,
                  style: pw.TextStyle(
                      fontWeight:
                          bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
            ],
          ),
        );
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('PAYSLIP',
              style:
                  pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text(DateFormat('MMMM yyyy').format(widget.month)),
          pw.Divider(),
          pw.Text(widget.emp.name,
              style:
                  pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          if (widget.emp.designation.isNotEmpty)
            pw.Text(widget.emp.designation),
          if (widget.emp.empId.isNotEmpty) pw.Text('ID: ${widget.emp.empId}'),
          pw.SizedBox(height: 12),
          row('Present days', r.presentDays.toStringAsFixed(1)),
          row('Paid leave', r.paidLeave.toStringAsFixed(1)),
          row('Per-day rate', money(r.perDay)),
          pw.Divider(),
          row('Gross', money(r.gross)),
          row('Bonus', '+ ${money(r.bonus)}'),
          row('Advance', '- ${money(r.advance)}'),
          row('Deduction', '- ${money(r.deduction)}'),
          pw.Divider(),
          row('Net salary', money(r.net), bold: true),
          row('Already paid', money(r.salaryPaid)),
          row('Pending', money(r.pending), bold: true),
          pw.SizedBox(height: 30),
          pw.Text('Generated by Attendance App',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
        ],
      ),
    ));
    final bytes = await doc.save();
    await Printing.sharePdf(
        bytes: bytes,
        filename:
            'Payslip_${widget.emp.name}_${DateFormat('MMM_yyyy').format(widget.month)}.pdf');
  }

  Widget _row(String k, String v, {bool bold = false, Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(k,
                style: TextStyle(
                    fontWeight: bold ? FontWeight.w700 : FontWeight.w400)),
            Text(v,
                style: TextStyle(
                    fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
                    color: color)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final r = _r;
    return Scaffold(
      appBar: AppBar(title: const Text('Payslip'), actions: [
        IconButton(
            tooltip: 'Share PDF',
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: r == null ? null : _sharePdf),
        IconButton(
            tooltip: 'WhatsApp',
            icon: const Icon(Icons.chat),
            onPressed: r == null ? null : _whatsapp),
      ]),
      body: r == null
          ? loading()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.emp.name,
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.w800)),
                        Text(DateFormat('MMMM yyyy').format(widget.month),
                            style: TextStyle(color: Colors.grey[600])),
                        const Divider(height: 24),
                        _row('Per-day rate', money(r.perDay)),
                        _row('Present days', r.presentDays.toStringAsFixed(1)),
                        _row('Paid leave', r.paidLeave.toStringAsFixed(1)),
                        _row('Unpaid leave', r.unpaidLeave.toStringAsFixed(1)),
                        const Divider(height: 24),
                        _row('Gross', money(r.gross)),
                        _row('Bonus', '+ ${money(r.bonus)}',
                            color: Colors.green),
                        _row('Advance', '- ${money(r.advance)}',
                            color: Colors.red),
                        _row('Deduction', '- ${money(r.deduction)}',
                            color: Colors.red),
                        const Divider(height: 24),
                        _row('Net salary', money(r.net), bold: true),
                        _row('Already paid', money(r.salaryPaid)),
                        _row('Pending', money(r.pending),
                            bold: true,
                            color: r.pending > 0 ? Colors.red : Colors.green),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                      child: OutlinedButton.icon(
                          onPressed: () => _addPay(PayType.bonus),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Bonus'))),
                  const SizedBox(width: 8),
                  Expanded(
                      child: OutlinedButton.icon(
                          onPressed: () => _addPay(PayType.advance),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Advance'))),
                  const SizedBox(width: 8),
                  Expanded(
                      child: OutlinedButton.icon(
                          onPressed: () => _addPay(PayType.deduction),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Deduct'))),
                ]),
                if (_monthPays.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('This month entries',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  ..._monthPays.map((p) => Card(
                        child: ListTile(
                          dense: true,
                          title:
                              Text('${payLabel(p.type)} · ${money(p.amount)}'),
                          subtitle: p.note.isEmpty ? null : Text(p.note),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, size: 20),
                            onPressed: () async {
                              await repo.deletePayment(p.id);
                              _calc();
                            },
                          ),
                        ),
                      )),
                ],
                const SizedBox(height: 12),
                if (r.pending > 0)
                  SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: _markPaid,
                      icon: const Icon(Icons.check_circle),
                      label: Text('Mark ${money(r.pending)} as Paid'),
                    ),
                  ),
              ],
            ),
    );
  }
}
