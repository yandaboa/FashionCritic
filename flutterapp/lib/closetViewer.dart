import 'package:flutter/material.dart';

class ClosetViewer extends StatefulWidget {
  @override
  _ClosetViewerState createState() => _ClosetViewerState();
}

class _ClosetViewerState extends State<ClosetViewer> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Closet Viewer'),
      ),
      body: Center(
        child: Text('Welcome to the Closet Viewer!'),
      ),
    );
  }
}