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
  late DateFormat fullDateFormat;
  late String _selectedYear;
  late String _selectedMonth;
  late List<String> _availableMonths;
  final Map<String, int> _monthNameToNumber = {};
  final ScrollController _weekScrollController = ScrollController();
  DateTime? _lastCenteredDate;
  double? _lastCenteredViewportWidth;

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
    fullDateFormat = DateFormat.yMMMMEEEEd(locale);

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

  @override
  void dispose() {
    _weekScrollController.dispose();
    super.dispose();
  }

  String _localized(String portuguese, String english) =>
      Localizations.localeOf(context).languageCode == 'pt'
          ? portuguese
          : english;

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

    Widget buildMonthPicker() => Semantics(
          button: true,
          label: fullDateFormat.format(currentDate),
          hint: _localized('Abrir seletor de data', 'Open date picker'),
          onTap: _pickDate,
          child: ExcludeSemantics(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _pickDate,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: scheme.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Icon(
                          Icons.calendar_month_rounded,
                          size: 20,
                          color: scheme.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          monthName,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );

    // Rodapé mais compacto (padding/tamanho mínimo/densidade reduzidos) para
    // que os 4 botões caibam ao lado do nome do mês em vez de empurrar uma
    // segunda linha — deixa o card mais baixo na Home. `visualDensity` é
    // necessário além de `padding`/`constraints` porque o tamanho mínimo de
    // área de toque (48dp) do Material é aplicado por fora do estilo do
    // botão e não encolhe só com padding/constraints menores.
    const compactPadding = EdgeInsets.all(6);
    const compactConstraints = BoxConstraints(minWidth: 36, minHeight: 36);
    const compactDensity = VisualDensity.compact;

    List<Widget> buildActions() => [
          IconButton.filledTonal(
            tooltip: _localized('Ir para hoje', 'Go to today'),
            icon: const Icon(Icons.today_outlined),
            onPressed: () => _selectDate(DateTime.now()),
            padding: compactPadding,
            constraints: compactConstraints,
            visualDensity: compactDensity,
          ),
          IconButton(
            tooltip: _localized('Semana anterior', 'Previous week'),
            icon: const Icon(Icons.chevron_left),
            onPressed: () => _changeWeek(-1),
            padding: compactPadding,
            constraints: compactConstraints,
            visualDensity: compactDensity,
          ),
          IconButton(
            tooltip: _localized('Próxima semana', 'Next week'),
            icon: const Icon(Icons.chevron_right),
            onPressed: () => _changeWeek(1),
            padding: compactPadding,
            constraints: compactConstraints,
            visualDensity: compactDensity,
          ),
          IconButton.filled(
            tooltip: _localized('Adicionar atividade', 'Add activity'),
            onPressed: widget.onAdd,
            icon: const Icon(Icons.add_rounded),
            padding: compactPadding,
            constraints: compactConstraints,
            visualDensity: compactDensity,
          ),
        ];

    return LayoutBuilder(
      builder: (context, constraints) {
        // Só empilha em Column em larguras realmente extremas (ex.: split
        // screen no Android). Em telas de celular normais os botões cabem
        // ao lado do nome do mês (ver compactPadding/compactConstraints
        // acima), deixando o card mais baixo.
        if (constraints.maxWidth < 220) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              buildMonthPicker(),
              // Wrap em vez de Row: em larguras abaixo de ~208dp (fora do
              // que qualquer celular/split-screen real usa) os 4 botões não
              // caberiam nem numa linha só; Wrap evita overflow quebrando
              // para uma segunda linha em vez de estourar a tela.
              Wrap(
                alignment: WrapAlignment.end,
                runSpacing: 4,
                children: buildActions(),
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: buildMonthPicker()),
            ...buildActions(),
          ],
        );
      },
    );
  }

  Widget _buildYearMonthPickerRow() {
    final yearOptions = _yearOptions();
    final yearValue =
        yearOptions.contains(_selectedYear) ? _selectedYear : null;

    Widget buildYearField() => DropdownButtonFormField<String>(
          decoration: InputDecoration(
            labelText: _localized('Ano', 'Year'),
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
        );

    Widget buildMonthField() => DropdownButtonFormField<String>(
          decoration: InputDecoration(
            labelText: _localized('Mês', 'Month'),
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
        );

    Widget buildPickers(double availableWidth) {
      if (availableWidth < 280) {
        return Column(
          children: [
            buildYearField(),
            const SizedBox(height: 8),
            buildMonthField(),
          ],
        );
      }
      return Row(
        children: [
          Expanded(child: buildYearField()),
          const SizedBox(width: 8),
          Expanded(child: buildMonthField()),
        ],
      );
    }

    List<Widget> buildActions() => [
          IconButton.filledTonal(
            tooltip: _localized('Ir para hoje', 'Go to today'),
            icon: const Icon(Icons.refresh),
            onPressed: () => _selectDate(DateTime.now()),
          ),
          IconButton(
            tooltip: _localized('Semana anterior', 'Previous week'),
            icon: const Icon(Icons.chevron_left),
            onPressed: () => _changeWeek(-1),
          ),
          IconButton(
            tooltip: _localized('Próxima semana', 'Next week'),
            icon: const Icon(Icons.chevron_right),
            onPressed: () => _changeWeek(1),
          ),
        ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 348) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              buildPickers(constraints.maxWidth),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: buildActions(),
              ),
            ],
          );
        }

        const actionsWidth = 144.0;
        const gap = 8.0;
        return Row(
          children: [
            Expanded(
              child: buildPickers(
                constraints.maxWidth - actionsWidth - gap,
              ),
            ),
            const SizedBox(width: gap),
            ...buildActions(),
          ],
        );
      },
    );
  }

  void _centerSelectedDay(
    List<DateTime> weekDates,
    double viewportWidth,
  ) {
    final selectedIndex = weekDates.indexWhere(
      (date) => DateUtils.isSameDay(date, widget.selectedDate),
    );
    if (selectedIndex < 0) return;

    final selectedDate = DateUtils.dateOnly(widget.selectedDate);
    if (DateUtils.isSameDay(_lastCenteredDate, selectedDate) &&
        _lastCenteredViewportWidth == viewportWidth) {
      return;
    }
    _lastCenteredDate = selectedDate;
    _lastCenteredViewportWidth = viewportWidth;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_weekScrollController.hasClients) return;
      const dayExtent = 48.0;
      final requestedOffset =
          selectedIndex * dayExtent - (viewportWidth - dayExtent) / 2;
      final targetOffset = requestedOffset
          .clamp(0.0, _weekScrollController.position.maxScrollExtent)
          .toDouble();
      _weekScrollController.jumpTo(targetOffset);
    });
  }

  Widget _buildDayTarget({
    required DateTime date,
    required bool isSelected,
    required int activityCount,
    required ColorScheme scheme,
  }) {
    final dayName = dayNameFormat.format(date);
    final isToday = DateUtils.isSameDay(date, DateTime.now());
    final countLabel = activityCount == 0
        ? _localized('Nenhuma atividade', 'No activities')
        : activityCount == 1
            ? _localized('1 atividade', '1 activity')
            : _localized(
                '$activityCount atividades',
                '$activityCount activities',
              );

    return Semantics(
      button: true,
      selected: isSelected,
      label: fullDateFormat.format(date),
      value: countLabel,
      hint: _localized('Selecionar data', 'Select date'),
      onTap: () => _selectDate(date),
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _selectDate(date),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              constraints: const BoxConstraints(minHeight: 52),
              margin: const EdgeInsets.symmetric(horizontal: 2),
              padding: const EdgeInsets.symmetric(vertical: 5),
              decoration: BoxDecoration(
                color: isSelected ? scheme.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: scheme.primary.withValues(alpha: 0.18),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    dayName[0].toUpperCase() +
                        dayName.substring(1).toLowerCase(),
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? scheme.onPrimary.withValues(alpha: 0.82)
                          : isToday
                              ? scheme.primary
                              : scheme.onSurface.withValues(alpha: 0.62),
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '${date.day}',
                    style: TextStyle(
                      fontSize: 16.5,
                      height: 1.1,
                      fontWeight: FontWeight.w800,
                      color: isSelected
                          ? scheme.onPrimary
                          : isToday
                              ? scheme.primary
                              : scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 3),
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 180),
                    opacity: activityCount > 0 ? 1 : 0,
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isSelected ? scheme.onPrimary : scheme.secondary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWeekStrip(
    List<DateTime> weekDates,
    ColorScheme scheme,
  ) {
    const minimumDayExtent = 48.0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(17),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          Widget buildDay(DateTime date) => _buildDayTarget(
                date: date,
                isSelected: DateUtils.isSameDay(date, widget.selectedDate),
                activityCount: _countActivitiesFor(date),
                scheme: scheme,
              );

          if (constraints.maxWidth >= minimumDayExtent * weekDates.length) {
            _lastCenteredDate = null;
            _lastCenteredViewportWidth = null;
            return Row(
              children: weekDates
                  .map((date) => Expanded(child: buildDay(date)))
                  .toList(),
            );
          }

          _centerSelectedDay(weekDates, constraints.maxWidth);
          return SingleChildScrollView(
            controller: _weekScrollController,
            scrollDirection: Axis.horizontal,
            child: Row(
              children: weekDates
                  .map(
                    (date) => SizedBox(
                      width: minimumDayExtent,
                      child: buildDay(date),
                    ),
                  )
                  .toList(),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final weekDates = _getWeekDates(currentDate);
    final scheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.055),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          widget.showMonthYearPicker
              ? _buildYearMonthPickerRow()
              : _buildMonthHeaderRow(scheme),
          const SizedBox(height: 6),
          _buildWeekStrip(weekDates, scheme),
        ],
      ),
    );
  }
}
