import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// clean, modern HRM palette (reference-inspired)
const seed = Color(0xFF5B7BFA); // periwinkle blue
const _ink = Color(0xFF1E2230);
const _bg = Color(0xFFF4F6FB);

ThemeData appTheme() => ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seed,
        primary: seed,
        brightness: Brightness.light,
      ).copyWith(surface: Colors.white),
      scaffoldBackgroundColor: _bg,
      dividerColor: const Color(0xFFEDEFF5),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: TextStyle(
            color: _ink, fontSize: 20, fontWeight: FontWeight.w800),
        iconTheme: IconThemeData(color: _ink),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        surfaceTintColor: Colors.white,
        shadowColor: const Color(0x14000000),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFFEEF0F6)),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF7F8FC),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE3E6EF))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE3E6EF))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: seed, width: 1.5)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: seed,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: seed,
          foregroundColor: Colors.white,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: seed),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: seed,
          side: const BorderSide(color: Color(0xFFD9DEEC)),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: seed,
        foregroundColor: Colors.white,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        elevation: 3,
        indicatorColor: seed.withOpacity(0.14),
        labelTextStyle: WidgetStateProperty.all(
            const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
            color: s.contains(WidgetState.selected) ? seed : Colors.grey)),
      ),
      datePickerTheme: const DatePickerThemeData(backgroundColor: Colors.white),
      timePickerTheme: const TimePickerThemeData(backgroundColor: Colors.white),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? seed : Colors.white),
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected)
                ? seed.withOpacity(0.5)
                : const Color(0xFFD9DEEC)),
      ),
      textTheme: const TextTheme().apply(bodyColor: _ink, displayColor: _ink),
    );

// gradient used for header cards (reference style)
const headerGradient = LinearGradient(
  colors: [Color(0xFF6C8BFF), Color(0xFF5B7BFA)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

void snack(BuildContext c, String msg, Color color) {
  ScaffoldMessenger.of(c).showSnackBar(
    SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}

Widget loading() => const Center(child: CircularProgressIndicator());

String t12(int ts) =>
    DateFormat('hh:mm a').format(DateTime.fromMillisecondsSinceEpoch(ts));

String t12s(String hms) {
  try {
    final p = hms.split(':');
    final d = DateTime(2000, 1, 1, int.parse(p[0]), int.parse(p[1]));
    return DateFormat('hh:mm a').format(d);
  } catch (_) {
    return hms;
  }
}
