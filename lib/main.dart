import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Takvim Ajanda',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: CalendarPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class Event {
  final String title;
  final TimeOfDay startTime;
  final TimeOfDay endTime;

  Event(this.title, this.startTime, this.endTime);

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'startTime': {'hour': startTime.hour, 'minute': startTime.minute},
      'endTime': {'hour': endTime.hour, 'minute': endTime.minute},
    };
  }

  static Event fromJson(Map<String, dynamic> json) {
    return Event(
      json['title'],
      TimeOfDay(hour: json['startTime']['hour'], minute: json['startTime']['minute']),
      TimeOfDay(hour: json['endTime']['hour'], minute: json['endTime']['minute']),
    );
  }
}

class CalendarPage extends StatefulWidget {
  @override
  _CalendarPageState createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();

  Map<DateTime, List<Event>> _events = {};
  List<Event> _selectedEvents = [];
  Set<Event> _selectedEventsSet = Set<Event>();

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Takvim Ajanda'),
        actions: [
          if (_selectedEvents.isNotEmpty)
            IconButton(
              icon: Icon(Icons.delete),
              onPressed: () => _showDeleteConfirmationDialog(),
            ),
        ],
      ),
      body: Column(
        children: [
          TableCalendar(
            focusedDay: _focusedDay,
            firstDay: DateTime(2000),
            lastDay: DateTime(2050),
            calendarFormat: _calendarFormat,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
                _selectedEvents = _getEventsForDay(_selectedDay);
                _selectedEventsSet.clear(); // Clear selected events
              });
            },
            onFormatChanged: (format) {
              if (_calendarFormat != format) {
                setState(() {
                  _calendarFormat = format;
                });
              }
            },
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: _getEventsForDay(_selectedDay).map((event) {
                  bool isSelected = _selectedEventsSet.contains(event);
                  return ListTile(
                    title: Text(
                        '${event.title} - ${event.startTime.format(context)} - ${event.endTime.format(context)}'),
                    leading: isSelected ? Icon(Icons.check_circle) : Icon(Icons.circle),
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedEventsSet.remove(event);
                        } else {
                          _selectedEventsSet.add(event);
                        }
                        _selectedEvents = _getEventsForDay(_selectedDay)
                            .where((e) => _selectedEventsSet.contains(e))
                            .toList();
                      });
                    },
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addEvent(),
        child: Icon(Icons.add),
      ),
    );
  }

  List<Event> _getEventsForDay(DateTime day) {
    final events = _events[day] ?? [];
    events.sort((a, b) => a.startTime.hour.compareTo(b.startTime.hour) == 0
        ? a.startTime.minute.compareTo(b.startTime.minute)
        : a.startTime.hour.compareTo(b.startTime.hour));
    return events;
  }

  void _addEvent() async {
    TimeOfDay? selectedStartTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (selectedStartTime == null) return;

    TimeOfDay? selectedEndTime = await showTimePicker(
      context: context,
      initialTime: selectedStartTime.replacing(
          hour: selectedStartTime.hour, minute: selectedStartTime.minute + 30),
    );

    if (selectedEndTime == null) return;

    if (selectedEndTime.hour < selectedStartTime.hour ||
        (selectedEndTime.hour == selectedStartTime.hour &&
            selectedEndTime.minute <= selectedStartTime.minute)) {
      _showErrorDialog('Bitiş saati başlangıç saatinden sonra olmalıdır.');
      return;
    }

    final titleController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Yeni Etkinlik Ekle'),
        content: TextField(
          controller: titleController,
          decoration: InputDecoration(hintText: 'Etkinlik başlığı'),
        ),
        actions: [
          TextButton(
            onPressed: () {
              final title = titleController.text;
              if (title.isEmpty) return;

              if (_isTimeSlotAvailable(
                  _selectedDay, selectedStartTime, selectedEndTime)) {
                setState(() {
                  if (_events[_selectedDay] != null) {
                    _events[_selectedDay]!.add(
                        Event(title, selectedStartTime, selectedEndTime));
                  } else {
                    _events[_selectedDay] = [
                      Event(title, selectedStartTime, selectedEndTime)
                    ];
                  }
                });
                _saveEvents();
                Navigator.pop(context);
              } else {
                _showErrorDialog(
                    'Bu saat aralığı dolu. Lütfen başka bir saat seçin.');
              }
            },
            child: Text('Ekle'),
          ),
        ],
      ),
    );
  }

  bool _isTimeSlotAvailable(
      DateTime day, TimeOfDay startTime, TimeOfDay endTime) {
    final events = _events[day];
    if (events == null) return true;

    for (final event in events) {
      if ((startTime.hour < event.endTime.hour ||
          (startTime.hour == event.endTime.hour &&
              startTime.minute < event.endTime.minute)) &&
          (endTime.hour > event.startTime.hour ||
              (endTime.hour == event.startTime.hour &&
                  endTime.minute > event.startTime.minute))) {
        return false;
      }
    }
    return true;
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Uyarı'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Tamam'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Silme Onayı'),
        content: Text('Seçilen etkinlikleri silmek istediğinizden emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _events[_selectedDay]?.removeWhere(
                        (event) => _selectedEventsSet.contains(event));
                _selectedEventsSet.clear();
                _saveEvents();
                Navigator.pop(context);
              });
            },
            child: Text('Sil'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('İptal'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveEvents() async {
    final prefs = await SharedPreferences.getInstance();

    Map<String, String> encodedEvents = {};
    _events.forEach((date, events) {
      encodedEvents[date.toIso8601String()] =
          jsonEncode(events.map((e) => e.toJson()).toList());
    });

    await prefs.setString('events', jsonEncode(encodedEvents));
  }

  Future<void> _loadEvents() async {
    final prefs = await SharedPreferences.getInstance();

    final encodedEvents = prefs.getString('events');
    if (encodedEvents == null) return;

    Map<String, dynamic> decodedEvents = jsonDecode(encodedEvents);
    _events = decodedEvents.map((date, eventsJson) {
      final eventsList = (jsonDecode(eventsJson) as List)
          .map((eventJson) => Event.fromJson(eventJson))
          .toList();
      return MapEntry(DateTime.parse(date), eventsList);
    });

    // Ekranın doğru etkinlikleri göstermesi için seçili günü güncelleyin
    setState(() {});
  }
}
