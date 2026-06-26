import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'models.dart';
import 'repo.dart';
import 'ui.dart';

class AnalyticsScreen extends StatefulWidget {
  final String ownerId;
  const AnalyticsScreen({super.key, required this.ownerId});
  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  List<Employee> _emps = [];
  List<AttEvent> _events = [];
  List<LeaveRequest> _leaves = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _emps = (await repo.employees(widget.ownerId)).where((e) => e.active).toList();
    _events = await repo.events(widget.ownerId);
    _leaves = await repo.leaves(widget.ownerId);
    if (mounted) setState(() => _loading = false);
  }

  int _presentDaysThisMonth(String empId) {
    final now = DateTime.now();
    final key = DateFormat('yyyy-MM').format(now);
    return _events
        .where((e) =>
            e.empId == empId &&
            e.type == PunchType.shiftIn &&
            e.date.startsWith(key))
        .map((e) => e.date)
        .toSet()
        .length;
  }

  bool _onLeaveToday(String empId) {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    for (final l in _leaves) {
      if (l.empId == empId && l.status == 'approved') {
        if (l.fromDate.compareTo(today) <= 0 && l.toDate.compareTo(today) >= 0) {
          return true;
        }
      }
    }
    return false;
  }

  bool _inToday(String empId) {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final ev = _events.where((e) => e.empId == empId && e.date == today).toList()
      ..sort((a, b) => a.ts.compareTo(b.ts));
    return ev.isNotEmpty && ev.last.type == PunchType.shiftIn;
  }

  @override
  Widget build(BuildContext context) {
    final present = _emps.where((e) => _inToday(e.id)).length;
    final onLeave = _emps.where((e) => _onLeaveToday(e.id)).length;
    final wd = DateTime.now();
    final workedSoFar = wd.day; // rough month progress
    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: _loading
          ? loading()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(children: [
                  _stat('Present now', '$present', Icons.login, Colors.green),
                  const SizedBox(width: 12),
                  _stat('On leave', '$onLeave', Icons.beach_access,
                      Colors.orange),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  _stat('Total staff', '${_emps.length}', Icons.groups, seed),
                  const SizedBox(width: 12),
                  _stat('Absent', '${_emps.length - present - onLeave}',
                      Icons.logout, Colors.red),
                ]),
                const SizedBox(height: 20),
                Text('Attendance this month',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                ..._emps.map((e) {
                  final d = _presentDaysThisMonth(e.id);
                  final pct = workedSoFar == 0
                      ? 0.0
                      : (d / workedSoFar).clamp(0.0, 1.0);
                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(e.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                              Text('$d / $workedSoFar days',
                                  style: TextStyle(color: Colors.grey[600])),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: pct,
                              minHeight: 8,
                              backgroundColor: Colors.grey[200],
                              color: pct > 0.8
                                  ? Colors.green
                                  : (pct > 0.5 ? Colors.orange : Colors.red),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text('${(pct * 100).toStringAsFixed(0)}% attendance',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[600])),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
    );
  }

  Widget _stat(String label, String value, IconData icon, Color c) {
    return Expanded(
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: c),
              const SizedBox(height: 8),
              Text(value,
                  style: const TextStyle(
                      fontSize: 26, fontWeight: FontWeight.w800)),
              Text(label, style: TextStyle(color: Colors.grey[600])),
            ],
          ),
        ),
      ),
    );
  }
}
