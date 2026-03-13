import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:routine/atividades/atividade.dart';

class CalendarHeaderHistory extends StatefulWidget {
  const CalendarHeaderHistory({
    super.key,
    required this.selectedDate,
    required this.onDateSelected,
    required this.atividades,
    required this.availableYears,
    this.onAdd,
    this.onDistribuir,
  });

  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;
  final VoidCallback? onAdd;
  final List<Atividade> atividades;
  final VoidCallback? onDistribuir;
  final List<String> availableYears;

  @override
  State<CalendarHeaderHistory> createState() => _CalendarHeaderHistoryState();
}

class _CalendarHeaderHistoryState extends State<CalendarHeaderHistory> {
  late DateFormat dayNameFormat;
  late String _selectedYear;
  late String _selectedMonth;
  late List<String> _availableMonths;
  final Map<String, int> _monthNameToNumber = {};

  @override
  void initState() {
    super.initState();
    _selectedYear = widget.selectedDate.year.toString();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locale = Localizations.localeOf(context).languageCode;
    dayNameFormat = DateFormat.E(locale);

    _monthNameToNumber.clear();
    _availableMonths = List.generate(12, (index) {
      final monthDate = DateTime(DateTime.now().year, index + 1, 1);
      final monthName = DateFormat.MMM(locale).format(monthDate);
      _monthNameToNumber[monthName] = index + 1;
      return monthName;
    });

    _selectedMonth = DateFormat.MMM(locale).format(widget.selectedDate);
    _syncSelectedYear(widget.selectedDate.year.toString());
  }

  @override
  void didUpdateWidget(covariant CalendarHeaderHistory oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedDate != oldWidget.selectedDate ||
        widget.availableYears != oldWidget.availableYears) {
      final locale = Localizations.localeOf(context).languageCode;
      _selectedMonth = DateFormat.MMM(locale).format(widget.selectedDate);
      _syncSelectedYear(widget.selectedDate.year.toString());
    }
  }

  List<String> _yearOptions() {
    final dedup = widget.availableYears.toSet().toList();
    dedup.sort();
    return dedup;
  }

  void _syncSelectedYear(String preferredYear) {
    final options = _yearOptions();
    if (options.isEmpty) {
      _selectedYear = preferredYear;
      return;
    }
    if (options.contains(preferredYear)) {
      _selectedYear = preferredYear;
      return;
    }
    if (options.contains(_selectedYear)) return;
    _selectedYear = options.first;
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
    final newDate = widget.selectedDate.add(Duration(days: 7 * offset));
    widget.onDateSelected(newDate);
  }

  void _updateDate(int? year, int? month) {
    if (year == null || month == null) return;
    final currentDay = widget.selectedDate.day;
    final lastDayOfMonth = DateTime(year, month + 1, 0).day;
    final newDay = currentDay > lastDayOfMonth ? lastDayOfMonth : currentDay;
    widget.onDateSelected(DateTime(year, month, newDay));
  }

  @override
  Widget build(BuildContext context) {
    final weekDates = _getWeekDates(widget.selectedDate);
    final yearOptions = _yearOptions();
    final yearValue =
        yearOptions.contains(_selectedYear) ? _selectedYear : null;
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Ano',
                        ),
                        value: yearValue,
                        items: yearOptions
                            .map(
                              (year) => DropdownMenuItem(
                                value: year,
                                child: Text(year),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _selectedYear = value);
                          _updateDate(
                            int.tryParse(_selectedYear),
                            _monthNameToNumber[_selectedMonth],
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Mes',
                        ),
                        value: _selectedMonth,
                        items: _availableMonths
                            .map(
                              (month) => DropdownMenuItem(
                                value: month,
                                child: Text(month),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _selectedMonth = value);
                          _updateDate(
                            int.tryParse(_selectedYear),
                            _monthNameToNumber[_selectedMonth],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                icon: const Icon(Icons.refresh),
                onPressed: () => widget.onDateSelected(DateTime.now()),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _changeWeek(-1),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => _changeWeek(1),
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
              final count = _countActivitiesFor(date);

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: GestureDetector(
                    onTap: () => widget.onDateSelected(date),
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
                            opacity: count > 0 ? 1 : 0.25,
                            child: Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: count > 0
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
