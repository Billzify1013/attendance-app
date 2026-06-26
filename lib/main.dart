import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import 'admin.dart';
import 'face_capture.dart';
import 'face_recognizer.dart';
import 'models.dart';
import 'repo.dart';
import 'staff.dart';
import 'ui.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    cameras = await availableCameras();
  } catch (_) {
    cameras = [];
  }
  await FaceRecognizer.instance.load();
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Attendance',
        debugShowCheckedModeBanner: false,
        theme: appTheme(),
        home: const AuthGate(),
      );
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late Future<Session?> _f;
  @override
  void initState() {
    super.initState();
    _f = repo.session();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Session?>(
      future: _f,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return Scaffold(body: loading());
        }
        final s = snap.data;
        if (s == null) return const RoleChooser();
        if (s.role == 'staff') return StaffKiosk(ownerId: s.ownerId);
        return AdminHome(ownerId: s.ownerId);
      },
    );
  }
}

// Choose Admin (full) or Staff Kiosk (scan only)
class RoleChooser extends StatelessWidget {
  const RoleChooser({super.key});

  Future<void> _staff(BuildContext context) async {
    final users = await repo.users();
    if (users.isEmpty) {
      if (context.mounted) {
        snack(context, 'No business yet. Create an admin account first.',
            Colors.orange);
      }
      return;
    }
    AppUser chosen = users.first;
    if (users.length > 1 && context.mounted) {
      final picked = await showModalBottomSheet<AppUser>(
        context: context,
        builder: (_) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: users
                .map((u) => ListTile(
                      title: Text(u.businessName),
                      subtitle: Text('@${u.username}'),
                      onTap: () => Navigator.pop(context, u),
                    ))
                .toList(),
          ),
        ),
      );
      if (picked == null) return;
      chosen = picked;
    }
    await repo.setSession(Session('staff', chosen.id));
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => StaffKiosk(ownerId: chosen.id)),
        (r) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                    color: seed, borderRadius: BorderRadius.circular(20)),
                child: const Icon(Icons.fingerprint,
                    color: Colors.white, size: 40),
              ),
              const SizedBox(height: 20),
              const Text('Attendance',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
              Text('Choose how you want to continue',
                  style: TextStyle(color: Colors.grey[600])),
              const Spacer(),
              _bigCard(
                context,
                icon: Icons.center_focus_strong,
                title: 'Staff Kiosk',
                sub: 'Just scan your face to punch',
                onTap: () => _staff(context),
              ),
              const SizedBox(height: 14),
              _bigCard(
                context,
                icon: Icons.admin_panel_settings,
                title: 'Admin / Owner',
                sub: 'Manage staff, attendance & more',
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const AdminAuthScreen())),
              ),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bigCard(BuildContext context,
      {required IconData icon,
      required String title,
      required String sub,
      required VoidCallback onTap}) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            CircleAvatar(
                radius: 26,
                backgroundColor: seed.withOpacity(0.12),
                child: Icon(icon, color: seed)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700)),
                  Text(sub, style: TextStyle(color: Colors.grey[600])),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

// Admin: list existing accounts to login, or create new
class AdminAuthScreen extends StatefulWidget {
  const AdminAuthScreen({super.key});
  @override
  State<AdminAuthScreen> createState() => _AdminAuthScreenState();
}

class _AdminAuthScreenState extends State<AdminAuthScreen> {
  List<AppUser> _users = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final u = await repo.users();
    if (!mounted) return;
    setState(() {
      _users = u;
      _loading = false;
    });
  }

  void _go(AppUser u) => Navigator.pushAndRemoveUntil(context,
      MaterialPageRoute(builder: (_) => AdminHome(ownerId: u.id)), (r) => false);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin')),
      body: _loading
          ? loading()
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (_users.isNotEmpty) ...[
                  const Text('Your businesses',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  ..._users.map((u) => Card(
                        elevation: 0,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: seed.withOpacity(0.12),
                            child: Text(
                                u.businessName.isNotEmpty
                                    ? u.businessName[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(color: seed)),
                          ),
                          title: Text(u.businessName),
                          subtitle: Text('@${u.username}'),
                          trailing: const Icon(Icons.lock_outline, size: 18),
                          onTap: () async {
                            final ok = await Navigator.push<AppUser>(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => AdminLogin(user: u)));
                            if (ok != null) _go(ok);
                          },
                        ),
                      )),
                  const SizedBox(height: 16),
                ],
                SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: () async {
                      final u = await Navigator.push<AppUser>(context,
                          MaterialPageRoute(builder: (_) => const SignupScreen()));
                      if (u != null) _go(u);
                    },
                    icon: const Icon(Icons.add_business),
                    label: const Text('Create Business Account'),
                  ),
                ),
              ],
            ),
    );
  }
}

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});
  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _biz = TextEditingController();
  final _type = TextEditingController();
  final _owner = TextEditingController();
  final _user = TextEditingController();
  final _pass = TextEditingController();
  bool _multi = false;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_biz, _type, _owner, _user, _pass]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_biz.text.trim().isEmpty ||
        _user.text.trim().isEmpty ||
        _pass.text.length < 4) {
      snack(context, 'Business name, username and 4+ char password required',
          Colors.orange);
      return;
    }
    setState(() => _busy = true);
    final draft = AppUser(
      id: '',
      businessName: _biz.text.trim(),
      businessType: _type.text.trim(),
      ownerName: _owner.text.trim(),
      username: _user.text.trim(),
      passHash: '',
      multiLocation: _multi,
      createdAt: 0,
    );
    final err = await repo.signup(draft, _pass.text);
    if (!mounted) return;
    if (err != null) {
      setState(() => _busy = false);
      snack(context, err, Colors.red);
      return;
    }
    final s = await repo.session();
    final u = s == null ? null : await repo.userById(s.ownerId);
    if (!mounted) return;
    Navigator.pop(context, u);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Business')),
      body: _busy
          ? loading()
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _tf(_biz, 'Business name', Icons.business),
                _tf(_type, 'Business type (shop, office, factory…)',
                    Icons.category),
                _tf(_owner, 'Owner name', Icons.person),
                _tf(_user, 'Username', Icons.alternate_email),
                _tf(_pass, 'Password', Icons.lock_outline, obscure: true),
                SwitchListTile(
                  value: _multi,
                  onChanged: (v) => setState(() => _multi = v),
                  title: const Text('Multiple locations'),
                  subtitle: const Text('Turn on if staff work at many sites'),
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 52,
                  child: FilledButton(
                      onPressed: _submit,
                      child: const Text('Create & Continue')),
                ),
              ],
            ),
    );
  }

  Widget _tf(TextEditingController c, String label, IconData icon,
      {bool obscure = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: c,
        obscureText: obscure,
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      ),
    );
  }
}

class AdminLogin extends StatefulWidget {
  final AppUser user;
  const AdminLogin({super.key, required this.user});
  @override
  State<AdminLogin> createState() => _AdminLoginState();
}

class _AdminLoginState extends State<AdminLogin> {
  final _pass = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    final u = await repo.login(widget.user.username, _pass.text);
    if (!mounted) return;
    if (u == null) {
      setState(() => _busy = false);
      snack(context, 'Wrong password', Colors.red);
      return;
    }
    Navigator.pop(context, u);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.user.businessName)),
      body: _busy
          ? loading()
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 20),
                TextField(
                  controller: _pass,
                  obscureText: true,
                  autofocus: true,
                  onSubmitted: (_) => _submit(),
                  decoration: const InputDecoration(
                      labelText: 'Password', prefixIcon: Icon(Icons.lock_outline)),
                ),
                const SizedBox(height: 20),
                SizedBox(
                    height: 52,
                    child: FilledButton(
                        onPressed: _submit, child: const Text('Login'))),
              ],
            ),
    );
  }
}
