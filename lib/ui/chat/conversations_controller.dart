import 'package:flutter/foundation.dart';

import '../../domain/entities/conversation.dart';
import '../../domain/repositories/chat_repository.dart';

class ConversationsController extends ChangeNotifier {
  ConversationsController({required this.repository});

  static const newConversationTitle = 'New chat';

  final ChatRepository repository;
  List<Conversation> _conversations = [];
  bool _isLoading = true;
  String? _errorMessage;

  List<Conversation> get conversations => _conversations;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  Conversation? get mostRecent =>
      _conversations.isEmpty ? null : _conversations.first;

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _conversations = await repository.listConversations();
    } catch (error) {
      _errorMessage = 'Could not load conversations: $error';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    try {
      _conversations = await repository.listConversations();
      _errorMessage = null;
      notifyListeners();
    } catch (error) {
      _errorMessage = 'Could not refresh conversations: $error';
      notifyListeners();
    }
  }

  Future<Conversation> create({
    required String modelId,
    String? systemPrompt,
  }) async {
    final conversation = await repository.createConversation(
      title: newConversationTitle,
      modelId: modelId,
      systemPrompt: systemPrompt,
    );
    _conversations = [conversation, ..._conversations];
    notifyListeners();
    return conversation;
  }

  Future<void> rename(Conversation conversation, String title) async {
    await repository.renameConversation(conversation.id, title);
    await refresh();
  }

  Future<void> delete(Conversation conversation) async {
    await repository.deleteConversation(conversation.id);
    _conversations = _conversations
        .where((item) => item.id != conversation.id)
        .toList();
    notifyListeners();
  }
}
