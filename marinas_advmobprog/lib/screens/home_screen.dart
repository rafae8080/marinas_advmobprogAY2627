import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'product_screen.dart';
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
  // Enhancement 2: index of the cart tab, used to hide the FAB.
  static const int _cartIndex = 1;

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
                  text: selectedIndex == _cartIndex ? 'Cart' : 'Profile',
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
          children: const [ProductScreen(), CartScreen(), ProfileScreen()],
          onPageChanged: (page) {
            setState(() {
              selectedIndex = page;
            });
          },
        ),
        // Enhancement 2: chat moved out of the bottom bar into this button,
        // which is hidden while the cart screen is showing.
        floatingActionButton: selectedIndex == _cartIndex
            ? null
            : FloatingActionButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const _ChatPage()),
                ),
                child: Icon(Icons.chat, size: 24.sp),
              ),
        bottomNavigationBar: BottomNavigationBar(
          showSelectedLabels: false,
          showUnselectedLabels: false,
          // Enhancement 2: Chat was replaced by Cart here.
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.shopping_bag),
              label: 'Shop',
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

// Enhancement 2: page opened by the chat FloatingActionButton.
class _ChatPage extends StatelessWidget {
  const _ChatPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: CustomText(
          text: 'Chat',
          fontSize: 20.sp,
          fontWeight: FontWeight.w600,
        ),
      ),
      body: Center(
        child: CustomText(text: 'No messages yet.', fontSize: 14.sp),
      ),
    );
  }
}
