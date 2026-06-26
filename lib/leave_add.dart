import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'models.dart';
import 'repo.dart';
import 'ui.dart';

class LeaveAddScreen extends StatefulWidget {
  final String ownerId;
  final List<Employee> emps;
  const LeaveAddScreen({super.key, required this.ownerId, required this.emps});
  @override
  State<LeaveAddScreen> createState() => _LeaveAddScreenState();
}

class _LeaveAddScreenState extends State<LeaveAddScreen> {
  late String _empId;
  LeaveType _type = LeaveType.casual;
  DateTime _from = DateTime.now();
  DateTime _to = DateTime.now();
  bool _half = false;
  final _reason = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _empId = widget.emps.first.id;
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  String _fmt(DateTime d) => DateFormat('dd MMM yyyy').format(d);

  Future<void> _pick(bool from) async {
    final d = await showDatePicker(
      context: context,
      initialDate: from ? _from : _to,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d == null) return;
    setState(() {
      if (from) {
        _from = d;
        if (_to.isBefore(_from)) _to = _from;
      } else {
        _to = d;
      }
    });
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final sameDay = _from.year == _to.year &&
        _from.month == _to.month &&
        _from.day == _to.day;
    final days = sameDay
        ? (_half ? 0.5 : 1.0)
        : (_to.difference(_from).inDays + 1).toDouble();
    await repo.saveLeave(LeaveRequest(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      ownerId: widget.ownerId,
      empId: _empId,
      type: _type,
      fromDate: DateFormat('yyyy-MM-dd').format(_from),
      toDate: DateFormat('yyyy-MM-dd').format(_to),
      days: days,
      reason: _reason.text.trim(),
      status: 'approved', // admin entry -> approved
      createdAt: DateTime.now().millisecondsSinceEpoch,
    ));
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final sameDay = _from.year == _to.year &&
        _from.month == _to.month &&
        _from.day == _to.day;
    return Scaffold(
      appBar: AppBar(title: const Text('Apply Leave')),
      body: _busy
          ? loading()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                DropdownButtonFormField<String>(
                  value: _empId,
                  decoration: const InputDecoration(labelText: 'Staff'),
                  items: widget.emps
                      .map((e) =>
                          DropdownMenuItem(value: e.id, child: Text(e.name)))
                      .toList(),
                  onChanged: (v) => setState(() => _empId = v ?? _empId),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<LeaveType>(
                  value: _type,
                  decoration: const InputDecoration(labelText: 'Leave type'),
                  items: LeaveType.values
                      .map((t) => DropdownMenuItem(
                          value: t, child: Text(leaveLabel(t))))
                      .toList(),
                  onChanged: (v) => setState(() => _type = v ?? _type),
                ),
                const SizedBox(height: 6),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        title: const Text('From'),
                        trailing: Text(_fmt(_from)),
                        onTap: () => _pick(true),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        title: const Text('To'),
                        trailing: Text(_fmt(_to)),
                        onTap: () => _pick(false),
                      ),
                    ],
                  ),
                ),
                if (sameDay)
                  SwitchListTile(
                    value: _half,
                    onChanged: (v) => setState(() => _half = v),
                    title: const Text('Half day'),
                    contentPadding: EdgeInsets.zero,
                  ),
                const SizedBox(height: 8),
                TextField(
                  controller: _reason,
                  decoration: const InputDecoration(labelText: 'Reason'),
                  maxLines: 2,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.check),
                    label: const Text('Save Leave'),
                  ),
                ),
              ],
            ),
    );
  }
}
