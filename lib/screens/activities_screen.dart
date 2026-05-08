import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database.dart';
import '../providers/activities_provider.dart';
import '../providers/stats_provider.dart';
import '../theme/app_theme.dart';

class ActivitiesScreen extends ConsumerWidget {
  const ActivitiesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activitiesAsync = ref.watch(activitiesProvider);
    final statsAsync = ref.watch(statsByActivityProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: activitiesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (activities) {
          if (activities.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.timer_outlined,
                      size: 64, color: Colors.white24),
                  const SizedBox(height: 16),
                  const Text('No hay actividades todavía'),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () => _showActivityDialog(context, ref),
                    icon: const Icon(Icons.add),
                    label: const Text('Nueva actividad'),
                  ),
                ],
              ),
            );
          }
          final stats = statsAsync.valueOrNull ?? {};
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: activities.length,
            itemBuilder: (ctx, i) {
              final act = activities[i];
              final seconds = stats[act.id] ?? 0;
              return _ActivityTile(
                activity: act,
                totalSeconds: seconds,
                onEdit: () => _showActivityDialog(context, ref, activity: act),
                onDelete: () => _confirmDelete(context, ref, act),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showActivityDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Nueva'),
      ),
    );
  }

  Future<void> _showActivityDialog(
    BuildContext context,
    WidgetRef ref, {
    Activity? activity,
  }) async {
    await showDialog(
      context: context,
      builder: (_) => _ActivityDialog(activity: activity, ref: ref),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, Activity act) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar actividad'),
        content: Text('¿Eliminar "${act.name}"? Se perderá el historial.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok == true) {
      ref.read(activitiesNotifierProvider.notifier).delete(act.id);
    }
  }
}

class _ActivityTile extends StatelessWidget {
  final Activity activity;
  final int totalSeconds;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ActivityTile({
    required this.activity,
    required this.totalSeconds,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final color = Color(activity.colorValue);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: color.withAlpha(40),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.timer, color: color, size: 28),
        ),
        title: Text(activity.name,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${activity.workMinutes}m trabajo · ${activity.breakMinutes}m descanso'
          '${totalSeconds > 0 ? ' · ${formatDuration(totalSeconds)} esta semana' : ''}',
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 26),
              onPressed: onEdit,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 26, color: Colors.redAccent),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityDialog extends StatefulWidget {
  final Activity? activity;
  final WidgetRef ref;

  const _ActivityDialog({this.activity, required this.ref});

  @override
  State<_ActivityDialog> createState() => _ActivityDialogState();
}

class _ActivityDialogState extends State<_ActivityDialog> {
  late final TextEditingController _nameCtrl;
  late Color _selectedColor;
  late int _workMin;
  late int _breakMin;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.activity?.name ?? '');
    _selectedColor = widget.activity != null
        ? Color(widget.activity!.colorValue)
        : AppTheme.activityColors.first;
    _workMin = widget.activity?.workMinutes ?? 25;
    _breakMin = widget.activity?.breakMinutes ?? 5;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.activity == null ? 'Nueva actividad' : 'Editar actividad'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nombre',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            const Text('Color', style: TextStyle(fontSize: 12, color: Colors.white54)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: AppTheme.activityColors.map((c) {
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = c),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: _selectedColor == c
                          ? Border.all(color: Colors.white, width: 3)
                          : null,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            _MinutePicker(
              label: 'Trabajo (min)',
              value: _workMin,
              min: 1,
              max: 120,
              onChanged: (v) => setState(() => _workMin = v),
            ),
            const SizedBox(height: 8),
            _MinutePicker(
              label: 'Descanso (min)',
              value: _breakMin,
              min: 1,
              max: 60,
              onChanged: (v) => setState(() => _breakMin = v),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Guardar'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    final notifier = widget.ref.read(activitiesNotifierProvider.notifier);
    if (widget.activity == null) {
      await notifier.add(
        name: name,
        color: _selectedColor,
        workMinutes: _workMin,
        breakMinutes: _breakMin,
      );
    } else {
      await notifier.update(widget.activity!.copyWith(
        name: name,
        colorValue: _selectedColor.toARGB32(),
        workMinutes: _workMin,
        breakMinutes: _breakMin,
      ));
    }
    if (mounted) Navigator.pop(context);
  }
}

class _MinutePicker extends StatefulWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  const _MinutePicker({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  State<_MinutePicker> createState() => _MinutePickerState();
}

class _MinutePickerState extends State<_MinutePicker> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: '${widget.value}');
  }

  @override
  void didUpdateWidget(_MinutePicker old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value && _ctrl.text != '${widget.value}') {
      _ctrl.text = '${widget.value}';
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit(String text) {
    final v = int.tryParse(text);
    if (v != null) {
      final clamped = v.clamp(widget.min, widget.max);
      widget.onChanged(clamped);
      if (clamped != v) _ctrl.text = '$clamped';
    } else {
      _ctrl.text = '${widget.value}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(widget.label,
              style: const TextStyle(fontSize: 13, color: Colors.white70)),
        ),
        IconButton(
          icon: const Icon(Icons.remove, size: 22),
          onPressed: widget.value > widget.min
              ? () => widget.onChanged(widget.value - 1)
              : null,
        ),
        SizedBox(
          width: 56,
          child: TextField(
            controller: _ctrl,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            onSubmitted: _submit,
            onTapOutside: (_) => _submit(_ctrl.text),
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8)),
              isDense: true,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add, size: 22),
          onPressed: widget.value < widget.max
              ? () => widget.onChanged(widget.value + 1)
              : null,
        ),
      ],
    );
  }
}
