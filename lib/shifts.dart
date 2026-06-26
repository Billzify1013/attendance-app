import 'package:flutter/material.dart';

import 'models.dart';
import 'repo.dart';
import 'ui.dart';

class ShiftsScreen extends StatefulWidget {
  final String ownerId;
  const ShiftsScreen({super.key, required this.ownerId});
  @override
  State<ShiftsScreen> createState() => _ShiftsScreenState();
}

class _ShiftsScreenState extends State<ShiftsScreen> {
  List<Shift> _shifts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _shifts = await repo.shifts(widget.ownerId);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _add() async {
    final name = TextEditingController();
    String start = '09:00';
    String end = '18:00';
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setLocal) {
        Future<void> pick(bool s) async {
          final cur = (s ? start : end).split(':');
          final t = await showTimePicker(
              context: context,
              initialTime: TimeOfDay(
                  hour: int.parse(cur[0]), minute: int.parse(cur[1])));
          if (t == null) return;
          final v =
              '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
          setLocal(() => s ? start = v : end = v);
        }

        return AlertDialog(
          title: const Text('Add shift'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: name,
                  decoration: const InputDecoration(
                      labelText: 'Shift name (Morning, Night…)')),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                    child: OutlinedButton(
                        onPressed: () => pick(true), child: Text('In: $start'))),
                const SizedBox(width: 10),
                Expanded(
                    child: OutlinedButton(
                        onPressed: () => pick(false), child: Text('Out: $end'))),
              ]),
            ],
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
    if (name.text.trim().isEmpty) {
      snack(context, 'Enter shift name', Colors.orange);
      return;
    }
    await repo.saveShift(Shift(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      ownerId: widget.ownerId,
      name: name.text.trim(),
      start: start,
      end: end,
    ));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Shifts')),
      floatingActionButton: FloatingActionButton.extended(
          onPressed: _add,
          icon: const Icon(Icons.add),
          label: const Text('Add Shift')),
      body: _loading
          ? loading()
          : _shifts.isEmpty
              ? Center(
                  child: Text('No shifts yet',
                      style: TextStyle(color: Colors.grey[600])))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                  children: _shifts
                      .map((s) => Card(
                            elevation: 0,
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              leading: CircleAvatar(
                                  backgroundColor: seed.withOpacity(0.12),
                                  child: const Icon(Icons.schedule, color: seed)),
                              title: Text(s.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                              subtitle: Text('${s.start} - ${s.end}'),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () async {
                                  await repo.deleteShift(s.id);
                                  _load();
                                },
                              ),
                            ),
                          ))
                      .toList(),
                ),
    );
  }
}
