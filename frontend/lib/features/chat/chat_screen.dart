import 'dart:async';
import 'dart:convert';
import 'dart:html' as html; 
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'message_model.dart';
import '../../services/message_service.dart';
import '../../services/media_picker_service.dart';
import '../../services/audio_recorder_service.dart';
import '../../crypto/crypto_manager.dart';
import '../../storage/cache/message_cache.dart';
import '../../services/screenshot_protection.dart';

// --- PROTOCOL CONSTANTS ---
const String _deletionSignal = "PROTOCOL_DELETE_CONVERSATION_SYNC";
const String _reactionSignalPrefix = "PROTOCOL_REACTION:";
const String _typingSignalPrefix = "PROTOCOL_TYPING:";
const String _deliveredSignalPrefix = "PROTOCOL_DELIVERED:";
const String _readSignalPrefix = "PROTOCOL_READ:";
const String _userLeftSignal = "PROTOCOL_USER_LEFT_ROOM";
const String _burnMessagePrefix = "PROTOCOL_BURN_MESSAGE:";

// --- TYPING PROVIDER ---
final typingStatusProvider = StateNotifierProvider.family<TypingNotifier, bool, String>(
  (ref, userId) => TypingNotifier(),
);

class TypingNotifier extends StateNotifier<bool> {
  TypingNotifier() : super(false);
  Timer? _clearTimer;

  void setTyping(bool isTyping) {
    state = isTyping;
    _clearTimer?.cancel();
    if (isTyping) {
      _clearTimer = Timer(const Duration(seconds: 4), () => state = false);
    }
  }

  @override
  void dispose() {
    _clearTimer?.cancel();
    super.dispose();
  }
}

final messagesProvider = StateNotifierProvider.family<MessagesNotifier, List<ChatMessage>, String>(
  (ref, userId) => MessagesNotifier(userId, ref),
);

// --- LOGIC ENGINE ---
class MessagesNotifier extends StateNotifier<List<ChatMessage>> {
  final String otherUserId;
  final Ref ref;
  final _messageService = MessageService();
  Timer? _refreshTimer;
  Timer? _burnTimer;
  Timer? _typingDebounce;
  
  Future<void> loadMessages() async {
    await _loadMessages();
  }

  MessagesNotifier(this.otherUserId, this.ref) : super([]) {
    _loadMessages();
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (_) => _loadMessages());
    _burnTimer = Timer.periodic(const Duration(seconds: 1), (_) => _checkBurnedMessages());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _burnTimer?.cancel();
    _typingDebounce?.cancel();
    super.dispose();
  }

  void sendTypingStatus(bool isTyping) {
    _typingDebounce?.cancel();
    _typingDebounce = Timer(const Duration(milliseconds: 300), () async {
      await _messageService.sendMessage(
        recipientUserId: otherUserId,
        messageText: "$_typingSignalPrefix$isTyping",
      );
    });
  }

  // FIXED: Remove the isDelivered check so it always updates
  Future<void> markAsDelivered(String messageId) async {
    final msgIndex = state.indexWhere((m) => m.id == messageId);
    if (msgIndex != -1) {
      final updated = state[msgIndex].copyWith(isDelivered: true);
      state = [for (final m in state) m.id == messageId ? updated : m];
      await MessageCache.saveMessage(updated);
      await _messageService.sendMessage(
        recipientUserId: otherUserId,
        messageText: "$_deliveredSignalPrefix$messageId",
      );
    }
  }

  Future<void> markAsRead(String messageId) async {
    final msgIndex = state.indexWhere((m) => m.id == messageId);
    if (msgIndex != -1 && !state[msgIndex].isRead) {
      final updated = state[msgIndex].copyWith(isDelivered: true, isRead: true);
      state = [for (final m in state) m.id == messageId ? updated : m];
      await MessageCache.saveMessage(updated);
      await _messageService.sendMessage(
        recipientUserId: otherUserId,
        messageText: "$_readSignalPrefix$messageId",
      );
    }
  }

  // FIXED: Properly handle burn timer with synchronization
  void _checkBurnedMessages() async {
    final now = DateTime.now();
    final myId = CryptoManager.instance.getUserId();
    if (myId == null) return;

    final burnedMessageIds = <String>[];
    
    final updated = state.where((msg) {
      if (msg.burnAfterSeconds == null) return true;
      final expiry = msg.timestamp.add(Duration(seconds: msg.burnAfterSeconds!));
      final shouldBurn = now.isAfter(expiry) || now.isAtSameMomentAs(expiry);
      
      if (shouldBurn) {
        burnedMessageIds.add(msg.id);
      }
      
      return !shouldBurn;
    }).toList();

    if (updated.length != state.length) {
      state = updated;
      
      // Delete from cache and notify other user
      for (final msgId in burnedMessageIds) {
        await MessageCache.deleteMessage(msgId);
        // Send burn signal to other user
        try {
          await _messageService.sendMessage(
            recipientUserId: otherUserId,
            messageText: "$_burnMessagePrefix$msgId",
          );
        } catch (e) {
          debugPrint('Error sending burn signal: $e');
        }
      }
    }
  }

  void reactToMessage(String messageId, String emoji) async {
    final myId = CryptoManager.instance.getUserId()!;
    state = [
      for (final m in state)
        if (m.id == messageId) m.copyWith(reactions: {...m.reactions, myId: emoji}) else m
    ];
    final updated = state.firstWhere((m) => m.id == messageId);
    await MessageCache.saveMessage(updated);
    await _messageService.sendMessage(
      recipientUserId: otherUserId,
      messageText: "$_reactionSignalPrefix$messageId:$emoji",
    );
  }

  Future<void> deleteForEveryone() async {
    final myId = CryptoManager.instance.getUserId();
    if (myId == null) return;
    try {
      await _messageService.sendMessage(recipientUserId: otherUserId, messageText: _deletionSignal);
      await MessageCache.clearConversation(myId, otherUserId);
      state = [];
    } catch (e) { 
      debugPrint('Delete Error: $e'); 
    }
  }

  Future<void> _loadMessages() async {
    try {
      final myUserId = CryptoManager.instance.getUserId()!;
      final server = await _messageService.receiveMessages('permanent_local_vault_key');
      final cached = await MessageCache.getConversation(myUserId, otherUserId);
      
      final Map<String, ChatMessage> merged = {for (var m in cached) m.id: m};
      bool hasChanges = false;

      for (final m in server) {
        if ((m.senderId == myUserId && m.recipientId == otherUserId) || 
            (m.senderId == otherUserId && m.recipientId == myUserId)) {
          
          final text = m.text;

          // Handle Signals
          if (text == _deletionSignal || text == _userLeftSignal) {
            await MessageCache.clearConversation(myUserId, otherUserId);
            state = [];
            return; 
          }

          if (text.startsWith(_typingSignalPrefix)) {
            final isTyping = text.replaceFirst(_typingSignalPrefix, "") == 'true';
            ref.read(typingStatusProvider(otherUserId).notifier).setTyping(isTyping);
            continue; 
          }

          if (text.startsWith(_deliveredSignalPrefix)) {
            final id = text.replaceFirst(_deliveredSignalPrefix, "");
            if (merged.containsKey(id) && !merged[id]!.isDelivered) {
              merged[id] = merged[id]!.copyWith(isDelivered: true);
              await MessageCache.saveMessage(merged[id]!);
              hasChanges = true;
            }
            continue;
          }

          if (text.startsWith(_readSignalPrefix)) {
            final id = text.replaceFirst(_readSignalPrefix, "");
            if (merged.containsKey(id) && !merged[id]!.isRead) {
              merged[id] = merged[id]!.copyWith(isDelivered: true, isRead: true);
              await MessageCache.saveMessage(merged[id]!);
              hasChanges = true;
            }
            continue;
          }

          if (text.startsWith(_reactionSignalPrefix)) {
            final parts = text.replaceFirst(_reactionSignalPrefix, "").split(":");
            if (parts.length >= 2 && merged.containsKey(parts[0])) {
               final target = merged[parts[0]]!;
               final newReactions = Map<String, String>.from(target.reactions)..[m.senderId] = parts[1];
               merged[parts[0]] = target.copyWith(reactions: newReactions);
               await MessageCache.saveMessage(merged[parts[0]]!);
               hasChanges = true;
            }
            continue;
          }

          // Handle burn message signal from other user
          if (text.startsWith(_burnMessagePrefix)) {
            final id = text.replaceFirst(_burnMessagePrefix, "");
            if (merged.containsKey(id)) {
              merged.remove(id);
              await MessageCache.deleteMessage(id);
              hasChanges = true;
            }
            continue;
          }

          // Handle Content
          if (!merged.containsKey(m.id)) {
            hasChanges = true;
            final newMsg = m.senderId == otherUserId ? m.copyWith(isDelivered: true) : m;
            merged[m.id] = newMsg;
            await MessageCache.saveMessage(newMsg);
            if (m.senderId == otherUserId) {
              markAsDelivered(m.id);
            }
          }
        }
      }
      
      if (hasChanges || merged.length != state.length) {
        state = merged.values.toList()..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      }
    } catch (e) { 
      debugPrint('Sync Error: $e'); 
    }
  }

  Future<void> sendMessage(String text, {int? burnSeconds, ChatMessage? mediaMessage}) async {
    final myId = CryptoManager.instance.getUserId()!;
    final msg = mediaMessage?.copyWith(burnAfterSeconds: burnSeconds, isSent: true) ?? 
      ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: text, 
        senderId: myId, 
        recipientId: otherUserId,
        timestamp: DateTime.now(), 
        isSent: true,
        burnAfterSeconds: burnSeconds,
      );
    
    await MessageCache.saveMessage(msg);
    state = [msg, ...state];
    
    await _messageService.sendMessage(
      recipientUserId: otherUserId, 
      messageText: msg.text, 
      mediaMessage: msg, 
      burnAfterSeconds: burnSeconds
    );
  }

  void markAllAsRead() {
    for (final m in state) {
      if (m.senderId == otherUserId && !m.isRead) {
        markAsRead(m.id);
      }
    }
  }
}

// --- UI SCREEN ---
class ChatScreen extends ConsumerStatefulWidget {
  final String userId;
  const ChatScreen({super.key, required this.userId});
  
  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> with WidgetsBindingObserver {
  final _controller = TextEditingController();
  final _mediaPicker = MediaPickerService();
  int? _mintoyTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ScreenshotProtection.enableProtection();
    _controller.addListener(_onTextChanged);
    Future.microtask(() => ref.read(messagesProvider(widget.userId).notifier).markAllAsRead());
  }

  @override
  void dispose() {
    MessageService().sendMessage(recipientUserId: widget.userId, messageText: _userLeftSignal);
    WidgetsBinding.instance.removeObserver(this);
    ScreenshotProtection.disableProtection();
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(messagesProvider(widget.userId).notifier).markAllAsRead();
    }
  }

  void _onTextChanged() {
    ref.read(messagesProvider(widget.userId).notifier).sendTypingStatus(_controller.text.isNotEmpty);
  }

  void _showRoomClosedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text("Room Closed"),
        content: const Text("The peer has left. Conversation data wiped."),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            }, 
            child: const Text("OK")
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(messagesProvider(widget.userId));
    final isTyping = ref.watch(typingStatusProvider(widget.userId));

    ref.listen(messagesProvider(widget.userId), (prev, next) {
      if (next.isEmpty && prev != null && prev.isNotEmpty) {
        _showRoomClosedDialog();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.userId),
            if (isTyping)
              const Text(
                'typing...', 
                style: TextStyle(
                  fontSize: 12, 
                  fontStyle: FontStyle.italic, 
                  color: Colors.white70
                )
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever, color: Colors.red),
            onPressed: () => ref.read(messagesProvider(widget.userId).notifier).deleteForEveryone(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              reverse: true,
              itemCount: messages.length,
              itemBuilder: (_, i) => _buildBubble(
                messages[i], 
                messages[i].senderId == CryptoManager.instance.getUserId()
              ),
            )
          ),
          _buildInput(),
        ]
      ),
    );
  }

  Widget _buildBubble(ChatMessage m, bool isMe) {
    final color = isMe ? Colors.white : Colors.black87;
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onLongPress: () => _showEmojiPicker(m),
            child: Container(
              margin: const EdgeInsets.all(6),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isMe ? Colors.blue : Colors.grey[300],
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _renderMsg(m, color),
                  if (isMe) ...[
                    const SizedBox(height: 4),
                    _buildStatusIcon(m),
                  ],
                ],
              ),
            ),
          ),
          if (m.reactions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Wrap(
                children: m.reactions.values.map((e) => Text(e)).toList()
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusIcon(ChatMessage m) {
    if (m.isRead) {
      return const Icon(Icons.done_all, size: 14, color: Colors.lightBlueAccent);
    }
    if (m.isDelivered) {
      return const Icon(Icons.done_all, size: 14, color: Colors.white70);
    }
    if (m.isSent) {
      return const Icon(Icons.check, size: 14, color: Colors.white70);
    }
    return const Icon(Icons.schedule, size: 14, color: Colors.white54);
  }

  Widget _renderMsg(ChatMessage m, Color color) {
    if (m.type == MessageType.image) {
      return Image.memory(base64Decode(m.fileData!), width: 180);
    }
    if (m.type == MessageType.audio) {
      return Row(
        mainAxisSize: MainAxisSize.min, 
        children: [
          Icon(Icons.play_circle, color: color),
          const SizedBox(width: 8),
          Text("Voice Message", style: TextStyle(color: color))
        ]
      );
    }
    return Text(m.text, style: TextStyle(color: color));
  }

  Widget _buildInput() {
    return Container(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              Icons.timer, 
              color: _mintoyTime != null ? Colors.orange : Colors.grey
            ), 
            onPressed: _showMintoyPicker
          ),
          IconButton(
            icon: const Icon(Icons.add), 
            onPressed: _showAttachments
          ),
          Expanded(
            child: TextField(
              controller: _controller, 
              decoration: const InputDecoration(hintText: "Aa")
            )
          ),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: () {
              if (_controller.text.isNotEmpty) {
                ref.read(messagesProvider(widget.userId).notifier).sendMessage(
                  _controller.text, 
                  burnSeconds: _mintoyTime
                );
                _controller.clear();
              }
            },
          ),
        ]
      ),
    );
  }

  void _showMintoyPicker() {
    showModalBottomSheet(
      context: context, 
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min, 
        children: [
          ListTile(
            title: const Text("Never"), 
            onTap: () => setState(() { 
              _mintoyTime = null; 
              Navigator.pop(ctx); 
            })
          ),
          ListTile(
            title: const Text("10 Seconds"), 
            onTap: () => setState(() { 
              _mintoyTime = 10; 
              Navigator.pop(ctx); 
            })
          ),
          ListTile(
            title: const Text("1 Minute"), 
            onTap: () => setState(() { 
              _mintoyTime = 60; 
              Navigator.pop(ctx); 
            })
          ),
        ]
      )
    );
  }

  void _showAttachments() {
    showModalBottomSheet(
      context: context, 
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min, 
        children: [
          ListTile(
            leading: const Icon(Icons.image), 
            title: const Text("Image"), 
            onTap: () async {
              Navigator.pop(ctx);
              final m = await _mediaPicker.pickImage(
                senderId: CryptoManager.instance.getUserId()!, 
                recipientId: widget.userId
              );
              if (m != null) {
                ref.read(messagesProvider(widget.userId).notifier).sendMessage(
                  "", 
                  mediaMessage: m, 
                  burnSeconds: _mintoyTime
                );
              }
            }
          ),
          ListTile(
            leading: const Icon(Icons.description), 
            title: const Text("File"), 
            onTap: () async {
              Navigator.pop(ctx);
              final m = await _mediaPicker.pickFile(
                senderId: CryptoManager.instance.getUserId()!, 
                recipientId: widget.userId
              );
              if (m != null) {
                ref.read(messagesProvider(widget.userId).notifier).sendMessage(
                  "", 
                  mediaMessage: m, 
                  burnSeconds: _mintoyTime
                );
              }
            }
          ),
          ListTile(
            leading: const Icon(Icons.mic), 
            title: const Text("Voice"), 
            onTap: () { 
              Navigator.pop(ctx); 
              _showVoice(); 
            }
          ),
        ]
      )
    );
  }

  void _showVoice() {
    showDialog(
      context: context, 
      builder: (ctx) => _VoiceRecorderDialog(
        onSend: (m) => ref.read(messagesProvider(widget.userId).notifier).sendMessage(
          "", 
          mediaMessage: m, 
          burnSeconds: _mintoyTime
        ),
        userId: widget.userId,
      )
    );
  }

  void _showEmojiPicker(ChatMessage m) {
    showDialog(
      context: context, 
      builder: (ctx) => AlertDialog(
        content: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly, 
          children: ['👍', '❤️', '😂', '🔥'].map((e) => InkWell(
            onTap: () {
              ref.read(messagesProvider(widget.userId).notifier).reactToMessage(m.id, e);
              Navigator.pop(ctx);
            },
            child: Text(e, style: const TextStyle(fontSize: 25)),
          )).toList()
        ),
      )
    );
  }
}

class _VoiceRecorderDialog extends StatefulWidget {
  final String userId;
  final Function(ChatMessage) onSend;
  
  const _VoiceRecorderDialog({
    required this.userId, 
    required this.onSend
  });
  
  @override 
  State<_VoiceRecorderDialog> createState() => _VoiceRecorderDialogState();
}

class _VoiceRecorderDialogState extends State<_VoiceRecorderDialog> {
  final _audio = AudioRecorderService();
  bool _isRec = false;
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Record Voice"),
      content: Icon(
        _isRec ? Icons.mic : Icons.mic_none, 
        color: _isRec ? Colors.red : Colors.grey, 
        size: 40
      ),
      actions: [
        ElevatedButton(
          onPressed: () async {
            if (!_isRec) {
              await _audio.startRecording();
              setState(() => _isRec = true);
            } else {
              final m = await _audio.stopRecording(
                senderId: CryptoManager.instance.getUserId()!, 
                recipientId: widget.userId
              );
              if (m != null) widget.onSend(m);
              Navigator.pop(context);
            }
          },
          child: Text(_isRec ? "Stop & Send" : "Start Recording"),
        ),
      ],
    );
  }
}