import 'package:driver/insee/camera.dart';
import 'package:driver/insee/history.dart';
import 'package:driver/insee/setting.dart';
import 'package:flutter/material.dart';
import 'package:animated_bottom_navigation_bar/animated_bottom_navigation_bar.dart';
import 'package:driver/insee/profile.dart';

class Root extends StatefulWidget {
  final String userID;
  final int initialIndex;
  const Root({super.key, required this.userID, this.initialIndex = 0});

  @override
  State<Root> createState() => _RootState();
}

class _RootState extends State<Root> {
  late int _bottomNavIndex;

  @override
  void initState() {
    super.initState();
    _bottomNavIndex = widget.initialIndex;
  }

  List<Widget> page = [
    const StartCamera(isVisible: true),
    const History(),
    const ProfilePage(),
    const Setting(),
  ];

  List<IconData> iconList = [
    Icons.camera,
    Icons.history,
    Icons.person,
    Icons.settings,
  ];

  List<String> titleList = [
    'Camera',
    'History',
    'Profile',
    'Setting',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        automaticallyImplyLeading: false,
        title: Text(
          titleList[_bottomNavIndex],
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w500,
            fontSize: 24,
          ),
        ),
      ),
      body: IndexedStack(
        index: _bottomNavIndex,
                children: [
          StartCamera(isVisible: _bottomNavIndex == 0),  // ส่ง prop isVisible
          const History(),
          const ProfilePage(),
          const Setting(),
        ],
      ),
      bottomNavigationBar: AnimatedBottomNavigationBar.builder(
        itemCount: iconList.length,
        tabBuilder: (int index, bool isActive) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius:
                      BorderRadius.circular(50), // ทำให้ Ripple เป็นวงกลม
                  splashColor:
                      Colors.white.withOpacity(0.3), // เอฟเฟกต์กดสีขาวจางๆ
                  highlightColor:
                      Colors.white.withOpacity(0.2), // สีเมื่อกดค้าง
                  child: Padding(
                    padding: const EdgeInsets.all(
                        1), // เพิ่มพื้นที่ให้ Ripple ใหญ่ขึ้น
                    child: Icon(
                      iconList[index],
                      size: isActive ? 50 : 40, // ไอคอนขยายขณะกด
                      color: isActive ? Colors.green : Colors.white,
                    ),
                  ),
                ),
              ),
              Text(
                titleList[index],
                style: TextStyle(
                  color: isActive ? Colors.green : Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          );
        },
        backgroundColor: Colors.blue,
        splashColor: Colors.white,
        activeIndex: _bottomNavIndex,
        gapLocation: GapLocation.none,
        notchSmoothness: NotchSmoothness.smoothEdge,
        height: 75,
        onTap: (index) {
          setState(() {
            _bottomNavIndex = index;
          });
        },
      ),
    );
  }
}