import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'face_capture.dart';
import 'geo.dart';
import 'main.dart';
import 'models.dart';
import 'repo.dart';
import 'ui.dart';

// Staff Kiosk: scan face -> identify -> punch. No details shown.
class StaffKiosk extends StatefulWidget {
  final String ownerId;
  const StaffKiosk({super.key, required this.ownerId});
  @override
  State<StaffKiosk> createState() => _StaffKioskState();
}

class _StaffKioskState extends State<StaffKiosk> {
  AppUser? _user;
  List<Employee> _emps = [];
  List<AttEvent> _events = [];
  List<WorkLocation> _locs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final u = await repo.userById(widget.ownerId);
    final e = await repo.employees(widget.ownerId);
    final ev = await repo.events(widget.ownerId);
    final l = await repo.locations(widget.ownerId);
    if (!mounted) return;
    setState(() {
      _user = u;
      _emps = e.where((x) => x.active).toList();
      _events = ev;
      _locs = l;
      _loading = false;
    });
  }

  List<AttEvent> _todayFor(String empId) {
    final t = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return _events.where((x) => x.empId == empId && x.date == t).toList()
      ..sort((a, b) => a.ts.compareTo(b.ts));
  }

  // figure out which actions make sense right now
  List<PunchType> _allowed(Employee e) {
    final today = _todayFor(e.id);
    final last = today.isEmpty ? null : today.last.type;
    final inShift = today.any((x) => x.type == PunchType.shiftIn) &&
        last != PunchType.shiftOut;
    final onLunch = last == PunchType.lunchOut;
    final lunchOn = (_user?.lunchTracking ?? true) && e.lunchEnabled;
    if (!inShift) return [PunchType.shiftIn];
    if (onLunch) return [PunchType.lunchIn];
    final list = <PunchType>[PunchType.shiftOut];
    if (lunchOn) list.insert(0, PunchType.lunchOut);
    return list;
  }

  Future<void> _alert(String title, String msg) async {
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(msg),
        actions: [
          FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK')),
        ],
      ),
    );
  }

  Future<void> _scan() async {
    if (_emps.isEmpty) {
      snack(context, 'No staff registered yet', Colors.orange);
      return;
    }
    final res = await Navigator.push<CaptureResult>(
      context,
      MaterialPageRoute(
        builder: (_) => FaceCaptureScreen(
            title: 'Scan to Punch', identifyAgainst: _emps),
      ),
    );
    if (res == null || res.matched == null || !mounted) return;
    final e = res.matched!;

    try {
      // let the camera screen finish closing before showing a dialog
      await Future.delayed(const Duration(milliseconds: 150));
      if (!mounted) return;

      // ---- STRICT GEOFENCE ----
      double? gLat, gLng;
      final sites = e.locationId.isEmpty
          ? _locs
          : _locs.where((l) => l.id == e.locationId).toList();
      if (sites.isNotEmpty) {
        final pos = await Geo.current();
        if (!mounted) return;
        if (pos == null) {
          await _alert('Location needed',
              'Turn ON location/GPS and allow permission, then scan again.');
          return;
        }
        gLat = pos.latitude;
        gLng = pos.longitude;
        // GPS itself is only accurate to a few meters; add that tolerance
        final tol = pos.accuracy + 50; // generous indoor GPS allowance
        double nearest = double.infinity;
        for (final l in sites) {
          final d = distanceMeters(gLat, gLng, l.lat, l.lng);
          if (d < nearest) nearest = d;
        }
        final allowed = sites.any((l) =>
            distanceMeters(gLat!, gLng!, l.lat, l.lng) <= l.radius + tol);
        if (!allowed) {
          await _alert('Out of work area',
              'You are ~${nearest.toStringAsFixed(0)}m from the site '
              '(GPS ±${pos.accuracy.toStringAsFixed(0)}m). Move closer or '
              'increase the site radius.');
          return;
        }
      }

      final actions = _allowed(e);
      PunchType picked;
      final ask = _user?.askOnScan ?? true;
      // ask only when admin wants it AND there is a real choice
      if (ask) {
        final chosen = await showDialog<PunchType>(
          context: context,
          barrierDismissible: true,
          builder: (dctx) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green),
                const SizedBox(width: 10),
                Expanded(child: Text('Hello, ${e.name}')),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: actions
                  .map((a) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: FilledButton.icon(
                            onPressed: () => Navigator.pop(dctx, a),
                            icon: Icon(_icon(a)),
                            label: Text(punchLabel(a)),
                          ),
                        ),
                      ))
                  .toList(),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dctx, null),
                  child: const Text('Cancel')),
            ],
          ),
        );
        if (chosen == null || !mounted) return;
        picked = chosen;
      } else {
        // auto: take the natural next action
        picked = actions.first;
      }

      final now = DateTime.now();
      await repo.addEvent(AttEvent(
        id: now.millisecondsSinceEpoch.toString(),
        empId: e.id,
        ownerId: widget.ownerId,
        type: picked,
        date: DateFormat('yyyy-MM-dd').format(now),
        time: DateFormat('HH:mm:ss').format(now),
        ts: now.millisecondsSinceEpoch,
        lat: gLat,
        lng: gLng,
      ));
      if (!mounted) return;
      _success(e.name, punchLabel(picked), now);
      await _load();
    } catch (err) {
      if (mounted) await _alert('Could not punch', err.toString());
    }
  }

  void _success(String name, String action, DateTime now) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dctx) {
        // auto-close after a moment so the next person can scan
        Future.delayed(const Duration(milliseconds: 1300), () {
          if (Navigator.of(dctx).canPop()) Navigator.of(dctx).pop();
        });
        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                  radius: 34,
                  backgroundColor: Colors.green,
                  child: const Icon(Icons.check, color: Colors.white, size: 40)),
              const SizedBox(height: 16),
              Text(name,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w800)),
              Text('$action · ${DateFormat('hh:mm a').format(now)}',
                  style: TextStyle(color: Colors.grey[700], fontSize: 15)),
            ],
          ),
        );
      },
    );
  }

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

  Future<void> _exit() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Exit kiosk?'),
        content: const Text('Go back to the home screen.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Exit')),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_user?.businessName ?? 'Kiosk'),
        actions: [
          IconButton(icon: const Icon(Icons.close), onPressed: _exit),
        ],
      ),
      body: _loading
          ? loading()
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                        color: seed.withOpacity(0.10), shape: BoxShape.circle),
                    child: const Icon(Icons.face_retouching_natural,
                        size: 70, color: seed),
                  ),
                  const SizedBox(height: 24),
                  const Text('Tap to scan your face',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  Text('Punch in / out hands-free',
                      style: TextStyle(color: Colors.grey[600])),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: 220,
                    height: 60,
                    child: FilledButton.icon(
                      onPressed: _scan,
                      icon: const Icon(Icons.center_focus_strong),
                      label: const Text('Scan to Punch'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
