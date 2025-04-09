import 'package:driver/global_user.dart';
import 'package:driver/insee/root.dart';
import 'package:driver/insee/setting.dart';
import 'package:flutter/material.dart';

class SettingCustom extends StatefulWidget {
  const SettingCustom({super.key});

  @override
  State<SettingCustom> createState() => _SettingCustomState();
}

class _SettingCustomState extends State<SettingCustom> {
  bool isSwitchedOne = false;
  bool isSwitchedTwo = false;
  String selectedInterval = "ไม่เว้นช่วง";
  final List<String> intervals = [
    "ไม่เว้นช่วง",
    "2 นาที",
    "4 นาที",
    "6 นาที",
    "8 นาที",
    "10 นาที"
  ];
  final TextEditingController customIntervalController =
      TextEditingController();

  static String getIntervalString(NotificationInterval interval) {
    switch (interval) {
      case NotificationInterval.twoMin:
        return "2 นาที";
      case NotificationInterval.fourMin:
        return "4 นาที";
      case NotificationInterval.sixMin:
        return "6 นาที";
      case NotificationInterval.eightMin:
        return "8 นาที";
      case NotificationInterval.tenMin:
        return "10 นาที";
      default:
        return "ไม่เว้นช่วง";
    }
  }

  NotificationInterval parseInterval(String interval) {
    switch (interval) {
      case "2 นาที":
        return NotificationInterval.twoMin;
      case "4 นาที":
        return NotificationInterval.fourMin;
      case "6 นาที":
        return NotificationInterval.sixMin;
      case "8 นาที":
        return NotificationInterval.eightMin;
      case "10 นาที":
        return NotificationInterval.tenMin;
      default:
        return NotificationInterval.custom;
    }
  }

  void saveSettings() {
    setState(() {
      GlobalUser.notificationSettings = CustomNotificationSettings(
        isSoundEnabled: isSwitchedOne,
        isVibrationEnabled: isSwitchedTwo,
        interval: parseInterval(selectedInterval),
        customIntervalMinutes: selectedInterval.contains("นาที")
            ? int.tryParse(selectedInterval.replaceAll(" นาที", ""))
            : null,
      );
    });

    globalSelectedMode = NotificationMode.custom;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const Root(userID: ''),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 60, left: 20, right: 20),
              height: size.height * 0.8,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.all(Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(.2),
                    spreadRadius: 2,
                    blurRadius: 20,
                    offset: const Offset(0, 0),
                  ),
                ],
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Positioned(
                    top: 10,
                    left: 20,
                    child: Text(
                      'Custom Setting',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Positioned(
                    top: 50,
                    left: 30,
                    child: Text(
                      'โหมดการแจ้งเตือน',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const Positioned(
                    top: 80,
                    left: 40,
                    child: Text(
                      'เสียง',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 105,
                    left: 40,
                    child: Transform.scale(
                      scale: 0.9,
                      child: Switch(
                        value: isSwitchedOne,
                        activeColor: Colors.green,
                        inactiveThumbColor: Colors.grey,
                        onChanged: (value) {
                          setState(() {
                            isSwitchedOne = value;
                          });
                        },
                      ),
                    ),
                  ),
                  const Positioned(
                    top: 150,
                    left: 40,
                    child: Text(
                      'สั่น',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 175,
                    left: 40,
                    child: Transform.scale(
                      scale: 0.9,
                      child: Switch(
                        value: isSwitchedTwo,
                        activeColor: Colors.green,
                        inactiveThumbColor: Colors.grey,
                        onChanged: (value) {
                          setState(() {
                            isSwitchedTwo = value;
                          });
                        },
                      ),
                    ),
                  ),
                  const Positioned(
                    top: 220,
                    left: 30,
                    child: Text(
                      'กำหนดช่วงเวลาในการตรวจจับ',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 260,
                    left: 40,
                    right: 40,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButton<String>(
                        value: selectedInterval,
                        isExpanded: true,
                        underline: const SizedBox(),
                        items: intervals.map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                        onChanged: (newValue) {
                          setState(() {
                            selectedInterval = newValue!;
                          });
                        },
                        dropdownColor: Colors.white,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 80,
                    left: 100,
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pop(context, false);
                      },
                      child: Container(
                        height: 40,
                        width: 120,
                        decoration: const BoxDecoration(
                          color: Colors.grey,
                          borderRadius: BorderRadius.all(Radius.circular(20)),
                        ),
                        child: const Center(
                          child: Text(
                            'ย้อนกลับ',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 30,
                    left: 100,
                    child: GestureDetector(
                      onTap: () {
                        saveSettings();
                      },
                      child: Container(
                        height: 40,
                        width: 120,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.all(Radius.circular(20)),
                        ),
                        child: const Center(
                          child: Text(
                            'บันทึก',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
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
}