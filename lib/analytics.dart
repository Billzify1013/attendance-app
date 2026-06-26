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
  DateTime _date = DateTime.now();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _emps =
        (await repo.employees(widget.ownerId)).where((e) => e.active).toList();
    _events = await repo.events(widget.ownerId);
    _leaves = await repo.leaves(widget.ownerId);
    if (mounted) setState(() => _loading = false);
  }

  String _key(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  LeaveRequest? _leaveOn(String empId, DateTime d) {
    final k = _key(d);
    for (final l in _leaves) {
      if (l.empId == empId &&
          l.status == 'approved' &&
          l.fromDate.compareTo(k) <= 0 &&
          l.toDate.compareTo(k) >= 0) {
        return l;
      }
    }
    return null;
  }

  bool _present(String empId, DateTime d) {
    final k = _key(d);
    return _events.any((e) =>
    e.empId == empId && e.date == k && e.type == PunchType.shiftIn);
  }

  int _presentMonth(String empId) {
    final key = DateFormat('yyyy-MM').format(DateTime.now());
    return _events
        .where((e) =>
    e.empId == empId &&
        e.type == PunchType.shiftIn &&
        e.date.startsWith(key))
        .map((e) => e.date)
        .toSet()
        .length;
  }

  @override
  Widget build(BuildContext context) {
    final todayKey = _key(DateTime.now());
    final isFuture = _key(_date).compareTo(todayKey) > 0;
    final isToday = _key(_date) == todayKey;

    final onLeave = _emps.where((e) => _leaveOn(e.id, _date) != null).toList();
    final notLeave =
    _emps.where((e) => _leaveOn(e.id, _date) == null).toList();
    final present = notLeave.where((e) => _present(e.id, _date)).toList();
    final absent = notLeave.where((e) => !_present(e.id, _date)).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: _loading
          ? loading()
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ---- date selector (past + future) ----
          Card(
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
                          lastDate: DateTime(2100));
                      if (d != null) setState(() => _date = d);
                    },
                  ),
                  IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () => setState(() =>
                      _date = _date.add(const Duration(days: 1)))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isFuture
                ? 'Planned for this day'
                : (isToday ? "Today's status" : 'That day\'s record'),
            style: const TextStyle(
                fontSize: 13, color: Color(0xFF8A8A8E)),
          ),
          const SizedBox(height: 12),

          // ---- summary cards ----
          if (isFuture)
            Row(children: [
              _stat('Available', '${notLeave.length}', Icons.event_available,
                  const Color(0xFF22C55E)),
              const SizedBox(width: 12),
              _stat('On Leave', '${onLeave.length}', Icons.beach_access,
                  const Color(0xFFF59E0B)),
            ])
          else
            Row(children: [
              _stat('Present', '${present.length}', Icons.login,
                  const Color(0xFF22C55E)),
              const SizedBox(width: 12),
              _stat('Absent', '${absent.length}', Icons.logout,
                  const Color(0xFFEF4444)),
              const SizedBox(width: 12),
              _stat('Leave', '${onLeave.length}', Icons.beach_access,
                  const Color(0xFFF59E0B)),
            ]),

          const SizedBox(height: 20),

          // ---- on leave list ----
          if (onLeave.isNotEmpty) ...[
            _sectionTitle('On Leave (${onLeave.length})',
                const Color(0xFFF59E0B)),
            ...onLeave.map((e) {
              final l = _leaveOn(e.id, _date);
              return _personTile(
                  e.name,
                  l != null ? leaveLabel(l.type) : 'Leave',
                  Icons.beach_access,
                  const Color(0xFFF59E0B));
            }),
            const SizedBox(height: 12),
          ],

          // ---- future: who will be available ----
          if (isFuture) ...[
            _sectionTitle('Expected to work (${notLeave.length})',
                const Color(0xFF22C55E)),
            ...notLeave.map((e) => _personTile(e.name,
                e.designation.isEmpty ? 'Available' : e.designation,
                Icons.check_circle, const Color(0xFF22C55E))),
          ] else ...[
            // past/today: present + absent
            if (present.isNotEmpty) ...[
              _sectionTitle('Present (${present.length})',
                  const Color(0xFF22C55E)),
              ...present.map((e) => _personTile(e.name, 'Came',
                  Icons.check_circle, const Color(0xFF22C55E))),
              const SizedBox(height: 12),
            ],
            if (absent.isNotEmpty) ...[
              _sectionTitle('Absent (${absent.length})',
                  const Color(0xFFEF4444)),
              ...absent.map((e) => _personTile(e.name, 'No punch',
                  Icons.cancel, const Color(0xFFEF4444))),
            ],
          ],

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 12),

          // ---- monthly attendance % ----
          Text('Attendance this month',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          ..._emps.map((e) {
            final d = _presentMonth(e.id);
            final daysSoFar = DateTime.now().day;
            final pct =
            daysSoFar == 0 ? 0.0 : (d / daysSoFar).clamp(0.0, 1.0);
            return Card(
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
                        Text('$d / $daysSoFar days',
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
                            ? const Color(0xFF22C55E)
                            : (pct > 0.5
                            ? const Color(0xFFF59E0B)
                            : const Color(0xFFEF4444)),
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

  Widget _sectionTitle(String t, Color c) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Container(width: 4, height: 18, color: c),
        const SizedBox(width: 8),
        Text(t,
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w800)),
      ],
    ),
  );

  Widget _personTile(String name, String sub, IconData icon, Color c) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: ListTile(
      dense: true,
      leading: CircleAvatar(
        backgroundColor: c.withOpacity(0.14),
        child: Icon(icon, color: c, size: 20),
      ),
      title:
      Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(sub),
    ),
  );

  Widget _stat(String label, String value, IconData icon, Color c) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEEF0F6)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: c),
            const SizedBox(height: 8),
            Text(value,
                style: TextStyle(
                    fontSize: 24, fontWeight: FontWeight.w800, color: c)),
            Text(label,
                style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          ],
        ),
      ),
    );
  }
}