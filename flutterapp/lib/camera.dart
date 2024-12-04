import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutterapp/standardAppBar.dart';

class CameraPage extends StatefulWidget {
  final BuildContext context;
  final List<CameraDescription> cameras;

  CameraPage({required this.context, required this.cameras});

  @override
  _CameraPageState createState() => _CameraPageState();
}
// class CameraPage extends StatefulWidget {

//   @override
//   _CameraPageState createState() => _CameraPageState();
// }

class _CameraPageState extends State<CameraPage> {
  late CameraController controller;
  late XFile? imageFile;

  @override
  void initState() {
    super.initState();
    controller = CameraController(widget.cameras[1], ResolutionPreset.max);
    controller.initialize().then((_) {
      if (!mounted) {
        return;
      }
      setState(() {});
    }).catchError((Object e) {
      if (e is CameraException) {
        switch (e.code) {
          case 'CameraAccessDenied':
            // Handle access errors here.
            break;
          default:
            // Handle other errors here.
            break;
        }
      }
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!controller.value.isInitialized) {
      return Container();
    }
    return Scaffold(
        appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text("Fashion Critic", textDirection: TextDirection.ltr,),
        leading: BackButton(
            color: Colors.white,
            onPressed: () {
              Navigator.pop(context);
            },
          )
      ),
        body: Stack(
          children: <Widget>[
            CameraPreview(controller),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: FloatingActionButton(
                  onPressed: () {
                    _takePicture(); // Call method to take picture
                  },
                  child: Icon(Icons.camera),
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.deepPurple,
                ),
              ),
            ),
          ],
        ),
      );
  }

  void _takePicture() async {
    try {
      final XFile picture = await controller.takePicture();
      setState(() {
        imageFile = picture;
      });
      // Navigate to the image view page after capturing the image
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ImageViewPage(imagePath: imageFile!.path),
        ),
      );
    } catch (e) {
      print("Error taking picture: $e");
    }
  }
}

class ImageViewPage extends StatefulWidget {
  final String imagePath;
  const ImageViewPage({super.key, required this.imagePath});

  @override
  State<ImageViewPage> createState() => _ImageViewPageState();
}

class _ImageViewPageState extends State<ImageViewPage> {
  bool isLoading = false;
  String userInput = "";

  @override
  void _getFeedback() async {
    setState(() {
      isLoading = true;
    });
    Uint8List imageBytes = await File(widget.imagePath).readAsBytes();
    String base64Image = base64Encode(imageBytes);
    setState(() {
      isLoading = false;
    });
    // Call the API to get feedback
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: StandardAppBar(
        title: "Fashion Critic"),
      body: 
      SingleChildScrollView(
        child: Column(
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: Image.file(File(widget.imagePath)), //TODO: delay rest of page until image is loaded
            ),
            const SizedBox(height: 20), // Add padding here
            if(!isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
              child: TextField(
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: "What's the occasion?",
                ),
                onChanged: (value) {
                  setState(() {
                    // Save the user input to a variable
                    userInput = value;
                  });
                },
              ),
            ),
            if (!isLoading) 
            SizedBox(
            width: double.infinity, // Make the button take the full width
            child: FloatingActionButton.extended(
              onPressed: () {_getFeedback();},
              label: const Text("Generate Outfit Feedback"),
              icon: const Icon(Icons.send),
            ),
            ),
            if (isLoading)
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
              Text(
                "Generating...",
                style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
              ),
              SizedBox(width: 10),
              SizedBox(
                width: 16.0,
                height: 16.0,
                child: CircularProgressIndicator(strokeWidth: 2.0),
              ),
              ],
            ),
        ],
      ),
    ))
    ;
  }
}