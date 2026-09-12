// Act4 Enhancement 3: profile screen. Everything it draws comes from the User
// model that UserService rebuilds out of SharedPreferences, so it renders with
// no network call and still works offline.

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

// models
import '../models/user.dart';

// providers
import '../providers/cart_provider.dart';

// services
import '../services/user_service.dart';

// widgets
import '../widgets/custom_text.dart';

import '../constants.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final UserService _userService = UserService();

  // The Future is built once in initState rather than in build(), so the
  // profile is not re-read from disk on every rebuild of this screen.
  late Future<User> _userFuture;

  @override
  void initState() {
    super.initState();
    _userFuture = _userService.getUser();
  }

  Future<void> _logout() async {
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

    if (confirmed != true || !mounted) return;

    // The cart is reset before the token is cleared, so the next person to sign
    // in cannot briefly see the previous user's items.
    context.read<CartProvider>().reset();
    await _userService.logout();

    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/signin', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: kScreenGrey,
      child: FutureBuilder<User>(
        future: _userFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: CustomText(
                text: 'Error: ${snapshot.error}',
                fontSize: 14.sp,
              ),
            );
          }

          final user = snapshot.data;
          if (user == null || user.id == 0) {
            return Center(
              child: CustomText(text: 'No profile saved.', fontSize: 14.sp),
            );
          }

          return SingleChildScrollView(
            child: Column(
              children: [
                _ProfileHeader(user: user),
                Padding(
                  padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 24.h),
                  child: Column(
                    children: [
                      _DetailsCard(user: user),
                      SizedBox(height: 24.h),
                      SizedBox(
                        width: double.infinity,
                        height: 48.h,
                        child: OutlinedButton.icon(
                          onPressed: _logout,
                          icon: Icon(
                            Icons.logout,
                            size: 18.sp,
                            color: Colors.red.shade700,
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.red.shade200),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                          ),
                          label: CustomText(
                            text: 'Log out',
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.red.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final User user;

  const _ProfileHeader({required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(24.w, 28.h, 24.w, 28.h),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [kPrimaryNavy, Color(0xFF1B2260)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(3.r),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: kAccentAmber, width: 2.5),
            ),
            child: CircleAvatar(
              radius: 44.r,
              backgroundColor: Colors.white,
              backgroundImage: user.image.isNotEmpty
                  ? NetworkImage(user.image)
                  : null,
              child: user.image.isEmpty
                  ? Icon(Icons.person, size: 40.sp, color: kPrimaryNavy)
                  : null,
            ),
          ),
          SizedBox(height: 14.h),
          CustomText(
            text: user.fullName.isEmpty ? user.username : user.fullName,
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          SizedBox(height: 4.h),
          CustomText(
            text: '@${user.username}',
            fontSize: 12.sp,
            color: Colors.white70,
          ),
        ],
      ),
    );
  }
}

class _DetailsCard extends StatelessWidget {
  final User user;

  const _DetailsCard({required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
      ),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
      child: Column(
        children: [
          _DetailRow(
            icon: Icons.badge_outlined,
            label: 'User ID',
            value: '${user.id}',
          ),
          _DetailRow(
            icon: Icons.person_outline,
            label: 'First name',
            value: user.firstName,
          ),
          _DetailRow(
            icon: Icons.person_outline,
            label: 'Last name',
            value: user.lastName,
          ),
          _DetailRow(
            icon: Icons.email_outlined,
            label: 'Email',
            value: user.email,
          ),
          _DetailRow(
            icon: Icons.wc_outlined,
            label: 'Gender',
            value: user.gender,
            isLast: true,
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isLast;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 12.h),
          child: Row(
            children: [
              Icon(icon, size: 18.sp, color: kPrimaryNavy),
              SizedBox(width: 12.w),
              CustomText(text: label, fontSize: 12.sp, color: Colors.black54),
              const Spacer(),
              Flexible(
                child: CustomText(
                  text: value.isEmpty ? '—' : value,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        if (!isLast) Divider(height: 1, color: Colors.grey.shade200),
      ],
    );
  }
}
