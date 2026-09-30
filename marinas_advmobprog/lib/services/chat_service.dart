import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/message.dart';

class ChatService {
  late final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  // Chat needs a Firebase session; a DummyJSON sign-in has none.
  static String? get currentUid =>
      Firebase.apps.isEmpty ? null : FirebaseAuth.instance.currentUser?.uid;

  // get all users
  // Act6 Enhancement 1: the signed-in user is left out of the list.
  Stream<List<Map<String, dynamic>>> getUsersStream() {
    final myUid = _firebaseAuth.currentUser?.uid;
    return _firestore.collection('users').snapshots().map((snapshot) {
      return snapshot.docs
          .where((doc) => doc.id != myUid)
          .map((doc) => {...doc.data(), 'uid': doc.id})
          .toList();
    });
  }

  // send message
  Future<void> sendMessage(String receiverId, String message) async {
    final String currentUserId = _firebaseAuth.currentUser!.uid;
    final String? currentUserEmail = _firebaseAuth.currentUser!.email;
    final Timestamp timestamp = Timestamp.now();

    MessageModel newMessage = MessageModel(
      senderId: currentUserId,
      senderEmail: currentUserEmail ?? '',
      receiverId: receiverId,
      message: message,
      timestamp: timestamp,
    );

    await _firestore
        .collection('chat_rooms')
        .doc(chatRoomId(currentUserId, receiverId))
        .collection('messages')
        .add(newMessage.toMap());
  }

  // get message
  // Act6 Enhancement 3: metadata changes are included so a message can be
  // shown as "sending" until the server acknowledges it.
  Stream<QuerySnapshot<Map<String, dynamic>>> getMessage(
    String userID,
    String otherUserID,
  ) {
    return _firestore
        .collection('chat_rooms')
        .doc(chatRoomId(userID, otherUserID))
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots(includeMetadataChanges: true);
  }

  // Act6 Enhancement 3: flips "seen" on the messages addressed to me.
  Future<void> markAsSeen(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    final batch = _firestore.batch();
    for (final doc in docs) {
      batch.update(doc.reference, {'seen': true});
    }
    await batch.commit();
  }

  Future<String?> getUidByEmail(String email) async {
    final q = await _firestore
        .collection('users')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();
    if (q.docs.isEmpty) return null;
    return q.docs.first.id;
  }

  // sorted so both users resolve to the same room
  static String chatRoomId(String a, String b) {
    final ids = [a, b]..sort();
    return ids.join('_');
  }
}
