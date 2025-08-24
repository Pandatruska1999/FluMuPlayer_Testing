import 'package:flutter/material.dart';

class ThemeToggle extends StatelessWidget {
  final bool isDarkMode;
  final ValueChanged<bool> onChanged;

  const ThemeToggle({
    super.key,
    required this.isDarkMode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Icon(
          isDarkMode ? Icons.dark_mode : Icons.light_mode,
          color: Colors.white.withOpacity(0.7),
        ),
        const SizedBox(width: 8),
        Switch(
          value: isDarkMode,
          onChanged: onChanged,
          activeColor: Colors.white,
          inactiveThumbColor: Colors.grey,
        ),
      ],
    );
  }
}