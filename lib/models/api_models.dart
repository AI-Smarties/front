// Small data models added so that frontend doesn't need to work directly with raw JSON maps.
// These models represent the backend REST response shapes in typed Dart objects.

class Category {
  final int id;
  final String name;

  const Category({
    required this.id,
    required this.name,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as int,
      // Defensive parsing to avoid crashing if backend gives null or odd types.
      name: (json['name'] ?? '').toString(),
    );
  }

  @override
  String toString() => name;
}

class Conversation {
  final int id;
  final String name;
  final String summary;
  final int? categoryId;
  final DateTime? timestamp;

  const Conversation({
    required this.id,
    required this.name,
    required this.summary,
    required this.categoryId,
    required this.timestamp,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'] as int,
      name: (json['name'] ?? '').toString(),
      summary: (json['summary'] ?? '').toString(),
      categoryId: json['category_id'] as int?,
      // Defensive parsing for nullable timestamp so malformed or missing values don't crash the app or side panel UI
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString())
          : null,
    );
  }
}

class ConversationVector {
  final int id;
  final String text;
  final int conversationId;

  const ConversationVector({
    required this.id,
    required this.text,
    required this.conversationId,
  });

  factory ConversationVector.fromJson(Map<String, dynamic> json) {
    return ConversationVector(
      id: json['id'] as int,
      text: (json['text'] ?? '').toString(),
      conversationId: json['conversation_id'] as int,
    );
  }
}
