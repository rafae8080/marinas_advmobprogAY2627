// Act5 Enhancement 1: auth helpers shared by the sign-in, signup, profile and
// settings screens.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../providers/cart_provider.dart';
import '../services/user_service.dart';
import '../widgets/custom_text.dart';

String readableAuthError(Object error) {
  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'Incorrect email or password.';
      case 'invalid-email':
        return 'That email address is not valid.';
      case 'email-already-in-use':
        return 'An account already exists for that email.';
      case 'weak-password':
        return 'That password is too weak.';
      case 'too-many-requests':
        return 'Too many attempts. Try again in a few minutes.';
      case 'operation-not-allowed':
        return 'Email/Password sign-in is not enabled in the Firebase console.';
      case 'network-request-failed':
        return 'Cannot reach the server. Check your connection.';
      case 'requires-recent-login':
        return 'Please sign in again before doing that.';
    }
    return error.message ?? 'Something went wrong. Please try again.';
  }

  // The DummyJSON calls throw the raw response body, which is JSON. Only the
  // message inside it is worth putting in front of the user.
  final text = error.toString();
  final match = RegExp('"message"\\s*:\\s*"([^"]+)"').firstMatch(text);
  if (match != null) return match.group(1)!;
  if (text.contains('SocketException') || text.contains('ClientException')) {
    return 'Cannot reach the server. Check your connection.';
  }
  return 'Something went wrong. Please try again.';
}

// Act5 Enhancement 2: used by the signup form and the change-password dialog.
String? validatePassword(String? value) {
  if (value == null || value.isEmpty) return 'Password is required';
  if (value.length < 8) return 'Use at least 8 characters';
  if (!RegExp('[A-Z]').hasMatch(value)) return 'Add an uppercase letter';
  if (!RegExp('[a-z]').hasMatch(value)) return 'Add a lowercase letter';
  if (!RegExp('[0-9]').hasMatch(value)) return 'Add a number';
  if (!RegExp(r'[^A-Za-z0-9]').hasMatch(value)) {
    return 'Add a symbol, e.g. ! @ # \$';
  }
  return null;
}

Future<void> confirmAndLogout(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: CustomText(
        text: 'Log out?',
        fontSize: 16.sp,
        fontWeight: FontWeight.w600,
      ),
      content: CustomText(
        text: 'You will need to sign in again to see your cart.',
        fontSize: 13.sp,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: CustomText(text: 'Cancel', fontSize: 13.sp),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: CustomText(
            text: 'Log out',
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
            color: Colors.red.shade700,
          ),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;
  await endSession(context);
}

// The cart is reset before the token is cleared, so the next person to sign in
// cannot briefly see the previous user's items.
Future<void> endSession(BuildContext context) async {
  context.read<CartProvider>().reset();
  await UserService().logout();

  if (!context.mounted) return;
  Navigator.pushNamedAndRemoveUntil(context, '/signin', (route) => false);
}
