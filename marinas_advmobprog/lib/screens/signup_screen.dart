// Act5 Enhancement 2: signup screen. The fields follow the user record on
// dummyjson.com/users, but the account itself is created in Firebase Auth,
// since DummyJSON never stores new users.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

// services
import '../services/user_service.dart';

// utils
import '../utils/auth_helpers.dart';

// widgets
import '../widgets/custom_text.dart';

import '../constants.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _ageController = TextEditingController();
  final _contactController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    for (final controller in [
      _firstNameController,
      _lastNameController,
      _ageController,
      _contactController,
      _usernameController,
      _emailController,
      _passwordController,
      _confirmController,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await UserService().registerUser(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        age: int.parse(_ageController.text.trim()),
        phone: _contactController.text.trim(),
        username: _usernameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/splash', (route) => false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = readableAuthError(e);
      });
    }
  }

  String? _required(String? value, String label) =>
      (value == null || value.trim().isEmpty) ? '$label is required' : null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kScreenGrey,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 24.h),
              child: _buildFormCard(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(12.w, 0, 24.w, 28.h),
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
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: _isLoading ? null : () => Navigator.pop(context),
            ),
            Padding(
              padding: EdgeInsets.only(left: 12.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomText(
                    text: 'Create an account',
                    fontSize: 24.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  SizedBox(height: 4.h),
                  CustomText(
                    text: 'Your account is secured with Firebase.',
                    fontSize: 12.sp,
                    color: Colors.white70,
                  ),
                ],
              ),
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
            _sectionLabel('Personal details'),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildField(
                    controller: _firstNameController,
                    label: 'First name',
                    icon: Icons.person_outline,
                    capitalization: TextCapitalization.words,
                    validator: (v) => _required(v, 'First name'),
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: _buildField(
                    controller: _lastNameController,
                    label: 'Last name',
                    icon: Icons.person_outline,
                    capitalization: TextCapitalization.words,
                    validator: (v) => _required(v, 'Last name'),
                  ),
                ),
              ],
            ),
            SizedBox(height: 14.h),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: _buildField(
                    controller: _ageController,
                    label: 'Age',
                    icon: Icons.cake_outlined,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(3),
                    ],
                    validator: (v) {
                      final age = int.tryParse(v?.trim() ?? '');
                      if (age == null) return 'Age is required';
                      if (age < 13 || age > 120) return 'Enter 13 – 120';
                      return null;
                    },
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  flex: 3,
                  child: _buildField(
                    controller: _contactController,
                    label: 'Contact no.',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9+\- ]')),
                    ],
                    validator: (v) {
                      final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
                      if (digits.isEmpty) return 'Contact no. is required';
                      if (digits.length < 10 || digits.length > 13) {
                        return 'Enter 10 – 13 digits';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            SizedBox(height: 20.h),
            _sectionLabel('Account'),
            _buildField(
              controller: _usernameController,
              label: 'Username',
              icon: Icons.alternate_email,
              validator: (v) {
                final value = v?.trim() ?? '';
                if (value.isEmpty) return 'Username is required';
                if (!RegExp(r'^[A-Za-z0-9_.]{3,20}$').hasMatch(value)) {
                  return '3 – 20 letters, numbers, _ or .';
                }
                return null;
              },
            ),
            SizedBox(height: 14.h),
            _buildField(
              controller: _emailController,
              label: 'Email address',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                final value = v?.trim() ?? '';
                if (value.isEmpty) return 'Email is required';
                if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)) {
                  return 'Enter a valid email address';
                }
                return null;
              },
            ),
            SizedBox(height: 14.h),
            _buildField(
              controller: _passwordController,
              label: 'Password',
              icon: Icons.lock_outline,
              obscure: _obscurePassword,
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
              helper: '8+ characters with upper, lower, number and symbol',
              validator: validatePassword,
            ),
            SizedBox(height: 14.h),
            _buildField(
              controller: _confirmController,
              label: 'Confirm password',
              icon: Icons.lock_outline,
              obscure: _obscurePassword,
              onSubmitted: (_) {
                if (!_isLoading) _signup();
              },
              validator: (v) => v != _passwordController.text
                  ? 'Passwords do not match'
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
                onPressed: _isLoading ? null : _signup,
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
                        text: 'Create account',
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

  Widget _sectionLabel(String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: CustomText(
        text: text,
        fontSize: 13.sp,
        fontWeight: FontWeight.w600,
        color: kPrimaryNavy,
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
    String? helper,
    TextInputType? keyboardType,
    TextCapitalization capitalization = TextCapitalization.none,
    List<TextInputFormatter>? inputFormatters,
    void Function(String)? onSubmitted,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      autocorrect: false,
      enableSuggestions: false,
      keyboardType: keyboardType,
      textCapitalization: capitalization,
      inputFormatters: inputFormatters,
      onFieldSubmitted: onSubmitted,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      style: TextStyle(fontFamily: 'Poppins', fontSize: 14.sp),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 13.sp,
          color: Colors.black54,
        ),
        helperText: helper,
        helperMaxLines: 2,
        helperStyle: TextStyle(fontFamily: 'Poppins', fontSize: 10.sp),
        errorMaxLines: 2,
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
