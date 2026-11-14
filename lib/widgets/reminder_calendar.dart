import 'package:flutter/material.dart';
import 'package:myvault/data/reminder_date.dart';
import 'package:myvault/theme/vault_theme.dart';

const _monthSpan = 60;

Future<DateTime?> showReminderCalendar({
  required BuildContext context,
  DateTime? selected,
  DateTime? today,
}) {
  return showDialog<DateTime>(
    context: context,
    barrierDismissible: true,
    builder: (context) {
      return ReminderCalendar(
        today: today ?? DateTime.now(),
        selected: selected,
      );
    },
  );
}

class ReminderCalendar extends StatefulWidget {
  const ReminderCalendar({required this.today, this.selected, super.key});

  final DateTime today;
  final DateTime? selected;

  @override
  State<ReminderCalendar> createState() => _ReminderCalendarState();
}

class _ReminderCalendarState extends State<ReminderCalendar> {
  late final PageController _page;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = _openingPage();
    _page = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  int _openingPage() {
    final selected = widget.selected;
    if (selected == null) return 0;
    final diff =
        (selected.year - widget.today.year) * 12 +
        selected.month -
        widget.today.month;
    if (diff < 0) return 0;
    if (diff >= _monthSpan) return _monthSpan - 1;
    return diff;
  }

  DateTime _monthAt(int index) {
    return DateTime(widget.today.year, widget.today.month + index);
  }

  Future<void> _shift(int delta) async {
    final next = _index + delta;
    if (next < 0 || next >= _monthSpan) return;
    await _page.animateToPage(
      next,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final month = _monthAt(_index);
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: VaultColors.ink, width: 3),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton(
                  key: const Key('reminder-prev-month'),
                  tooltip: 'Previous month',
                  onPressed: _index == 0 ? null : () => _shift(-1),
                  icon: const Icon(Icons.chevron_left_rounded),
                  color: VaultColors.ink,
                ),
                Expanded(
                  child: Text(
                    reminderMonthTitle(month),
                    key: const Key('reminder-month'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('reminder-next-month'),
                  tooltip: 'Next month',
                  onPressed: _index == _monthSpan - 1 ? null : () => _shift(1),
                  icon: const Icon(Icons.chevron_right_rounded),
                  color: VaultColors.ink,
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Row(
              children: [
                _Weekday('Mon'),
                _Weekday('Tue'),
                _Weekday('Wed'),
                _Weekday('Thu'),
                _Weekday('Fri'),
                _Weekday('Sat'),
                _Weekday('Sun'),
              ],
            ),
            const SizedBox(height: 4),
            SizedBox(
              key: const Key('reminder-pages'),
              height: 288,
              child: PageView.builder(
                controller: _page,
                itemCount: _monthSpan,
                onPageChanged: (index) => setState(() => _index = index),
                itemBuilder: (context, index) {
                  return _MonthGrid(
                    month: _monthAt(index),
                    today: widget.today,
                    selected: widget.selected,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Weekday extends StatelessWidget {
  const _Weekday(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: VaultColors.grape,
        ),
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.today,
    required this.selected,
  });

  final DateTime month;
  final DateTime today;
  final DateTime? selected;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month);
    final lead = first.weekday - DateTime.monday;
    final count = DateTime(month.year, month.month + 1, 0).day;
    final cells = lead + count;
    final rows = (cells / 7).ceil();
    return Column(
      children: [
        for (var row = 0; row < rows; row++)
          Expanded(
            child: Row(
              children: [
                for (var column = 0; column < 7; column++)
                  Expanded(
                    child: _cell(context, row * 7 + column - lead, count),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _cell(BuildContext context, int dayNumber, int count) {
    if (dayNumber < 1 || dayNumber > count) return const SizedBox.shrink();
    final day = DateTime(month.year, month.month, dayNumber);
    final enabled = reminderDayEnabled(day, today);
    final isToday = reminderIsToday(day, today);
    final isSelected =
        selected != null &&
        selected!.year == day.year &&
        selected!.month == day.month &&
        selected!.day == day.day;
    final fill = isSelected ? VaultColors.pink : Colors.transparent;
    final textColor = !enabled
        ? const Color(0xFFCBB8D6)
        : isSelected
        ? Colors.white
        : VaultColors.ink;
    return InkWell(
      key: Key('reminder-day-${reminderDateKey(day)}'),
      customBorder: const CircleBorder(),
      onTap: enabled
          ? () => Navigator.pop(context, DateTime(day.year, day.month, day.day))
          : null,
      child: Center(
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: fill,
            border: isToday
                ? Border.all(
                    color: isSelected ? Colors.white : VaultColors.pink,
                    width: 2,
                  )
                : null,
          ),
          child: Text(
            '$dayNumber',
            style: TextStyle(fontWeight: FontWeight.w700, color: textColor),
          ),
        ),
      ),
    );
  }
}
