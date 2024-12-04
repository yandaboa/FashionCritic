import 'package:flutter/material.dart';

class StandardAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;

  StandardAppBar({required this.title});

  @override
  Widget build(BuildContext context) {
    return MediaQuery.removePadding(
      context: context,
      removeBottom: true,
      child: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text("Fashion Critic", textDirection: TextDirection.ltr,),
      )
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight);
}