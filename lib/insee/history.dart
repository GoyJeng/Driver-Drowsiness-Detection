import 'dart:convert';
import 'package:driver/global_user.dart';
import 'package:driver/insee/cause.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:table_calendar/table_calendar.dart';
import 'package:fl_chart/fl_chart.dart';

class History extends StatefulWidget {
  const History({super.key});

  @override
  State<History> createState() => _HistoryState();
}

class _HistoryState extends State<History> {
  Map<String, int> _notificationCounts = {};
  bool _isLoading = false;
  String _selectedPeriod = 'all';
  bool _showMenu = true;
  final ScrollController _scrollController = ScrollController();
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  bool _showChart = false;

  @override
  void initState() {
    super.initState();
    fetchNotifications();
    _scrollController.addListener(_onScroll);
    _selectedDay = DateTime.now();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.offset <= 0) {
      if (!_showMenu) {
        setState(() => _showMenu = true);
      }
    } else {
      if (_showMenu) {
        setState(() => _showMenu = false);
      }
    }
  }

  Future<void> fetchNotifications() async {
    setState(() => _isLoading = true);
    try {
      var userId = GlobalUser.userID;
      if (userId == null || userId.isEmpty) {
        print('UserID is empty or null');
        return;
      }

      final response = await http.get(
        Uri.parse('http://192.168.239.7:3000/history?userId=$userId'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        Map<String, int> counts = {};
        for (var notification in data) {
          String dateUtc = notification['date'] ?? 'Unknown';
          DateTime parsedDate = DateTime.parse(dateUtc).toLocal();
          String formattedDate =
              "${parsedDate.year}-${parsedDate.month.toString().padLeft(2, '0')}-${parsedDate.day.toString().padLeft(2, '0')}";
          counts[formattedDate] = (counts[formattedDate] ?? 0) + 1;
        }
        setState(() => _notificationCounts = counts);
        _showChart = true;
      }
    } catch (e) {
      print('Error fetching notifications: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showCalendarDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TableCalendar(
                  firstDay: DateTime.utc(2020, 1, 1),
                  lastDay: DateTime.now(),
                  focusedDay: _focusedDay,
                  calendarFormat: CalendarFormat.month,
                  availableCalendarFormats: const {
                    CalendarFormat.month: 'Month'
                  },
                  selectedDayPredicate: (day) {
                    return isSameDay(_selectedDay, day);
                  },
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                      String formattedDate =
                          "${selectedDay.year}-${selectedDay.month.toString().padLeft(2, '0')}-${selectedDay.day.toString().padLeft(2, '0')}";
                      _selectedPeriod = formattedDate;
                    });
                    Navigator.pop(context);
                  },
                  // ปรับแต่งสีและสไตล์ของปฏิทิน
                  calendarStyle: CalendarStyle(
                    // สีพื้นหลังของวันที่ถูกเลือก
                    selectedDecoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                    // สีตัวเลขของวันที่ถูกเลือก
                    selectedTextStyle: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    // สีพื้นหลังของวันนี้
                    todayDecoration: BoxDecoration(
                      color: Colors.blue[400],
                      shape: BoxShape.circle,
                    ),
                    // สีตัวเลขของวันนี้
                    todayTextStyle: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    // สีตัวเลขวันปกติ
                    defaultTextStyle: const TextStyle(
                      color: Colors.black87,
                    ),
                    // สีตัวเลขวันที่นอกเดือนปัจจุบัน
                    outsideTextStyle: TextStyle(
                      color: Colors.grey[400],
                    ),
                    // สีตัวเลขวันสุดสัปดาห์
                    weekendTextStyle: TextStyle(
                      color: Colors.red[300],
                    ),
                    // เมื่อ hover หรือ highlight วันที่
                    markerDecoration: BoxDecoration(
                      color: Colors.blue[200],
                      shape: BoxShape.circle,
                    ),
                  ),
                  // ปรับแต่งส่วนหัวของปฏิทิน
                  headerStyle: const HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                    // สีข้อความส่วนหัว
                    titleTextStyle: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                    // สีปุ่มเปลี่ยนเดือน
                    leftChevronIcon:
                        Icon(Icons.chevron_left, color: Colors.blue),
                    rightChevronIcon:
                        Icon(Icons.chevron_right, color: Colors.blue),
                  ),
                  // ปรับแต่งสีของหัวข้อวัน (จ-อา)
                  daysOfWeekStyle: const DaysOfWeekStyle(
                    weekdayStyle: TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                    ),
                    weekendStyle: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Map<String, int> getFilteredData() {
    if (_selectedPeriod == 'all') {
      // Create a new map to store the sorted data
      Map<String, int> sortedData = {};

      // Convert the dates to a list for sorting
      List<String> dates = _notificationCounts.keys.toList();

      // Sort dates in descending order (newest first)
      dates.sort((a, b) => b.compareTo(a));

      // Rebuild the map in sorted order
      for (String date in dates) {
        sortedData[date] = _notificationCounts[date]!;
      }

      return sortedData;
    }

    // For specific date selection, no need to sort as it's just one date
    Map<String, int> filtered = {};
    _notificationCounts.forEach((dateStr, count) {
      if (dateStr == _selectedPeriod) {
        filtered[dateStr] = count;
      }
    });

    return filtered;
  }

  List<FlSpot> getChartData() {
    List<FlSpot> spots = [];
    if (_selectedDay == null) return spots;

    // เริ่มนับจากวันที่ผู้ใช้เลือก ย้อนหลังไป 7 วัน
    DateTime startDate = _selectedDay!.subtract(const Duration(days: 6));

    // สร้างจุดข้อมูลสำหรับแต่ละวัน
    for (int i = 0; i < 7; i++) {
      DateTime currentDate = startDate.add(Duration(days: i));
      String formattedDate =
          "${currentDate.year}-${currentDate.month.toString().padLeft(2, '0')}-${currentDate.day.toString().padLeft(2, '0')}";

      // ถ้ามีข้อมูลในวันนั้น ให้ใช้ค่าจริง ถ้าไม่มีให้ใช้ 0
      double value = _notificationCounts[formattedDate]?.toDouble() ?? 0;
      spots.add(FlSpot(i.toDouble(), value));
    }

    return spots;
  }

// เพิ่มเมธอดสำหรับสร้างชื่อวันที่ในแกน X
  List<String> getChartLabels() {
    List<String> labels = [];
    if (_selectedDay == null) return labels;

    // เริ่มนับจากวันที่ผู้ใช้เลือก ย้อนหลังไป 7 วัน
    DateTime startDate = _selectedDay!.subtract(const Duration(days: 6));

    // สร้างชื่อวันในรูปแบบ "dd/MM"
    for (int i = 0; i < 7; i++) {
      DateTime currentDate = startDate.add(Duration(days: i));
      String shortDate = "${currentDate.day}/${currentDate.month}";
      labels.add(shortDate);
    }

    return labels;
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    Map<String, int> filteredData = getFilteredData();
    bool isCurrentDate = _selectedPeriod == 'all' ||
        _selectedPeriod == DateTime.now().toString().split(' ')[0];

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.all(16),
              height: size.height * 0.75,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.all(Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(.5),
                    spreadRadius: 10,
                    blurRadius: 20,
                    offset: const Offset(0, 0),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : filteredData.isEmpty
                          ? const Center(
                              child: Text(
                                'ไม่พบข้อมูลประวัติการแจ้งเตือน',
                                style: TextStyle(
                                  color: Colors.black54,
                                  fontSize: 16,
                                ),
                              ),
                            )
                          : ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.only(top: 200),
                              itemCount: filteredData.length,
                              itemBuilder: (context, index) {
                                String date =
                                    filteredData.keys.elementAt(index);
                                int count = filteredData[date]!;
                                return GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            CausePage(date: date),
                                      ),
                                    );
                                  },
                                  child: buildHistoryItem(
                                    date: date,
                                    count: count.toString(),
                                  ),
                                );
                              },
                            ),
                  if (_showMenu)
                    if (_showChart && _selectedDay != null)
                      Positioned(
                        top: 10,
                        left: 10,
                        right: 10,
                        height: 180,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.2),
                                spreadRadius: 2,
                                blurRadius: 1,
                                offset: const Offset(0, 0),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding:
                                    EdgeInsets.only(left: 8.0, bottom: 8.0),
                                child: Text(
                                  'การแจ้งเตือนย้อนหลัง 7 วัน',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Expanded(
                                child: LineChart(
                                  LineChartData(
                                    gridData: FlGridData(
                                      show: true,
                                      drawVerticalLine: true,
                                      horizontalInterval: 1,
                                      verticalInterval: 1,
                                      getDrawingHorizontalLine: (value) {
                                        return FlLine(
                                          color: Colors.grey.withOpacity(0.2),
                                          strokeWidth: 1,
                                        );
                                      },
                                      getDrawingVerticalLine: (value) {
                                        return FlLine(
                                          color: Colors.grey.withOpacity(0.2),
                                          strokeWidth: 1,
                                        );
                                      },
                                    ),
                                    titlesData: FlTitlesData(
                                      show: true,
                                      rightTitles: AxisTitles(
                                        sideTitles:
                                            SideTitles(showTitles: false),
                                      ),
                                      topTitles: AxisTitles(
                                        sideTitles:
                                            SideTitles(showTitles: false),
                                      ),
                                      bottomTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          getTitlesWidget: (value, meta) {
                                            List<String> labels =
                                                getChartLabels();
                                            if (value.toInt() < 0 ||
                                                value.toInt() >=
                                                    labels.length) {
                                              return const Text('');
                                            }
                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                  top: 8.0),
                                              child: Text(
                                                labels[value.toInt()],
                                                style: const TextStyle(
                                                  color: Colors.black54,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 10,
                                                ),
                                              ),
                                            );
                                          },
                                          reservedSize: 30,
                                        ),
                                      ),
                                      leftTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          getTitlesWidget: (value, meta) {
                                            return Text(
                                              value.toInt().toString(),
                                              style: const TextStyle(
                                                color: Colors.black54,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 10,
                                              ),
                                            );
                                          },
                                          reservedSize: 28,
                                        ),
                                      ),
                                    ),
                                    borderData: FlBorderData(
                                      show: true,
                                      border: Border.all(
                                          color: Colors.grey.withOpacity(0.2)),
                                    ),
                                    minX: 0,
                                    maxX: 6,
                                    minY: 0,
                                    lineBarsData: [
                                      LineChartBarData(
                                        spots: getChartData(),
                                        isCurved: true,
                                        color: Colors.green,
                                        barWidth: 3,
                                        isStrokeCapRound: true,
                                        dotData: FlDotData(
                                          show: true,
                                          getDotPainter:
                                              (spot, percent, barData, index) {
                                            return FlDotCirclePainter(
                                              radius: 4,
                                              color: Colors.green,
                                              strokeWidth: 1,
                                              strokeColor: Colors.white,
                                            );
                                          },
                                        ),
                                        belowBarData: BarAreaData(
                                          show: true,
                                          color: Colors.green.withOpacity(0.2),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  // Calendar icon
                  if (_showMenu)
                    Positioned(
                      top: 5,
                      right: 10,
                      child: Row(
                        children: [
                          // Show Return to Today button only when not viewing current date
                          if (!isCurrentDate)
                            Container(
                              margin: const EdgeInsets.only(right: 10),
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _selectedDay = DateTime.now();
                                    _focusedDay = DateTime.now();
                                    _selectedPeriod =
                                        DateTime.now().toString().split(' ')[0];
                                  });
                                },
                                icon: const Icon(Icons.today, size: 18),
                                label: const Text('วันนี้'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 0,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                              ),
                            ),
                          IconButton(
                            icon: const Icon(Icons.calendar_today,
                                size: 30, color: Colors.blue),
                            onPressed: _showCalendarDialog,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildHistoryItem({
    required String date,
    required String count,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(10)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(.2),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 5,
            height: 60,
            decoration: const BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(10),
                bottomLeft: Radius.circular(10),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Stack(
              children: [
                // The main content (date and other UI elements)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Date',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Text(
                          date,
                          style: const TextStyle(
                            color: Colors.green,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                // The count label, adjusted higher using Positioned
                Positioned(
                  top: 14, // Adjust the 'top' property to move it up or down
                  right: 0,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      "$count ครั้ง",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}