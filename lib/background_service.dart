import 'dart:async';
import 'dart:ui';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:vosk_flutter_2/vosk_flutter_2.dart';


Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      isForegroundMode: true,
      autoStart: true,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onStart,
    ),
  );

  await service.startService();
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) {
  DartPluginRegistrant.ensureInitialized();

  () async {
    final vosk = VoskFlutterPlugin.instance();
    final modelPath = await ModelLoader().loadFromAssets('assets/models/vosk-model-small-en-us-0.15.zip');
    final model = await vosk.createModel(modelPath);

    final recognizer = await vosk.createRecognizer(
      model: model,
      sampleRate: 16000,
      grammar: ['hi vision start recording', 'vision stop recording'],
    );

    final speechService = await vosk.initSpeechService(recognizer);

    speechService.onResult().forEach((result) {
      print("Result: $result");
      if (result.contains("hi vision start recording")) {
        service.invoke("startRecording");
      } else if (result.contains("vision stop recording")) {
        service.invoke("stopRecording");
      }
    });

    service.on("stopService").listen((event) {
      service.stopSelf();
      speechService.stop();
    });

    await speechService.start();
  }();
}