import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'models.dart';
import 'repo.dart';
import 'ui.dart';

// Admin attendance log + manual add/edit/delete (face fail fallback)
class AttendanceAdmin extends StatefulWidget {
  final String ownerId;
  const AttendanceAdmin({super.key, required this.ownerId});
  @override
  State<AttendanceAdmin> createState() => _AttendanceAdminState();
}

class _AttendanceAdminState extends State<AttendanceAdmin> {
  List<Employee> _emps = [];
  List<AttEvent> _events = [];
  Employee? _sel;
  DateTime _date = DateTime.now();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _emps = await repo.employees(widget.ownerId);
    _events = await repo.events(widget.ownerId);
    _sel ??= _emps.isNotEmpty ? _emps.first : null;
    if (mounted) setState(() => _loading = false);
  }

  String get _dKey => DateFormat('yyyy-MM-dd').format(_date);

  List<AttEvent> get _dayEvents {
    if (_sel == null) return [];
    return _events.where((e) => e.empId == _sel!.id && e.date == _dKey).toList()
      ..sort((a, b) => a.ts.compareTo(b.ts));
  }

  Future<void> _addManual() async {
    if (_sel == null) return;
    PunchType type = PunchType.shiftIn;
    TimeOfDay time = TimeOfDay.now();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setLocal) {
        return AlertDialog(
          title: const Text('Manual entry'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<PunchType>(
                value: type,
                decoration: const InputDecoration(labelText: 'Type'),
                items: PunchType.values
                    .map((t) =>
                        DropdownMenuItem(value: t, child: Text(punchLabel(t))))
                    .toList(),
                onChanged: (v) => setLocal(() => type = v ?? type),
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Time: ${time.format(context)}'),
                trailing: const Icon(Icons.access_time, size: 18),
                onTap: () async {
                  final t =
                      await showTimePicker(context: context, initialTime: time);
                  if (t != null) setLocal(() => time = t);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Add')),
          ],
        );
      }),
    );
    if (ok != true) return;
    final dt = DateTime(_date.year, _date.month, _date.day, time.hour, time.minute);
    await repo.addEvent(AttEvent(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      empId: _sel!.id,
      ownerId: widget.ownerId,
      type: type,
      date: _dKey,
      time: DateFormat('HH:mm:ss').format(dt),
      ts: dt.millisecondsSinceEpoch,
      manual: true,
      note: 'Manual',
    ));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Attendance')),
      floatingActionButton: _sel == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _addManual,
              icon: const Icon(Icons.add),
              label: const Text('Manual')),
      body: _loading
          ? loading()
          : _emps.isEmpty
              ? Center(
                  child: Text('No staff',
                      style: TextStyle(color: Colors.grey[600])))
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _sel!.id,
                              decoration:
                                  const InputDecoration(labelText: 'Staff'),
                              items: _emps
                                  .map((e) => DropdownMenuItem(
                                      value: e.id, child: Text(e.name)))
                                  .toList(),
                              onChanged: (v) => setState(() => _sel =
                                  _emps.firstWhere((e) => e.id == v)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          OutlinedButton.icon(
                            onPressed: () async {
                              final d = await showDatePicker(
                                  context: context,
                                  initialDate: _date,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2100));
                              if (d != null) setState(() => _date = d);
                            },
                            icon: const Icon(Icons.calendar_today, size: 16),
                            label: Text(DateFormat('dd MMM').format(_date)),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _dayEvents.isEmpty
                          ? Center(
                              child: Text('No punches this day',
                                  style: TextStyle(color: Colors.grey[500])))
                          : ListView(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
                              children: _dayEvents
                                  .map((ev) => Card(
                                        elevation: 0,
                                        margin:
                                            const EdgeInsets.only(bottom: 8),
                                        child: ListTile(
                                          leading: Icon(
                                            ev.type == PunchType.shiftIn ||
                                                    ev.type == PunchType.lunchIn
                                                ? Icons.login
                                                : Icons.logout,
                                            color: Colors.black87,
                                          ),
                                          title: Text(punchLabel(ev.type)),
                                          subtitle: Text(t12(ev.ts) +
                                              (ev.manual ? ' · manual' : '')),
                                          trailing: IconButton(
                                            icon: const Icon(
                                                Icons.delete_outline),
                                            onPressed: () async {
                                              await repo.deleteEvent(ev.id);
                                              _load();
                                            },
                                          ),
                                        ),
                                      ))
                                  .toList(),
                            ),
                    ),
                  ],
                ),
    );
  }
}
