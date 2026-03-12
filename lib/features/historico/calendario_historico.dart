import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:routine/atividades/atividade.dart';


class CalendarHeaderHistory extends StatefulWidget {
 final DateTime selectedDate;
 final Function(DateTime) onDateSelected;
 final VoidCallback? onAdd;
 final List<Atividade> atividades; // Note: This list is received but not used within this widget's build method in the provided code.
 final VoidCallback? onDistribuir; // Note: This callback is received but not used within this widget's build method in the provided code.
 final List<String> availableYears; // New parameter for available years


  CalendarHeaderHistory({
  super.key,
  required this.selectedDate,
  required this.onDateSelected,
  this.onAdd,
  required this.atividades, // Keep as required if parent uses it after callback
  this.onDistribuir, // Keep if parent uses it
  required this.availableYears, // Require available years
 });

 @override
 State<CalendarHeaderHistory> createState() => _CalendarHeaderHistoryState();
}

class _CalendarHeaderHistoryState extends State<CalendarHeaderHistory> {
 late DateFormat dayNameFormat;
 late String _selectedYear;
 late String _selectedMonth;
 late List<String> _availableMonths;


 // Mapping from abbreviated localized month names to their numerical representation.
 final Map<String, int> _monthNameToNumber = {};


 @override
 void initState() {
  super.initState();
  // Initialize selected year and month from the initially selected date
  _selectedYear = widget.selectedDate.year.toString();

 }

 @override
 void didChangeDependencies() {
  super.didChangeDependencies();
  final locale = Localizations.localeOf(context).languageCode;
  dayNameFormat = DateFormat.E(locale);

  // Generate localized month names and populate the mapping
  _availableMonths = List.generate(12, (index) {
   final monthDate = DateTime(DateTime.now().year, index + 1, 1);
   final monthName = DateFormat.MMM(locale).format(monthDate);
   _monthNameToNumber[monthName] = index + 1;
   return monthName;
  });

  // Initialize selected month after generating month names
  _selectedMonth = DateFormat.MMM(locale).format(widget.selectedDate);

 }

 @override
 void didUpdateWidget(covariant CalendarHeaderHistory oldWidget) {
  super.didUpdateWidget(oldWidget);
  // Update internal selected year and month if the selectedDate changes from parent
  if (widget.selectedDate != oldWidget.selectedDate) {
   final locale = Localizations.localeOf(context).languageCode;
   _selectedYear = widget.selectedDate.year.toString();
   _selectedMonth = DateFormat.MMM(locale).format(widget.selectedDate);
  }
 }


 List<DateTime> _getWeekDates(DateTime date) {
  // Ensure the week starts on Monday (weekday 1)
  final firstDayOfWeek = date.subtract(Duration(days: date.weekday - 1));
  return List.generate(7, (i) => firstDayOfWeek.add(Duration(days: i)));
 }

 void _changeWeek(int offset) {
  // Calculate the new date based on the current selected date
  final newDate = widget.selectedDate.add(Duration(days: 7 * offset));
  // Notify the parent widget of the new date
  widget.onDateSelected(newDate);
  // No need to call setState here as the parent will rebuild this widget
  // with the new selectedDate.
 }

 // Helper to create a new DateTime based on selected year, month, and current day
 void _updateDate(int? year, int? month) {
  if (year != null && month != null) {
   // Get the current day from the selectedDate
   final currentDay = widget.selectedDate.day;
   // Calculate the last day of the selected month/year
   final lastDayOfMonth = DateTime(year, month + 1, 0).day;
   // Ensure the new day is not beyond the last day of the month
   final newDay = currentDay > lastDayOfMonth ? lastDayOfMonth : currentDay;

   final newDate = DateTime(year, month, newDay);
   widget.onDateSelected(newDate); // Notify parent
  }
 }


 @override
 Widget build(BuildContext context) {
  // Use widget.selectedDate to get the week
  final weekDates = _getWeekDates(widget.selectedDate);


  return Container(
   margin:  EdgeInsets.fromLTRB(15, 0, 15, 0),
   child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
     // Year and Month dropdowns, Today and Week navigation buttons
     Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
       // Year and Month Dropdowns
       Expanded(
        child: Row(
         children: [
          // Year Dropdown
          Expanded(
           child: DropdownButtonFormField<String>(
            decoration:  InputDecoration(
             labelText: 'Ano', // Localize if needed
             border: OutlineInputBorder(),
             isDense: true, // Make it more compact
             contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            value: _selectedYear,
            items: widget.availableYears.map((year) => DropdownMenuItem(value: year, child: Text(year))).toList(),
            onChanged: (value) {
             if (value != null) {
              setState(() {
               _selectedYear = value;
              });
              // Update the parent's selected date
              _updateDate(int.tryParse(_selectedYear), _monthNameToNumber[_selectedMonth]);
             }
            },
           ),
          ),
           SizedBox(width: 8), // Spacing between year and month dropdowns
          // Month Dropdown
          Expanded(
           child: DropdownButtonFormField<String>(
            decoration:  InputDecoration(
             labelText: 'Mês', // Localize if needed
             border: OutlineInputBorder(),
             isDense: true, // Make it more compact
             contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            value: _selectedMonth,
            items: _availableMonths.map((month) => DropdownMenuItem(value: month, child: Text(month))).toList(),
            onChanged: (value) {
             if (value != null) {
              setState(() {
               _selectedMonth = value;
              });
              // Update the parent's selected date
              _updateDate(int.tryParse(_selectedYear), _monthNameToNumber[_selectedMonth]);
             }
            },
           ),
          ),
         ],
        ),
       ),

       // Today and Week navigation buttons
       Row(
        mainAxisSize: MainAxisSize.min, // Use minimum size
        children: [
         // Button to jump to today
         IconButton(
          icon: Icon(
           Icons.refresh,
           color: Colors.green.shade700,
           size: 28,
          ),
          onPressed: () {
           final today = DateTime.now();
           // Notify parent widget to set the date to today
           widget.onDateSelected(today);
           // No need to call setState here, didUpdateWidget will handle state update
           // when parent rebuilds.
          },
         ),
          SizedBox(width: 8), // Spacing
         // Week navigation buttons
         IconButton(
          icon:  Icon(Icons.chevron_left),
          onPressed: () => _changeWeek(-1),
         ),
         IconButton(
          icon:  Icon(Icons.chevron_right),
          onPressed: () => _changeWeek(1),
         ),
        ],
       ),

      ],
     ),
      SizedBox(height: 8),
     // Days of the week
     Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: weekDates.map((date) {
       // Compare date with the selectedDate from widget
       final isSelected = DateUtils.isSameDay(date, widget.selectedDate);
       final dayName = dayNameFormat.format(date);
       final dayNumber = date.day;

       return Expanded(
        child: GestureDetector(
         onTap: () => widget.onDateSelected(date), // Notify parent of selected day
         child: Container(
          padding:  EdgeInsets.fromLTRB(0, 8, 0, 8),
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
             SizedBox(height: 4),
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