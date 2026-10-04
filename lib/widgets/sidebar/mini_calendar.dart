import 'package:flutter/material.dart';

import '../../theme/nocturne_theme.dart';

const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];
const _weekdayLabels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

/// The sidebar's month grid: today is a filled accent circle, a different
/// selected day gets an accent ring, and every cell navigates to the Day
/// view for that date on tap.
class MiniCalendar extends StatelessWidget {
  const MiniCalendar({
    super.key,
    required this.month,
    required this.selectedDay,
    required this.onDayTap,
  });

  final DateTime month;
  final DateTime? selectedDay;
  final ValueChanged<DateTime> onDayTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.nocturne;
    final accent = context.nocturneAccent;
    final today = DateTime.now();
    final firstOfMonth = DateTime(month.year, month.month, 1);
    final startOffset = firstOfMonth.weekday % 7;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;

    bool isSameDay(DateTime a, DateTime b) =>
        a.year == b.year && a.month == b.month && a.day == b.day;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '${_monthNames[month.month - 1]} ${month.year}',
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 0.06,
                fontWeight: FontWeight.w500,
                color: tokens.neutral500,
              ),
            ),
          ),
          Row(
            children: [
              for (final label in _weekdayLabels)
                Expanded(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 10, color: tokens.neutral500),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 3,
              crossAxisSpacing: 3,
              childAspectRatio: 1.6,
            ),
            itemCount: startOffset + daysInMonth,
            itemBuilder: (context, index) {
              if (index < startOffset) return const SizedBox.shrink();
              final day = index - startOffset + 1;
              final date = DateTime(month.year, month.month, day);
              final isToday = isSameDay(date, today);
              final isSelected = selectedDay != null
                  ? isSameDay(date, selectedDay!)
                  : false;

              return InkWell(
                onTap: () => onDayTap(date),
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isToday ? accent : null,
                    shape: BoxShape.circle,
                    border: (!isToday && isSelected)
                        ? Border.all(color: accent)
                        : null,
                  ),
                  child: Text(
                    '$day',
                    style: TextStyle(
                      fontSize: 11,
                      color: isToday
                          ? Colors.white
                          : (isSelected ? accent : tokens.neutral300),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
