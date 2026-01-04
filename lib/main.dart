import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:table_calendar/table_calendar.dart';

void main() async {
  await Hive.initFlutter();
  Hive.registerAdapter(DayEntryAdapter());
  await Hive.openBox<DayEntry>('daily_ratings');

  // Modern B&W Status Bar
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark, // Black icons
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const DailyRatingApp());
}

class DailyRatingApp extends StatelessWidget {
  const DailyRatingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Daily Rating',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: const ColorScheme.light(
          primary: Colors.black,
          secondary: Colors.black,
          surface: Colors.white,
          onSurface: Colors.black,
          error: Colors.black, // Even errors are black in this theme
        ),
        scaffoldBackgroundColor: Colors.white,
        useMaterial3: true,
        fontFamily: 'SF Pro Display',
        // Define standard button styles
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      home: const HomePage(),
    );
  }
}

// --- Data Model (Unchanged) ---
class DayEntry {
  final DateTime date;
  final int rating;
  final String note;

  DayEntry({required this.date, required this.rating, this.note = ''});
}

class DayEntryAdapter extends TypeAdapter<DayEntry> {
  @override
  final int typeId = 0;

  @override
  DayEntry read(BinaryReader reader) {
    return DayEntry(
      date: DateTime.parse(reader.readString()),
      rating: reader.readInt(),
      note: reader.readString(),
    );
  }

  @override
  void write(BinaryWriter writer, DayEntry obj) {
    writer.writeString(obj.date.toIso8601String());
    writer.writeInt(obj.rating);
    writer.writeString(obj.note);
  }
}

// --- Main Screen ---
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Box<DayEntry> _box;
  int _currentRating = 3;
  final TextEditingController _noteController = TextEditingController();

  final CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _box = Hive.box<DayEntry>('daily_ratings');
    _selectedDay = _focusedDay;
  }

  DayEntry? _getEntryForDay(DateTime day) {
    try {
      return _box.values.firstWhere((entry) => _isSameDay(entry.date, day));
    } catch (e) {
      return null;
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Marhay na aga";
    if (hour < 17) return "Marhay na hapon";
    return "Mamanggi";
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  void _saveEntry() {
    if (_noteController.text.isEmpty && _currentRating == 0) return;

    final now = DateTime.now();
    // Check for duplicate day
    final existingEntryIndex = _box.values.toList().indexWhere(
      (entry) => _isSameDay(entry.date, now),
    );

    if (existingEntryIndex != -1) {
      HapticFeedback.heavyImpact();
      _showSnack("Bawal doble boii!!", isError: true);
      return;
    }

    HapticFeedback.mediumImpact();

    final newEntry = DayEntry(
      date: DateTime.now(),
      rating: _currentRating,
      note: _noteController.text,
    );

    // _box.add(newEntry);
    // _noteController.clear();
    // setState(() => _currentRating = 3);

    _box.add(newEntry);
    _noteController.clear();
    setState(() {
      _currentRating = 3;
      // Update calendar focus to today so the shading appears immediately
      _focusedDay = DateTime.now();
    });

    FocusManager.instance.primaryFocus?.unfocus();
    _showSnack("Nasave ko na");
  }

  void _deleteEntry(int index) {
    HapticFeedback.selectionClick();
    final entryToDelete = _box.getAt(index);
    _box.deleteAt(index);
    setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          "Entry deleted",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.black,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'UNDO',
          textColor: Colors.grey[400],
          onPressed: () {
            if (entryToDelete != null) {
              _box.add(entryToDelete);
              setState(() {});
            }
          },
        ),
      ),
    );
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final historyList = _box.values.toList().reversed.toList();

    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        // Pure white background for modern look
        backgroundColor: Colors.white,
        body: SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // --- 1. Minimal Header ---
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 40, 24, 30),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "DAILY RATING APP NI NOEL",
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          color: Colors.black,
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            DateFormat(
                              'MMM d, yyyy',
                            ).format(DateTime.now()).toUpperCase(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color.fromARGB(255, 75, 75, 75),
                              letterSpacing: 2.0,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 40),

                      Text(
                        _getGreeting(),
                        style: GoogleFonts.bebasNeue(
                          fontSize: 45,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 10,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAFAFA),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: TableCalendar(
                      firstDay: DateTime.utc(2024, 1, 1),
                      lastDay: DateTime.utc(2030, 12, 31),
                      focusedDay: _focusedDay,
                      calendarFormat: _calendarFormat,
                      startingDayOfWeek: StartingDayOfWeek.sunday,

                      // Theme Styling
                      headerStyle: HeaderStyle(
                        titleCentered: true,
                        formatButtonVisible: false,
                        titleTextStyle: GoogleFonts.montserrat(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        leftChevronIcon: const Icon(
                          Icons.chevron_left,
                          color: Colors.black,
                        ),
                        rightChevronIcon: const Icon(
                          Icons.chevron_right,
                          color: Colors.black,
                        ),
                      ),

                      // Logic to change dates
                      onDaySelected: (selectedDay, focusedDay) {
                        setState(() {
                          _selectedDay = selectedDay;
                          _focusedDay = focusedDay;
                        });
                      },
                      onPageChanged: (focusedDay) {
                        _focusedDay = focusedDay;
                      },

                      // --- THE BUILDERS: This handles the "Shading" ---
                      calendarBuilders: CalendarBuilders(
                        // Builder for days that have data
                        defaultBuilder: (context, day, focusedDay) {
                          final entry = _getEntryForDay(day);
                          if (entry != null) {
                            return Center(
                              child: Container(
                                margin: const EdgeInsets.all(6.0),
                                alignment: Alignment.center,
                                decoration: const BoxDecoration(
                                  color: Colors.black, // Shaded Black
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  '${day.day}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                  ), // White Text
                                ),
                              ),
                            );
                          }
                          return null; // Use default look for empty days
                        },

                        // Builder for Today (if it has data, keep it black, else outline)
                        todayBuilder: (context, day, focusedDay) {
                          final entry = _getEntryForDay(day);
                          if (entry != null) {
                            return Center(
                              child: Container(
                                margin: const EdgeInsets.all(6.0),
                                alignment: Alignment.center,
                                decoration: const BoxDecoration(
                                  color: Colors.black,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  '${day.day}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            );
                          }
                          // Today but no entry yet
                          return Center(
                            child: Container(
                              margin: const EdgeInsets.all(6.0),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.black,
                                  width: 2,
                                ),
                              ),
                              child: Text(
                                '${day.day}',
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
              // --- 2. Input Section ---
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 35),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Text(
                          "Inano ang aldaw mo ngunian",
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),
                      // Star Rating
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(5, (index) {
                          final starIndex = index + 1;
                          final isSelected = starIndex <= _currentRating;
                          return GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              setState(() => _currentRating = starIndex);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSelected
                                    ? Colors.black
                                    : Colors.transparent,
                                border: Border.all(
                                  color: Colors.black,
                                  width: 1.5,
                                ),
                              ),
                              child: Icon(
                                isSelected ? Icons.star : Icons.star_border,
                                size: 14,
                                color: isSelected ? Colors.white : Colors.black,
                              ),
                            ),
                          );
                        }),
                      ),

                      const SizedBox(height: 12),

                      // Rating Text Label
                      Center(
                        child: Text(
                          [
                            "",
                            "yudepota",
                            "Habo ko na",
                            "Pwede Na",
                            "Pakak",
                            "Renas",
                          ][_currentRating],
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            letterSpacing: 2.0,
                          ),
                        ),
                      ),

                      // Input Field (Minimalist Line)
                      const SizedBox(height: 30),

                      TextField(
                        controller: _noteController,
                        maxLines: 4,
                        minLines: 1,
                        cursorColor: Colors.black,
                        textCapitalization: TextCapitalization.sentences,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.black,
                          height: 1.4,
                        ),
                        decoration: InputDecoration(
                          hintText: "Inano daa?",
                          hintStyle: TextStyle(
                            color: const Color.fromARGB(255, 122, 122, 122),
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                          ),
                          filled: true,
                          fillColor: const Color(
                            0xFFFAFAFA,
                          ), // Almost white, very subtle depth
                          contentPadding: const EdgeInsets.all(20),
                          // Idle State: Subtle Grey Border
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: const Color.fromARGB(255, 0, 0, 0),
                              width: 1,
                            ),
                          ),

                          // Focused State: Bold Black Border
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Colors.black,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Black Save Button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _saveEntry,
                          child: const Text(
                            "Rate mo na",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // --- 3. List Divider ---
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 30,
                      ),
                      child: Text(
                        "Your Journey (Paglakaw)",

                        // style: TextStyle(
                        //   fontWeight: FontWeight.w700,
                        //   fontSize: 18,
                        //   color: const Color.fromARGB(255, 0, 0, 0),
                        // ),
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                          color: const Color.fromARGB(255, 0, 0, 0),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // --- 4. History List ---
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                sliver: historyList.isEmpty
                    ? SliverToBoxAdapter(
                        child: Center(
                          child: Text(
                            "NO ENTRIES YET",
                            style: TextStyle(
                              color: const Color.fromARGB(255, 43, 43, 43),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      )
                    : SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final entry = historyList[index];
                          final originalIndex = _box.length - 1 - index;

                          return Dismissible(
                            key: UniqueKey(),
                            direction: DismissDirection.endToStart,
                            onDismissed: (_) => _deleteEntry(originalIndex),
                            background: Container(
                              alignment: Alignment.centerRight,
                              color: const Color.fromARGB(
                                255,
                                245,
                                75,
                                75,
                              ), // Black background for swipe
                              padding: const EdgeInsets.only(right: 20),
                              child: const Icon(
                                Icons.delete_outline,
                                color: Colors.white,
                              ),
                            ),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 24),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Date Column
                                  SizedBox(
                                    width: 50,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          DateFormat('dd').format(entry.date),
                                          style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            height: 1.0,
                                          ),
                                        ),
                                        Text(
                                          DateFormat(
                                            'MMM',
                                          ).format(entry.date).toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey[500],
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1.0,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(width: 12),

                                  // Vertical Line
                                  Container(
                                    height: 40,
                                    width: 1,
                                    color: Colors.grey[200],
                                  ),

                                  const SizedBox(width: 16),

                                  // Content Column
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            // Mini Star Display
                                            Row(
                                              children: List.generate(5, (
                                                starI,
                                              ) {
                                                return Icon(
                                                  Icons.star,
                                                  size: 12,
                                                  color: starI < entry.rating
                                                      ? Colors.black
                                                      : Colors.grey[200],
                                                );
                                              }),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        if (entry.note.isNotEmpty)
                                          Text(
                                            entry.note,
                                            style: TextStyle(
                                              color: Colors.grey[800],
                                              fontSize: 14,
                                              height: 1.4,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          )
                                        else
                                          Text(
                                            "No note added.",
                                            style: TextStyle(
                                              color: const Color.fromARGB(
                                                255,
                                                73,
                                                73,
                                                73,
                                              ),
                                              fontStyle: FontStyle.italic,
                                              fontSize: 13,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }, childCount: historyList.length),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
