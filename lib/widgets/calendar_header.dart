import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:routine/atividades/atividade.dart';


class CalendarHeader extends StatefulWidget {
  final DateTime selectedDate;
  final Function(DateTime) onDateSelected;
  final VoidCallback? onAdd;
  final List<Atividade> atividades;
  final VoidCallback? onDistribuir;

  const CalendarHeader({
    super.key,
    required this.selectedDate,
    required this.onDateSelected,
    this.onAdd,
    required this.atividades,
    this.onDistribuir,
  });

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
  void didChangeDependencies() {
    super.didChangeDependencies();
    monthFormat = DateFormat.MMMM(Localizations.localeOf(context).languageCode);
    dayNameFormat = DateFormat.E(Localizations.localeOf(context).languageCode);
  }

  List<DateTime> _getWeekDates(DateTime date) {
    final firstDayOfWeek = date.subtract(Duration(days: date.weekday - 1));
    return List.generate(7, (i) => firstDayOfWeek.add(Duration(days: i)));
  }

  void _changeWeek(int offset) {
    setState(() {
      currentDate = currentDate.add(Duration(days: 7 * offset));
      widget.onDateSelected(currentDate);
    });
  }

  @override
  Widget build(BuildContext context) {
    final weekDates = _getWeekDates(currentDate);
    final monthName = monthFormat.format(currentDate).toUpperCase();

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(15, 0, 15, 0),
          child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () {
                      showDatePicker(
                        context: context,
                        initialDate: currentDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      ).then((picked) {
                        if (picked != null) {
                          setState(() {
                            currentDate = picked;
                            widget.onDateSelected(picked);
                          });
                        }
                      });
                    },
                    child: Text(
                      monthName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: Icon(
                      Icons.refresh,
                      color: Colors.green.shade700,
                      size: 28,
                    ),
                    onPressed: () {
                      final today = DateTime.now();
                      setState(() {
                        currentDate = today;
                      });
                      widget.onDateSelected(today);
                    },
                  ),
                  Row(
                    children: [
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
                  IconButton(
                    onPressed: widget.onAdd,
                    icon: const Icon(Icons.edit_calendar, color: Colors.green),
                  )
                ],
              ),
              
          ),

          
              // Dias da semana
              Container(
                margin: EdgeInsets.fromLTRB(10, 0, 10, 0), // left, top, right, bottom
                child: Row(
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
                                dayName[0].toUpperCase()+dayName.substring(1).toLowerCase(),
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
              ),
            
          ]
        );
      
    
  }
}