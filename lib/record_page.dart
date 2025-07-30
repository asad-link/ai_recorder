import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

import 'background_service.dart';

class RecordPage extends StatefulWidget {
  const RecordPage({super.key});

  @override
  State<RecordPage> createState() => _RecordPageState();
}

class _RecordPageState extends State<RecordPage> {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final FlutterSoundPlayer _player = FlutterSoundPlayer();
  bool isRecording = false;
  bool isRecorderInitialize = false;
  int _elapsedSeconds = 0;
  String? _currentlyPlayingPath;
  bool _isPlaying = false;
  Timer? _timer;
  List<FileSystemEntity> _recordings = [];
  Directory? _recordingDirectory;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    permissionHandler();
    Directory dir = Directory('/storage/emulated/0/Download/MyRecordings');
    if (!await dir.exists()) await dir.create(recursive: true);
    _recordingDirectory = dir;
    _loadRecordings();
  }

  Future<void> permissionHandler() async {
    var status = await Permission.microphone.status;
    if (status.isDenied || status.isPermanentlyDenied) {
      status = await Permission.microphone.request();
    }
    if (status.isGranted) {
      print("Microphone permission granted");
      _recorder.openRecorder();
      setState(() {
        isRecorderInitialize = true;
      });
    } else if (status.isPermanentlyDenied) {
      print("Permission permanently denied, please enable it from settings");
      openAppSettings();
    } else {
      print("Microphone permission denied");
    }
  }

  Future<void> _startRecording() async {
    if (isRecorderInitialize && !isRecording) {
      await permissionHandler();
      if (await Permission.microphone.isGranted) {
        String fileName = 'recording_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.aac';
        String path = '${_recordingDirectory!.path}/$fileName';
        print("Recording saved to: $path");

        await _recorder.startRecorder(toFile: path, audioSource: AudioSource.microphone);
        setState(() {
          isRecording = true;
          _elapsedSeconds = 0;
        });
        _startTimer();
      }
    }
  }
  Future<void> _stopRecording() async {
    await _recorder.stopRecorder();
    _stopTimer();
    setState(() {
      isRecording = false;
    });
    _loadRecordings();
  }

  void _loadRecordings() async {
    final files = _recordingDirectory!.listSync()..sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
    setState(() {
      _recordings = files;
    });
  }

  void _playOrPauseRecording(String path) async {
    if (_currentlyPlayingPath == path && _isPlaying) {
      await _player.pausePlayer();
      setState(() {
        _isPlaying = false;
      });
    } else if (_currentlyPlayingPath == path && !_isPlaying) {
      await _player.resumePlayer();
      setState(() {
        _isPlaying = true;
      });
    } else {
      await _player.stopPlayer(); // Stop previous
      await _player.openPlayer();
      await _player.startPlayer(
        fromURI: path,
        whenFinished: () async {
          await _player.stopPlayer();
          setState(() {
            _isPlaying = false;
            _currentlyPlayingPath = null;
          });
        },
      );
      setState(() {
        _isPlaying = true;
        _currentlyPlayingPath = path;
      });
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(Duration(seconds: 1), (_) {
      setState(() {
        _elapsedSeconds++;
      });
    });
  }
  void _stopTimer() {
    _timer?.cancel();
  }

  String get formattedTime {
    final Duration duration = Duration(seconds: _elapsedSeconds);
    return [duration.inHours, duration.inMinutes % 60, duration.inSeconds % 60].map((seg) => seg.toString().padLeft(2, '0')).join(':');
  }

  Future<void> _renameFile(FileSystemEntity file) async {
    final oldPath = file.path;
    final directory = file.parent;
    final oldName = oldPath.split('/').last;
    final controller = TextEditingController(text: oldName.replaceAll('.aac', ''));

    await showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: Text("Rename File"),
            content: TextField(controller: controller, decoration: InputDecoration(hintText: "Enter new file name")),
            actions: [
              TextButton(child: Text("Cancel"), onPressed: () => Navigator.pop(context)),
              TextButton(
                child: Text("Rename"),
                onPressed: () async {
                  String newName = controller.text.trim();
                  if (newName.isNotEmpty) {
                    String newPath = '${directory.path}/$newName.aac';
                    await File(oldPath).rename(newPath);
                    _loadRecordings();
                  }
                  Navigator.pop(context);
                },
              ),
            ],
          ),
    );
  }

  Future<void> startBackgroundService() async {
    await initializeService();
    FlutterBackgroundService().on('startRecording').listen((event) {
      if (isRecorderInitialize && !isRecording) {
        _startRecording();
      }
    });
    FlutterBackgroundService().on('stopRecording').listen((event) {
      if (isRecording) {
        _stopRecording();
      }
    });
  }
  Future<void> stopBackgroundService() async {
    FlutterBackgroundService().invoke("stopService");
  }

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.closeRecorder();
    isRecorderInitialize = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          SizedBox(height: 80),
          ElevatedButton(
            onPressed: isRecording ? _stopRecording : _startRecording,
            child: Text(isRecording ? 'Stop Recording' : 'Start Recording',
            ),
          ),
          SizedBox(height: 20),
          Text(formattedTime),
          Divider(height: 50),
          Text("Saved Recordings", style: TextStyle(fontSize: 18)),
          Expanded(
            child: ListView.builder(
              itemCount: _recordings.length,
              itemBuilder: (context, index) {
                final file = _recordings[index];
                final path = file.path;
                final name = path.split('/').last;
                final isThisPlaying = _currentlyPlayingPath == path && _isPlaying;
                // final isThisPaused = _currentlyPlayingPath == path && !_isPlaying;
                return ListTile(
                  title: Text(name),
                  leading: IconButton(
                    icon: Icon(isThisPlaying ? Icons.pause : Icons.play_arrow, color: Colors.blue),
                    onPressed: () => _playOrPauseRecording(file.path),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(icon: Icon(Icons.edit), onPressed: () => _renameFile(file)),
                      IconButton(
                        icon: Icon(Icons.delete),
                        onPressed: () async {
                          await File(file.path).delete();
                          _loadRecordings();
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            onPressed: startBackgroundService,
            child: Text('AI'),
          ),
          SizedBox(width: 10),
          FloatingActionButton(
            onPressed: stopBackgroundService,
            child: Icon(Icons.stop_outlined),
          ),
        ],
      ),
    );
  }
}
