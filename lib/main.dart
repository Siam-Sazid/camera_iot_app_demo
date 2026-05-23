import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/camera_control_screen.dart';
import 'services/iot_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LightIotService(),
      child: MaterialApp(
        title: 'Camera IoT Demo',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        ),
        home: CameraControlScreen(),
      ),
    );
  }
}
