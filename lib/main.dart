import 'package:calculator/features/calculator/pages/calculator.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF000000),
        fontFamily: 'SF Pro Text',
        useMaterial3: true,
      ),
      home: const Calculator(),
    ),
  );
}
