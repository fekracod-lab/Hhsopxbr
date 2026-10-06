import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:url_launcher/url_launcher.dart';

class ChatPage extends StatefulWidget {
  final String orderId;
  final String otherUserName;
  final String otherUserPhone;
  final String otherUserType; // 'customer', 'merchant', 'admin'
  final String collectionName; // 'mersal_requests', 'restaurant_orders', 'store_orders'

  const ChatPage({
    super.key,
    required this.orderId,
    required this.otherUserName,
    this.otherUserPhone = '',
    this.otherUserType = 'customer',
    this.collectionName = 'mersal_requests',
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final String? _uid = FirebaseAuth.instance.currentUser?.uid;

  static const Color _bgLight = Color(0xFFF8FAFC);
  static const Color _cardLight = Color(0xFFFFFFFF);
  static const Color _textMain = Color(0xFF0F172A);
  static const Color _textSub = Color(0xFF475569);
  static const Color _borderLight = Color(0xFFE2E8F0);
  static const Color _primaryLight = Color(0xFF00BFA5);

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _bgLight,
      appBar: AppBar(
        backgroundColor: _cardLight,
        elevation: 0,
        foregroundColor: _textMain,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.otherUserName,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: _textMain),
            ),
            Text(
              widget.otherUserType == 'customer'
                  ? 'الزبون'
                  : (widget.otherUserType == 'merchant' ? 'المتجر / المطعم' : 'الدعم الفني'),
              style: const TextStyle(fontSize: 11, color: _textSub, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          if (widget.otherUserPhone.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.phone_rounded, color: Color(0xFF00C853)),
              tooltip: 'اتصال مباشر',
              onPressed: () => launchUrl(Uri.parse('tel:${widget.otherUserPhone}')),
            ),
        ],
      ),
        body: Column(
          children: [
            Expanded(child: _buildMessagesList()),
            _buildMessageInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildMessagesList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(widget.collectionName)
          .doc(widget.orderId)
          .collection('messages')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: _primaryLight));
        }

        final messages = snapshot.data!.docs;
        if (messages.isEmpty) {
          return const Center(
            child: Text(
              'ماكو رسائل حالياً سابقة. ابدأ المحادثة الآن',
              style: TextStyle(color: _textSub, fontSize: 13, fontWeight: FontWeight.bold),
            ),
          );
        }

        return ListView.builder(
          controller: _scrollController,
          reverse: true,
          padding: const EdgeInsets.all(16),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final data = messages[index].data() as Map<String, dynamic>;
            final bool isMe = data['senderId'] == _uid;

            return _buildChatBubble(
              text: data['text'] ?? '',
              time: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
              isMe: isMe,
            );
          },
        );
      },
    );
  }

  Widget _buildChatBubble({required String text, required DateTime time, required bool isMe}) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMe ? _primaryLight : _cardLight,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMe ? 18 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 18),
          ),
          border: Border.all(color: isMe ? _primaryLight : _borderLight),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isMe ? 0.08 : 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              text,
              style: TextStyle(
                color: isMe ? Colors.white : _textMain,
                fontSize: 13.5,
                fontWeight: isMe ? FontWeight.bold : FontWeight.w600,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('hh:mm a').format(time),
              style: TextStyle(
                color: isMe ? Colors.white70 : Colors.grey,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: EdgeInsets.fromLTRB(14, 10, 14, MediaQuery.of(context).padding.bottom + 10),
      decoration: BoxDecoration(
        color: _cardLight,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: _bgLight,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: _borderLight),
              ),
              child: TextField(
                controller: _messageController,
                style: const TextStyle(color: _textMain, fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'اكتب رسالتك للمستلم هنا...',
                  hintStyle: TextStyle(color: Colors.grey, fontSize: 13),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF00BFA5), Color(0xFF00897B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _uid == null) return;

    _messageController.clear();

    await FirebaseFirestore.instance
        .collection(widget.collectionName)
        .doc(widget.orderId)
        .collection('messages')
        .add({
      'text': text,
      'senderId': _uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
