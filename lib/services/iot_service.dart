import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';


class LightIotService extends ChangeNotifier {
  MqttServerClient? _client;
  int _brightness = 50; // 0-100
  bool _isConnected = false;

  int get brightness => _brightness;
  bool get isConnected => _isConnected;

  Future<void> connect(String brokerUrl, String clientId) async {
    _client = MqttServerClient(brokerUrl, clientId);
    _client!.port = 1883;
    _client!.keepAlivePeriod = 20;
    _client!.logging(on: false);
    _client!.onConnected = _onConnected;
    _client!.onDisconnected = _onDisconnected;
    _client!.onSubscribed = _onSubscribed;

    final connMessage = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);

    _client!.connectionMessage = connMessage;

    try {
      await _client!.connect();
    } catch (e) {
      print('MQTT connection failed: $e');
      _isConnected = false;
      notifyListeners();
    }
  }

  void _onConnected() {
    _isConnected = true;
    _client!.subscribe('home/light/brightness/state', MqttQos.atLeastOnce);
    notifyListeners();
  }

  void _onDisconnected() {
    _isConnected = false;
    notifyListeners();
  }

  void _onSubscribed(String topic) {
    print('Subscribed to: $topic');
  }

  // Publish brightness command (0-255 or 0-100 depending on your bulb)
  Future<void> setBrightness(int value) async {
    if (!_isConnected) return;
    final builder = MqttClientPayloadBuilder();
    builder.addString(value.toString());
    _client!.publishMessage('home/light/brightness/set', MqttQos.atLeastOnce, builder.payload!);
    _brightness = value;
    notifyListeners();
  }

  void disconnect() {
    _client?.disconnect();
    _isConnected = false;
  }
}