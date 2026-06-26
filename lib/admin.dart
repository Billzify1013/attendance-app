import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'face_capture.dart';
import 'activity.dart';
import 'analytics.dart';
import 'attendance_admin.dart';
import 'geo.dart';
import 'khata.dart';
import 'leave_add.dart';
import 'payroll.dart';
import 'shifts.dart';
import 'face_recognizer.dart';
import 'models.dart';
import 'repo.dart';
import 'main.dart';
import 'staff.dart';
import 'ui.dart';

class AdminHome extends StatefulWidget {
  final String ownerId;
  const AdminHome({super.key, required this.ownerId});
  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  AppUser? _user;
  List<Employee> _emps = [];
  List<WorkLocation> _locs = [];
  List<LeaveRequest> _leaves = [];
  List<AttEvent> _events = [];
  DateTime _date = DateTime.now();
  bool _loading = true;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final u = await repo.userById(widget.ownerId);
    final e = await repo.employees(widget.ownerId);
    final l = await repo.locations(widget.ownerId);
    final lv = await repo.leaves(widget.ownerId);
    final ev = await repo.events(widget.ownerId);
    if (!mounted) return;
    setState(() {
      _user = u;
      _emps = e..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      _locs = l;
      _leaves = lv..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _events = ev;
      _loading = false;
    });
  }

  Future<void> _addEdit([Employee? e]) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (_) => AddEditEmployee(ownerId: widget.ownerId, existing: e)),
    );
    if (saved == true) _load();
  }

  void _openKiosk() {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => StaffKiosk(ownerId: widget.ownerId)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_user?.businessName ?? 'Admin'),
        actions: [
          IconButton(
              tooltip: 'Open Staff Kiosk',
              icon: const Icon(Icons.center_focus_strong),
              onPressed: _openKiosk),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'out') _confirmSignOut();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'out', child: Text('Sign out')),
            ],
          ),
        ],
      ),
      floatingActionButton: _tab == 1
          ? FloatingActionButton.extended(
          onPressed: () => _addEdit(),
          icon: const Icon(Icons.person_add_alt_1),
          label: const Text('Add Staff'))
          : _tab == 2
          ? FloatingActionButton.extended(
          onPressed: _addLocation,
          icon: const Icon(Icons.add_location_alt),
          label: const Text('Add Site'))
          : _tab == 3
          ? FloatingActionButton.extended(
          onPressed: _addLeave,
          icon: const Icon(Icons.add),
          label: const Text('Apply Leave'))
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'Dashboard'),
          NavigationDestination(
              icon: Icon(Icons.groups_outlined),
              selectedIcon: Icon(Icons.groups),
              label: 'Staff'),
          NavigationDestination(
              icon: Icon(Icons.place_outlined),
              selectedIcon: Icon(Icons.place),
              label: 'Sites'),
          NavigationDestination(
              icon: Icon(Icons.event_note_outlined),
              selectedIcon: Icon(Icons.event_note),
              label: 'Leave'),
        ],
      ),
      body: _loading
          ? loading()
          : RefreshIndicator(
        onRefresh: _load,
        child: _tab == 0
            ? _dashboard()
            : _tab == 1
            ? _staffList()
            : _tab == 2
            ? _sites()
            : _leaveList(),
      ),
    );
  }

  Future<void> _confirmSignOut() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sign out?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sign out')),
        ],
      ),
    );
    if (ok == true) {
      await repo.setSession(null);
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const AuthGate()),
            (r) => false,
      );
    }
  }

  Widget _dashboard() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: headerGradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: seed.withOpacity(0.30),
                  blurRadius: 18,
                  offset: const Offset(0, 8)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(_user?.businessName ?? 'Dashboard',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800)),
                  ),
                  const Icon(Icons.notifications_none, color: Colors.white),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                  '${_user?.businessType ?? ''} · ${DateFormat('EEE, dd MMM').format(DateTime.now())}',
                  style: const TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 16),
              Row(
                children: [
                  _headerStat('${_emps.length}', 'Staff'),
                  _headerDivider(),
                  _headerStat('${_presentOn(DateTime.now())}', 'Present'),
                  _headerDivider(),
                  _headerStat('${_absentOn(DateTime.now())}', 'Absent'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _dateBar(),
        const SizedBox(height: 12),
        Row(
          children: [
            _statCard('Present', '${_presentOn(_date)}', Icons.login,
                const Color(0xFF22C55E)),
            const SizedBox(width: 12),
            _statCard('Absent', '${_absentOn(_date)}', Icons.logout,
                const Color(0xFFEF4444)),
          ],
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: _openKiosk,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFEEF0F6)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: seed.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.center_focus_strong, color: seed),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Open Staff Kiosk',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                      Text('Staff scan to punch on this device',
                          style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.grey),
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),
        Text('Manage',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.45,
          children: [
            _tool('Attendance', Icons.fact_check, const Color(0xFF5B7BFA), () => _open(AttendanceAdmin(ownerId: widget.ownerId))),
            _tool('Payroll', Icons.receipt_long, const Color(0xFF22C55E), () => _open(PayrollScreen(ownerId: widget.ownerId))),
            _tool('Khata / Pay', Icons.account_balance_wallet, const Color(0xFFF59E0B), () => _open(KhataScreen(ownerId: widget.ownerId))),
            _tool('Analytics', Icons.insights, const Color(0xFFA855F7), () => _open(AnalyticsScreen(ownerId: widget.ownerId))),
            _tool('Shifts', Icons.schedule, const Color(0xFF06B6D4), () => _open(ShiftsScreen(ownerId: widget.ownerId))),
            _tool('Activity', Icons.timeline, const Color(0xFFEC4899), () => _open(ActivityScreen(ownerId: widget.ownerId))),
            _tool('Settings', Icons.settings, const Color(0xFF64748B), () => _open(SettingsScreen(ownerId: widget.ownerId))),
          ],
        ),
      ],
    );
  }

  Future<void> _open(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    _load();
  }

  Widget _tool(String label, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFEEF0F6)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 10),
            Text(label,
                style: const TextStyle(
                    fontSize: 14.5, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Widget _headerStat(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800)),
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _headerDivider() => Container(
      width: 1, height: 34, color: Colors.white.withOpacity(0.25));

  Widget _dateBar() {
    final isToday = DateFormat('yyyy-MM-dd').format(_date) ==
        DateFormat('yyyy-MM-dd').format(DateTime.now());
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => setState(() =>
                _date = _date.subtract(const Duration(days: 1)))),
            TextButton.icon(
              icon: const Icon(Icons.calendar_today, size: 16),
              label: Text(isToday
                  ? 'Today, ${DateFormat('dd MMM').format(_date)}'
                  : DateFormat('EEE, dd MMM yyyy').format(_date)),
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
                    : () => setState(() =>
                _date = _date.add(const Duration(days: 1)))),
          ],
        ),
      ),
    );
  }

  int _presentOn(DateTime d) {
    final key = DateFormat('yyyy-MM-dd').format(d);
    final ids = _events
        .where((e) => e.date == key && e.type == PunchType.shiftIn)
        .map((e) => e.empId)
        .toSet();
    return ids.length;
  }

  bool _onLeaveOn(String empId, DateTime d) {
    final key = DateFormat('yyyy-MM-dd').format(d);
    return _leaves.any((l) =>
    l.empId == empId &&
        l.status == 'approved' &&
        l.fromDate.compareTo(key) <= 0 &&
        l.toDate.compareTo(key) >= 0);
  }

  int _absentOn(DateTime d) {
    final key = DateFormat('yyyy-MM-dd').format(d);
    final present = _events
        .where((e) => e.date == key && e.type == PunchType.shiftIn)
        .map((e) => e.empId)
        .toSet();
    int absent = 0;
    for (final e in _emps.where((x) => x.active)) {
      if (!present.contains(e.id) && !_onLeaveOn(e.id, d)) absent++;
    }
    return absent;
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFEEF0F6)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 10),
            Text(value,
                style: TextStyle(
                    fontSize: 26, fontWeight: FontWeight.w800, color: color)),
            Text(label,
                style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _staffList() {
    if (_emps.isEmpty) {
      return ListView(children: [
        const SizedBox(height: 120),
        Icon(Icons.groups_outlined, size: 64, color: Colors.grey[400]),
        const SizedBox(height: 12),
        Center(
            child: Text('No staff yet',
                style: TextStyle(color: Colors.grey[600], fontSize: 16))),
      ]);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: _emps
          .map((e) => Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 12),
        child: ListTile(
          leading: e.photo.isNotEmpty
              ? CircleAvatar(
              backgroundImage: MemoryImage(base64Decode(e.photo)))
              : CircleAvatar(
              backgroundColor: seed.withOpacity(0.12),
              child: Text(
                  e.name.isNotEmpty ? e.name[0].toUpperCase() : '?',
                  style: const TextStyle(color: seed))),
          title: Text(e.name,
              style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text([
            if (e.designation.isNotEmpty) e.designation,
            if (e.department.isNotEmpty) e.department,
            if (e.monthlySalary > 0)
              '₹${e.monthlySalary.toStringAsFixed(0)}/mo',
          ].join(' · ')),
          trailing: PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'edit') _addEdit(e);
              if (v == 'delete') _delete(e);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
          onTap: () => _addEdit(e),
        ),
      ))
          .toList(),
    );
  }

  Widget _sites() {
    if (_locs.isEmpty) {
      return ListView(children: [
        const SizedBox(height: 100),
        Icon(Icons.place_outlined, size: 64, color: Colors.grey[400]),
        const SizedBox(height: 12),
        Center(
            child: Text('No sites yet',
                style: TextStyle(color: Colors.grey[600], fontSize: 16))),
        const SizedBox(height: 4),
        Center(
            child: Text('Add a site to enable 30m geofenced punch',
                style: TextStyle(color: Colors.grey[500], fontSize: 12))),
      ]);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: _locs
          .map((l) => Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 12),
        child: ListTile(
          leading: CircleAvatar(
              backgroundColor: seed.withOpacity(0.12),
              child: const Icon(Icons.place, color: seed)),
          title: Text(l.name,
              style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(
              '${l.lat.toStringAsFixed(5)}, ${l.lng.toStringAsFixed(5)} · ${l.radius.toInt()}m'),
          trailing: PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'radius') _editRadius(l);
              if (v == 'delete') {
                await repo.deleteLocation(l.id);
                _load();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'radius', child: Text('Edit radius')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ),
      ))
          .toList(),
    );
  }

  Future<void> _addLocation() async {
    final nameCtl = TextEditingController();
    final radCtl = TextEditingController(text: '30');
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add site'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: nameCtl,
                decoration: const InputDecoration(labelText: 'Site name')),
            const SizedBox(height: 12),
            TextField(
                controller: radCtl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Radius (meters)')),
            const SizedBox(height: 8),
            const Text('Current GPS location of THIS device will be saved.',
                style: TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Get GPS & Save')),
        ],
      ),
    );
    if (ok != true) return;
    if (nameCtl.text.trim().isEmpty) {
      snack(context, 'Enter site name', Colors.orange);
      return;
    }
    setState(() => _loading = true);
    final pos = await Geo.current();
    if (!mounted) return;
    if (pos == null) {
      setState(() => _loading = false);
      snack(context, 'Turn on location & allow permission, then retry',
          Colors.red);
      return;
    }
    await repo.saveLocation(WorkLocation(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      ownerId: widget.ownerId,
      name: nameCtl.text.trim(),
      lat: pos.latitude,
      lng: pos.longitude,
      radius: double.tryParse(radCtl.text.trim()) ?? 30,
    ));
    await _load();
    if (mounted) snack(context, 'Site saved', Colors.green);
  }

  Future<void> _editRadius(WorkLocation l) async {
    final ctl = TextEditingController(text: l.radius.toInt().toString());
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l.name),
        content: TextField(
            controller: ctl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Radius (meters)')),
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
    await repo.saveLocation(WorkLocation(
      id: l.id,
      ownerId: l.ownerId,
      name: l.name,
      lat: l.lat,
      lng: l.lng,
      radius: double.tryParse(ctl.text.trim()) ?? l.radius,
    ));
    _load();
  }

  String _empName(String id) =>
      _emps.firstWhere((e) => e.id == id,
          orElse: () => Employee(id: '', ownerId: '', name: 'Unknown', createdAt: 0))
          .name;

  Color _statusColor(String s) {
    if (s == 'approved') return Colors.green;
    if (s == 'rejected') return Colors.red;
    return Colors.orange;
  }

  Widget _leaveList() {
    if (_leaves.isEmpty) {
      return ListView(children: [
        const SizedBox(height: 100),
        Icon(Icons.event_note_outlined, size: 64, color: Colors.grey[400]),
        const SizedBox(height: 12),
        Center(
            child: Text('No leave records',
                style: TextStyle(color: Colors.grey[600], fontSize: 16))),
      ]);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: _leaves.map((l) {
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(_empName(l.empId),
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _statusColor(l.status).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(l.status.toUpperCase(),
                          style: TextStyle(
                              color: _statusColor(l.status),
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                    '${leaveLabel(l.type)} · ${l.days} day(s) · ${l.fromDate}'
                        '${l.toDate != l.fromDate ? ' → ${l.toDate}' : ''}',
                    style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                if (l.reason.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(l.reason,
                        style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                  ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (l.status != 'approved')
                      TextButton(
                          onPressed: () => _setLeave(l, 'approved'),
                          child: const Text('Approve')),
                    if (l.status != 'rejected')
                      TextButton(
                          onPressed: () => _setLeave(l, 'rejected'),
                          child: const Text('Reject',
                              style: TextStyle(color: Colors.red))),
                    IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20),
                        onPressed: () async {
                          await repo.deleteLeave(l.id);
                          _load();
                        }),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Future<void> _setLeave(LeaveRequest l, String status) async {
    await repo.saveLeave(l.copyWith(status: status));
    _load();
  }

  Future<void> _addLeave() async {
    if (_emps.isEmpty) {
      snack(context, 'Add staff first', Colors.orange);
      return;
    }
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (_) =>
              LeaveAddScreen(ownerId: widget.ownerId, emps: _emps)),
    );
    if (ok == true) _load();
  }

  Future<void> _delete(Employee e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete staff?'),
        content: Text('${e.name} and their records will be removed.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      await repo.deleteEmployee(e.id);
      _load();
    }
  }
}

// ===========================================================================
// ADD / EDIT EMPLOYEE
// ===========================================================================
class AddEditEmployee extends StatefulWidget {
  final String ownerId;
  final Employee? existing;
  const AddEditEmployee({super.key, required this.ownerId, this.existing});
  @override
  State<AddEditEmployee> createState() => _AddEditEmployeeState();
}

class _AddEditEmployeeState extends State<AddEditEmployee> {
  late TextEditingController _name, _empId, _phone, _dept, _desig, _monthly, _perday;
  String _shiftStart = '09:00';
  String _shiftEnd = '18:00';
  bool _lunch = false;
  String _joinDate = '';
  bool _active = true;
  String? _photo;
  List<List<double>>? _templates;
  bool _busy = false;
  List<WorkLocation> _locs = [];
  List<Shift> _shifts = [];
  String _locationId = '';

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _empId = TextEditingController(text: e?.empId ?? '');
    _phone = TextEditingController(text: e?.phone ?? '');
    _dept = TextEditingController(text: e?.department ?? '');
    _desig = TextEditingController(text: e?.designation ?? '');
    _monthly = TextEditingController(
        text: (e?.monthlySalary ?? 0) > 0 ? '${e!.monthlySalary.toInt()}' : '');
    _perday = TextEditingController(
        text: (e?.perDaySalary ?? 0) > 0 ? '${e!.perDaySalary.toInt()}' : '');
    _shiftStart = e?.shiftStart ?? '09:00';
    _shiftEnd = e?.shiftEnd ?? '18:00';
    _lunch = e?.lunchEnabled ?? false;
    _joinDate = e?.joinDate ?? '';
    _active = e?.active ?? true;
    _photo = (e?.photo.isNotEmpty ?? false) ? e!.photo : null;
    _templates = (e?.templates.isNotEmpty ?? false) ? e!.templates : null;
    _locationId = e?.locationId ?? '';
    _loadLocs();
  }

  Future<void> _loadLocs() async {
    final l = await repo.locations(widget.ownerId);
    final sh = await repo.shifts(widget.ownerId);
    if (mounted) setState(() { _locs = l; _shifts = sh; });
  }

  @override
  void dispose() {
    for (final c in [_name, _empId, _phone, _dept, _desig, _monthly, _perday]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _scanFace() async {
    final res = await Navigator.push<CaptureResult>(
      context,
      MaterialPageRoute(
          builder: (_) =>
          const FaceCaptureScreen(title: 'Register face', samples: 5)),
    );
    if (res == null || !mounted) return;
    setState(() => _busy = true);
    final existing = await repo.employees(widget.ownerId);
    Employee? dup;
    for (final e in existing) {
      if (_editing && e.id == widget.existing!.id) continue;
      double best = -1;
      for (final probe in res.templates) {
        final s = bestScore(probe, e.templates);
        if (s > best) best = s;
      }
      if (best >= kDupThreshold) {
        dup = e;
        break;
      }
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (dup != null) {
      snack(context, 'This face is already registered as ${dup.name}',
          Colors.red);
      return;
    }
    setState(() {
      _photo = res.photoB64;
      _templates = res.templates;
    });
    snack(context, 'Face registered (${res.templates.length} scans)',
        Colors.green);
  }

  Future<void> _pickTime(bool start) async {
    final parts = (start ? _shiftStart : _shiftEnd).split(':');
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
          hour: int.tryParse(parts[0]) ?? 9, minute: int.tryParse(parts[1]) ?? 0),
    );
    if (t == null) return;
    final v =
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    setState(() => start ? _shiftStart = v : _shiftEnd = v);
  }

  Future<void> _pickJoinDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d == null) return;
    setState(() => _joinDate = DateFormat('yyyy-MM-dd').format(d));
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      snack(context, 'Enter name', Colors.orange);
      return;
    }
    if (_templates == null || _templates!.isEmpty) {
      snack(context, 'Register face first', Colors.orange);
      return;
    }
    final base = widget.existing ??
        Employee(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            ownerId: widget.ownerId,
            name: '',
            createdAt: DateTime.now().millisecondsSinceEpoch);
    final emp = base.copyWith(
      name: _name.text.trim(),
      empId: _empId.text.trim(),
      phone: _phone.text.trim(),
      department: _dept.text.trim(),
      designation: _desig.text.trim(),
      monthlySalary: double.tryParse(_monthly.text.trim()) ?? 0,
      perDaySalary: double.tryParse(_perday.text.trim()) ?? 0,
      shiftStart: _shiftStart,
      shiftEnd: _shiftEnd,
      lunchEnabled: _lunch,
      joinDate: _joinDate,
      active: _active,
      locationId: _locationId,
      photo: _photo ?? '',
      templates: _templates,
    );
    await repo.saveEmployee(emp);
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Edit Staff' : 'Add Staff')),
      body: _busy
          ? loading()
          : ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: GestureDetector(
              onTap: _scanFace,
              child: CircleAvatar(
                radius: 56,
                backgroundColor: seed.withOpacity(0.12),
                backgroundImage: _photo != null
                    ? MemoryImage(base64Decode(_photo!))
                    : null,
                child: _photo == null
                    ? Icon(Icons.add_a_photo, color: seed, size: 32)
                    : null,
              ),
            ),
          ),
          Center(
            child: TextButton.icon(
                onPressed: _scanFace,
                icon: const Icon(Icons.camera_alt, size: 18),
                label: Text(_photo == null ? 'Scan Face' : 'Re-scan')),
          ),
          const SizedBox(height: 8),
          _tf(_name, 'Full name', Icons.person),
          _tf(_empId, 'Employee ID', Icons.badge_outlined),
          _tf(_phone, 'Phone', Icons.phone, type: TextInputType.phone),
          _tf(_dept, 'Department', Icons.apartment),
          _tf(_desig, 'Designation', Icons.work_outline),
          Row(children: [
            Expanded(
                child: _tf(_monthly, 'Monthly salary', Icons.payments,
                    type: TextInputType.number)),
            const SizedBox(width: 12),
            Expanded(
                child: _tf(_perday, 'Per-day salary', Icons.today,
                    type: TextInputType.number)),
          ]),
          Row(children: [
            Expanded(
                child: _pickTile('Shift in', _shiftStart,
                    Icons.login, () => _pickTime(true))),
            const SizedBox(width: 12),
            Expanded(
                child: _pickTile('Shift out', _shiftEnd, Icons.logout,
                        () => _pickTime(false))),
          ]),
          const SizedBox(height: 12),
          _pickTile('Joining date',
              _joinDate.isEmpty ? 'Not set' : _joinDate,
              Icons.event, _pickJoinDate),
          if (_shifts.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: DropdownButtonFormField<String>(
                value: null,
                decoration: const InputDecoration(
                    labelText: 'Apply a shift (sets times)',
                    prefixIcon: Icon(Icons.schedule)),
                items: _shifts
                    .map((sh) => DropdownMenuItem(
                    value: sh.id,
                    child: Text('${sh.name} (${sh.start}-${sh.end})')))
                    .toList(),
                onChanged: (v) {
                  final sh = _shifts.firstWhere((x) => x.id == v);
                  setState(() {
                    _shiftStart = sh.start;
                    _shiftEnd = sh.end;
                  });
                },
              ),
            ),
          if (_locs.isNotEmpty)
            Builder(builder: (_) {
              final safeVal =
              _locs.any((l) => l.id == _locationId) ? _locationId : '';
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: DropdownButtonFormField<String>(
                  value: safeVal,
                  decoration: const InputDecoration(
                      labelText: 'Work site (geofence)',
                      prefixIcon: Icon(Icons.place_outlined)),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('Any site')),
                    ..._locs.map((l) => DropdownMenuItem(
                        value: l.id, child: Text(l.name))),
                  ],
                  onChanged: (v) => setState(() => _locationId = v ?? ''),
                ),
              );
            }),
          SwitchListTile(
            value: _lunch,
            onChanged: (v) => setState(() => _lunch = v),
            title: const Text('Lunch in/out tracking'),
            contentPadding: EdgeInsets.zero,
          ),
          SwitchListTile(
            value: _active,
            onChanged: (v) => setState(() => _active = v),
            title: const Text('Active'),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 16),
          SizedBox(
              height: 52,
              child: FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.check),
                  label: const Text('Save'))),
        ],
      ),
    );
  }

  Widget _tf(TextEditingController c, String label, IconData icon,
      {TextInputType? type}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: c,
        keyboardType: type,
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      ),
    );
  }

  Widget _pickTile(String label, String value, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Colors.grey[700]),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                  Text(value,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}