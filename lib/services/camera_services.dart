import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';

class CameraService {
  CameraController? _controller;
  bool _isInitialized = false;

  Future<void> initialize() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) throw Exception('Camera permission denied');

    final cameras = await availableCameras();
    if (cameras.isEmpty) throw Exception('No cameras found');

    // ultraHigh maps to 4K on supported devices
    _controller = CameraController(
      cameras.first,
      ResolutionPreset.ultraHigh,
      enableAudio: true,
    );

    await _controller!.initialize();
    _isInitialized = true;
  }

  CameraController? get controller => _isInitialized ? _controller : null;
  bool get isInitialized => _isInitialized;

  Future<XFile?> takePicture() async {
    if (!_isInitialized) return null;
    return await _controller!.takePicture();
  }

  Future<void> startVideoRecording(String path) async {
    if (!_isInitialized) return;
    await _controller!.startVideoRecording();
  }

  Future<XFile?> stopVideoRecording() async {
    if (!_isInitialized) return null;
    return await _controller!.stopVideoRecording();
  }

  void dispose() {
    _controller?.dispose();
    _isInitialized = false;
  }
}