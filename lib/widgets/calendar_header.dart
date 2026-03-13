import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:routine/atividades/atividade.dart';

class CalendarHeader extends StatefulWidget {
  const CalendarHeader({
    super.key,
    required this.selectedDate,
    required this.onDateSelected,
    required this.atividades,
    this.onAdd,
    this.onDistribuir,
  });

  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;
  final VoidCallback? onAdd;
  final List<Atividade> atividades;
  final VoidCallback? onDistribuir;

  @override
  State<CalendarHeader> createState() => _CalendarHeaderState();
}

class _CalendarHeaderState extends State<CalendarHeader> {
  late DateTime currentDate;
  late DateFormat monthFormat;
  late DateFormat dayNameFormat;

  @override
  void initState() {
    super.initState();
    currentDate = widget.selectedDate;
  }

  @override
  void didUpdateWidget(covariant CalendarHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedDate != oldWidget.selectedDate) {
      currentDate = widget.selectedDate;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locale = Localizations.localeOf(context).languageCode;
    monthFormat = DateFormat.MMMM(locale);
    dayNameFormat = DateFormat.E(locale);
  }

  List<DateTime> _getWeekDates(DateTime date) {
    final firstDayOfWeek = date.subtract(Duration(days: date.weekday - 1));
    return List.generate(7, (i) => firstDayOfWeek.add(Duration(days: i)));
  }

  int _countActivitiesFor(DateTime day) {
    return widget.atividades.where((a) {
      return a.data.year == day.year &&
          a.data.month == day.month &&
          a.data.day == day.day;
    }).length;
  }

  void _changeWeek(int offset) {
    final next = currentDate.add(Duration(days: 7 * offset));
    setState(() => currentDate = next);
    widget.onDateSelected(next);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: currentDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() => currentDate = picked);
    widget.onDateSelected(picked);
  }

  @override
  Widget build(BuildContext context) {
    final weekDates = _getWeekDates(currentDate);
    final monthName = toBeginningOfSentenceCase(monthFormat.format(currentDate));
    final scheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _pickDate,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_month, color: scheme.primary),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            monthName,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontSize: 22,
                                ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              IconButton.filledTonal(
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  final today = DateTime.now();
                  setState(() => currentDate = today);
                  widget.onDateSelected(today);
                },
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _changeWeek(-1),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => _changeWeek(1),
              ),
              const SizedBox(width: 4),
              IconButton.filled(
                onPressed: widget.onAdd,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: weekDates.map((date) {
              final isSelected = DateUtils.isSameDay(date, widget.selectedDate);
              final dayName = dayNameFormat.format(date);
              final dayNumber = date.day;
              final activityCount = _countActivitiesFor(date);

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: GestureDetector(
                    onTap: () {
                      setState(() => currentDate = date);
                      widget.onDateSelected(date);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 240),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        gradient: isSelected
                            ? LinearGradient(
                                colors: [
                                  scheme.primary.withValues(alpha: 0.16),
                                  scheme.secondary.withValues(alpha: 0.10),
                                ],
                              )
                            : null,
                        color: isSelected ? null : scheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? scheme.primary.withValues(alpha: 0.4)
                              : scheme.primary.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            dayName[0].toUpperCase() +
                                dayName.substring(1).toLowerCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isSelected
                                  ? scheme.primary
                                  : Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$dayNumber',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: isSelected
                                  ? scheme.primary
                                  : scheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          AnimatedOpacity(
                            duration: const Duration(milliseconds: 200),
                            opacity: activityCount > 0 ? 1 : 0.25,
                            child: Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: activityCount > 0
                                    ? scheme.secondary
                                    : Colors.transparent,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
