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

  String feedbackPrompt = "The first image should show the current outfit. If it doesn't, say that, and don't generate advice. If it is a human, proceed. The rest of the images show the aesthetics/styles that the user wants to capture with their outfit. Give specific advice for someone who wants to change their style from the first image to a comprehensive but coherent aggregation of the rest. Briefly describe the differences in styles, and then give actionable advice on what clothing pieces to buy or thrift for. Specifically, give advice for only: top, bottoms, shoes, accessories.\n\nExample of output format (don't use anything other than plain text and colons):\nAdvice: Yo, you're dressing quite casually. Usually, formal ware conveys a more professional demeanor, and that's not what your shoes and shirt communicate.\nTop: Grab a button shirt t-shirt. Look for a high-quality cotton shirt with a smooth finish, like poplin or twill. Ensure it fits well (tailored or slim-fit for a modern look).\nWhere: Zara, Uniqlo, Men's Wearhouse.\nPants: The darker jeans you have are quite nice. Perhaps go with dress pants if you want more formal. Choose trousers made of high-quality wool or a wool blend for a polished, formal look. Flat-front trousers are sleek and modern, ideal for slimmer builds. Pleated trousers offer extra comfort and room, suitable for more traditional formal outfits.\nWhere: Men's Wearhouse, Levi's\n...";

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

  //after statusMessage == "success", these should be populated with the AI recommendations:
  String generalAdvice = "";
  String topAdvice = "";
  String bottomAdvice = ""; 
  String shoeAdvice = "";
  String accessoryAdvice = "";

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
    await Future.delayed(const Duration(seconds: 1));
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
    // print(supabaseKey);
    List imageUrls = [];

    for (String i in styleMatches){
      final String selectedStyle = i.toLowerCase(); // Assuming the first match is the selected style

      // print(selectedStyle);
      SupabaseClient client = Supabase.instance.client;
      var supabaseResponse = await client.from("FitReferences").select("image_url").eq("label", selectedStyle);

      if (supabaseResponse != null) {
        // Map the rows to a list of image_url strings
        List<String> urls = (supabaseResponse as List<dynamic>)
            .map((row) => row['image_url'] as String)
            .toList();
        for (String i in urls){
          imageUrls.add(i);
        }
      } else {
        print('Error: ${supabaseResponse}');
      }
    }

    setState(() {
      statusMessage = "Generating feedback...";
    });

    final Uri openaiurl = Uri.parse('https://api.openai.com/v1/chat/completions');

    String finalPrompt = "$feedbackPrompt\n\nFinally, consider the user prompt: $userInput";

    List messages = [];
    messages.add(
            {'type': 'text', 'text': finalPrompt}
          );
    
    messages.add(
        {'type': 'image_url', 'image_url': {'url': 'data:image/jpeg;base64,$base64Image'}}
      );
  
    for (int i = 0; i < 3; i++){
        print(imageUrls[i]);
        messages.add(
              {'type': 'image_url', 'image_url': {'url': imageUrls[i]}}
            );
    }

    final response = await http.post(
      openaiurl,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $openaiApiKey',
      },
      body: jsonEncode({
        'model': 'gpt-4o',
        'messages': [
          {'role': 'user', 
          'content': messages},
        ],
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      print(data['choices'][0]['message']['content']);
      setState(() {
        isLoading = false;
        statusMessage = "success";
        generalAdvice = data['choices'][0]['message']['content'].split("Top:")[0].trim();
        topAdvice = data['choices'][0]['message']['content'].split("Top:")[1].split("Bottoms:")[0].trim();
        bottomAdvice = data['choices'][0]['message']['content'].split("Bottoms:")[1].split("Shoes:")[0].trim();
        shoeAdvice = data['choices'][0]['message']['content'].split("Shoes:")[1].split("Accessories:")[0].trim();
        accessoryAdvice = data['choices'][0]['message']['content'].split("Accessories:")[1].trim();
      });
    } else {
      print('Error: ${response.statusCode}');
      print(response.body);
      return;
    }
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
            if (!isLoading && statusMessage != "success")
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
            if(!isLoading && statusMessage != "success")
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
            if (!isLoading && statusMessage != "success") 
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
            if (statusMessage == "success")
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
              child: Container(
              decoration: BoxDecoration(
                color: Colors.deepPurple[50], // Background color
                borderRadius: BorderRadius.circular(12.0), // Rounded corners
              ),
              padding: const EdgeInsets.all(16.0),
              child: Text(
                generalAdvice,
                style: const TextStyle(
                fontSize: 16.0,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurpleAccent,
                ),
              ),
              ),
            ),
            if(statusMessage == "success")
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
              child: Container(
              decoration: BoxDecoration(
                color: Colors.deepPurple[50], // Background color
                borderRadius: BorderRadius.circular(12.0), // Rounded corners
              ),
              padding: const EdgeInsets.all(16.0),
              child: Text(
                topAdvice,
                style: const TextStyle(
                fontSize: 16.0,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurpleAccent,
                ),
              ),
              ),
            ),
            if(statusMessage == "success")
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
              child: Container(
              decoration: BoxDecoration(
                color: Colors.deepPurple[50], // Background color
                borderRadius: BorderRadius.circular(12.0), // Rounded corners
              ),
              padding: const EdgeInsets.all(16.0),
              child: Text(
                bottomAdvice,
                style: const TextStyle(
                fontSize: 16.0,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurpleAccent,
                ),
              ),
              ),
            ),
            if(statusMessage == "success")
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
              child: Container(
              decoration: BoxDecoration(
                color: Colors.deepPurple[50], // Background color
                borderRadius: BorderRadius.circular(12.0), // Rounded corners
              ),
              padding: const EdgeInsets.all(16.0),
              child: Text(
                shoeAdvice,
                style: const TextStyle(
                fontSize: 16.0,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurpleAccent,
                ),
              ),
              ),
            ),
            if(statusMessage == "success")
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
              child: Container(
              decoration: BoxDecoration(
                color: Colors.deepPurple[50], // Background color
                borderRadius: BorderRadius.circular(12.0), // Rounded corners
              ),
              padding: const EdgeInsets.all(16.0),
              child: Text(
                accessoryAdvice,
                style: const TextStyle(
                fontSize: 16.0,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurpleAccent,
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