import 'package:driver/insee/setting.dart';

class GlobalUser {
  static String? userID;
  static CustomNotificationSettings notificationSettings =
      CustomNotificationSettings();

  static void clear() {
    userID = null;
    notificationSettings = CustomNotificationSettings();
  }
}

bool isSafeMode = false; // โหมดปลอดภัย
bool isHighSafeMode = false; // โหมดปลอดภัยสูง
bool isCustomMode = false;
NotificationMode? globalSelectedMode;

enum NotificationInterval {
  none, // ไม่เว้นช่วง
  twoMin, // 2 นาที
  fourMin, // 4 นาที
  sixMin, // 6 นาที
  eightMin, // 8 นาที
  tenMin, // 10 นาที
  custom // กำหนดเอง
}

// คลาสสำหรับเก็บการตั้งค่าการแจ้งเตือนแบบกำหนดเอง
class CustomNotificationSettings {
  bool isSoundEnabled; // เปิด/ปิดเสียง
  bool isVibrationEnabled; // เปิด/ปิดการสั่น
  NotificationInterval interval; // ช่วงเวลาในการแจ้งเตือน
  int? customIntervalMinutes; // สำหรับกรณีกำหนดเวลาเอง

  CustomNotificationSettings({
    this.isSoundEnabled = true,
    this.isVibrationEnabled = true,
    this.interval = NotificationInterval.none,
    this.customIntervalMinutes,
  });
}