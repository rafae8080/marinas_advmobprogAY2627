import 'package:flutter/material.dart';

class ThemeProvider with ChangeNotifier {
  bool _isDark = false;

  bool get isDark => _isDark;

  ThemeData get lightTheme => ThemeData.light();
  ThemeData get darkTheme => ThemeData.dark();

  void toggleTheme() {
    _isDark = !_isDark;
    notifyListeners();
  }

  // Enhancement 3: added for the SwitchListTile on the settings screen, which
  // hands over an explicit on/off value instead of just flipping the theme.
  void setDarkMode(bool value) {
    if (_isDark == value) return; // skip redundant rebuilds
    _isDark = value;
    notifyListeners();
  }
}
