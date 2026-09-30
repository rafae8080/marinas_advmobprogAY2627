// Enhancement 3: New file. This whole screen was added so the dark/light mode
// switch lives here instead of on the home screen.

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

// providers
import '../providers/theme_provider.dart';

// utils
import '../utils/auth_helpers.dart';

// widgets
import '../widgets/custom_text.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Enhancement 3: watch the ThemeProvider so this page rebuilds the moment
    // the switch flips.
    final themeModel = context.watch<ThemeProvider>();

    return Scaffold(
      appBar: AppBar(
        elevation: 2,
        title: CustomText(
          text: 'Settings',
          fontSize: 20.sp,
          fontWeight: FontWeight.w600,
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
          children: [
            CustomText(
              text: 'Appearance',
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
            ),
            SizedBox(height: 8.h),
            // Enhancement 3: the dark/light mode switch, moved out of the home
            // screen and into this settings page.
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: SwitchListTile(
                value: themeModel.isDark,
                onChanged: (value) => themeModel.setDarkMode(value),
                secondary: Icon(
                  themeModel.isDark ? Icons.dark_mode : Icons.light_mode,
                  size: 24.sp,
                ),
                title: CustomText(
                  text: themeModel.isDark ? 'Dark Mode' : 'Light Mode',
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
                subtitle: CustomText(text: 'On', fontSize: 12.sp),
              ),
            ),
            SizedBox(height: 24.h),
            CustomText(
              text: 'Account',
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
            ),
            SizedBox(height: 8.h),
            // Act5 Enhancement 3: logout from settings, back to the login.
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: ListTile(
                leading: Icon(
                  Icons.logout,
                  size: 24.sp,
                  color: Colors.red.shade700,
                ),
                title: CustomText(
                  text: 'Log out',
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.red.shade700,
                ),
                subtitle: CustomText(
                  text: 'Clears your session on this device',
                  fontSize: 12.sp,
                ),
                onTap: () => confirmAndLogout(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
