import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

class CustomTitleBar extends StatelessWidget {
  final String title;
  final bool isDarkMode;

  const CustomTitleBar({
    super.key,
    required this.title,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanStart: (details) => windowManager.startDragging(),
              child: Padding(
                padding: const EdgeInsets.only(left: 12.0),
                child: Text(
                  title,
                  style: TextStyle(
                    color: isDarkMode 
                      ? Colors.white.withOpacity(0.9)
                      : Colors.black.withOpacity(0.9),
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.minimize, size: 16),
                color: isDarkMode 
                  ? Colors.white.withOpacity(0.7)
                  : Colors.black.withOpacity(0.7),
                onPressed: () => windowManager.minimize(),
              ),
              IconButton(
                icon: Icon(Icons.crop_square, size: 16),
                color: isDarkMode 
                  ? Colors.white.withOpacity(0.7)
                  : Colors.black.withOpacity(0.7),
                onPressed: () => windowManager.maximize(),
              ),
              IconButton(
                icon: Icon(Icons.close, size: 16),
                color: isDarkMode 
                  ? Colors.white.withOpacity(0.7)
                  : Colors.black.withOpacity(0.7),
                onPressed: () => windowManager.close(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}