import 'package:window_manager/window_manager.dart';
import 'dart:ui'; // Import for Size class
import 'package:flutter/material.dart'; // Import for Colors

class WindowService {
  static Future<void> initializeWindow() async {
    await windowManager.ensureInitialized();
    WindowOptions windowOptions = const WindowOptions(
      size: Size(900, 650),
      minimumSize: Size(700, 500),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden,
      windowButtonVisibility: false,
    );
    
    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  static Future<void> minimize() => windowManager.minimize();
  static Future<void> maximize() => windowManager.maximize();
  static Future<void> close() => windowManager.close();
  static Future<void> startDragging() => windowManager.startDragging();
}