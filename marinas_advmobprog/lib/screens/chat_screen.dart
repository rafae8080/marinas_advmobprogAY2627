import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../services/chat_service.dart';
import '../services/user_service.dart';
import '../widgets/custom_text.dart';
import '../constants.dart';
import 'chat_detailscreen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _searchChatController = TextEditingController();
  final ChatService _chatService = ChatService();
  // Built once, so typing in the search bar does not resubscribe.
  late final Stream<List<Map<String, dynamic>>> _usersStream = _chatService
      .getUsersStream();
  String? _currentUserEmail;
  String _searchText = '';

  @override
  void initState() {
    super.initState();
    _loadCurrentUserEmail();
  }

  Future<void> _loadCurrentUserEmail() async {
    final userData = await userService.value.getUserData();
    if (!mounted) return;
    setState(() {
      _currentUserEmail = userData['email'];
    });
  }

  @override
  void dispose() {
    _searchChatController.dispose();
    super.dispose();
  }

  // Act6 Enhancement 2: matches on first name, last name, username or email.
  bool _matches(Map<String, dynamic> user) {
    final query = _searchText.trim().toLowerCase();
    if (query.isEmpty) return true;
    final fullName = '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}';
    return [
      fullName,
      user['username'],
      user['email'],
    ].any((field) => (field ?? '').toString().toLowerCase().contains(query));
  }

  @override
  Widget build(BuildContext context) {
    if (ChatService.currentUid == null) {
      return _message(
        Icons.lock_outline,
        'Chat is only available for Firebase accounts.\n'
        'Sign in with your email to start chatting.',
      );
    }

    return Column(
      children: [
        SizedBox(height: 20.h),
        // Act6 Enhancement 2: search bar
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 23.w),
          child: TextField(
            controller: _searchChatController,
            textInputAction: TextInputAction.search,
            onChanged: (value) => setState(() => _searchText = value),
            style: TextStyle(fontFamily: 'Poppins', fontSize: 14.sp),
            decoration: InputDecoration(
              hintText: 'Search name or email...',
              hintStyle: TextStyle(fontFamily: 'Poppins', fontSize: 14.sp),
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchChatController.text.isNotEmpty
                  ? IconButton(
                      tooltip: 'Clear',
                      icon: const Icon(Icons.cancel),
                      onPressed: () {
                        setState(() {
                          _searchChatController.clear();
                          _searchText = '';
                        });
                      },
                    )
                  : null,
              filled: true,
              fillColor: Theme.of(context).cardColor,
              contentPadding: EdgeInsets.symmetric(vertical: 12.h),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        SizedBox(height: 10.h),

        // Users Stream
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: _usersStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator.adaptive(),
                );
              }
              if (snapshot.hasError) {
                return _message(Icons.error_outline, 'Error loading users');
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return _message(Icons.people_outline, 'No users found');
              }

              final users = snapshot.data!.where(_matches).toList();

              if (users.isEmpty) {
                return _message(
                  Icons.search_off,
                  'No one matches "${_searchText.trim()}"',
                );
              }

              return ListView.builder(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final user = users[index];
                  return _UserTile(
                    user: user,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatDetailScreen(
                          currentUserEmail: _currentUserEmail ?? '',
                          tappedUser: user,
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _message(IconData icon, String text) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(16.sp),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48.sp, color: Colors.grey),
            SizedBox(height: 8.h),
            CustomText(
              text: text,
              fontSize: 14.sp,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({required this.user, required this.onTap});

  final Map<String, dynamic> user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final firstName = (user['firstName'] ?? '').toString();
    final name = '$firstName ${user['lastName'] ?? ''}'.trim();

    return Card(
      elevation: 0,
      margin: EdgeInsets.symmetric(vertical: 4.h),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: onTap,
        contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
        leading: Hero(
          tag: 'avatar-${user['uid']}',
          child: CircleAvatar(
            radius: 22.r,
            backgroundColor: kPrimaryNavy,
            child: CustomText(
              text: firstName.isNotEmpty ? firstName[0].toUpperCase() : '?',
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        title: CustomText(
          text: name.isNotEmpty ? name : (user['username'] ?? 'Unknown'),
          fontSize: 16.sp,
          fontWeight: FontWeight.w600,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: CustomText(
          text: user['email'] ?? 'No email',
          fontSize: 12.sp,
          fontWeight: FontWeight.w300,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
