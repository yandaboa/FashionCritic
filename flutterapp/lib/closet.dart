import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'standardAppBar.dart';

class Closet extends StatefulWidget {

    final BuildContext context;
  final List<CameraDescription> cameras;

  Closet({required this.context, required this.cameras});

  @override
  _ClosetState createState() => _ClosetState();
}

class _ClosetState extends State<Closet> {
  late CameraController controller;
  late XFile? imageFile;

  @override
  void initState() {
    super.initState();
    controller = CameraController(widget.cameras[0], ResolutionPreset.max);
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
        title: const Text("Virtual Closet", textDirection: TextDirection.ltr,),
        leading: BackButton(
            color: Colors.white,
            onPressed: () {
              Navigator.pop(context);
            },
          )
      ),
        body: Column(
          children: <Widget>[
            CameraPreview(controller),
            const SizedBox(height: 20), // Add spacing here
            const Center(
              child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: SizedBox(
                width: double.infinity,
                child: Text(
                "Lay your clothing item on a flat surface and take a picture of it. We will analyze the image and confirm before adding it to your closet.",
                style: TextStyle(color: Colors.green, fontSize: 16),
                textAlign: TextAlign.center,
                ),
              ),
              ),
            ),
            const SizedBox(height: 20),
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

  String openaiApiKey = "";

  String description = '';
  bool canAddToCloset = false;

  String status_message = '';
  
  @override
  void initState() {
    super.initState();
    openaiApiKey = dotenv.env['OPENAI_API_KEY']!;

  }

  void getImageDescription() async{
    setState(() {
      isLoading = true;
    });

    // Call the OpenAI API to get the image description
    // Use the openaiApiKey variable to authenticate the request
      final bytes = await File(widget.imagePath).readAsBytes();
      final base64Image = base64Encode(bytes);

      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $openaiApiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'gpt-4o',
          'messages': [
            {
              'role': 'user',
              'content': [
                {'type': 'text', 'text': 'Describe the clothing item in this image. Focus on one item, the most prominent one in the image. If there\'s no clothing item, output NONE'},
                {'type': 'image_url', 'image_url': {'url': 'data:image/jpeg;base64,$base64Image'}},
              ]
            }
          ]
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        description = responseData['choices'][0]['message']['content'];
      } else {
        description = 'Failed to get image description: ${response.statusCode}';
      }
      if(description == 'NONE'){
        canAddToCloset = false;
        description = "Please take a picture of a clothing item";
      } else {
        canAddToCloset = true;
      }

    setState(() {
      setState(() {
        description = description;
        isLoading = false;
      });
    });
  }

  void addToCloset() async {
    setState(() {
      status_message = 'Adding to closet...';
    });
    await Future.delayed(Duration(seconds: 1));

    setState(() {
      status_message = 'Added to closet!';
    });
  }

  @override
  Widget build(BuildContext context) {
    // getImageDescription();

    return Scaffold(
      appBar: StandardAppBar(
        title: "Virtual Closet"),
      body: 
      SingleChildScrollView(
        child: Column( 
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: Image.file(File(widget.imagePath)), //TODO: delay rest of page until image is loaded
            ),
            const SizedBox(height: 20),
            if(isLoading)
            const SizedBox(
                width: 16.0,
                height: 16.0,
                child: CircularProgressIndicator(strokeWidth: 2.0),
              ), // Add padding here
            if (!isLoading && description.isEmpty)
               Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: 
                FloatingActionButton(onPressed: 
                  () {
                  // Call the function to get the image description
                  getImageDescription();
                },
                child: Icon(Icons.check),
                )
               ),
               if (!isLoading && description.isNotEmpty && status_message.isEmpty)
               Center(
              child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: SizedBox(
                width: double.infinity,
                child: Text(
                  description,
                style: TextStyle(color: Colors.black, fontSize: 16),
                textAlign: TextAlign.center,
                ),
              ),
              ),
            ),
            if (!isLoading && description.isNotEmpty && status_message.isEmpty && canAddToCloset)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: 
                FloatingActionButton.extended(
                  onPressed: () {
                  // Call the function to get the image description
                  addToCloset();
                  },
                  label: Text('Add to Closet'),
                  icon: Icon(Icons.send),
                ),
               ),
            if (status_message.isNotEmpty)
              Center(
              child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: SizedBox(
                width: double.infinity,
                child: Text(
                  status_message,
                style: TextStyle(color: Colors.green, fontSize: 16),
                textAlign: TextAlign.center,
                ),
              ),
              ),
            ),
        ],
      ),
    ))
    ;
  }
}