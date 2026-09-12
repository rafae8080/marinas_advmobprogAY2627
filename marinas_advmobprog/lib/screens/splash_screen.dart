// Act4 Enhancement 1: splash screen. It is the loading step between signing in
// and the home screen: it reads the user saved in SharedPreferences and fetches
// that user's cart before the app opens. A session restored from a previous run
// arrives here the same way, which is what makes the login persistent.

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

// providers
import '../providers/cart_provider.dart';

// services
import '../services/user_service.dart';

import '../constants.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final UserService _userService = UserService();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Without a token there is nothing to load, so this falls back to the form
    // rather than opening the app.
    if (!await _userService.isLoggedIn()) {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/signin');
      return;
    }

    final userData = await _userService.getUserData();
    if (!mounted) return;

    // Act4 Enhancement 3: the saved id is what the cart is fetched under, so
    // the cart tab opens on this user's cart.
    final userId = userData['id'] as int? ?? 0;
    if (userId > 0) {
      await context.read<CartProvider>().loadForUser(userId);
    }

    // A load that finishes instantly would flash the logo for a single frame,
    // so the screen is held just long enough to read.
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/home', arguments: userData);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kPrimaryNavy,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(20.r),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Image.asset(
                'assets/images/exchange_logo.png',
                width: 130.w,
                fit: BoxFit.contain,
              ),
            ),
            SizedBox(height: 32.h),
            SizedBox(
              width: 26.w,
              height: 26.w,
              child: const CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation(kAccentAmber),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
