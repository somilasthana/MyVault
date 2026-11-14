import 'package:flutter/material.dart';
import 'package:myvault/app/vault_app.dart';
import 'package:myvault/data/reminder_date.dart';
import 'package:myvault/data/vault_item.dart';
import 'package:myvault/theme/vault_theme.dart';
import 'package:myvault/widgets/reminder_calendar.dart';
import 'package:myvault/widgets/vault_kind_icon.dart';
import 'package:myvault/widgets/vault_widgets.dart';

const secureNoteReminderHelp =
    'Set reminder to notify about this secure note by enabling the slider. '
    'You will be asked to select a date for the reminder to go off. '
    'The reminder will be triggered and an app notification will pop up on your phone at 10:00 AM local time.';

class SecureNoteFormScreen extends StatefulWidget {
  const SecureNoteFormScreen({this.existing, super.key});

  final VaultItem? existing;

  @override
  State<SecureNoteFormScreen> createState() => _SecureNoteFormScreenState();
}

class _SecureNoteFormScreenState extends State<SecureNoteFormScreen> {
  late final TextEditingController _title;
  late final TextEditingController _notes;
  DateTime? _reminder;
  var _picking = false;
  var _leaving = false;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _title = TextEditingController(text: existing?.title ?? '');
    _notes = TextEditingController(text: existing?.notes ?? '');
    _reminder = parseReminderDate(existing?.reminderDate);
    for (final controller in [_title, _notes]) {
      controller.addListener(_refresh);
    }
  }

  @override
  void dispose() {
    for (final controller in [_title, _notes]) {
      controller.removeListener(_refresh);
      controller.dispose();
    }
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  bool get _dirty {
    final existing = widget.existing;
    if (existing == null) {
      return _title.text.isNotEmpty ||
          _notes.text.isNotEmpty ||
          _reminder != null;
    }
    return _title.text != existing.title ||
        _notes.text != existing.notes ||
        reminderDateKeyOrNull(_reminder) != existing.reminderDate;
  }

  Future<void> _requestLeave() async {
    if (!_dirty) {
      Navigator.of(context).pop();
      return;
    }
    if (_title.text.trim().isEmpty) {
      await _message('Missing Information', 'Title is mandatory.');
      return;
    }
    final save = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Do you want to save?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Yes'),
            ),
          ],
        );
      },
    );
    if (!mounted || save == null) return;
    if (!save) {
      _leaveToList();
      return;
    }
    await _saveAndLeave();
  }

  Future<void> _saveAndLeave() async {
    if (_saving) return;
    if (noteSaveBlock(title: _title.text) == NoteSaveBlock.missingTitle) {
      await _message('Missing Information', 'Title is mandatory.');
      return;
    }

    final now = DateTime.now().toUtc();
    final existing = widget.existing;
    final item = VaultItem(
      id: existing?.id ?? newVaultItemId(),
      type: VaultItemType.secret,
      title: _title.text.trim(),
      username: '',
      password: '',
      notes: _notes.text,
      reminderDate: reminderDateKeyOrNull(_reminder),
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    _saving = true;
    try {
      await VaultScope.of(context).saveItem(item);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save this secure note on the phone.'),
        ),
      );
      return;
    } finally {
      _saving = false;
    }
    if (!mounted) return;
    _leaveToList();
  }

  void _leaveToList() {
    setState(() => _leaving = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    });
  }

  Future<void> _message(String title, String body) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _toggleReminder(bool on) async {
    if (!on) {
      setState(() => _reminder = null);
      return;
    }
    final allowed = await VaultScope.of(context).reminders.ensurePermission();
    if (!mounted) return;
    if (!allowed) {
      setState(() => _reminder = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Notifications are off in phone settings.'),
        ),
      );
      return;
    }
    setState(() => _picking = true);
    final picked = await showReminderCalendar(context: context);
    if (!mounted) return;
    setState(() {
      _picking = false;
      _reminder = picked;
    });
  }

  Future<void> _changeDate() async {
    final picked = await showReminderCalendar(
      context: context,
      selected: _reminder,
    );
    if (!mounted || picked == null) return;
    setState(() => _reminder = picked);
  }

  @override
  Widget build(BuildContext context) {
    final reminder = _reminder;
    return PopScope(
      canPop: _leaving || !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _requestLeave();
      },
      child: AuthScaffold(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            children: [
              Row(
                children: [
                  StickerIconButton(
                    tooltip: 'Back',
                    icon: Icons.arrow_back_rounded,
                    onPressed: _requestLeave,
                  ),
                  const Spacer(),
                  TextButton(
                    key: const Key('note-save'),
                    onPressed: _saving ? null : _saveAndLeave,
                    child: const Text(
                      'Save',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: VaultColors.pink,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context)
                      .copyWith(scrollbars: false),
                  child: ListView(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const VaultKindIcon(
                            type: VaultItemType.secret,
                            size: 56,
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: _titleField()),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _label('Note'),
                      const SizedBox(height: 8),
                      TextField(
                        key: const Key('note-body'),
                        controller: _notes,
                        minLines: 4,
                        maxLines: 8,
                        cursorColor: VaultColors.pink,
                        style: _valueStyle,
                        decoration: _inputDecoration('Note'),
                      ),
                      const SizedBox(height: 18),
                      _label('Notification'),
                      const SizedBox(height: 8),
                      const Text(
                        secureNoteReminderHelp,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.35,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Reminder',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Switch(
                            key: const Key('note-reminder'),
                            value: reminder != null || _picking,
                            onChanged: _saving || _picking
                                ? null
                                : _toggleReminder,
                          ),
                        ],
                      ),
                      if (reminder != null)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            key: const Key('note-reminder-line'),
                            onPressed: _changeDate,
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              alignment: Alignment.centerLeft,
                              foregroundColor: VaultColors.ink,
                            ),
                            child: Text(
                              reminderTriggerLine(reminder),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _titleField() {
    return TextField(
      key: const Key('note-title'),
      controller: _title,
      cursorColor: VaultColors.pink,
      style: const TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: VaultColors.ink,
      ),
      decoration: _inputDecoration('Title').copyWith(
        hintStyle: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: Color(0xFFB89BC4),
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: VaultColors.grape,
      ),
    );
  }
}

String? reminderDateKeyOrNull(DateTime? day) {
  if (day == null) return null;
  return reminderDateKey(day);
}

const _valueStyle = TextStyle(
  fontSize: 18,
  fontWeight: FontWeight.w500,
  color: VaultColors.ink,
);

InputDecoration _inputDecoration(String hint) {
  return InputDecoration(
    filled: true,
    fillColor: Colors.white,
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xFFB89BC4), fontSize: 16),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    enabledBorder: _border(VaultColors.ink),
    focusedBorder: _border(VaultColors.pink),
  );
}

OutlineInputBorder _border(Color color) {
  return OutlineInputBorder(
    borderRadius: BorderRadius.circular(18),
    borderSide: BorderSide(color: color, width: 2.5),
  );
}
