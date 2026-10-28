import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/home_page.dart';
import 'screens/login_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Keep a device copy of the data so the app works offline (already the default on Android, not on web).
  FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: true);
  runApp(const MemoryStackApp());
}

const brand = Color(0xFF6C4EF5);

/// One look for every screen: soft lavender background, white cards with soft shadows, pill buttons.
ThemeData appTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final colors = ColorScheme.fromSeed(
    seedColor: brand,
    brightness: brightness,
    primary: dark ? const Color(0xFFA996FF) : brand,
    surface: dark ? const Color(0xFF121218) : const Color(0xFFF6F5FB),
    surfaceContainerLowest: dark ? const Color(0xFF1C1B24) : Colors.white,
  );
  const pill = StadiumBorder();
  return ThemeData(
    fontFamily: 'Roboto',
    colorScheme: colors,
    scaffoldBackgroundColor: colors.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: colors.onSurface),
    ),
    cardTheme: CardThemeData(
      elevation: dark ? 0 : 1.5,
      shadowColor: brand.withValues(alpha: 0.18),
      color: colors.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: dark ? BorderSide(color: colors.outlineVariant.withValues(alpha: 0.4)) : BorderSide.none,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(shape: pill, minimumSize: const Size(0, 50), textStyle: const TextStyle(fontWeight: FontWeight.w700)),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(shape: pill, minimumSize: const Size(0, 46), side: BorderSide(color: colors.outlineVariant)),
    ),
    chipTheme: ChipThemeData(shape: const StadiumBorder(), side: BorderSide.none, backgroundColor: colors.primaryContainer.withValues(alpha: 0.5)),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.surfaceContainerLowest,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.6))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.6))),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: colors.surfaceContainerLowest,
      indicatorColor: colors.primaryContainer,
      indicatorShape: const StadiumBorder(),
      elevation: 8,
      shadowColor: brand.withValues(alpha: 0.15),
      labelTextStyle: WidgetStatePropertyAll(TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.onSurfaceVariant)),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(shape: StadiumBorder()),
    snackBarTheme: SnackBarThemeData(behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
    dividerTheme: DividerThemeData(color: colors.outlineVariant.withValues(alpha: 0.35)),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
    }),
    listTileTheme: const ListTileThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16)))),
  );
}

class MemoryStackApp extends StatelessWidget {
  const MemoryStackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Memory Stack',
      debugShowCheckedModeBanner: false,
      // On wide screens (web on a PC) keep the app a readable column instead of stretching edge to edge.
      builder: (context, child) => ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560), child: child)),
      ),
      theme: appTheme(Brightness.light),
      darkTheme: appTheme(Brightness.dark),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          return snapshot.data == null ? const LoginPage() : HomePage(user: snapshot.data!);
        },
      ),
    );
  }
}
