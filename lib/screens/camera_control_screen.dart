import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../services/camera_services.dart';
import '../services/iot_service.dart';

class CameraControlScreen extends StatefulWidget {
  @override
  State<CameraControlScreen> createState() => _CameraControlScreenState();
}

class _CameraControlScreenState extends State<CameraControlScreen>
    with WidgetsBindingObserver {
  final _cameraService = CameraService();
  bool _isRecording = false;
  bool _isSwitching = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cameraService.initialize().then((_) {
      if (mounted) setState(() {});
    }).catchError((e) => debugPrint('Camera init failed: $e'));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      if (_isRecording) {
        _cameraService.stopVideoRecording();
        _isRecording = false;
      }
      _cameraService.pause().then((_) {
        if (mounted) setState(() {});
      });
    } else if (state == AppLifecycleState.resumed) {
      _cameraService.resume().then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  Future<void> _switchResolution(ResolutionPreset preset) async {
    setState(() => _isSwitching = true);
    await _cameraService.switchResolution(preset);
    if (mounted) setState(() => _isSwitching = false);
  }

  Future<String> _saveToDocuments(XFile src, String prefix, String ext) async {
    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final dest = '${dir.path}/${prefix}_$timestamp.$ext';
    await src.saveTo(dest);
    return dest;
  }

  Future<void> _takePhoto() async {
    await _switchResolution(ResolutionPreset.ultraHigh);
    final file = await _cameraService.takePicture();
    await _switchResolution(ResolutionPreset.high);
    if (file == null || !mounted) return;
    final path = await _saveToDocuments(file, 'IMG', 'jpg');
    await Gal.putImage(path);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo saved to gallery')),
      );
    }
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      final file = await _cameraService.stopVideoRecording();
      await _switchResolution(ResolutionPreset.high);
      if (!mounted) return;
      setState(() => _isRecording = false);
      if (file == null) return;
      final path = await _saveToDocuments(file, 'VID', 'mp4');
      await Gal.putVideo(path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Video saved to gallery')),
        );
      }
    } else {
      await _switchResolution(ResolutionPreset.ultraHigh);
      if (!mounted) return;
      await _cameraService.startVideoRecording();
      if (mounted) setState(() => _isRecording = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lightService = context.watch<LightIotService>();

    if (!_cameraService.isInitialized || _isSwitching) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: CameraPreview(_cameraService.controller!),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.all(16),
              color: Colors.black54,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                          color: lightService.isConnected
                              ? Colors.green
                              : Colors.red,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _takePhoto,
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Photo'),
                      ),
                      ElevatedButton.icon(
                        onPressed: _toggleRecording,
                        icon: Icon(_isRecording ? Icons.stop : Icons.videocam),
                        label: Text(_isRecording ? 'Stop' : 'Video'),
                        style: _isRecording
                            ? ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              )
                            : null,
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
