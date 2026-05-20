import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/camera_services.dart';
import '../services/iot_service.dart';


class CameraControlScreen extends StatefulWidget {
  @override
  State<CameraControlScreen> createState() => _CameraControlScreenState();
}

class _CameraControlScreenState extends State<CameraControlScreen> {
  final _cameraService = CameraService();

  @override
  void initState() {
    super.initState();
    _cameraService.initialize().then((_) {
      if (mounted) setState(() {});
    }).catchError((e) => debugPrint('Camera init failed: $e'));
  }

  @override
  void dispose() {
    _cameraService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lightService = context.watch<LightIotService>();

    if (!_cameraService.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      body: Stack(
        children: [
          // Camera Preview
          Positioned.fill(
            child: CameraPreview(_cameraService.controller!),
          ),
          // Bottom Controls
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.all(16),
              color: Colors.black54,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Brightness Slider
                  Row(
                    children: [
                      const Icon(Icons.lightbulb, color: Colors.yellow),
                      Expanded(
                        child: Slider(
                          value: lightService.brightness.toDouble(),
                          max: 100,
                          divisions: 100,
                          label: '${lightService.brightness}%',
                          onChanged: lightService.isConnected
                              ? (v) => lightService.setBrightness(v.round())
                              : null,
                        ),
                      ),
                      Text(
                        lightService.isConnected ? 'Connected' : 'Offline',
                        style: TextStyle(
                          color: lightService.isConnected ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                  // Capture Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _cameraService.takePicture(),
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Photo'),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          // Implement video recording with path_provider
                        },
                        icon: const Icon(Icons.videocam),
                        label: const Text('Video'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}