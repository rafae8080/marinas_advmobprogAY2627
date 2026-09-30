import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'product_screen.dart';
// Act6: chat list backed by Firestore.
import 'chat_screen.dart';
// Enhancement 1: cart screen rendering the /carts endpoint.
import 'cart_screen.dart';
// Enhancement 6: the Profile tab now renders the signed-in user.
import 'profile_screen.dart';
import '../widgets/custom_text.dart';

class HomeScreen extends StatefulWidget {
  final String? username;
  const HomeScreen({super.key, this.username});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Act6: Chat is back as the second tab; the chat FAB is gone.
  static const _titles = ['', 'Chats', 'Cart', 'Profile'];

  int selectedIndex = 0;
  final PageController pageController = PageController();

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          elevation: 2,
          title: selectedIndex == 0
              ? Image.asset('assets/images/exchange_logo.png', scale: 11.3)
              : CustomText(
                  text: _titles[selectedIndex],
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w600,
                ),
          // Enhancement 3: the dark/light mode switch used to sit here in the
          // app bar. It was replaced by this settings button, which opens the
          // settings screen where the switch now lives.
          actions: [
            IconButton(
              icon: Icon(Icons.settings, size: 24.sp),
              onPressed: () => Navigator.pushNamed(context, '/settings'),
            ),
          ],
        ),
        body: PageView(
          physics: const NeverScrollableScrollPhysics(),
          controller: pageController,
          // Enhancement 2: the bar had three tabs but only one page, so tapping
          // anything other than Shop rendered a blank screen.
          children: const [
            ProductScreen(),
            ChatScreen(),
            CartScreen(),
            ProfileScreen(),
          ],
          onPageChanged: (page) {
            setState(() {
              selectedIndex = page;
            });
          },
        ),
        bottomNavigationBar: BottomNavigationBar(
          showSelectedLabels: false,
          showUnselectedLabels: false,
          // Four items would switch the bar to "shifting", which draws white
          // icons on the white bar.
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.shopping_bag),
              label: 'Shop',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble_outline),
              activeIcon: Icon(Icons.chat_bubble),
              label: 'Chat',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.shopping_cart),
              label: 'Cart',
            ),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          ],
          currentIndex: selectedIndex,
          onTap: (int value) {
            setState(() {
              selectedIndex = value;
              pageController.jumpToPage(value);
            });
          },
        ),
      ),
    );
  }
}
