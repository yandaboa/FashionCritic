import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutterapp/standardAppBar.dart';
import 'package:http/http.dart' as http;

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  String statusMessage = "";
  String userInput = "";
  int userInputLength = 0;

  List fashionStyles = [
    "Casual: Relaxed and comfortable clothing for everyday wear. Common pieces include jeans, T-shirts, sneakers, hoodies, and simple dresses.",
    "Professional: Tailored and polished outfits suitable for work or formal settings. Common pieces include blazers, dress shirts, trousers, pencil skirts, and loafers.",
    "Streetwear: Urban and trendy, influenced by hip-hop, skate culture, and youth fashion. Common pieces include oversized hoodies, graphic T-shirts, cargo pants, and sneakers.",
    "Evening Wear: Elegant and sophisticated attire for special occasions. Common pieces include gowns, suits, tuxedos, dress shoes, and accessories like ties or clutches.",
    "Athleisure: A blend of athletic and leisurewear, combining functionality with style. Common pieces include leggings, joggers, sports bras, sneakers, and zip-up jackets.",
    "Bohemian: Free-spirited and artistic, inspired by the hippie movement. Common pieces include flowing dresses, fringe details, earthy tones, and layered jewelry.",
    "Preppy: Polished and youthful, inspired by Ivy League fashion. Common pieces include polo shirts, chinos, pleated skirts, cardigans, and loafers.",
    "Minimalist: Simple, clean, and understated with neutral tones and streamlined designs. Common pieces include plain tops, tailored trousers, monochrome outfits, and minimal accessories.",
    "Romantic: Feminine and delicate, with an emphasis on soft fabrics and pretty details. Common pieces include lace blouses, floral dresses, ruffles, and pastel colors.",
    "Edgy: Bold and rebellious, often inspired by punk or rock aesthetics. Common pieces include leather jackets, ripped jeans, combat boots, and dark tones."
  ];

  String openaiApiKey = "";

  @override
  void initState() {
    super.initState();
    openaiApiKey = dotenv.env['OPENAI_API_KEY']!;
  }

  @override
  void _getFeedback() async {
    setState(() {
      isLoading = true;
      statusMessage = "Generating embeddings...";
    });
    Uint8List imageBytes = await File(widget.imagePath).readAsBytes();
    await Future.delayed(const Duration(seconds: 2));
    String base64Image = base64Encode(imageBytes);

    final Uri embeddingsurl = Uri.parse("https://api.openai.com/v1/embeddings");
    final embeddingsResponse = await http.post(
      embeddingsurl,
      headers: {
        'Content-Type': 'application/json',
        "Authorization": 'Bearer $openaiApiKey',
      },
      body: jsonEncode({
        'input': userInput,
        'model': 'text-embedding-3-large',
      }));
    
    if (embeddingsResponse.statusCode != 200) {
      print('Error: ${embeddingsResponse.statusCode}');
      print(embeddingsResponse.body);
      setState(() {
        statusMessage = '${embeddingsResponse.statusCode} error while generating embeddings';
      });
      await Future.delayed(const Duration(seconds: 1));
      setState(() {
        isLoading = false;
        statusMessage = "";
      });
      return;
    }
    
    List<dynamic> embeddings = jsonDecode(embeddingsResponse.body)['data'][0]['embedding'];
    List<double> vector = embeddings.map((e) => e as double).toList();
    // print(jsonDecode(embeddingsResponse.body)['data'][0]['embedding']);

    // String sanityCheck = embeddings.toString();
    // print(sanityCheck.substring(0, 10));
    // print(sanityCheck.substring(sanityCheck.length - 10));

    // return;
    print("done embedding:");
    print(embeddings);

    setState(() {
      statusMessage = "Finding relevant style...";
    });
    String pineconeAPIKey = dotenv.env['PINECONE_API_KEY']!;

    final Uri pineconeurl = Uri.parse("https://fit-labels-qz22kzx.svc.aped-4627-b74a.pinecone.io/query");
    final pineconeResponse = await http.post(
      pineconeurl,
      headers: {
        'Api-key': pineconeAPIKey,
        'Content-Type': 'application/json',
        // 'X-Pinecone-API-Version': '2024-07'
      },
      body: jsonEncode({
        'topK': 3,
        'vector': vector
        }
      )
    );

    if(pineconeResponse.statusCode != 200) {
      print('Error: ${pineconeResponse.statusCode}');
      print(pineconeResponse.body);
      setState(() {
        statusMessage = 'error finding matches (${pineconeResponse.statusCode})';
      });
      await Future.delayed(const Duration(seconds: 1));
      setState(() {
        isLoading = false;
        statusMessage = "";
      });
      return;
    }

    List styleMatches = [];
    List similarityScroes = [];

    for (var i in jsonDecode(pineconeResponse.body)['matches']){
      styleMatches.add(fashionStyles[int.parse(i['id'].split("-")[1])].split(":")[0]);
      print(styleMatches[styleMatches.length - 1]);
      similarityScroes.add(i['score']);
      print(similarityScroes[styleMatches.length - 1]);
    }

    setState(() {
      statusMessage = "Retrieving references...";
    });

    // final String supabaseUrl = dotenv.env['SUPABASE_URL']!;
    String supabaseKey = dotenv.env['SUPABASE_KEY']!;
    print(supabaseKey);
    List imageUrls = [];

    for (String i in styleMatches){
      final String selectedStyle = i.toLowerCase(); // Assuming the first match is the selected style

      print(selectedStyle);
      final Uri supabaseUrl = Uri.parse('https://idzbxusgiufdpxygfnlu.supabase.co/rest/v1/FitReferences?select=*');
      
      final supabaseResponse = await http.get(
        supabaseUrl,
        headers: {
          'apikey': supabaseKey,
          'Authorization': 'Bearer $supabaseKey',
          'Content-Type': 'application/json',
        },
      );

      if (supabaseResponse.statusCode == 200) {
        print(supabaseResponse.body);
        List<dynamic> imageUrls = jsonDecode(supabaseResponse.body);
        print('Image URLs:');
        print(imageUrls);
      } else {
        print('Error: ${supabaseResponse.statusCode}');
        print(supabaseResponse.body);
      }
    }
    return;


    final Uri openaiurl = Uri.parse('https://api.openai.com/v1/chat/completions');

    final response = await http.post(
      openaiurl,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $openaiApiKey',
      },
      body: jsonEncode({
        'model': 'gpt-4o',
        'messages': [
          {'role': 'user', 'content': [
            {'type': 'text', 'data': {'text': 'I want to know what to wear'}}
          ]},
          {'role': 'user', 'content': [
            {'type': 'image_url', 'image_url': {'url': 'data:image/jpeg;base64,$base64Image'}}
          ]},
          {'role': 'assistant', 'content': [
            {'type': 'text', 'data': {'text': userInput}}
          ]}
        ]
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      print(data['choices'][0]['message']['content']);
    } else {
      print('Error: ${response.statusCode}');
      print(response.body);
    }
    
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
            if (!isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Center(
                child:
                SizedBox(
                  width: double.infinity,
                  child: Text("Instructions: at least 10 words and as specific as possible :D"
                    , style: TextStyle(color: Colors.green)),
                )
              )),
            if(!isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
              child: TextField(
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: "What's the occasion?",
                ),
                onChanged: (value) {
                  setState(() {
                    // Save the user input to a variable
                    userInputLength = value.split(" ").length;
                    userInput = value;
                  });
                },
              ),
            ),
            if (!isLoading) 
            SizedBox(
            width: double.infinity, // Make the button take the full width
            child: FloatingActionButton.extended(
              disabledElevation: userInputLength < 10 ? 0 : 4,
              backgroundColor: userInputLength < 10 ? Colors.grey : Colors.green,
              onPressed: userInputLength < 10 ? null : () {_getFeedback();},
              label: const Text("Generate Outfit Feedback"),
              icon: const Icon(Icons.send),
            ),
            ),
            if (isLoading)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
              Text(
                statusMessage,
                style: const TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 10),
              const SizedBox(
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