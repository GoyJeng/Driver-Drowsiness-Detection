import 'dart:convert';
import 'package:driver/global_user.dart';
import 'package:driver/insee/history.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

class CausePage extends StatefulWidget {
  final String date;

  const CausePage({super.key, required this.date});

  @override
  State<CausePage> createState() => _CausePageState();
}

class _CausePageState extends State<CausePage> {
  List<Map<String, dynamic>> _causes = [];
  Map<String, List<Map<String, dynamic>>> _groupedCauses = {};
  bool _isLoading = false;
  List<Map<String, dynamic>> _timePeriods = [];
  bool _showChart = false;
  Map<String, int> _hourlyNotifications = {};
  final ScrollController _scrollController = ScrollController();
  bool _showMenu = true;

  String formatTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return '';

    try {
      // Pattern: HH.mm.ss.000000 → 14.02.21.000000
      final regex = RegExp(r'^(\d{2})\.(\d{2})\.(\d{2})\.\d{6}$');
      final match = regex.firstMatch(timeStr);

      if (match != null) {
        final hour = match.group(1);
        final minute = match.group(2);
        return '$hour:$minute';  // Return only HH:MM format
      }

      // Pattern: HH:mm:ss → return HH:mm
      final colonRegex = RegExp(r'^(\d{2}):(\d{2}):(\d{2})$');
      final colonMatch = colonRegex.firstMatch(timeStr);
      if (colonMatch != null) {
        return '${colonMatch.group(1)}:${colonMatch.group(2)}';
      }

      // Try parse ISO string (handle ISO format that might end with microseconds)
      if (timeStr.contains('T') || timeStr.contains('Z') || timeStr.contains('+')) {
        final dateTime = DateTime.tryParse(timeStr);
        if (dateTime != null) {
          return DateFormat('HH:mm').format(dateTime);
        }
      }
      
      // Handle other formats that might contain milliseconds/microseconds
      if (timeStr.contains('.')) {
        // Remove everything after the last dot
        final parts = timeStr.split('.');
        if (parts.length > 1) {
          final mainPart = parts[0];
          // If it's already in HH:MM format
          if (mainPart.length == 5 && mainPart.contains(':')) {
            return mainPart;
          }
          // If it's in HH:MM:SS format
          if (mainPart.length == 8 && mainPart.contains(':')) {
            final timeParts = mainPart.split(':');
            return '${timeParts[0]}:${timeParts[1]}';
          }
        }
      }

      return timeStr; // If no pattern matches, return the original string
    } catch (e) {
      print('FormatTime Error: $e');
      return timeStr;
    }
  }

  Future<void> fetchCauses() async {
    setState(() => _isLoading = true);
    try {
      var userId = GlobalUser.userID;
      if (userId == null || userId.isEmpty) return;

      final response = await http.get(
        Uri.parse('http://192.168.239.7:3000/history?userId=$userId'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        Map<String, int> hourlyData = {};

        // Initialize hourly data with zeros
        for (int i = 0; i < 24; i++) {
          String hour = i.toString().padLeft(2, '0');
          hourlyData[hour] = 0;
        }

        // Filter causes for the selected date
        final causesForDate = List<Map<String, dynamic>>.from(
          data.where((notification) {
            String dateUtc = notification['date'] ?? 'Unknown';
            DateTime parsedDate = DateTime.parse(dateUtc).toLocal();
            String formattedDate =
                "${parsedDate.year}-${parsedDate.month.toString().padLeft(2, '0')}-${parsedDate.day.toString().padLeft(2, '0')}";
            
            if (formattedDate == widget.date) {
              // Extract hour from time for chart data
              String time = notification['time'] ?? '';
              if (time.isNotEmpty) {
                String hour = time.split(':')[0];
                hourlyData[hour] = (hourlyData[hour] ?? 0) + 1;
              }
              return true;
            }
            return false;
          }),
        );

        // Sort causes by time
        causesForDate.sort((a, b) {
          String timeA = a['time'] ?? '';
          String timeB = b['time'] ?? '';
          return timeA.compareTo(timeB);
        });

        setState(() {
          _causes = causesForDate;
          _hourlyNotifications = hourlyData;
          _showChart = true;
          _groupCausesByTimePeriods();
        });
      }
    } catch (e) {
      print('Error fetching causes: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> fetchUserTime() async {
    try {
      var userId = GlobalUser.userID;
      if (userId == null || userId.isEmpty) return;

      final response = await http.get(
        Uri.parse('http://192.168.239.7:3000/usertime?userId=$userId'),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        
        if (jsonData['status'] == 'success') {
          final List<dynamic> times = jsonData['data'];

          // Convert the times to a format we can use for grouping
          List<Map<String, dynamic>> periods = [];
          
          for (var time in times) {
            String startTime = time['starttime']?.toString() ?? '';
            String stopTime = time['stoptime']?.toString() ?? '';
            
            if (startTime.isNotEmpty) {
              periods.add({
                'startTime': formatTime(startTime),
                'stopTime': stopTime.isNotEmpty ? formatTime(stopTime) : null,
                'causes': <Map<String, dynamic>>[]
              });
            }
          }

          setState(() {
            _timePeriods = periods;
            _groupCausesByTimePeriods();
          });
        }
      }
    } catch (e) {
      print('Error fetching user time: $e');
    }
  }

  void _groupCausesByTimePeriods() {
    // Skip if either causes or time periods are not loaded yet
    if (_causes.isEmpty || _timePeriods.isEmpty) return;
    
    Map<String, List<Map<String, dynamic>>> groupedMap = {};
    
    // First, create a map entry for each time period
    for (var period in _timePeriods) {
      String startTime = period['startTime'];
      String stopTime = period['stopTime'] ?? '';
      String periodKey = '$startTime - $stopTime';
      
      groupedMap[periodKey] = [];
    }
    
    // If we have no time periods, create a default one
    if (_timePeriods.isEmpty && _causes.isNotEmpty) {
      groupedMap['All Notifications'] = _causes;
    } else {
      // For each cause, find which time period it belongs to
      for (var cause in _causes) {
        String causeTime = formatTime(cause['time']);
        bool assigned = false;
        
        for (var period in _timePeriods) {
          String startTime = period['startTime'];
          String stopTime = period['stopTime'] ?? '';
          
          if (stopTime.isEmpty) {
            // If there's no end time, put all remaining causes here
            String periodKey = '$startTime - $stopTime';
            groupedMap[periodKey]?.add(cause);
            assigned = true;
            break;
          } else if (_isTimeInRange(causeTime, startTime, stopTime)) {
            String periodKey = '$startTime - $stopTime';
            groupedMap[periodKey]?.add(cause);
            assigned = true;
            break;
          }
        }
        
        // If the cause wasn't assigned to any period, put it in "Other"
        if (!assigned) {
          groupedMap['Other'] = groupedMap['Other'] ?? [];
          groupedMap['Other']?.add(cause);
        }
      }
    }
    
    setState(() {
      _groupedCauses = groupedMap;
    });
  }

  bool _isTimeInRange(String time, String start, String end) {
    // Simple string comparison for HH:MM format
    return time.compareTo(start) >= 0 && time.compareTo(end) <= 0;
  }

  List<FlSpot> getChartData() {
    List<FlSpot> spots = [];

    // เรียงลำดับตามชั่วโมง (0-23)
    List<String> sortedHours = _hourlyNotifications.keys.toList()..sort();

    for (int i = 0; i < sortedHours.length; i++) {
      String hour = sortedHours[i];
      double value = _hourlyNotifications[hour]?.toDouble() ?? 0;
      spots.add(FlSpot(double.parse(hour), value));
    }

    return spots;
  }

  @override
  void initState() {
    super.initState();
    fetchCauses();
    fetchUserTime();
    _scrollController.addListener(_onScroll);
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

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Cause',
            style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Chart section - Collapsible
          if (_showChart && !_isLoading && _showMenu)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
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
              height: 180,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
                    child: Text(
                      'การแจ้งเตือนตามช่วงเวลาวันที่ ${widget.date}',
                      style: const TextStyle(
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
                          verticalInterval: 2,
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
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                if (value % 4 == 0 && value < 24) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Text(
                                      '${value.toInt()}:00',
                                      style: const TextStyle(
                                        color: Colors.black54,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10,
                                      ),
                                    ),
                                  );
                                }
                                return const Text('');
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
                          border: Border.all(color: Colors.grey.withOpacity(0.2)),
                        ),
                        minX: 0,
                        maxX: 23,
                        minY: 0,
                        lineBarsData: [
                          LineChartBarData(
                            spots: getChartData(),
                            isCurved: true,
                            color: Colors.blue,
                            barWidth: 3,
                            isStrokeCapRound: true,
                            dotData: FlDotData(
                              show: true,
                              getDotPainter: (spot, percent, barData, index) {
                                return FlDotCirclePainter(
                                  radius: 4,
                                  color: Colors.blue,
                                  strokeWidth: 1,
                                  strokeColor: Colors.white,
                                );
                              },
                            ),
                            belowBarData: BarAreaData(
                              show: true,
                              color: Colors.blue.withOpacity(0.2),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Grouped causes section
Expanded(
  child: _isLoading
      ? const Center(child: CircularProgressIndicator())
      : _groupedCauses.isEmpty
          ? const Center(child: Text('No causes found'))
          : ListView(
              controller: _scrollController,
              children: [
                // Render each time period with its causes
                ..._groupedCauses.entries.map((entry) {
                  final periodKey = entry.key;
                  final causes = entry.value;
                  
                  if (causes.isEmpty) return Container();
                  
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Time period header
                      // Container for all causes in this period
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.3),
                              spreadRadius: 5,
                              blurRadius: 10,
                              offset: const Offset(0, 2),)
                          ],
                        ),
                        child: Column(
                          children: [
                            // เวลาเริ่มต้นและสิ้นสุด
                            Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'เวลาเริ่มต้น: ${periodKey.split(' - ')[0]}',
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                  Text(
                                    'เวลาสิ้นสุด: ${periodKey.split(' - ')[1]}',
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ),
                            // เส้นคั่น
                            const Divider(height: 1, color: Colors.grey),
                            // รายการสาเหตุทั้งหมดในช่องเดียวกัน
                            ...causes.map((cause) => buildCauseItem(cause)).toList(),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ],
            ),
),
        ],
      ),
    );
  }

  Widget buildCauseItem(Map<String, dynamic> cause) {
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
              color: Colors.blue,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(10),
                bottomLeft: Radius.circular(10),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'No. ${cause['notiID']}',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      'เวลา  : ${cause['time']}',
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                RichText(
                  text: TextSpan(
                    children: [
                      const TextSpan(
                        text: 'สาเหตุ : ',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 18,
                        ),
                      ),
                      TextSpan(
                        text: '${cause['cause']}',
                        style: const TextStyle(
                          color: Colors.blue,
                          fontSize: 18,
                        ),
                      ),
                    ],
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