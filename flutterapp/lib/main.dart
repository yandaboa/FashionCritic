import 'package:flutter/material.dart';
import 'package:flutterapp/standardAppBar.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'package:camera/camera.dart';
import 'camera.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'closet.dart';
import 'closetViewer.dart';

List<CameraDescription> cameras = [];

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  await dotenv.load();
  await Supabase.initialize(
    url: 'https://idzbxusgiufdpxygfnlu.supabase.co',
    anonKey: dotenv.env['SUPABASE_KEY']!,
  );

  runApp(MaterialApp(home: MyApp()));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    requestStoragePermission();
  }

  void requestStoragePermission() async {
    // Check if the platform is not web, as web has no permissions
      // Request storage permission
      var status = await Permission.storage.status;

      if (!status.isGranted) {
        await Permission.storage.request();
      }

      // Request camera permission
      var cameraStatus = await Permission.camera.status;
      if (!cameraStatus.isGranted) {
        await Permission.camera.request();
      }
  }

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
      appBar: StandardAppBar(
        title: "Fashion Critic"),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(
                  context).push(
                  MaterialPageRoute(builder: (context) => CameraPage(context: context, cameras: cameras,)),
                );
              },
              child: Icon(Icons.camera_alt),
            ),
            ElevatedButton(onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => Closet(context: context, cameras: cameras,)),
              );
            },
            child: Icon(Icons.add)),
            ElevatedButton(onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => ClosetViewer()),
              );
            },
            child: const Icon(Icons.home)),
          ]
        ),
      ),
    )
    );
  }
}