import 'package:driver/insee/root.dart';
import 'package:flutter/material.dart';

class Welcome extends StatelessWidget {
  final Color _iconColor = Colors.white;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Logo and text in a tight column
              Column(
                children: [
                      Image.asset(
                        'images/logoapp.png',
                        width: 250,
                      ),
                      const Text(
                        'Driver Drowsiness Detection',
                        style: TextStyle(
                            fontSize: 25,
                            color: Colors.black,
                            fontWeight: FontWeight.w600
                        ),
                      ),
                    ],
              ),
              const SizedBox(height: 20), 
              GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 20,
                mainAxisSpacing: 20,
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                children: [
                  _buildGridItem(
                    icon: Icons.camera,
                    color: _iconColor,
                    title: 'Camera',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const Root(userID: '', initialIndex: 0),
                        ),
                      );
                    },
                  ),
                  _buildGridItem(
                    icon: Icons.history,
                    color: _iconColor,
                    title: 'History',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const Root(userID: '', initialIndex: 1),
                        ),
                      );
                    },
                  ),
                  _buildGridItem(
                    icon: Icons.person,
                    color: _iconColor,
                    title: 'Profile',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const Root(userID: '', initialIndex: 2),
                        ),
                      );
                    },
                  ),
                  _buildGridItem(
                    icon: Icons.settings,
                    color: _iconColor,
                    title: 'Setting',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const Root(userID: '', initialIndex: 3),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGridItem({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.blue,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Colors.white,
              offset: Offset(0, 4),
              blurRadius: 5.0,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 80,
              color: color,
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}