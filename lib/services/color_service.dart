import 'dart:ui';
import 'package:palette_generator/palette_generator.dart';

class ColorService {
  static Future<(Color, Color)> extractColorsFromImage(String imagePath) async {
    // In a real implementation, you would extract colors from album art
    // For now, return some nice gradient colors
    return (
      const Color(0xFF4568DC),
      const Color(0xFFB06AB3),
    );
  }

  static (Color, Color) getDefaultColors(bool isDarkMode) {
    return isDarkMode 
      ? (const Color(0xFF1E1E1E), const Color(0xFF111111))
      : (const Color(0xFFF5F5F5), const Color(0xFFDDDDDD));
  }
}