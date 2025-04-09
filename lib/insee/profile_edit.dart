import 'package:flutter/material.dart';
import 'package:driver/insee/root.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:driver/global_user.dart';

class ProfileEdit extends StatefulWidget {
  final Map<String, dynamic> userData;

  const ProfileEdit(
      {super.key,
      required this.userData,
      required String userID,
      required String username,
      required String name,
      required String email,
      required String phone});

  @override
  _ProfileEditState createState() => _ProfileEditState();
}

class _ProfileEditState extends State<ProfileEdit> {
  TextEditingController nameController = TextEditingController();
  TextEditingController gmailController = TextEditingController();
  TextEditingController phoneController = TextEditingController();
  TextEditingController usernameController =
      TextEditingController(); // เพิ่มการประกาศ controller สำหรับ username
  Map<String, dynamic>? userData;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();

    // กำหนดค่าเริ่มต้นของ TextEditingController จาก userData
    nameController.text = widget.userData['name'] ?? '';
    gmailController.text = widget.userData['email'] ?? '';
    phoneController.text = widget.userData['phone'] ?? '';
  }

Future<void> fetchProfile() async {
  final userID = GlobalUser.userID;
  try {
    final response = await http.get(
      Uri.parse('http://192.168.239.7:3000/profile?ID=${GlobalUser.userID}'),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (mounted) { // ตรวจสอบว่า Widget ยังคง mount อยู่
        setState(() {
          userData = data;
          nameController.text = data['data']['name'] ?? '';
          gmailController.text = data['data']['email'] ?? '';
          phoneController.text = data['data']['phone'] ?? '';
          isLoading = false;
        });
      }
    } else {
      if (mounted) { // ตรวจสอบว่า Widget ยังคง mount อยู่
        setState(() {
          isLoading = false;
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่สามารถโหลดข้อมูลโปรไฟล์ได้')),
      );
    }
  } catch (e) {
    if (mounted) { // ตรวจสอบว่า Widget ยังคง mount อยู่
      setState(() {
        isLoading = false;
      });
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
    );
  }
}

Future<void> updateProfile() async {
  final userID = widget.userData['userID'] ?? GlobalUser.userID;
  final response = await http.put(
    Uri.parse('http://192.168.239.7:3000/profile_edit/$userID'),
    headers: <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
    },
    body: jsonEncode({
      'name': nameController.text,
      'email': gmailController.text,
      'phone': phoneController.text,
    }),
  );

  if (response.statusCode == 200) {
    if (mounted) { // ตรวจสอบว่า Widget ยังคง mount อยู่
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully')),
      );
      Navigator.pop(context, true);
    }
  } else {
    if (mounted) { // ตรวจสอบว่า Widget ยังคง mount อยู่
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update profile')),
      );
    }
  }
}

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    fetchProfile();
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
                    left: 30,
                    child: Text(
                      'Profile Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 50,
                    left: size.width * 0.1,
                    child: const CircleAvatar(
                      radius: 50,
                      backgroundImage: AssetImage('images/profile.jpg'),
                    ),
                  ),
                  Positioned(
                    top: 120,
                    left: 110,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(100),
                        color: Colors.yellow,
                      ),
                      child: const Icon(
                        Icons.edit,
                        color: Colors.black,
                        size: 20,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 170,
                    left: 20,
                    right: 20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius:
                            const BorderRadius.all(Radius.circular(10)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(.2),
                            spreadRadius: 2,
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Name',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 0),
                          TextField(
                            controller: nameController,
                            decoration: const InputDecoration(
                              hintText: 'Enter your name',
                              hintStyle:
                                  TextStyle(color: Colors.green, fontSize: 14),
                              border: InputBorder.none,
                            ),
                            style: const TextStyle(
                              color: Colors.green,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 260,
                    left: 20,
                    right: 20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius:
                            const BorderRadius.all(Radius.circular(10)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(.2),
                            spreadRadius: 2,
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Gmail',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 0),
                          TextField(
                            controller: gmailController,
                            decoration: const InputDecoration(
                              hintText: 'Enter your Gmail',
                              hintStyle:
                                  TextStyle(color: Colors.green, fontSize: 14),
                              border: InputBorder.none,
                            ),
                            style: const TextStyle(
                              color: Colors.green,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 350,
                    left: 20,
                    right: 20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius:
                            const BorderRadius.all(Radius.circular(10)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(.2),
                            spreadRadius: 2,
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Phone',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 0),
                          TextField(
                            controller: phoneController,
                            decoration: const InputDecoration(
                              hintText: 'Enter your phone number',
                              hintStyle:
                                  TextStyle(color: Colors.green, fontSize: 14),
                              border: InputBorder.none,
                            ),
                            style: const TextStyle(
                              color: Colors.green,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 60,
                    right: 40,
                    child: GestureDetector(
                      onTap: () {
                        updateProfile();
                      },
                      child: Container(
                        height: 30,
                        width: 110,
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
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 100,
                    right: 40,
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pop(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const Root(
                                    userID: '',
                                  )),
                        );
                      },
                      child: Container(
                        height: 30,
                        width: 110,
                        decoration: const BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.all(Radius.circular(20)),
                        ),
                        child: const Center(
                          child: Text(
                            'ย้อนกลับ',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
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

  @override
  void dispose() {
    nameController.dispose();
    gmailController.dispose();
    phoneController.dispose();
    super.dispose();
  }
}