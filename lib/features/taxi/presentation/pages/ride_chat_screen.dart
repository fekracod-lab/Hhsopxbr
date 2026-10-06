import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart' as intl;
import 'package:url_launcher/url_launcher.dart';
import 'package:dalal_alqaim/services/notification_service.dart';
import 'package:dalal_alqaim/models/notification_model.dart';

class TripDesign {
  static const Color primary = Color(0xFF26A69A);
  static const Color primaryLight = Color(0xFF80CBC4);
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkCard = Color(0xFF1E2124);
  static const Color accent = Color(0xFF00BFA5);
}

class RideChatScreen extends StatefulWidget {
  final String rideId;
  final String peerName;
  final String peerId;
  final String? peerImage;
  final String? peerPhone;

  const RideChatScreen({
    super.key,
    required this.rideId,
    required this.peerName,
    required this.peerId,
    this.peerImage,
    this.peerPhone,
  });

  @override
  State<RideChatScreen> createState() => _RideChatScreenState();
}

class _RideChatScreenState extends State<RideChatScreen> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void dispose() {
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;
    
    final messageText = text;
    _msgController.clear();

    try {
      await FirebaseFirestore.instance
          .collection('ride_requests')
          .doc(widget.rideId)
          .collection('messages')
          .add({
        'text': messageText,
        'senderId': _currentUserId,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });
      _scrollToBottom();

      // Emit push notification & save to recipient history
      if (widget.peerId.isNotEmpty) {
        final senderName = FirebaseAuth.instance.currentUser?.displayName ?? 'المحادثة';
        await NotificationService.emitEvent(
          type: 'new_chat_message',
          payload: {
            'targetUserId': widget.peerId,
            'senderId': _currentUserId,
            'senderName': senderName,
            'rideId': widget.rideId,
            'message': messageText,
            'title': 'رسالة جديدة من $senderName',
            'body': messageText,
          },
        );

        await NotificationService.saveToHistory(
          userId: widget.peerId,
          title: 'رسالة جديدة من $senderName',
          body: messageText,
          type: NotificationType.taxi,
          data: {
            'rideId': widget.rideId,
            'type': 'ride_chat',
            'peerId': _currentUserId,
            'peerName': senderName,
          },
        );
      }
    } catch (e) {
      debugPrint('Error sending message: $e');
    }
  }

  void _scrollToBottom() {
    if (!mounted) return;
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatTime(dynamic timestamp) {
    if (timestamp == null) return '';
    try {
      DateTime date;
      if (timestamp is Timestamp) {
        date = timestamp.toDate();
      } else if (timestamp is DateTime) {
        date = timestamp;
      } else {
        return '';
      }
      return intl.DateFormat('hh:mm a').format(date);
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TripDesign.darkBackground,
      appBar: _buildAppBar(),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _buildMessagesList()),
            _buildQuickMessages(),
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: TripDesign.darkCard,
      elevation: 4,
      automaticallyImplyLeading: false,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Row(
        children: [
          CircleAvatar(
            backgroundColor: TripDesign.primary.withValues(alpha: 0.2),
            radius: 18,
            backgroundImage: (widget.peerImage != null && widget.peerImage!.isNotEmpty)
                ? NetworkImage(widget.peerImage!)
                : null,
            child: (widget.peerImage == null || widget.peerImage!.isEmpty)
                ? const Icon(Icons.person, color: TripDesign.primary, size: 20)
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.peerName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const Text(
                  'متصل الآن',
                  style: TextStyle(color: TripDesign.primary, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.phone_in_talk_rounded, color: Colors.white70, size: 22),
          onPressed: () async {
            if (widget.peerPhone != null && widget.peerPhone!.isNotEmpty) {
              final Uri url = Uri.parse('tel:${widget.peerPhone}');
              if (await canLaunchUrl(url)) {
                await launchUrl(url);
              }
            }
          },
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildMessagesList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('ride_requests')
          .doc(widget.rideId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('خطأ في تحميل الرسائل', style: TextStyle(color: Colors.white)));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: TripDesign.primary));
        }

        final messages = snapshot.data!.docs;

        return ListView.builder(
          controller: _scrollController,
          reverse: true,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final msg = messages[index].data() as Map<String, dynamic>;
            final isMe = msg['senderId'] == _currentUserId;
            final time = _formatTime(msg['timestamp']);

            return _buildChatBubble(msg['text'] ?? '', isMe, time);
          },
        );
      },
    );
  }

  Widget _buildChatBubble(String text, bool isMe, String time) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
            margin: const EdgeInsets.only(bottom: 2),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: isMe
                  ? const LinearGradient(
                      colors: [TripDesign.primary, TripDesign.accent],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: isMe ? null : TripDesign.darkCard,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: isMe ? const Radius.circular(18) : Radius.zero,
                bottomRight: isMe ? Radius.zero : const Radius.circular(18),
              ),
            ),
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ),
          if (time.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                time,
                style: const TextStyle(color: Colors.white38, fontSize: 9),
              ),
            ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildQuickMessages() {
    final List<String> quickMsgs = [
      'أنا بانتظارك',
      'أين أنت الآن؟',
      'تمام، شكراً لك',
      'سأخرج الآن',
    ];

    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: quickMsgs.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ActionChip(
              backgroundColor: TripDesign.primary.withValues(alpha: 0.1),
              side: BorderSide(color: TripDesign.primary.withValues(alpha: 0.2)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              label: Text(
                quickMsgs[index],
                style: const TextStyle(color: TripDesign.primaryLight, fontSize: 11),
              ),
              onPressed: () {
                _msgController.text = quickMsgs[index];
                _sendMessage();
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: TripDesign.darkCard,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, -2)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(22),
              ),
              child: TextField(
                controller: _msgController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'اكتب رسالة...',
                  hintStyle: TextStyle(color: Colors.white30, fontSize: 13),
                  border: InputBorder.none,
                ),
                maxLines: 4,
                minLines: 1,
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [TripDesign.primary, TripDesign.accent]),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 22),
            ),
          ),
        ],
      ),
    );
  }
}


