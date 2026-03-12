import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:routine/atividades/atividade.dart';

class CalendarHeaderHistory extends StatefulWidget {
  final DateTime selectedDate;
  final Function(DateTime) onDateSelected;
  final VoidCallback? onAdd;
  final List<Atividade> atividades;
  final VoidCallback? onDistribuir;
  final List<String> availableYears;

  const CalendarHeaderHistory({
    super.key,
    required this.selectedDate,
    required this.onDateSelected,
    this.onAdd,
    required this.atividades,
    this.onDistribuir,
    required this.availableYears,
  });

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
    if (options.contains(_selectedYear)) {
      return;
    }
    _selectedYear = options.first;
  }

  List<DateTime> _getWeekDates(DateTime date) {
    final firstDayOfWeek = date.subtract(Duration(days: date.weekday - 1));
    return List.generate(7, (i) => firstDayOfWeek.add(Duration(days: i)));
  }

  void _changeWeek(int offset) {
    final newDate = widget.selectedDate.add(Duration(days: 7 * offset));
    widget.onDateSelected(newDate);
  }

  void _updateDate(int? year, int? month) {
    if (year != null && month != null) {
      final currentDay = widget.selectedDate.day;
      final lastDayOfMonth = DateTime(year, month + 1, 0).day;
      final newDay = currentDay > lastDayOfMonth ? lastDayOfMonth : currentDay;

      final newDate = DateTime(year, month, newDay);
      widget.onDateSelected(newDate);
    }
  }

  @override
  Widget build(BuildContext context) {
    final weekDates = _getWeekDates(widget.selectedDate);
    final yearOptions = _yearOptions();
    final yearValue = yearOptions.contains(_selectedYear) ? _selectedYear : null;

    return Container(
      margin: const EdgeInsets.fromLTRB(15, 0, 15, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Ano',
                          border: OutlineInputBorder(),
                          isDense: true,
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                          if (value != null) {
                            setState(() {
                              _selectedYear = value;
                            });
                            _updateDate(
                              int.tryParse(_selectedYear),
                              _monthNameToNumber[_selectedMonth],
                            );
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Mês',
                          border: OutlineInputBorder(),
                          isDense: true,
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                          if (value != null) {
                            setState(() {
                              _selectedMonth = value;
                            });
                            _updateDate(
                              int.tryParse(_selectedYear),
                              _monthNameToNumber[_selectedMonth],
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.refresh,
                      color: Colors.green.shade700,
                      size: 28,
                    ),
                    onPressed: () {
                      final today = DateTime.now();
                      widget.onDateSelected(today);
                    },
                  ),
                  const SizedBox(width: 8),
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
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: weekDates.map((date) {
              final isSelected = DateUtils.isSameDay(date, widget.selectedDate);
              final dayName = dayNameFormat.format(date);
              final dayNumber = date.day;

              return Expanded(
                child: GestureDetector(
                  onTap: () => widget.onDateSelected(date),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
                    decoration: isSelected
                        ? BoxDecoration(
                            color: Colors.indigo.shade100,
                            borderRadius: BorderRadius.circular(12),
                          )
                        : null,
                    child: Column(
                      children: [
                        Text(
                          dayName[0].toUpperCase() +
                              dayName.substring(1).toLowerCase(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? Colors.indigo : Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$dayNumber',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.indigo : Colors.black,
                          ),
                        ),
                      ],
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
