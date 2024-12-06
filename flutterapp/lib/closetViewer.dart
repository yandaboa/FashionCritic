import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class ClosetViewer extends StatefulWidget {
  @override
  _ClosetViewerState createState() => _ClosetViewerState();
}

class _ClosetViewerState extends State<ClosetViewer> {

  bool isLoading = true;
  List<String> clothes = [];

  String closet_status = "Loading your closet...";

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    print('hello');
    updateFromDatabase();
    for (String i in clothes) {
      print(i);
    }
  }

  void updateFromDatabase() async {
    // Get the data from the database
    String pineconeAPIKey = dotenv.env['PINECONE_API_KEY']!;
    String pineconeURL = dotenv.env['PINECONE_CLOSET_URL']!;
    Uri url = Uri.parse(pineconeURL + "/query");

    List<double> vector = List<double>.filled(3072, 0.0);
    
    final pineconeResponse = await http.post(
      url,
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

    if (pineconeResponse.statusCode == 200) {
      for (var i in jsonDecode(pineconeResponse.body)['matches']) {
        clothes.add(i['id']);
      }
      setState(() {
        closet_status = "";
      });
    } else {
      print('Failed to get data from Pinecone');
      setState(() {
        closet_status = "Failed to retrieve closet data D:";
      });
    }

    // Set the state of the widget
    setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Your Virtual Wardrobe'),
      ),
      body: Center(
        child: 
        Column(children: [
         Text(closet_status),
          isLoading ? const CircularProgressIndicator() : const Text("There may be a delay if you recently added clothes"),
          Expanded(
            child: ListView.builder(
              itemCount: clothes.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.deepPurple[50], // Background color
                      borderRadius: BorderRadius.circular(12.0), // Rounded corners
                    ),
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      clothes[index],
                      style: const TextStyle(
                        fontSize: 16.0,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurpleAccent,
                      ),
                    ),
                  ),
                );
              },
            ),
          )
        ],)
      ),
    );
  }
}