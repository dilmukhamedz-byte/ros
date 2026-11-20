import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'api_service.dart';
import 'models.dart';

enum ChatStatus { empty, loading, success, error, offline, timeout }

class ChatProvider extends ChangeNotifier {
  final ApiService api;
  ChatProvider(this.api);

  final List<ChatMessage> messages = [];
  String conversationId = const Uuid().v4();
  String role = 'consultant';
  ChatStatus status = ChatStatus.empty;
  String? error;
  String? pendingText; // сообщение, сохранённое при ошибке (для повтора)

  bool get isLoading => status == ChatStatus.loading;
  bool get hasFailed =>
      status == ChatStatus.error || status == ChatStatus.offline || status == ChatStatus.timeout;

  void newChat() {
    if (isLoading) return;
    messages.clear();
    conversationId = const Uuid().v4();
    pendingText = null;
    error = null;
    status = ChatStatus.empty;
    notifyListeners();
  }

  Future<void> openConversation(Conversation c) async {
    if (isLoading) return;
    try {
      final list = await api.messages(c.id);
      messages
        ..clear()
        ..addAll(list);
      conversationId = c.id;
      role = c.role;
      pendingText = null;
      error = null;
      status = messages.isEmpty ? ChatStatus.empty : ChatStatus.success;
    } on ApiException catch (e) {
      _fail(e);
    }
    notifyListeners();
  }

  void setRole(String r) {
    role = r;
    notifyListeners();
  }

  /// Возвращает true при успехе (тогда UI очищает поле ввода).
  Future<bool> send(String text) async {
    if (isLoading) return false; // защита от повторной отправки
    text = text.trim();
    if (text.isEmpty) return false;

    pendingText = text;
    error = null;
    status = ChatStatus.loading;
    final reply = ChatMessage('assistant', '');
    messages
      ..add(ChatMessage('user', text))
      ..add(reply);
    notifyListeners();

    try {
      await for (final d in api.chatStream(text, conversationId, role)) {
        reply.content += d;
        notifyListeners();
      }
      status = ChatStatus.success;
      pendingText = null;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      // убираем неотправленные пузыри; текст остаётся в pendingText
      messages.removeLast();
      messages.removeLast();
      _fail(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> retry() async {
    final t = pendingText;
    if (t == null) return false;
    return send(t);
  }

  void _fail(ApiException e) {
    error = e.message;
    status = switch (e.kind) {
      ErrKind.offline => ChatStatus.offline,
      ErrKind.timeout => ChatStatus.timeout,
      _ => ChatStatus.error,
    };
  }
}
