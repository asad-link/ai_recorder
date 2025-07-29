import 'package:ai_recorder/record_page.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(scaffoldBackgroundColor: Colors.white),
      home: SafeArea(child: HomePage()),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: IconButton(
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const RecordPage()));
          },
          icon: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.double_arrow,size: 80,),
              Text('Next',style: TextStyle(fontSize: 24),)
            ],
          ),
        ),
      ),
    );
  }
}
