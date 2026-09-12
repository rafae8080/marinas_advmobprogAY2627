// Act4 Enhancement 2: sign-in screen. It is the app's entry route. It owns the
// form state and hands the credentials to UserService, which performs
// POST /auth/login and persists the returned token and profile to
// SharedPreferences, then sends you to the splash screen to finish loading.

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

// services
import '../services/user_service.dart';

// widgets
import '../widgets/custom_text.dart';

import '../constants.dart';

class SigninScreen extends StatefulWidget {
  const SigninScreen({super.key});

  @override
  State<SigninScreen> createState() => _SigninScreenState();
}

class _SigninScreenState extends State<SigninScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  // Act4 Enhancement 1: the form is held back until the saved-token check
  // finishes, so a returning user never sees it flash before being forwarded.
  bool _checkingSession = true;
  // The failure is shown in the card itself rather than only in a SnackBar,
  // which disappears before it can be read.
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkExistingSession();
  }

  // Act4 Enhancement 1: persistent authentication. A token saved by a previous
  // run means this form can be skipped entirely.
  Future<void> _checkExistingSession() async {
    final loggedIn = await UserService().isLoggedIn();
    if (!mounted) return;

    if (loggedIn) {
      Navigator.pushReplacementNamed(context, '/splash');
      return;
    }
    setState(() => _checkingSession = false);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _login() async {
    UserService userService = UserService();
    // The spinner starts only after validation passes, so a rejected form does
    // not leave the button loading forever.
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      try {
        final response = await userService.loginUser(
          _usernameController.text.trim(),
          _passwordController.text.trim(),
        );

        // Save user data to SharedPreferences
        await userService.saveUserData(response);

        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });

        // The splash screen takes it from here: it loads this user's cart and
        // then opens the home screen.
        Navigator.pushReplacementNamed(context, '/splash', arguments: response);
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _errorMessage = _readableError(e);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login failed: ${e.toString()}')),
        );
      }
    }
  }

  // The service throws the raw response body, which is JSON. Only the message
  // inside it is worth putting in front of the user.
  String _readableError(Object error) {
    final text = error.toString();
    final match = RegExp('"message"\\s*:\\s*"([^"]+)"').firstMatch(text);
    if (match != null) return match.group(1)!;
    if (text.contains('SocketException') || text.contains('ClientException')) {
      return 'Cannot reach the server. Check your connection.';
    }
    return 'Something went wrong. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingSession) {
      return const Scaffold(backgroundColor: kPrimaryNavy, body: SizedBox());
    }

    return Scaffold(
      backgroundColor: kScreenGrey,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 24.h),
              child: Transform.translate(
                offset: Offset(0, -28.h),
                child: _buildFormCard(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(24.w, 0, 24.w, 48.h),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [kPrimaryNavy, Color(0xFF1B2260)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 24.h),
            Container(
              padding: EdgeInsets.all(12.r),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16.r),
              ),
              child: Image.asset(
                'assets/images/exchange_logo.png',
                width: 92.w,
                fit: BoxFit.contain,
              ),
            ),
            SizedBox(height: 20.h),
            CustomText(
              text: 'Welcome back',
              fontSize: 24.sp,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            SizedBox(height: 4.h),
            CustomText(
              text: 'Sign in to pick up where you left off.',
              fontSize: 12.sp,
              color: Colors.white70,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormCard() {
    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildField(
              controller: _usernameController,
              label: 'Username',
              icon: Icons.person_outline,
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Username is required'
                  : null,
            ),
            SizedBox(height: 14.h),
            _buildField(
              controller: _passwordController,
              label: 'Password',
              icon: Icons.lock_outline,
              obscure: _obscurePassword,
              onSubmitted: (_) {
                if (!_isLoading) _login();
              },
              suffix: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 20.sp,
                  color: Colors.black45,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
              validator: (value) => (value == null || value.isEmpty)
                  ? 'Password is required'
                  : null,
            ),
            if (_errorMessage != null) ...[
              SizedBox(height: 14.h),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDECEC),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 18.sp,
                      color: Colors.red.shade700,
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: CustomText(
                        text: _errorMessage!,
                        fontSize: 11.sp,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            SizedBox(height: 22.h),
            SizedBox(
              height: 50.h,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kAccentAmber,
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: kAccentAmber.withValues(alpha: 0.6),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                onPressed: _isLoading ? null : _login,
                child: _isLoading
                    ? SizedBox(
                        width: 20.w,
                        height: 20.w,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.black54),
                        ),
                      )
                    : CustomText(
                        text: 'Sign in',
                        fontSize: 15.sp,
                        fontWeight: FontWeight.bold,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String? Function(String?) validator,
    bool obscure = false,
    Widget? suffix,
    void Function(String)? onSubmitted,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      autocorrect: false,
      enableSuggestions: false,
      textCapitalization: TextCapitalization.none,
      onFieldSubmitted: onSubmitted,
      style: TextStyle(fontFamily: 'Poppins', fontSize: 14.sp),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 13.sp,
          color: Colors.black54,
        ),
        prefixIcon: Icon(icon, size: 20.sp, color: kPrimaryNavy),
        suffixIcon: suffix,
        filled: true,
        fillColor: kScreenGrey,
        contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 16.h),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: const BorderSide(color: kPrimaryNavy, width: 1.5),
        ),
      ),
      validator: validator,
    );
  }
}
