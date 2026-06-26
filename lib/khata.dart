import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'models.dart';
import 'payroll.dart' show money;
import 'repo.dart';
import 'ui.dart';

// Khata: advances, bonus, salary paid, expenses, deductions
class KhataScreen extends StatefulWidget {
  final String ownerId;
  const KhataScreen({super.key, required this.ownerId});
  @override
  State<KhataScreen> createState() => _KhataScreenState();
}

class _KhataScreenState extends State<KhataScreen> {
  List<Employee> _emps = [];
  List<Payment> _pays = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _emps = await repo.employees(widget.ownerId);
    _pays = await repo.payments(widget.ownerId)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (mounted) setState(() => _loading = false);
  }

  String _name(String id) => _emps
      .firstWhere((e) => e.id == id,
          orElse: () =>
              Employee(id: '', ownerId: '', name: 'Unknown', createdAt: 0))
      .name;

  Color _color(PayType t) {
    switch (t) {
      case PayType.bonus:
      case PayType.salary:
        return Colors.green;
      default:
        return Colors.red;
    }
  }

  Future<void> _add() async {
    if (_emps.isEmpty) {
      snack(context, 'Add staff first', Colors.orange);
      return;
    }
    String empId = _emps.first.id;
    PayType type = PayType.advance;
    final amount = TextEditingController();
    final note = TextEditingController();
    DateTime date = DateTime.now();

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setLocal) {
        return AlertDialog(
          title: const Text('Add entry'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: empId,
                  decoration: const InputDecoration(labelText: 'Staff'),
                  items: _emps
                      .map((e) =>
                          DropdownMenuItem(value: e.id, child: Text(e.name)))
                      .toList(),
                  onChanged: (v) => setLocal(() => empId = v ?? empId),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<PayType>(
                  value: type,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: PayType.values
                      .map((t) => DropdownMenuItem(
                          value: t, child: Text(payLabel(t))))
                      .toList(),
                  onChanged: (v) => setLocal(() => type = v ?? type),
                ),
                const SizedBox(height: 10),
                TextField(
                    controller: amount,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Amount ₹')),
                TextField(
                    controller: note,
                    decoration: const InputDecoration(labelText: 'Note')),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(DateFormat('dd MMM yyyy').format(date)),
                  trailing: const Icon(Icons.calendar_today, size: 18),
                  onTap: () async {
                    final d = await showDatePicker(
                        context: context,
                        initialDate: date,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100));
                    if (d != null) setLocal(() => date = d);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Save')),
          ],
        );
      }),
    );
    if (ok != true) return;
    final amt = double.tryParse(amount.text.trim()) ?? 0;
    if (amt <= 0) {
      snack(context, 'Enter amount', Colors.orange);
      return;
    }
    await repo.savePayment(Payment(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      ownerId: widget.ownerId,
      empId: empId,
      type: type,
      amount: amt,
      date: DateFormat('yyyy-MM-dd').format(date),
      note: note.text.trim(),
      createdAt: DateTime.now().millisecondsSinceEpoch,
    ));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Khata / Payments')),
      floatingActionButton: FloatingActionButton.extended(
          onPressed: _add,
          icon: const Icon(Icons.add),
          label: const Text('Add')),
      body: _loading
          ? loading()
          : _pays.isEmpty
              ? Center(
                  child: Text('No entries yet',
                      style: TextStyle(color: Colors.grey[600])))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                  children: _pays
                      .map((p) => Card(
                            elevation: 0,
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: _color(p.type).withOpacity(0.12),
                                child: Icon(Icons.payments,
                                    color: _color(p.type), size: 20),
                              ),
                              title: Text('${_name(p.empId)} · ${payLabel(p.type)}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                              subtitle: Text('${p.date}'
                                  '${p.note.isNotEmpty ? ' · ${p.note}' : ''}'),
                              trailing: Text(money(p.amount),
                                  style: TextStyle(
                                      color: _color(p.type),
                                      fontWeight: FontWeight.w700)),
                              onLongPress: () async {
                                await repo.deletePayment(p.id);
                                _load();
                              },
                            ),
                          ))
                      .toList(),
                ),
    );
  }
}
