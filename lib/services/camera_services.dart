import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';

class CameraService {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isInitialized = false;

  CameraController? get controller => _isInitialized ? _controller : null;
  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) throw Exception('Camera permission denied');

    _cameras = await availableCameras();
    if (_cameras.isEmpty) throw Exception('No cameras found');

    await _reinitController(ResolutionPreset.high);
  }

  Future<void> _reinitController(ResolutionPreset preset) async {
    await _controller?.dispose();
    _isInitialized = false;
    _controller = CameraController(
      _cameras.first,
      preset,
      enableAudio: true,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    await _controller!.initialize();
    _isInitialized = true;
  }

  Future<void> switchResolution(ResolutionPreset preset) =>
      _reinitController(preset);

  Future<void> pause() async {
    await _controller?.dispose();
    _controller = null;
    _isInitialized = false;
  }

  Future<void> resume() async {
    if (_cameras.isEmpty) return;
    await _reinitController(ResolutionPreset.high);
  }

  Future<XFile?> takePicture() async {
    if (!_isInitialized) return null;
    return await _controller!.takePicture();
  }

  Future<void> startVideoRecording() async {
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
