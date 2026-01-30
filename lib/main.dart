import 'dart:async';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

// Ekran importları
import 'screens/planner_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/tools_screen.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/favorites_screen.dart';

// GLOBAL TEMA YÖNETİCİSİ
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

Future<void> main() async {
  runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);

      // Status Bar ayarı
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
      );

      try {
        await dotenv.load(fileName: ".env");

        //Firebase Başlatma
        String apiKey = dotenv.env['FIREBASE_API_KEY'] ?? "";

        if (apiKey.isNotEmpty) {
          await Firebase.initializeApp(
            options: FirebaseOptions(
              apiKey: apiKey,
              authDomain:
                  "${dotenv.env['FIREBASE_PROJECT_ID']}.firebaseapp.com",
              projectId: dotenv.env['FIREBASE_PROJECT_ID'] ?? "",
              storageBucket: dotenv.env['FIREBASE_STORAGE_BUCKET'] ?? "",
              messagingSenderId:
                  dotenv.env['FIREBASE_MESSAGING_SENDER_ID'] ?? "",
              appId: dotenv.env['FIREBASE_APP_ID'] ?? "",
            ),
          );
        } else {
          await Firebase.initializeApp();
        }

        //Crashlytics & Performance
        if (!kIsWeb) {
          FlutterError.onError =
              FirebaseCrashlytics.instance.recordFlutterFatalError;
        }

        // Firestore Cache
        FirebaseFirestore.instance.settings = const Settings(
          persistenceEnabled: true,
          cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
        );

        //App Check

        await FirebaseAppCheck.instance.activate(
          androidProvider: kReleaseMode
              ? AndroidProvider.playIntegrity
              : AndroidProvider.debug,
          appleProvider: kReleaseMode
              ? AppleProvider.appAttest
              : AppleProvider.debug,
        );

        //Tercihleri Yükle
        final prefs = await SharedPreferences.getInstance();
        final isDark = prefs.getBool('dark_mode') ?? false;
        themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;

        bool seenOnboarding = prefs.getBool('seen_onboarding') ?? false;

        runApp(MyApp(seenOnboarding: seenOnboarding));
      } catch (e, stack) {
        if (kDebugMode) print("BAŞLATMA HATASI: $e");

        if (Firebase.apps.isNotEmpty) {
          FirebaseCrashlytics.instance.recordError(e, stack, fatal: true);
        }

        runApp(const MyApp(seenOnboarding: false));
      }
    },
    (error, stack) {
      if (Firebase.apps.isNotEmpty) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      }
    },
  );
}

class MyApp extends StatelessWidget {
  final bool seenOnboarding;

  const MyApp({super.key, required this.seenOnboarding});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, child) {
        return MaterialApp(
          title: 'TUGA',
          debugShowCheckedModeBanner: false,
          themeMode: currentMode,

          // AÇIK TEMA AYARLARI
          theme: ThemeData(
            brightness: Brightness.light,
            textTheme: GoogleFonts.poppinsTextTheme(),
            useMaterial3: true,
            scaffoldBackgroundColor: const Color(0xFFF5F7FA),
            cardColor: Colors.white,
            canvasColor: Colors.white,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF0066CC),
              brightness: Brightness.light,
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.black87,
              elevation: 0,
              centerTitle: true,
            ),

            bottomSheetTheme: const BottomSheetThemeData(
              backgroundColor: Colors.white,
            ),
          ),

          // KOYU TEMA
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
            useMaterial3: true,
            scaffoldBackgroundColor: const Color(0xFF121212),
            cardColor: const Color(0xFF1E1E1E),
            canvasColor: const Color(0xFF1E1E1E),
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF0066CC),
              brightness: Brightness.dark,
              surface: const Color(0xFF1E1E1E),
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              elevation: 0,
              centerTitle: true,
            ),

            bottomSheetTheme: const BottomSheetThemeData(
              backgroundColor: Color(0xFF1E1E1E),
            ),
          ),

          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('tr', 'TR'), Locale('en', 'US')],

          home: StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasData) {
                return const AnaEkran();
              }

              if (seenOnboarding) {
                return const AuthScreen();
              }

              return const OnboardingScreen();
            },
          ),
        );
      },
    );
  }
}

class AnaEkran extends StatefulWidget {
  const AnaEkran({super.key});
  @override
  State<AnaEkran> createState() => _AnaEkranState();
}

class _AnaEkranState extends State<AnaEkran> {
  int _seciliSayfaIndex = 0;

  final List<Widget> _sayfalar = const [
    HomeScreen(),
    PlannerScreen(),
    FavoritesScreen(),
    ToolsScreen(),
    ProfileScreen(),
  ];

  void _onDestinationSelected(int index) {
    if (_seciliSayfaIndex != index) {
      setState(() => _seciliSayfaIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final navBarColor = isDark
        ? const Color(0xFF1E1E1E).withOpacity(0.95)
        : Colors.white.withOpacity(0.95);

    return Scaffold(
      resizeToAvoidBottomInset: false,

      body: IndexedStack(index: _seciliSayfaIndex, children: _sayfalar),

      extendBody: true,

      bottomNavigationBar: Container(
        margin: const EdgeInsets.only(left: 15, right: 15, bottom: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: NavigationBar(
              height: 65,
              elevation: 0,
              backgroundColor: navBarColor,
              indicatorColor: Theme.of(
                context,
              ).colorScheme.primary.withOpacity(0.15),
              selectedIndex: _seciliSayfaIndex,
              labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
              onDestinationSelected: _onDestinationSelected,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_rounded),
                  label: 'Ana Sayfa',
                ),
                NavigationDestination(
                  icon: Icon(Icons.calendar_month_outlined),
                  selectedIcon: Icon(Icons.calendar_month_rounded),
                  label: 'Planlar',
                ),
                NavigationDestination(
                  icon: Icon(Icons.favorite_border),
                  selectedIcon: Icon(
                    Icons.favorite_rounded,
                    color: Colors.redAccent,
                  ),
                  label: 'Favoriler',
                ),
                NavigationDestination(
                  icon: Icon(Icons.grid_view),
                  selectedIcon: Icon(Icons.grid_view_rounded),
                  label: 'Araçlar',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person_rounded),
                  label: 'Profil',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
