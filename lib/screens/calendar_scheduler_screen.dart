import 'package:flutter/material.dart';
import '../models/user_model.dart';

class ScheduledEventItem {
  final String id;
  final String title;
  final String time;
  final String category; // 'morning', 'afternoon', 'night'
  final String location;
  final Color dotColor;
  final bool hasStar;
  final bool isGreenTag;
  final bool isWaveform;
  final DateTime date;

  ScheduledEventItem({
    required this.id,
    required this.title,
    required this.time,
    required this.category,
    required this.location,
    required this.dotColor,
    this.hasStar = false,
    this.isGreenTag = false,
    this.isWaveform = false,
    required this.date,
  });
}

class CalendarSchedulerScreen extends StatefulWidget {
  final UserModel? user;
  final VoidCallback? onOpenMeetings;

  const CalendarSchedulerScreen({
    super.key,
    required this.user,
    this.onOpenMeetings,
  });

  @override
  State<CalendarSchedulerScreen> createState() => _CalendarSchedulerScreenState();
}

class _CalendarSchedulerScreenState extends State<CalendarSchedulerScreen> {
  // Page 0: Goals (Left Screen)
  // Page 1: Month Calendar (Center Screen - Default)
  // Page 2: Day Schedule (Right Screen)
  late final PageController _pageController;
  int _currentPage = 1;

  DateTime _selectedDate = DateTime(2026, 1, 17);
  DateTime _currentMonth = DateTime(2026, 1, 1);

  late List<ScheduledEventItem> _events;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 1);

    final eventDate = DateTime(2026, 1, 17);
    _events = [
      // Morning Block (Mint Green)
      ScheduledEventItem(
        id: '1',
        title: 'Morning\n5h deep',
        time: '08:00',
        category: 'morning',
        location: 'Focus Room',
        dotColor: const Color(0xFF22C55E),
        isGreenTag: true,
        date: eventDate,
      ),
      ScheduledEventItem(
        id: '2',
        title: 'Voice Note & Agenda Preview',
        time: '08:00',
        category: 'morning',
        location: 'Audio Sync',
        dotColor: const Color(0xFF64748B),
        isWaveform: true,
        date: eventDate,
      ),
      ScheduledEventItem(
        id: '3',
        title: 'Morning routine',
        time: '08:00',
        category: 'morning',
        location: 'Wellness & Setup',
        dotColor: const Color(0xFF94A3B8),
        date: eventDate,
      ),
      ScheduledEventItem(
        id: '4',
        title: 'VC preparation\nA301 - meeting room',
        time: '08:00',
        category: 'morning',
        location: 'Room A301',
        dotColor: const Color(0xFF3B82F6),
        hasStar: true,
        date: eventDate,
      ),

      // Afternoon Block (Pastel Blue)
      ScheduledEventItem(
        id: '5',
        title: 'CONNEKT Product & Ecosystem Sync',
        time: '02:00',
        category: 'afternoon',
        location: 'Executive Room Alpha',
        dotColor: const Color(0xFF0F3B82),
        date: eventDate,
      ),
      ScheduledEventItem(
        id: '6',
        title: 'UX Review & Architecture Demo',
        time: '03:45',
        category: 'afternoon',
        location: 'Design Lab',
        dotColor: const Color(0xFF8B5CF6),
        hasStar: true,
        date: eventDate,
      ),

      // Night Block (Dark Navy)
      ScheduledEventItem(
        id: '7',
        title: 'Daily Wrap-up & Notes Review',
        time: '07:30',
        category: 'night',
        location: 'Personal Workspace',
        dotColor: const Color(0xFF06B6D4),
        date: eventDate,
      ),
    ];
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToPage(int page) {
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        page,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOut,
      );
    }
  }

  void _changeMonth(int delta) {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + delta, 1);
    });
  }

  void _showAddMeetingDialog() {
    final titleController = TextEditingController();
    DateTime pickedDate = _selectedDate;
    TimeOfDay pickedTime = const TimeOfDay(hour: 15, minute: 0);
    String selectedCategory = 'morning';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Schedule New Meeting',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F1E36),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: titleController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Meeting Title (e.g. Design Sync)',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF0F3B82), width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                // Time & Category Pickers
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final t = await showTimePicker(
                            context: context,
                            initialTime: pickedTime,
                          );
                          if (t != null) {
                            setDialogState(() => pickedTime = t);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.access_time_rounded, size: 18, color: Color(0xFF0F3B82)),
                              const SizedBox(width: 8),
                              Text(
                                pickedTime.format(context),
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F1E36)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Category selector (Morning/Afternoon/Night)
                    DropdownButton<String>(
                      value: selectedCategory,
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(value: 'morning', child: Text('Morning')),
                        DropdownMenuItem(value: 'afternoon', child: Text('Afternoon')),
                        DropdownMenuItem(value: 'night', child: Text('Night')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selectedCategory = val);
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      final title = titleController.text.trim();
                      if (title.isEmpty) return;

                      final newEvent = ScheduledEventItem(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        title: title,
                        time: pickedTime.format(context),
                        category: selectedCategory,
                        location: 'CONNEKT Meeting Room',
                        dotColor: const Color(0xFF0F3B82),
                        hasStar: true,
                        date: pickedDate,
                      );

                      setState(() {
                        _events.add(newEvent);
                      });

                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Meeting "$title" scheduled!')),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F3B82),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Confirm Schedule', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }

  String _getWeekdayName(int weekday) {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFBFD),
      body: SafeArea(
        child: Column(
          children: [
            // TOP HEADER BAR (Dynamic per page)
            _buildTopHeader(),

            // MAIN CONTENT: Swipeable PageView across all 3 panels
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const BouncingScrollPhysics(),
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                children: [
                  _buildGoalsView(),          // Page 0: Left Screen
                  _buildMonthCalendarView(),   // Page 1: Center Screen (Default)
                  _buildDayTimelineView(),     // Page 2: Right Screen
                ],
              ),
            ),

            // BOTTOM FLOATING ACTION BAR (< , Join Meeting, +)
            _buildBottomFloatingBar(),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // 1. TOP HEADER (Adapts cleanly per active screen)
  // ===========================================================================

  Widget _buildTopHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Screen Title
          if (_currentPage == 0)
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Goals',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F1E36),
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  'For today',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            )
          else if (_currentPage == 1)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${_currentMonth.year}',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F1E36),
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  _getMonthName(_currentMonth.month),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _getWeekdayName(_selectedDate.weekday),
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F1E36),
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  '${_getMonthName(_selectedDate.month)} ${_selectedDate.day}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),

          // Right: Badges or Close Button
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_currentPage == 0) ...[
                // Goals "08 June" Badge with Red Dot
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '08',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F1E36),
                              height: 1.1,
                            ),
                          ),
                          Text(
                            'June',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFFEF4444),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
              ],

              // Close (X) Button to dismiss screen
              InkWell(
                onTap: () => Navigator.pop(context),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF475569)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 2. VIEW 1: MONTH CALENDAR & WEATHER CARD (Center Screen in Image 2)
  // ===========================================================================

  Widget _buildMonthCalendarView() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Month navigation arrows
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, color: Color(0xFF475569)),
                onPressed: () => _changeMonth(-1),
                tooltip: 'Previous Month',
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, color: Color(0xFF475569)),
                onPressed: () => _changeMonth(1),
                tooltip: 'Next Month',
              ),
            ],
          ),

          // Days of week header: M T W T F S S
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _WeekdayLabel('M'),
              _WeekdayLabel('T'),
              _WeekdayLabel('W'),
              _WeekdayLabel('T'),
              _WeekdayLabel('F'),
              _WeekdayLabel('S'),
              _WeekdayLabel('S'),
            ],
          ),
          const SizedBox(height: 6),

          // Calendar Grid
          _buildCalendarGrid(),

          const SizedBox(height: 16),

          // Weather & Scenic Landscape Card (from Image 2)
          _buildWeatherLandscapeCard(),

          const SizedBox(height: 14),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid() {
    final daysInMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    final firstWeekday = _currentMonth.weekday; // 1 = Mon, 7 = Sun
    final prevMonthDays = DateTime(_currentMonth.year, _currentMonth.month, 0).day;

    final List<Widget> dayWidgets = [];

    // Previous month filler days
    for (int i = firstWeekday - 1; i > 0; i--) {
      dayWidgets.add(
        _buildCalendarDayCell(
          dayNumber: prevMonthDays - i + 1,
          isCurrentMonth: false,
          date: DateTime(_currentMonth.year, _currentMonth.month - 1, prevMonthDays - i + 1),
        ),
      );
    }

    // Current month days
    for (int d = 1; d <= daysInMonth; d++) {
      final cellDate = DateTime(_currentMonth.year, _currentMonth.month, d);
      dayWidgets.add(
        _buildCalendarDayCell(
          dayNumber: d,
          isCurrentMonth: true,
          date: cellDate,
        ),
      );
    }

    // Remaining filler days to complete grid
    final totalCells = (dayWidgets.length / 7).ceil() * 7;
    int nextMonthDay = 1;
    while (dayWidgets.length < totalCells) {
      dayWidgets.add(
        _buildCalendarDayCell(
          dayNumber: nextMonthDay,
          isCurrentMonth: false,
          date: DateTime(_currentMonth.year, _currentMonth.month + 1, nextMonthDay),
        ),
      );
      nextMonthDay++;
    }

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 7,
      mainAxisSpacing: 6,
      crossAxisSpacing: 6,
      childAspectRatio: 0.95,
      children: dayWidgets,
    );
  }

  Widget _buildCalendarDayCell({
    required int dayNumber,
    required bool isCurrentMonth,
    required DateTime date,
  }) {
    final isSelected = isCurrentMonth &&
        _selectedDate.year == date.year &&
        _selectedDate.month == date.month &&
        _selectedDate.day == date.day;

    // Badges/dots indicators like in Image 2
    final hasBlueStar = isCurrentMonth && (dayNumber == 1 || dayNumber == 28);
    final hasOrangeDot = isCurrentMonth && (dayNumber == 4 || dayNumber == 7 || dayNumber == 23);
    final hasGreenDot = isCurrentMonth && (dayNumber == 14 || dayNumber == 30);
    final hasDoubleDots = isCurrentMonth && (dayNumber == 14 || dayNumber == 21 || dayNumber == 30);

    return InkWell(
      onTap: () {
        setState(() {
          _selectedDate = date;
        });
        // Smoothly glide into Day Schedule (Page 2)
        _goToPage(2);
      },
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Date number container (black oval pill if selected)
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF0F172A) : Colors.transparent,
              borderRadius: BorderRadius.circular(17),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Text(
                  '$dayNumber',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected
                        ? Colors.white
                        : (isCurrentMonth ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1)),
                  ),
                ),
                if (isSelected)
                  Positioned(
                    bottom: 3,
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                        color: Color(0xFF22C55E),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 2),

          // Event status indicators (colored dots like Image 2)
          if (isCurrentMonth && !isSelected)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (hasBlueStar)
                  Container(
                    width: 5,
                    height: 5,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: const BoxDecoration(
                      color: Color(0xFF3B82F6),
                      shape: BoxShape.circle,
                    ),
                  ),
                if (hasOrangeDot)
                  Container(
                    width: 5,
                    height: 5,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF97316),
                      shape: BoxShape.circle,
                    ),
                  ),
                if (hasGreenDot && !hasOrangeDot)
                  Container(
                    width: 5,
                    height: 5,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: const BoxDecoration(
                      color: Color(0xFF22C55E),
                      shape: BoxShape.circle,
                    ),
                  ),
                if (hasDoubleDots)
                  Container(
                    width: 5,
                    height: 5,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: const BoxDecoration(
                      color: Color(0xFF06B6D4),
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            )
          else
            const SizedBox(height: 5),
        ],
      ),
    );
  }

  Widget _buildWeatherLandscapeCard() {
    return Container(
      width: double.infinity,
      height: 120,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Landscape artwork background
          Positioned.fill(
            child: Image.asset(
              'assets/images/weather_landscape.png',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF5B8C85), Color(0xFFD4A373)],
                  ),
                ),
              ),
            ),
          ),

          // Weather & Date Overlay text
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Today',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  '21°C',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_selectedDate.day} ${_getMonthName(_selectedDate.month)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 3. VIEW 2: DAY SCHEDULE / TIME BLOCKS (Right Screen in Image 2)
  // ===========================================================================

  Widget _buildDayTimelineView() {
    final morningEvents = _events.where((e) => e.category == 'morning').toList();
    final afternoonEvents = _events.where((e) => e.category == 'afternoon').toList();
    final nightEvents = _events.where((e) => e.category == 'night').toList();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section 1: Morning Block (Mint Pastel Green)
          _buildMorningTimeBlock(morningEvents),

          const SizedBox(height: 12),

          // Section 2: Afternoon Block (Pastel Soft Blue)
          _buildTimeBlockContainer(
            title: 'Afternoon',
            color: const Color(0xFFDBEAFE),
            textColor: const Color(0xFF1E40AF),
            events: afternoonEvents,
          ),

          const SizedBox(height: 12),

          // Section 3: Night Block (Dark Navy with Moon Icon)
          _buildTimeBlockContainer(
            title: 'Night',
            color: const Color(0xFF1E293B),
            textColor: Colors.white,
            events: nightEvents,
            isDark: true,
          ),

          const SizedBox(height: 16),

          // Mini Weekday selector row at bottom (M T W T Fri S S)
          _buildMiniWeekSelector(),

          const SizedBox(height: 14),
        ],
      ),
    );
  }

  Widget _buildMorningTimeBlock(List<ScheduledEventItem> events) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFDDF3E4),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Morning',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF166534),
            ),
          ),
          const SizedBox(height: 10),

          // Item 1: 08:00 Morning / 5h deep (with green round badge)
          _buildScheduleItemRow(
            time: '08:00',
            title: 'Morning',
            subtitle: '5h deep',
            badge: Container(
              width: 16,
              height: 16,
              decoration: const BoxDecoration(
                color: Color(0xFF22C55E),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.remove, size: 12, color: Colors.white),
            ),
          ),
          const SizedBox(height: 8),

          // Item 2: 08:00 Waveform / voice memo representation
          Row(
            children: [
              const SizedBox(
                width: 44,
                child: Text(
                  '08:00',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: _buildWaveformGraphic()),
            ],
          ),
          const SizedBox(height: 8),

          // Item 3: 08:00 Morning routine
          _buildScheduleItemRow(
            time: '08:00',
            title: 'Morning routine',
            subtitle: null,
          ),
          const SizedBox(height: 8),

          // Item 4: 08:00 VC preparation / A301 - meeting room (star badge)
          _buildScheduleItemRow(
            time: '08:00',
            title: 'VC preparation',
            subtitle: 'A301 - meeting room',
            badge: Container(
              width: 18,
              height: 18,
              decoration: const BoxDecoration(
                color: Color(0xFF3B82F6),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.star_rounded, size: 13, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleItemRow({
    required String time,
    required String title,
    String? subtitle,
    Widget? badge,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(
              time,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
              ],
            ),
          ),
          ?badge,
        ],
      ),
    );
  }

  Widget _buildWaveformGraphic() {
    final heights = [6.0, 14.0, 8.0, 18.0, 22.0, 12.0, 16.0, 20.0, 10.0, 15.0, 8.0, 19.0, 13.0, 9.0, 16.0, 21.0, 11.0, 7.0, 14.0, 18.0, 10.0, 6.0];
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: heights.map((h) => Container(
          width: 2.2,
          height: h,
          decoration: BoxDecoration(
            color: const Color(0xFFCBD5E1),
            borderRadius: BorderRadius.circular(1.5),
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildTimeBlockContainer({
    required String title,
    required Color color,
    required Color textColor,
    required List<ScheduledEventItem> events,
    bool isDark = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              if (isDark)
                const Icon(Icons.nightlight_round, size: 16, color: Colors.white70),
            ],
          ),
          const SizedBox(height: 10),
          if (events.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No events scheduled',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white60 : Colors.black45,
                ),
              ),
            )
          else
            ...events.map(
              (e) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Text(
                      e.time,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white70 : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e.title,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF1E293B),
                            ),
                          ),
                          Text(
                            e.location,
                            style: TextStyle(
                              fontSize: 10.5,
                              color: isDark ? Colors.white54 : const Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (e.hasStar)
                      const Icon(Icons.star_rounded, size: 16, color: Color(0xFF3B82F6))
                    else
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: e.dotColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMiniWeekSelector() {
    final now = DateTime(2026, 1, 17); // Fixed base to Jan 2026 for consistency with Image 2
    final monday = now.subtract(Duration(days: now.weekday - 1));
    const labels = ['M', 'T', 'W', 'T', 'Fri', 'S', 'S'];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: List.generate(7, (i) {
        final dayDate = monday.add(Duration(days: i));
        final isSelected = dayDate.day == _selectedDate.day;

        return InkWell(
          onTap: () {
            setState(() => _selectedDate = dayDate);
          },
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 38,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: isSelected ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              children: [
                Text(
                  labels[i],
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? const Color(0xFF0F3B82) : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${dayDate.day}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? const Color(0xFF0F1E36) : const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  // ===========================================================================
  // 4. VIEW 3: GOALS & UPCOMING MEETINGS (Left Screen in Image 2)
  // ===========================================================================

  Widget _buildGoalsView() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero Meeting Card: "10:00 Meeting - Product Launch UX"
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '10:00',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Meeting',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0F1E36)),
                ),
                const Text(
                  'Product Launch UX',
                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        widget.onOpenMeetings?.call();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
                      ),
                      child: const Text('Start', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                    // Participant Avatar stack matching Image 2
                    Row(
                      children: [
                        Container(
                          width: 26,
                          height: 26,
                          decoration: const BoxDecoration(
                            color: Color(0xFFBFDBFE),
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Text('H', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E40AF))),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          width: 26,
                          height: 26,
                          decoration: const BoxDecoration(
                            color: Color(0xFFFED7AA),
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Icon(Icons.person, size: 16, color: Color(0xFFC2410C)),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          width: 26,
                          height: 26,
                          decoration: const BoxDecoration(
                            color: Color(0xFFF1F5F9),
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Text('+6', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          const Text(
            'Recent',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 10),

          // Two side-by-side cards: "Design Review" and "Discussion"
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 120,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFE2EDFB), Color(0xFFD3E4F9)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        right: -10,
                        bottom: -15,
                        child: Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Design Review',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F1E36),
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'July 30th',
                                style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                          Container(
                            width: 26,
                            height: 26,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check_rounded, color: Color(0xFF22C55E), size: 16),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  height: 120,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Discussion',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F1E36),
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Discuss launch timeline',
                                  style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.bookmark_border_rounded, size: 16, color: Color(0xFF94A3B8)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Rate',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Card 3: "Meeting Preparation / Designer Team" with black pill of 3 icons
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Meeting Preparation',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F1E36),
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Designer Team',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.school_outlined, color: Colors.white, size: 18),
                        SizedBox(width: 14),
                        Icon(Icons.all_inclusive_rounded, color: Colors.white, size: 18),
                        SizedBox(width: 14),
                        Icon(Icons.work_outline_rounded, color: Colors.white, size: 18),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ===========================================================================
  // 5. BOTTOM FLOATING ACTION BAR (< , Join Meeting, +)
  // ===========================================================================

  Widget _buildBottomFloatingBar() {
    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 20, bottom: 14, top: 6),
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Left Action Button
            if (_currentPage == 0)
              // Calendar Icon -> Takes to Month Calendar (Page 1)
              InkWell(
                onTap: () => _goToPage(1),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.calendar_month_rounded, size: 20, color: Color(0xFF0F3B82)),
                ),
              )
            else
              // Chevron Left (<) -> Back to previous page
              InkWell(
                onTap: () {
                  if (_currentPage == 2) {
                    _goToPage(1);
                  } else {
                    _goToPage(0);
                  }
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.chevron_left_rounded, size: 22, color: Color(0xFF0F3B82)),
                ),
              ),

            const SizedBox(width: 8),

            // Middle Action: Join Meeting
            Expanded(
              child: InkWell(
                onTap: () {
                  widget.onOpenMeetings?.call();
                },
                borderRadius: BorderRadius.circular(22),
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F3B82), Color(0xFF1E40AF)],
                    ),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: const Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.videocam_rounded, color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Join Meeting',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 8),

            // Right Action Button
            if (_currentPage == 0)
              // Profile/Person button matching left screen
              InkWell(
                onTap: () {
                  _goToPage(1);
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person_outline_rounded, size: 20, color: Color(0xFF475569)),
                ),
              )
            else
              // Add (+) Button -> Opens Schedule New Meeting Modal
              InkWell(
                onTap: _showAddMeetingDialog,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: Color(0xFF0F3B82),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add_rounded, size: 22, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _WeekdayLabel extends StatelessWidget {
  final String label;
  const _WeekdayLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF94A3B8),
          ),
        ),
      ),
    );
  }
}
