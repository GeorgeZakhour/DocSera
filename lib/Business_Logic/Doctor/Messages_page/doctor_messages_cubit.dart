import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../models/conversation.dart';
import 'doctor_messages_state.dart';

class DoctorMessagesCubit extends Cubit<DoctorMessagesState> {
  final String doctorId;
  StreamSubscription<QuerySnapshot>? _subscription;

  DoctorMessagesCubit({required this.doctorId}) : super(DoctorMessagesLoading());

  void loadDoctorMessages() {
    emit(DoctorMessagesLoading());
    _subscription?.cancel();

    _subscription = FirebaseFirestore.instance
        .collection('conversations')
        .where('doctorId', isEqualTo: doctorId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .listen((snapshot) async {
      final futures = snapshot.docs.map((doc) async {
        final baseConvo = Conversation.fromFirestore(doc);
        final unread = doc.data().containsKey('unreadCountForDoctor') ? doc['unreadCountForDoctor'] : 0;
        final convoWithUnread = baseConvo.copyWith(unreadCountForDoctor: unread);

        final msgSnapshot = await doc.reference
            .collection('messages')
            .orderBy('timestamp', descending: true)
            .limit(1)
            .get();

        final messages = <Map<String, dynamic>>[];
        if (msgSnapshot.docs.isNotEmpty) {
          final data = msgSnapshot.docs.first.data();
          messages.add({
            'text': data['text'],
            'timestamp': (data['timestamp'] as Timestamp?)?.toDate(),
            'senderId': data['senderId'],
            'readByDoctor': data['readByDoctor'] ?? false,
            'isUser': data['isUser'] ?? false,
          });
        }

        return convoWithUnread.copyWith(messages: messages);
      }).toList();

      final loaded = await Future.wait(futures);
      emit(DoctorMessagesLoaded(loaded));
    }, onError: (e) {
      emit(DoctorMessagesError("فشل تحميل المحادثات: $e"));
    });
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
