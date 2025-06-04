import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/widgets.dart';
import 'messages_state.dart';
import '../Authentication/auth_cubit.dart';
import '../Authentication/auth_state.dart';
import '../../models/conversation.dart';

class MessagesCubit extends Cubit<MessagesState> {
  MessagesCubit() : super(MessagesLoading());

  StreamSubscription<QuerySnapshot>? _subscription;

  /// ✅ تحميل المحادثات من Firestore باستخدام AuthCubit
  void loadMessages(BuildContext context) {
    final authState = context.read<AuthCubit>().state;

    if (authState is! AuthAuthenticated) {
      emit(MessagesNotLogged());
      return;
    }

    final userId = authState.user.uid;
    _listenToConversations(userId);
  }

  Future<void> startConversation({
    required String patientId,
    required String doctorId,
    required String message,
    required String doctorName,
    required String doctorSpecialty,
    required String doctorImage,
    required String patientName,
    required String accountHolderName,
    required String selectedReason,
  }) async {
    try {
      final convoRef = FirebaseFirestore.instance.collection('conversations');

      final existingQuery = await convoRef
          .where('patientId', isEqualTo: patientId)
          .where('doctorId', isEqualTo: doctorId)
          .limit(1)
          .get();

      final messageData = {
        'senderId': patientId,
        'text': message,
        'timestamp': FieldValue.serverTimestamp(),
        'isSeen': false,
        'senderName': patientName,
        'isUser': true,
      };

      DocumentReference convoDoc;

      if (existingQuery.docs.isNotEmpty) {
        convoDoc = existingQuery.docs.first.reference;

        final msgRef = await convoDoc.collection('messages').add(messageData);
        final msgSnapshot = await msgRef.get();
        final actualTimestamp = (msgSnapshot['timestamp'] as Timestamp).toDate();

        await convoDoc.update({
          'lastMessage': message,
          'lastSenderId': patientId,
          'updatedAt': actualTimestamp,
          'doctorName': doctorName,
          'doctorSpecialty': doctorSpecialty,
          'doctorImage': doctorImage,
          'isClosed': false,
          'patientName': patientName,
          'accountHolderName': accountHolderName,
          'selectedReason': selectedReason,
        });
      } else {
        convoDoc = await convoRef.add({
          'patientId': patientId,
          'doctorId': doctorId,
          'participants': [FirebaseAuth.instance.currentUser!.uid, patientId, doctorId],
          'lastMessage': message,
          'lastSenderId': patientId,
          'updatedAt': DateTime.now(), // مؤقتًا
          'doctorName': doctorName,
          'doctorSpecialty': doctorSpecialty,
          'doctorImage': doctorImage,
          'isClosed': false,
          'patientName': patientName,
          'accountHolderName': accountHolderName,
          'selectedReason': selectedReason,
          'unreadCountForDoctor': 1,
        });


        final msgRef = await convoDoc.collection('messages').add(messageData);
        final msgSnapshot = await msgRef.get();
        final actualTimestamp = (msgSnapshot['timestamp'] as Timestamp).toDate();

        await convoDoc.update({
          'updatedAt': actualTimestamp,
        });
      }
    } catch (e) {
      print("❌ Failed to start conversation: $e");
      emit(MessagesError("حدث خطأ أثناء إرسال الرسالة"));
    }
  }



  /// ✅ الاستماع إلى جميع المحادثات الخاصة بالمستخدم الحالي
  void _listenToConversations(String userId) {
    emit(MessagesLoading());
    _subscription?.cancel();

    _subscription = FirebaseFirestore.instance
        .collection('conversations')
        .where('participants', arrayContains: userId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      final List<Future<Conversation>> futures = [];

      for (final doc in snapshot.docs) {
        final baseConvo = Conversation.fromFirestore(doc);
        final unreadCount = doc.data().containsKey('unreadCountForUser')
            ? doc['unreadCountForUser']
            : 0;
        final convoWithUnread = baseConvo.copyWith(unreadCountForUser: unreadCount);


        futures.add(
          doc.reference
              .collection('messages')
              .orderBy('timestamp', descending: true)
              .limit(1)
              .get()
              .then((msgSnapshot) {
            final messages = <Map<String, dynamic>>[];

            if (msgSnapshot.docs.isNotEmpty) {
              final data = msgSnapshot.docs.first.data();
              messages.add({
                'text': data['text'],
                'timestamp': (data['timestamp'] as Timestamp?)?.toDate(),
                'senderId': data['senderId'],
                'readByUser': data['readByUser'] ?? false,
                'isUser': data['isUser'] ?? false,
              });
            }

            return convoWithUnread.copyWith(messages: messages);
          }),
        );
      }

      Future.wait(futures).then((loadedConversations) {
        emit(MessagesLoaded(loadedConversations));
      });
    }, onError: (e) {
      emit(MessagesError("Failed to load messages: $e"));
    });
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
