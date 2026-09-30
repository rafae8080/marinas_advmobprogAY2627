// Act4 Enhancement 3: profile screen. Everything it draws comes from the User
// model that UserService rebuilds out of SharedPreferences, so it renders with
// no network call and still works offline.

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

// models
import '../models/user.dart';

// services
import '../services/user_service.dart';

// utils
import '../utils/auth_helpers.dart';

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

  void _reload() => setState(() => _userFuture = _userService.getUser());

  void _showMessage(String text) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: CustomText(text: text, fontSize: 12.sp)));
  }

  Future<void> _updateUsername(User user) async {
    final updated = await showDialog<bool>(
      context: context,
      builder: (_) => _ActionDialog(
        title: 'Update username',
        confirmLabel: 'Save',
        fields: [
          _DialogField(
            label: 'New username',
            initialValue: user.username,
            validator: (v) {
              final value = v?.trim() ?? '';
              if (value.isEmpty) return 'Username is required';
              if (!RegExp(r'^[A-Za-z0-9_.]{3,20}$').hasMatch(value)) {
                return '3 – 20 letters, numbers, _ or .';
              }
              return null;
            },
          ),
        ],
        onConfirm: (values) =>
            _userService.updateUsername(username: values[0].trim()),
      ),
    );
    if (updated != true || !mounted) return;
    _reload();
    _showMessage('Username updated.');
  }

  Future<void> _changePassword(User user) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => _ActionDialog(
        title: 'Change password',
        confirmLabel: 'Change',
        fields: [
          _DialogField(
            label: 'Current password',
            obscure: true,
            validator: (v) =>
                (v == null || v.isEmpty) ? 'Enter your current password' : null,
          ),
          _DialogField(
            label: 'New password',
            obscure: true,
            validator: validatePassword,
          ),
          _DialogField(label: 'Confirm new password', obscure: true),
        ],
        crossCheck: (values) =>
            values[1] != values[2] ? 'New passwords do not match.' : null,
        onConfirm: (values) => _userService.resetPasswordFromCurrentPassword(
          currentPassword: values[0],
          newPassword: values[1],
          email: user.email,
        ),
      ),
    );
    if (changed != true || !mounted) return;
    _showMessage('Password changed.');
  }

  Future<void> _deleteAccount(User user) async {
    final deleted = await showDialog<bool>(
      context: context,
      builder: (_) => _ActionDialog(
        title: 'Delete account?',
        message:
            'This permanently removes ${user.email} and its profile. '
            'Enter your password to confirm.',
        confirmLabel: 'Delete',
        destructive: true,
        fields: [
          _DialogField(
            label: 'Password',
            obscure: true,
            validator: (v) =>
                (v == null || v.isEmpty) ? 'Enter your password' : null,
          ),
        ],
        onConfirm: (values) =>
            _userService.deleteAccount(email: user.email, password: values[0]),
      ),
    );
    if (deleted != true || !mounted) return;
    await endSession(context);
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
          if (user == null || !user.hasSession) {
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
                      SizedBox(height: 16.h),
                      _AccountCard(
                        user: user,
                        onUpdateUsername: () => _updateUsername(user),
                        onChangePassword: () => _changePassword(user),
                        onDeleteAccount: () => _deleteAccount(user),
                      ),
                      SizedBox(height: 24.h),
                      SizedBox(
                        width: double.infinity,
                        height: 48.h,
                        child: OutlinedButton.icon(
                          onPressed: () => confirmAndLogout(context),
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
          SizedBox(height: 10.h),
          // Act5 Enhancement 3: which backend this session belongs to.
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: kAccentAmber,
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  user.isFirebase
                      ? Icons.local_fire_department
                      : Icons.cloud_outlined,
                  size: 14.sp,
                ),
                SizedBox(width: 4.w),
                CustomText(
                  text: '${user.loginType.label} account',
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ],
            ),
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
    // Act5 Enhancement 3: DummyJSON and Firebase users carry different fields,
    // so the rows are picked by LoginType.
    final rows = <_DetailRow>[
      if (user.isFirebase)
        _DetailRow(icon: Icons.fingerprint, label: 'UID', value: user.uid)
      else
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
        icon: Icons.cake_outlined,
        label: 'Age',
        value: user.age == 0 ? '' : '${user.age}',
      ),
      _DetailRow(
        icon: Icons.phone_outlined,
        label: 'Contact no.',
        value: user.phone,
      ),
      _DetailRow(icon: Icons.email_outlined, label: 'Email', value: user.email),
      if (!user.isFirebase)
        _DetailRow(
          icon: Icons.wc_outlined,
          label: 'Gender',
          value: user.gender,
        ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
      ),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            rows[i],
            if (i < rows.length - 1)
              Divider(height: 1, color: Colors.grey.shade200),
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 12.h),
      child: Row(
        children: [
          Icon(icon, size: 18.sp, color: kPrimaryNavy),
          SizedBox(width: 12.w),
          CustomText(text: label, fontSize: 12.sp, color: Colors.black54),
          SizedBox(width: 12.w),
          Expanded(
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
    );
  }
}

class _AccountCard extends StatelessWidget {
  final User user;
  final VoidCallback onUpdateUsername;
  final VoidCallback onChangePassword;
  final VoidCallback onDeleteAccount;

  const _AccountCard({
    required this.user,
    required this.onUpdateUsername,
    required this.onChangePassword,
    required this.onDeleteAccount,
  });

  @override
  Widget build(BuildContext context) {
    // Act5 Enhancement 3: DummyJSON cannot change a password or delete a user
    // for real, so those actions are only offered to Firebase accounts.
    final firebaseOnly = user.isFirebase
        ? null
        : 'Only available for Firebase accounts';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        children: [
          _ActionTile(
            icon: Icons.edit_outlined,
            label: 'Update username',
            onTap: onUpdateUsername,
          ),
          Divider(height: 1, color: Colors.grey.shade200),
          _ActionTile(
            icon: Icons.password_outlined,
            label: 'Change password',
            disabledReason: firebaseOnly,
            onTap: onChangePassword,
          ),
          Divider(height: 1, color: Colors.grey.shade200),
          _ActionTile(
            icon: Icons.delete_outline,
            label: 'Delete account',
            color: Colors.red.shade700,
            disabledReason: firebaseOnly,
            onTap: onDeleteAccount,
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  final String? disabledReason;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = kPrimaryNavy,
    this.disabledReason,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = disabledReason == null;
    return ListTile(
      enabled: enabled,
      leading: Icon(icon, size: 20.sp, color: enabled ? color : Colors.grey),
      title: CustomText(
        text: label,
        fontSize: 13.sp,
        fontWeight: FontWeight.w600,
        color: enabled ? color : Colors.grey,
      ),
      subtitle: enabled
          ? null
          : CustomText(
              text: disabledReason!,
              fontSize: 11.sp,
              color: Colors.grey,
            ),
      trailing: Icon(Icons.chevron_right, size: 20.sp),
      onTap: onTap,
    );
  }
}

class _DialogField {
  final String label;
  final String initialValue;
  final bool obscure;
  final String? Function(String?)? validator;

  const _DialogField({
    required this.label,
    this.initialValue = '',
    this.obscure = false,
    this.validator,
  });
}

// One dialog for all three account actions: it validates, runs the action,
// and keeps itself open with the error if the action throws.
class _ActionDialog extends StatefulWidget {
  final String title;
  final String? message;
  final String confirmLabel;
  final bool destructive;
  final List<_DialogField> fields;
  final String? Function(List<String> values)? crossCheck;
  final Future<void> Function(List<String> values) onConfirm;

  const _ActionDialog({
    required this.title,
    required this.confirmLabel,
    required this.fields,
    required this.onConfirm,
    this.message,
    this.destructive = false,
    this.crossCheck,
  });

  @override
  State<_ActionDialog> createState() => _ActionDialogState();
}

class _ActionDialogState extends State<_ActionDialog> {
  final _formKey = GlobalKey<FormState>();
  late final List<TextEditingController> _controllers = [
    for (final field in widget.fields)
      TextEditingController(text: field.initialValue),
  ];

  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final values = [for (final c in _controllers) c.text];
    final mismatch = widget.crossCheck?.call(values);
    if (mismatch != null) {
      setState(() => _error = mismatch);
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await widget.onConfirm(values);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = readableAuthError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.destructive ? Colors.red.shade700 : kPrimaryNavy;

    return AlertDialog(
      title: CustomText(
        text: widget.title,
        fontSize: 16.sp,
        fontWeight: FontWeight.w600,
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.message != null) ...[
                CustomText(text: widget.message!, fontSize: 12.sp),
                SizedBox(height: 12.h),
              ],
              for (var i = 0; i < widget.fields.length; i++)
                Padding(
                  padding: EdgeInsets.only(bottom: 10.h),
                  child: TextFormField(
                    controller: _controllers[i],
                    obscureText: widget.fields[i].obscure,
                    autocorrect: false,
                    enableSuggestions: false,
                    enabled: !_isLoading,
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 13.sp),
                    decoration: InputDecoration(
                      labelText: widget.fields[i].label,
                      errorMaxLines: 2,
                    ),
                    validator: widget.fields[i].validator,
                  ),
                ),
              if (_error != null)
                CustomText(
                  text: _error!,
                  fontSize: 11.sp,
                  color: Colors.red.shade700,
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context, false),
          child: CustomText(text: 'Cancel', fontSize: 13.sp),
        ),
        TextButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? SizedBox(
                  width: 16.w,
                  height: 16.w,
                  child: const CircularProgressIndicator(strokeWidth: 2),
                )
              : CustomText(
                  text: widget.confirmLabel,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: accent,
                ),
        ),
      ],
    );
  }
}
