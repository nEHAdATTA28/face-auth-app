import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/camera_screen.dart';

void main() => runApp(const FaceAuthApp());

class FaceAuthApp extends StatelessWidget {
  const FaceAuthApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NeonAuth Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.black,
        scaffoldBackgroundColor: Colors.black,
        textTheme: GoogleFonts.orbitronTextTheme(ThemeData.dark().textTheme)
            .apply(bodyColor: Colors.white, displayColor: Colors.white),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      home: const CameraScreen(),
    );
  }
}