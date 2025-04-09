import 'package:driver/insee/SettingCustom.dart';
import 'package:driver/insee/camera.dart';
import 'package:driver/insee/detection.dart';
import 'package:driver/insee/setting.dart';
import 'package:driver/insee/welcome.dart';
import 'package:driver/outsee/complete.dart';
import 'package:driver/outsee/home.dart';
import 'package:driver/insee/profile_edit.dart';
import 'package:driver/insee/root.dart';
import 'package:driver/outsee/login.dart';
import 'package:driver/insee/profile.dart';
import 'package:driver/outsee/register.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home:  Home(),
      routes: {
        'home': (context) => const Home(),
        'register': (context) => const RegisterScreen(),
        'login': (context) => const LoginScreen(),
        'profile': (context) => const ProfilePage(),
        'profile_edit': (context) => const ProfileEdit(
              userID: '',
              username: '',
              name: '',
              email: '',
              phone: '',
              userData: {},
            ),
        'root': (context) => const Root(
              userID: '',
            ),
        'complete': (context) => const Complete(),
        'StartCamera': (context) => const StartCamera(isVisible: true),
        'CameraPage': (context) => const CameraPage(),
        'Setting': (context) => const Setting(),
        'SettingCustom': (context) => const SettingCustom(),
        'welcome': (context) => Welcome()
      },
    );
  }
}
