import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'models.dart';
import 'repo.dart';
import 'ui.dart';

// Tracking: who did what at what time (per date)
class ActivityScreen extends StatefulWidget {
  final String ownerId;
  const ActivityScreen({super.key, required this.ownerId});
  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  List<Employee> _emps = [];
  List<AttEvent> _events = [];
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
    if (mounted) setState(() => _loading = false);
  }

  String _name(String id) => _emps
      .firstWhere((e) => e.id == id,
          orElse: () =>
              Employee(id: '', ownerId: '', name: 'Unknown', createdAt: 0))
      .name;

  IconData _icon(PunchType t) {
    switch (t) {
      case PunchType.shiftIn:
        return Icons.login;
      case PunchType.shiftOut:
        return Icons.logout;
      case PunchType.lunchOut:
        return Icons.restaurant;
      case PunchType.lunchIn:
        return Icons.work;
    }
  }

  Color _color(PunchType t) =>
      (t == PunchType.shiftIn || t == PunchType.lunchIn)
          ? Colors.green
          : Colors.red;

  @override
  Widget build(BuildContext context) {
    final key = DateFormat('yyyy-MM-dd').format(_date);
    final day = _events.where((e) => e.date == key).toList()
      ..sort((a, b) => b.ts.compareTo(a.ts));
    final isToday = key == DateFormat('yyyy-MM-dd').format(DateTime.now());
    return Scaffold(
      appBar: AppBar(title: const Text('Activity / Tracking')),
      body: _loading
          ? loading()
          : Column(
              children: [
                Card(
                  elevation: 0,
                  margin: const EdgeInsets.all(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                            icon: const Icon(Icons.chevron_left),
                            onPressed: () => setState(() => _date =
                                _date.subtract(const Duration(days: 1)))),
                        TextButton.icon(
                          icon: const Icon(Icons.calendar_today, size: 16),
                          label: Text(DateFormat('EEE, dd MMM yyyy')
                              .format(_date)),
                          onPressed: () async {
                            final d = await showDatePicker(
                                context: context,
                                initialDate: _date,
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now());
                            if (d != null) setState(() => _date = d);
                          },
                        ),
                        IconButton(
                            icon: const Icon(Icons.chevron_right),
                            onPressed: isToday
                                ? null
                                : () => setState(() => _date =
                                    _date.add(const Duration(days: 1)))),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: day.isEmpty
                      ? Center(
                          child: Text('No activity this day',
                              style: TextStyle(color: Colors.grey[500])))
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          itemCount: day.length,
                          itemBuilder: (_, i) {
                            final e = day[i];
                            return Card(
                              elevation: 0,
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor:
                                      _color(e.type).withOpacity(0.12),
                                  child: Icon(_icon(e.type),
                                      color: _color(e.type), size: 20),
                                ),
                                title: Text(_name(e.empId),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700)),
                                subtitle: Text(punchLabel(e.type) +
                                    (e.manual ? ' · manual' : '')),
                                trailing: Text(
                                  DateFormat('hh:mm a').format(
                                      DateTime.fromMillisecondsSinceEpoch(e.ts)),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

// Admin settings: control scan behaviour
class SettingsScreen extends StatefulWidget {
  final String ownerId;
  const SettingsScreen({super.key, required this.ownerId});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  AppUser? _u;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final u = await repo.userById(widget.ownerId);
    if (mounted) setState(() => _u = u);
  }

  Future<void> _save(AppUser u) async {
    await repo.updateUser(u);
    if (mounted) setState(() => _u = u);
  }

  @override
  Widget build(BuildContext context) {
    final u = _u;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: u == null
          ? loading()
          : ListView(
              padding: const EdgeInsets.all(8),
              children: [
                SwitchListTile(
                  value: u.askOnScan,
                  onChanged: (v) => _save(u.copyWith(askOnScan: v)),
                  title: const Text('Ask action on scan'),
                  subtitle: const Text(
                      'ON: employee chooses (lunch/shift). OFF: auto punch in/out, no popup.'),
                ),
                SwitchListTile(
                  value: u.lunchTracking,
                  onChanged: (v) => _save(u.copyWith(lunchTracking: v)),
                  title: const Text('Lunch in/out tracking'),
                  subtitle: const Text(
                      'OFF: only shift in/out, lunch options hidden everywhere.'),
                ),
              ],
            ),
    );
  }
}
