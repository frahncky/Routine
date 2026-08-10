import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:routine/atividades/atividade.dart';

/// Cabeçalho de calendário semanal, usado tanto na Home (mês + navegação +
/// botão de adicionar) quanto no Histórico (`showMonthYearPicker: true`,
/// seletores de ano/mês em vez de nome do mês/botão de adicionar) — as duas
/// telas compartilham a mesma tira de 7 dias.
class CalendarHeader extends StatefulWidget {
  const CalendarHeader({
    super.key,
    required this.selectedDate,
    required this.onDateSelected,
    required this.atividades,
    this.onAdd,
    this.onDistribuir,
    this.showMonthYearPicker = false,
    this.availableYears = const [],
  });

  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;
  final VoidCallback? onAdd;
  final List<Atividade> atividades;
  final VoidCallback? onDistribuir;
  final bool showMonthYearPicker;
  final List<String> availableYears;

  @override
  State<CalendarHeader> createState() => _CalendarHeaderState();
}

class _CalendarHeaderState extends State<CalendarHeader> {
  late DateTime currentDate;
  late DateFormat monthFormat;
  late DateFormat dayNameFormat;
  late String _selectedYear;
  late String _selectedMonth;
  late List<String> _availableMonths;
  final Map<String, int> _monthNameToNumber = {};

  @override
  void initState() {
    super.initState();
    currentDate = widget.selectedDate;
    _selectedYear = widget.selectedDate.year.toString();
  }

  @override
  void didUpdateWidget(covariant CalendarHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    final dateChanged = widget.selectedDate != oldWidget.selectedDate;
    if (dateChanged) {
      currentDate = widget.selectedDate;
    }
    if (widget.showMonthYearPicker &&
        (dateChanged || widget.availableYears != oldWidget.availableYears)) {
      final locale = Localizations.localeOf(context).languageCode;
      _selectedMonth = DateFormat.MMM(locale).format(widget.selectedDate);
      _syncSelectedYear(widget.selectedDate.year.toString());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locale = Localizations.localeOf(context).languageCode;
    monthFormat = DateFormat.MMMM(locale);
    dayNameFormat = DateFormat.E(locale);

    if (widget.showMonthYearPicker) {
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

  void _selectDate(DateTime date) {
    setState(() => currentDate = date);
    widget.onDateSelected(date);
  }

  void _changeWeek(int offset) {
    _selectDate(currentDate.add(Duration(days: 7 * offset)));
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: currentDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    _selectDate(picked);
  }

  void _updateDate(int? year, int? month) {
    if (year == null || month == null) return;
    final currentDay = currentDate.day;
    final lastDayOfMonth = DateTime(year, month + 1, 0).day;
    final newDay = currentDay > lastDayOfMonth ? lastDayOfMonth : currentDay;
    _selectDate(DateTime(year, month, newDay));
  }

  Widget _buildMonthHeaderRow(ColorScheme scheme) {
    final monthName =
        toBeginningOfSentenceCase(monthFormat.format(currentDate));
    return Row(
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
                      style:
                          Theme.of(context).textTheme.titleLarge?.copyWith(
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
          onPressed: () => _selectDate(DateTime.now()),
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
    );
  }

  Widget _buildYearMonthPickerRow() {
    final yearOptions = _yearOptions();
    final yearValue =
        yearOptions.contains(_selectedYear) ? _selectedYear : null;
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Ano',
                  ),
                  initialValue: yearValue,
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
                  initialValue: _selectedMonth,
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
          onPressed: () => _selectDate(DateTime.now()),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final weekDates = _getWeekDates(currentDate);
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
          widget.showMonthYearPicker
              ? _buildYearMonthPickerRow()
              : _buildMonthHeaderRow(scheme),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: weekDates.map((date) {
              final isSelected =
                  DateUtils.isSameDay(date, widget.selectedDate);
              final dayName = dayNameFormat.format(date);
              final dayNumber = date.day;
              final activityCount = _countActivitiesFor(date);

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: GestureDetector(
                    onTap: () => _selectDate(date),
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
