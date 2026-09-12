// packages
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

// screens
import 'screens/home_screen.dart';
// Enhancement 3: import the new settings screen that now holds the theme switch.
import 'screens/settings_screen.dart';

// providers
import 'providers/theme_provider.dart';
// Enhancement 4: shared cart state, so the cart tab shows the products added
// from the shop.
import 'providers/cart_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: 'assets/.env');
  runApp(const MarinasAdvMobProg());
  // Locking the orientation is not supported on every platform, so it runs
  // after runApp — a failure here must not stop the app from rendering.
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
}

class MarinasAdvMobProg extends StatelessWidget {
  const MarinasAdvMobProg({super.key});

  @override
  Widget build(BuildContext context) {
    // Enhancement 4: two providers now sit above MaterialApp, so both the shop
    // and the cart tab share one CartProvider instance.
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
      ],
      child: ScreenUtilInit(
        designSize: const Size(412, 715),
        minTextAdapt: true,
        splitScreenMode: true,
        builder: (build, child) {
          final themeModel = build.watch<ThemeProvider>();
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: themeModel.lightTheme,
            darkTheme: themeModel.darkTheme,
            themeMode: themeModel.isDark ? ThemeMode.dark : ThemeMode.light,
            title: 'E-Commerce App',
            initialRoute: '/home',
            routes: {
              '/home': (context) => const HomeScreen(),
              // Enhancement 3: named route for the settings page so the home
              // screen's settings button can navigate to it.
              '/settings': (context) => const SettingsScreen(),
            },
          );
        },
      ),
    );
  }
}
