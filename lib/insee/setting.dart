import 'package:driver/global_user.dart';
import 'package:driver/insee/SettingCustom.dart';
import 'package:flutter/material.dart';
import 'package:driver/insee/root.dart';

class Setting extends StatefulWidget {
  const Setting({super.key});

  @override
  State<Setting> createState() => _SettingState();
}

class _SettingState extends State<Setting> {
  NotificationMode? selectedMode = NotificationMode.safe;

  get customIntervalMinutes => null;

  @override
  void initState() {
    super.initState();
    selectedMode = globalSelectedMode ?? NotificationMode.safe; // ถ้ามีค่าใน
  }

  void resetCustomMode() {
    setState(() {
      if (selectedMode == NotificationMode.custom) {
        selectedMode = NotificationMode.safe; // or any default mode you prefer
        globalSelectedMode = selectedMode;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            Stack(
              children: [
                Container(
                  margin: const EdgeInsets.all(16),
                  height: size.height * 0.7,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.all(Radius.circular(20)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.5),
                        spreadRadius: 10,
                        blurRadius: 20,
                        offset: const Offset(0, 0),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 30,
                  left: size.width * 0.1,
                  child: const Text(
                    'โหมดการแจ้งเตือน',
                    style: TextStyle(
                        color: Colors.black,
                        fontSize: 25,
                        fontWeight: FontWeight.w500),
                  ),
                ),
                Positioned(
                  top: 70,
                  left: size.width * 0.15,
                  child: const Text(
                    'ปลอดภัย',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 18,
                    ),
                  ),
                ),
                Positioned(
                  top: 73,
                  left: size.width * 0.35,
                  child: const Text(
                    '(เสียง)',
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 15,
                    ),
                  ),
                ),
                Positioned(
                  top: 95,
                  left: size.width * 0.15,
                  child: Transform.scale(
                    scale: 0.9,
                    child: Switch(
                      value: selectedMode == NotificationMode.safe,
                      activeColor: Colors.green,
                      inactiveThumbColor: Colors.grey,
                      onChanged: (value) {
                        setState(() {
                          if (value) {
                            selectedMode = NotificationMode.safe;
                          }
                        });
                      },
                    ),
                  ),
                ),
                Positioned(
                  top: 140,
                  left: size.width * 0.15,
                  child: const Text(
                    'ปลอดภัยสูง',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 18,
                    ),
                  ),
                ),
                Positioned(
                  top: 143,
                  left: size.width * 0.4,
                  child: const Text(
                    '(เสียงและสั่น)',
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 15,
                    ),
                  ),
                ),
                Positioned(
                  top: 165,
                  left: size.width * 0.15,
                  child: Transform.scale(
                    scale: 0.9,
                    child: Switch(
                      value: selectedMode == NotificationMode.highSafety,
                      activeColor: Colors.green,
                      inactiveThumbColor: Colors.grey,
                      onChanged: (value) {
                        setState(() {
                          if (value) {
                            selectedMode = NotificationMode.highSafety;
                          }
                        });
                      },
                    ),
                  ),
                ),
                Positioned(
                  top: 210,
                  left: size.width * 0.15,
                  child: const Text(
                    'กำหนดเอง',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 18,
                    ),
                  ),
                ),
                Positioned(
                  top: 213,
                  left: size.width * 0.36,
                  child: const Text(
                    '  (กำหนดช่วงเวลาตรวจจับ)',
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 15,
                    ),
                  ),
                ),
                Positioned(
                  top: 235,
                  left: size.width * 0.15,
                  child: Transform.scale(
                    scale: 0.9,
                    child: Switch(
                      value: selectedMode == NotificationMode.custom,
                      activeColor: Colors.green,
                      inactiveThumbColor: Colors.grey,
                      onChanged: (value) {
                        setState(() {
                          if (value) {
                            selectedMode = NotificationMode.custom;
                          }
                        });

                        if (value) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SettingCustom(),
                            ),
                          ).then((result) {
                            // If result is false (cancelled), reset the custom mode
                            if (result == false) {
                              resetCustomMode();
                            }
                          });
                        }
                      },
                    ),
                  ),
                ),
                if (selectedMode == NotificationMode.custom)
                  Positioned(
                    bottom: 125,
                    left: 50,
                    right: 50,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(255, 230, 230, 230),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.3),
                            spreadRadius: 2,
                            blurRadius: 10,
                            offset: const Offset(0, 0),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'เสียง',
                                style: TextStyle(
                                    fontSize: 16, color: Colors.black),
                              ),
                              // Replace the Switch with a non-interactive indicator
                              Container(
                                width: 50,
                                height: 30,
                                alignment: Alignment.centerRight,
                                child: GlobalUser
                                        .notificationSettings.isSoundEnabled
                                    ? const Icon(Icons.check_circle,
                                        color: Colors.green)
                                    : const Icon(Icons.cancel,
                                        color: Colors.red),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'สั่น',
                                style: TextStyle(
                                    fontSize: 16, color: Colors.black),
                              ),
                              // Replace the Switch with a non-interactive indicator
                              Container(
                                width: 50,
                                height: 30,
                                alignment: Alignment.centerRight,
                                child: GlobalUser
                                        .notificationSettings.isVibrationEnabled
                                    ? const Icon(Icons.check_circle,
                                        color: Colors.green)
                                    : const Icon(Icons.cancel,
                                        color: Colors.red),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'เว้นช่วงเวลาตรวจจับ ',
                                style: TextStyle(
                                    fontSize: 16, color: Colors.black),
                              ),
                              Text(
                                _getIntervalText(
                                    GlobalUser.notificationSettings.interval),
                                style: const TextStyle(
                                    fontSize: 16, color: Colors.green),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'กรุณาแตะปุ่มแก้ไขเพื่อปรับการตั้งค่า',
                            style: TextStyle(
                                fontSize: 13,
                                fontStyle: FontStyle.italic,
                                color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (selectedMode == NotificationMode.custom)
                  Positioned(
                    bottom: 270,
                    right: 45,
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SettingCustom(),
                            ) // Replace `NewPage` with your target page
                            );
                      },
                      child: Container(
                        width: 35,
                        height: 35,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(100),
                          color: Colors.yellow,
                        ),
                        child: const Icon(
                          Icons.edit,
                          color: Colors.black,
                          size: 25,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  bottom: 50,
                  left: 137,
                  child: GestureDetector(
                    onTap: () {
                      globalSelectedMode = selectedMode;
                      print("โหมดที่เลือก: $selectedMode");
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const Root(
                                  userID: '',
                                )),
                      );
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
                            fontSize: 16,
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
          ],
        ),
      ),
    );
  }

  String _getIntervalText(NotificationInterval interval) {
    switch (interval) {
      case NotificationInterval.none:
        return 'ไม่เว้นช่วง';
      case NotificationInterval.twoMin:
        return '2 นาที';
      case NotificationInterval.fourMin:
        return '4 นาที';
      case NotificationInterval.sixMin:
        return '6 นาที';
      case NotificationInterval.eightMin:
        return '8 นาที';
      case NotificationInterval.tenMin:
        return '10 นาที';
      case NotificationInterval.custom:
        return customIntervalMinutes != null
            ? '$customIntervalMinutes นาที'
            : 'ไม่เว้นช่วง';
    }
  }
}

enum NotificationMode { safe, highSafety, custom }