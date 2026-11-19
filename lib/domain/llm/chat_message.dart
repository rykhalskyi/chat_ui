import '../entities/chat_role.dart';

class ChatMessage {
  const ChatMessage({required this.role, required this.content});

  const ChatMessage.system(this.content) : role = ChatRole.system;

  const ChatMessage.user(this.content) : role = ChatRole.user;

  const ChatMessage.assistant(this.content) : role = ChatRole.assistant;

  final ChatRole role;
  final String content;

  Map<String, dynamic> toJson() => {'role': role.name, 'content': content};
}
