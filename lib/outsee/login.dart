import 'package:driver/outsee/home.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:driver/global_user.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _loginState();
}

class _loginState extends State<LoginScreen> {
  final formKey = GlobalKey<FormState>();
  final TextEditingController username = TextEditingController();
  final TextEditingController password = TextEditingController();

  Future<void> sign_in() async {
    final response = await http.post(
      Uri.parse('http://192.168.239.7:3000/login'),
      headers: <String, String>{
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'username': username.text,
        'password': password.text,
      }),
    );

    final data = jsonDecode(response.body);
    print('API Response: $data');

    if (data['status'] == 'success') {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Login Successful')));

      GlobalUser.userID = data['data']['UserID'].toString();

      Navigator.pushNamed(
        context,
        'welcome',
      );
    } else {
            ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Username or password is incorrect. Please try again.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
      body: SafeArea(
        child: Form(
          key: formKey,
          child: Container(
            padding: const EdgeInsets.only(top: 30, left: 20, right: 20),
            height: size.height,
            width: size.width,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Positioned(
                  top: 10,
                  left: 0,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pushReplacement(context,
                          MaterialPageRoute(builder: (_) => const Home()));
                    },
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      height: 30,
                      width: 30,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color.fromARGB(255, 236, 231, 231),
                            Color.fromARGB(255, 236, 231, 231),
                          ],
                          stops: [0.0, 1.0],
                          begin: FractionalOffset.topLeft,
                          end: FractionalOffset.bottomRight,
                        ),
                        borderRadius: BorderRadius.all(Radius.circular(5)),
                      ),
                      child: Image.asset('images/angle-left.png'),
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: 550,
                    child: RichText(
                      text: const TextSpan(
                        text: 'Welcome to Driver\n',
                        style: TextStyle(
                            fontSize: 30,
                            color: Colors.black,
                            fontWeight: FontWeight.w500),
                        children: <TextSpan>[
                          TextSpan(
                            text: 'Drowsiness Detection!',
                            style: TextStyle(
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  height: size.height * .6,
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
                          'Login Here',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 60,
                        left: 40,
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Transform.translate(
                                  offset: const Offset(-25, 0),
                                  child: const Icon(
                                    Icons.person,
                                    color: Colors.grey,
                                    size: 35,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.only(left: 0),
                                  width: 200,
                                  child: TextFormField(
                                    cursorColor: Colors.grey,
                                    style: const TextStyle(
                                      color: Colors.black54,
                                      fontSize: 18,
                                      letterSpacing: 1.4,
                                    ),
                                    decoration: const InputDecoration(
                                      border: InputBorder.none,
                                      hintText: 'Username',
                                      errorStyle: TextStyle(
                                        fontSize: 14,
                                        color: Colors.red,
                                      ),
                                    ),
                                    validator: (val) {
                                      if (val!.isEmpty) {
                                        return "is't Empty";
                                      }
                                      return null;
                                    },
                                    controller: username,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(
                              width: size.width * .7,
                              child: const Divider(
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        top: 140,
                        left: 40,
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Transform.translate(
                                  offset: const Offset(-25, 0),
                                  child: const Icon(
                                    Icons.key,
                                    color: Colors.grey,
                                    size: 35,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.only(left: 0),
                                  width: 200,
                                  child: TextFormField(
                                    obscureText: true,
                                    cursorColor: Colors.grey,
                                    style: const TextStyle(
                                      color: Colors.black54,
                                      fontSize: 18,
                                      letterSpacing: 1.4,
                                    ),
                                    decoration: const InputDecoration(
                                      border: InputBorder.none,
                                      hintText: 'Password',
                                      errorStyle: TextStyle(
                                        fontSize: 14,
                                        color: Colors.red,
                                      ),
                                    ),
                                    validator: (val) {
                                      if (val!.isEmpty) {
                                        return "is't Empty";
                                      }
                                      return null;
                                    },
                                    controller: password,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(
                              width: size.width * .7,
                              child: const Divider(
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        top: 220,
                        left: 120,
                        child: SizedBox(
                          width: size.width * .8,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TextButton(
                                onPressed: () {
                                  Navigator.pushNamed(context, 'register');
                                },
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  textStyle:
                                      const TextStyle(color: Colors.black54),
                                ),
                                child: const Text(
                                  "Didn't Have Any Account?",
                                  style: TextStyle(
                                    fontSize: 16, // กำหนดขนาดตัวหนังสือที่นี่
                                    color: Colors.blue, // สีตัวอักษร
                                    fontWeight:
                                        FontWeight.w400, // ความหนาของตัวอักษร
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 10,
                        left: 0,
                        right: 0,
                        child: Padding(
                          padding: const EdgeInsets.all(40.0),
                          child: GestureDetector(
                            onTap: () {
                              bool isValid = formKey.currentState!.validate();
                              if (isValid) {
                                sign_in();
                              }
                            },
                            child: Container(
                              height: 60,
                              decoration: const BoxDecoration(
                                color: Colors.blue,
                                borderRadius:
                                    BorderRadius.all(Radius.circular(10)),
                              ),
                              child: const Center(
                                child: Text(
                                  'Login',
                                  style: TextStyle(
                                    fontSize: 20,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
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
        ),
      ),
    );
  }
}
