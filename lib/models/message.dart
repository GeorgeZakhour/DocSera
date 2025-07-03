class Message {
  final String id;
  final String senderId;
  final String text;
  final DateTime timestamp;
  final bool isSeen;

  Message({
    required this.id,
    required this.senderId,
    required this.text,
    required this.timestamp,
    required this.isSeen,
  });


  factory Message.fromMap(Map<String, dynamic> data) {
    return Message(
      id: data['id'].toString(),
      senderId: data['senderId'] ?? '',
      text: data['text'] ?? '',
      timestamp: DateTime.parse(data['timestamp']),
      isSeen: data['isSeen'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderId': senderId,
      'text': text,
      'timestamp': timestamp.toIso8601String(),
      'isSeen': isSeen,
    };
  }



}
