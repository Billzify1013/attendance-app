import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

// Swap-able data layer. Today: LocalRepo (on-device).
// Later: implement ApiRepo with the same methods — UI won't change.
abstract class Repo {
  Future<List<AppUser>> users();
  Future<String?> signup(AppUser draft, String password);
  Future<AppUser?> login(String username, String password);
  Future<AppUser?> userById(String id);
  Future<void> updateUser(AppUser u);

  Future<void> setSession(Session? s);
  Future<Session?> session();

  Future<List<Employee>> employees(String ownerId);
  Future<void> saveEmployee(Employee e); // add or update
  Future<void> deleteEmployee(String empId);

  Future<List<WorkLocation>> locations(String ownerId);
  Future<void> saveLocation(WorkLocation l);
  Future<void> deleteLocation(String id);

  Future<List<AttEvent>> events(String ownerId);
  Future<void> addEvent(AttEvent ev);
  Future<void> deleteEvent(String id);

  Future<List<LeaveRequest>> leaves(String ownerId);
  Future<void> saveLeave(LeaveRequest l);
  Future<void> deleteLeave(String id);

  Future<List<Payment>> payments(String ownerId);
  Future<void> savePayment(Payment p);
  Future<void> deletePayment(String id);

  Future<List<Shift>> shifts(String ownerId);
  Future<void> saveShift(Shift s);
  Future<void> deleteShift(String id);
}

// global repo handle — replace with ApiRepo() later in main()
Repo repo = LocalRepo();

class LocalRepo implements Repo {
  static const _kUsers = 'users';
  static const _kEmps = 'employees';
  static const _kLocs = 'locations';
  static const _kEvents = 'events';
  static const _kLeaves = 'leaves';
  static const _kPays = 'payments';
  static const _kShifts = 'shifts';
  static const _kSessRole = 'sess_role';
  static const _kSessOwner = 'sess_owner';

  String _hash(String u, String p) =>
      sha256.convert(utf8.encode('att::$u::$p')).toString();

  Future<SharedPreferences> get _p => SharedPreferences.getInstance();

  @override
  Future<List<AppUser>> users() async {
    final p = await _p;
    return (p.getStringList(_kUsers) ?? [])
        .map((e) => AppUser.fromJson(jsonDecode(e)))
        .toList();
  }

  @override
  Future<String?> signup(AppUser draft, String password) async {
    final all = await users();
    final uname = draft.username.trim().toLowerCase();
    if (all.any((u) => u.username == uname)) return 'Username already exists';
    final user = AppUser(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      businessName: draft.businessName,
      businessType: draft.businessType,
      ownerName: draft.ownerName,
      username: uname,
      passHash: _hash(uname, password),
      multiLocation: draft.multiLocation,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    all.add(user);
    final p = await _p;
    await p.setStringList(_kUsers, all.map((e) => jsonEncode(e.toJson())).toList());
    await setSession(Session('admin', user.id));
    return null;
  }

  @override
  Future<AppUser?> login(String username, String password) async {
    final uname = username.trim().toLowerCase();
    for (final u in await users()) {
      if (u.username == uname && u.passHash == _hash(uname, password)) {
        await setSession(Session('admin', u.id));
        return u;
      }
    }
    return null;
  }

  @override
  Future<AppUser?> userById(String id) async {
    for (final u in await users()) {
      if (u.id == id) return u;
    }
    return null;
  }

  @override
  Future<void> updateUser(AppUser u) async {
    final all = await users();
    final i = all.indexWhere((x) => x.id == u.id);
    if (i >= 0) {
      all[i] = u;
      final p = await _p;
      await p.setStringList(
          _kUsers, all.map((e) => jsonEncode(e.toJson())).toList());
    }
  }

  @override
  Future<void> setSession(Session? s) async {
    final p = await _p;
    if (s == null) {
      await p.remove(_kSessRole);
      await p.remove(_kSessOwner);
    } else {
      await p.setString(_kSessRole, s.role);
      await p.setString(_kSessOwner, s.ownerId);
    }
  }

  @override
  Future<Session?> session() async {
    final p = await _p;
    final role = p.getString(_kSessRole);
    final owner = p.getString(_kSessOwner);
    if (role == null || owner == null) return null;
    if (await userById(owner) == null) return null;
    return Session(role, owner);
  }

  // ---- employees ----
  Future<List<Employee>> _allEmps() async {
    final p = await _p;
    return (p.getStringList(_kEmps) ?? [])
        .map((e) => Employee.fromJson(jsonDecode(e)))
        .toList();
  }

  Future<void> _saveEmps(List<Employee> list) async {
    final p = await _p;
    await p.setStringList(_kEmps, list.map((e) => jsonEncode(e.toJson())).toList());
  }

  @override
  Future<List<Employee>> employees(String ownerId) async =>
      (await _allEmps()).where((e) => e.ownerId == ownerId).toList();

  @override
  Future<void> saveEmployee(Employee e) async {
    final all = await _allEmps();
    final i = all.indexWhere((x) => x.id == e.id);
    if (i >= 0) {
      all[i] = e;
    } else {
      all.add(e);
    }
    await _saveEmps(all);
  }

  @override
  Future<void> deleteEmployee(String empId) async {
    final all = (await _allEmps()).where((e) => e.id != empId).toList();
    await _saveEmps(all);
    final ev = (await _allEvents()).where((x) => x.empId != empId).toList();
    await _saveEvents(ev);
  }

  // ---- locations ----
  Future<List<WorkLocation>> _allLocs() async {
    final p = await _p;
    return (p.getStringList(_kLocs) ?? [])
        .map((e) => WorkLocation.fromJson(jsonDecode(e)))
        .toList();
  }

  @override
  Future<List<WorkLocation>> locations(String ownerId) async =>
      (await _allLocs()).where((l) => l.ownerId == ownerId).toList();

  @override
  Future<void> saveLocation(WorkLocation l) async {
    final all = await _allLocs();
    final i = all.indexWhere((x) => x.id == l.id);
    if (i >= 0) {
      all[i] = l;
    } else {
      all.add(l);
    }
    final p = await _p;
    await p.setStringList(_kLocs, all.map((e) => jsonEncode(e.toJson())).toList());
  }

  @override
  Future<void> deleteLocation(String id) async {
    final all = (await _allLocs()).where((l) => l.id != id).toList();
    final p = await _p;
    await p.setStringList(_kLocs, all.map((e) => jsonEncode(e.toJson())).toList());
  }

  // ---- events ----
  Future<List<AttEvent>> _allEvents() async {
    final p = await _p;
    return (p.getStringList(_kEvents) ?? [])
        .map((e) => AttEvent.fromJson(jsonDecode(e)))
        .toList();
  }

  Future<void> _saveEvents(List<AttEvent> list) async {
    final p = await _p;
    await p.setStringList(_kEvents, list.map((e) => jsonEncode(e.toJson())).toList());
  }

  @override
  Future<List<AttEvent>> events(String ownerId) async =>
      (await _allEvents()).where((e) => e.ownerId == ownerId).toList();

  @override
  Future<void> addEvent(AttEvent ev) async {
    final all = await _allEvents();
    all.add(ev);
    await _saveEvents(all);
  }

  @override
  Future<void> deleteEvent(String id) async {
    final all = (await _allEvents()).where((e) => e.id != id).toList();
    await _saveEvents(all);
  }

  // ---- leaves ----
  Future<List<LeaveRequest>> _allLeaves() async {
    final p = await _p;
    return (p.getStringList(_kLeaves) ?? [])
        .map((e) => LeaveRequest.fromJson(jsonDecode(e)))
        .toList();
  }

  Future<void> _saveLeaves(List<LeaveRequest> list) async {
    final p = await _p;
    await p.setStringList(
        _kLeaves, list.map((e) => jsonEncode(e.toJson())).toList());
  }

  @override
  Future<List<LeaveRequest>> leaves(String ownerId) async =>
      (await _allLeaves()).where((l) => l.ownerId == ownerId).toList();

  @override
  Future<void> saveLeave(LeaveRequest l) async {
    final all = await _allLeaves();
    final i = all.indexWhere((x) => x.id == l.id);
    if (i >= 0) {
      all[i] = l;
    } else {
      all.add(l);
    }
    await _saveLeaves(all);
  }

  @override
  Future<void> deleteLeave(String id) async {
    final all = (await _allLeaves()).where((l) => l.id != id).toList();
    await _saveLeaves(all);
  }

  // ---- payments ----
  Future<List<Payment>> _allPays() async {
    final p = await _p;
    return (p.getStringList(_kPays) ?? [])
        .map((e) => Payment.fromJson(jsonDecode(e)))
        .toList();
  }

  Future<void> _savePays(List<Payment> list) async {
    final p = await _p;
    await p.setStringList(_kPays, list.map((e) => jsonEncode(e.toJson())).toList());
  }

  @override
  Future<List<Payment>> payments(String ownerId) async =>
      (await _allPays()).where((x) => x.ownerId == ownerId).toList();

  @override
  Future<void> savePayment(Payment p) async {
    final all = await _allPays();
    final i = all.indexWhere((x) => x.id == p.id);
    if (i >= 0) { all[i] = p; } else { all.add(p); }
    await _savePays(all);
  }

  @override
  Future<void> deletePayment(String id) async {
    final all = (await _allPays()).where((x) => x.id != id).toList();
    await _savePays(all);
  }

  // ---- shifts ----
  Future<List<Shift>> _allShifts() async {
    final p = await _p;
    return (p.getStringList(_kShifts) ?? [])
        .map((e) => Shift.fromJson(jsonDecode(e)))
        .toList();
  }

  @override
  Future<List<Shift>> shifts(String ownerId) async =>
      (await _allShifts()).where((s) => s.ownerId == ownerId).toList();

  @override
  Future<void> saveShift(Shift s) async {
    final all = await _allShifts();
    final i = all.indexWhere((x) => x.id == s.id);
    if (i >= 0) { all[i] = s; } else { all.add(s); }
    final p = await _p;
    await p.setStringList(_kShifts, all.map((e) => jsonEncode(e.toJson())).toList());
  }

  @override
  Future<void> deleteShift(String id) async {
    final all = (await _allShifts()).where((s) => s.id != id).toList();
    final p = await _p;
    await p.setStringList(_kShifts, all.map((e) => jsonEncode(e.toJson())).toList());
  }
}


// distance between two lat/lng in meters (Haversine)
double distanceMeters(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371000.0;
  final dLat = (lat2 - lat1) * math.pi / 180;
  final dLng = (lng2 - lng1) * math.pi / 180;
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1 * math.pi / 180) *
          math.cos(lat2 * math.pi / 180) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}
