import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../sensor_service.dart';
import 'login_view.dart';
import '../main.dart';

class AuthWrapper extends StatelessWidget {
  final SensorService sensors;
  const AuthWrapper({super.key, required this.sensors});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Color(0xFF2563EB).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: CircularProgressIndicator(
                      color: Color(0xFF2563EB),
                      strokeWidth: 3,
                    ),
                  ),
                  SizedBox(height: 20),
                  Text(
                    "Loading Chetna...",
                    style: TextStyle(fontSize: 16, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
          );
        }

        if (snapshot.hasData) {
          return ChetnaDashboardWrapper(sensors: sensors);
        }

        return LoginPage(sensorService: sensors);
      },
    );
  }
}
