import 'package:flutter/material.dart';

class AlbumCover extends StatelessWidget {
  final Color primaryColor;
  final Color secondaryColor;

  const AlbumCover({
    super.key,
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      height: 280,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 2,
          )
        ],
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primaryColor, secondaryColor],
        ),
      ),
      child: Icon(
        Icons.music_note,
        size: 64,
        color: Colors.white.withOpacity(0.8),
      ),
    );
  }
}