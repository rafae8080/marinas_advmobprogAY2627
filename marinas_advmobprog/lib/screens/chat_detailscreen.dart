import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../constants.dart';
import '../models/message.dart';
import '../services/chat_service.dart';
import '../widgets/custom_text.dart';

final ChatService chatService = ChatService();

class ChatDetailScreen extends StatefulWidget {
  final String currentUserEmail;
  final Map<String, dynamic> tappedUser;

  const ChatDetailScreen({
    super.key,
    required this.currentUserEmail,
    required this.tappedUser,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _msgCtrl = TextEditingController();
  final FocusNode _msgFocus = FocusNode();
  final ScrollController _scrollCtrl = ScrollController();

  late final String _currentUserId = ChatService.currentUid ?? '';
  late final String _tappedUserId = (widget.tappedUser['uid'] ?? '').toString();
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _messages = chatService
      .getMessage(_currentUserId, _tappedUserId);

  // Act6 Enhancement 3: only messages that arrive after the first load
  // animate in, and each "seen" update is sent once.
  Set<String>? _knownIds;
  final Set<String> _markedSeen = {};

  bool get _canSend => _msgCtrl.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _msgCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _msgFocus.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // Act6 Enhancement 3: not awaited. Firestore shows the message locally at
  // once, and the bubble reports "sending..." until the server confirms it.
  void _send() {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;

    _msgCtrl.clear();
    _msgFocus.requestFocus();
    chatService.sendMessage(_tappedUserId, text).catchError((e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to send: $e')));
    });

    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _markIncomingAsSeen(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final unseen = docs.where((d) {
      final data = d.data();
      return data['receiverId'] == _currentUserId &&
          data['seen'] != true &&
          _markedSeen.add(d.id);
    }).toList();
    if (unseen.isEmpty) return;
    chatService.markAsSeen(unseen).catchError((_) {
      _markedSeen.removeAll(unseen.map((d) => d.id));
    });
  }

  @override
  Widget build(BuildContext context) {
    final tappedUserName =
        '${widget.tappedUser['firstName'] ?? ''} ${widget.tappedUser['lastName'] ?? ''}'
            .trim();
    final initial = tappedUserName.isNotEmpty
        ? tappedUserName[0].toUpperCase()
        : '?';

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            Hero(
              tag: 'avatar-$_tappedUserId',
              child: CircleAvatar(
                radius: 18.r,
                backgroundColor: kAccentAmber,
                child: CustomText(
                  text: initial,
                  fontSize: 15.sp,
                  fontWeight: FontWeight.bold,
                  color: kPrimaryNavy,
                ),
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomText(
                    text: tappedUserName.isNotEmpty ? tappedUserName : 'Chat',
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  CustomText(
                    text: (widget.tappedUser['email'] ?? '').toString(),
                    fontSize: 11.sp,
                    color: Colors.white70,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Messages
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _messages,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error loading messages: ${snapshot.error}'),
                  );
                }

                final docs = snapshot.data?.docs ?? [];
                _knownIds ??= docs.map((d) => d.id).toSet();
                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => _markIncomingAsSeen(docs),
                );

                if (docs.isEmpty) return _EmptyChat(name: tappedUserName);

                return ListView.builder(
                  controller: _scrollCtrl,
                  reverse: true,
                  padding: EdgeInsets.symmetric(
                    vertical: 12.h,
                    horizontal: 10.w,
                  ),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final message = MessageModel.fromMap(doc.data());
                    final isMe = message.senderId == _currentUserId;

                    // The list is reversed: index - 1 is the newer neighbour.
                    final newerFromSame =
                        index > 0 &&
                        docs[index - 1].data()['senderId'] == message.senderId;
                    final olderFromSame =
                        index < docs.length - 1 &&
                        docs[index + 1].data()['senderId'] == message.senderId;

                    final status = doc.metadata.hasPendingWrites
                        ? MessageStatus.sending
                        : message.seen
                        ? MessageStatus.seen
                        : MessageStatus.delivered;

                    return _AnimatedEntry(
                      key: ValueKey(doc.id),
                      animate: _knownIds!.add(doc.id),
                      fromRight: isMe,
                      child: _ChatBubble(
                        message: message,
                        isMe: isMe,
                        status: status,
                        showTail: !newerFromSame,
                        groupedAbove: olderFromSame,
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // Composer
          _Composer(
            controller: _msgCtrl,
            focusNode: _msgFocus,
            canSend: _canSend,
            onSend: _send,
          ),
        ],
      ),
    );
  }
}

// Act6 Enhancement 3: fade + slide for messages as they arrive.
class _AnimatedEntry extends StatefulWidget {
  const _AnimatedEntry({
    super.key,
    required this.animate,
    required this.fromRight,
    required this.child,
  });

  final bool animate;
  final bool fromRight;
  final Widget child;

  @override
  State<_AnimatedEntry> createState() => _AnimatedEntryState();
}

class _AnimatedEntryState extends State<_AnimatedEntry>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
    value: widget.animate ? 0 : 1,
  )..forward();

  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curve,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: Offset(widget.fromRight ? 0.25 : -0.25, 0.3),
          end: Offset.zero,
        ).animate(_curve),
        child: SizeTransition(
          sizeFactor: _curve,
          axisAlignment: -1,
          child: widget.child,
        ),
      ),
    );
  }
}

// Act6 Enhancement 3: navy bubbles on the right for me, neutral bubbles on
// the left for the other person, with a tail only on the last of a run.
class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    required this.message,
    required this.isMe,
    required this.status,
    required this.showTail,
    required this.groupedAbove,
  });

  final MessageModel message;
  final bool isMe;
  final MessageStatus status;
  final bool showTail;
  final bool groupedAbove;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isMe
        ? Colors.white
        : (isDark ? Colors.white : Colors.black87);
    final metaColor = isMe
        ? Colors.white70
        : (isDark ? Colors.white54 : Colors.black45);
    const radius = Radius.circular(18);
    const tail = Radius.circular(4);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(top: groupedAbove ? 2.h : 8.h),
        padding: EdgeInsets.fromLTRB(14.w, 9.h, 10.w, 6.h),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          gradient: isMe
              ? const LinearGradient(
                  colors: [kPrimaryNavy, Color(0xFF4353B8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isMe
              ? null
              : (isDark ? const Color(0xFF3A3A3C) : Colors.white),
          borderRadius: BorderRadius.only(
            topLeft: radius,
            topRight: radius,
            bottomLeft: !isMe && showTail ? tail : radius,
            bottomRight: isMe && showTail ? tail : radius,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              widthFactor: 1,
              child: CustomText(
                text: message.message.isNotEmpty ? message.message : '[empty]',
                fontSize: 15.sp,
                color: textColor,
              ),
            ),
            SizedBox(height: 3.h),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomText(
                  text: _formatTime(message.timestamp.toDate()),
                  fontSize: 10.sp,
                  color: metaColor,
                ),
                if (isMe) ...[
                  SizedBox(width: 4.w),
                  _StatusIndicator(status: status, color: metaColor),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _formatTime(DateTime time) {
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${time.hour < 12 ? 'AM' : 'PM'}';
  }
}

// Act6 Enhancement 3: "sending..." -> ✓ delivered -> ✓✓ seen.
class _StatusIndicator extends StatelessWidget {
  const _StatusIndicator({required this.status, required this.color});

  final MessageStatus status;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final Widget child = switch (status) {
      MessageStatus.sending => Row(
        key: const ValueKey('sending'),
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule, size: 12.sp, color: color),
          SizedBox(width: 2.w),
          CustomText(
            text: 'sending...',
            fontSize: 10.sp,
            fontStyle: FontStyle.italic,
            color: color,
          ),
        ],
      ),
      MessageStatus.delivered => Icon(
        Icons.done,
        key: const ValueKey('delivered'),
        size: 14.sp,
        color: color,
      ),
      MessageStatus.seen => Icon(
        Icons.done_all,
        key: const ValueKey('seen'),
        size: 14.sp,
        color: kAccentAmber,
      ),
    };

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      transitionBuilder: (child, animation) =>
          ScaleTransition(scale: animation, child: child),
      child: child,
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.canSend,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool canSend;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.fromLTRB(10.w, 8.h, 8.w, 8.h),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                textInputAction: TextInputAction.send,
                textCapitalization: TextCapitalization.sentences,
                minLines: 1,
                maxLines: 4,
                onSubmitted: (_) => onSend(),
                style: TextStyle(fontFamily: 'Poppins', fontSize: 14.sp),
                decoration: InputDecoration(
                  hintText: 'Type a message…',
                  hintStyle: TextStyle(fontFamily: 'Poppins', fontSize: 14.sp),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF2C2C2E) : kScreenGrey,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 12.h,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            SizedBox(width: 8.w),
            AnimatedScale(
              scale: canSend ? 1 : 0.85,
              duration: const Duration(milliseconds: 200),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: canSend ? kPrimaryNavy : Colors.grey.shade400,
                ),
                child: IconButton(
                  icon: const Icon(Icons.send_rounded, color: Colors.white),
                  onPressed: canSend ? onSend : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutBack,
        builder: (context, value, child) => Opacity(
          opacity: value.clamp(0, 1),
          child: Transform.scale(scale: value, child: child),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.waving_hand_outlined, size: 48.sp, color: kAccentAmber),
            SizedBox(height: 8.h),
            CustomText(
              text: 'No messages yet',
              fontSize: 15.sp,
              fontWeight: FontWeight.w600,
            ),
            CustomText(
              text: name.isNotEmpty ? 'Say hi to $name!' : 'Say hi!',
              fontSize: 12.sp,
              color: Colors.grey,
            ),
          ],
        ),
      ),
    );
  }
}
