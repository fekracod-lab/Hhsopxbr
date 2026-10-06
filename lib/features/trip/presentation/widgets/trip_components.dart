import 'package:flutter/material.dart';
import 'package:dalal_alqaim/features/trip/domain/entities/trip.dart';
import 'package:dalal_alqaim/features/trip/presentation/trip_design.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TripDetailsCard extends StatelessWidget {
  final Trip trip;
  final int? etaMinutes;
  final String? distance;

  const TripDetailsCard({super.key, required this.trip, this.etaMinutes, this.distance});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFF1F1F1))),
      ),
      child: Column(
        children: [
          _buildTimelineRow(true, "موقع الالتقاء", trip.pickupAddress),
          if (etaMinutes != null || distance != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: TripDesign.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  if (etaMinutes != null)
                    _buildInfolabel(Icons.access_time_filled_rounded, "$etaMinutes دقيقة وصول"),
                  Container(width: 1, height: 20, color: TripDesign.primary.withValues(alpha: 0.2)),
                  if (distance != null) _buildInfolabel(Icons.route_rounded, distance!),
                ],
              ),
            ),
          ],
          const SizedBox(height: 15),
          _buildTimelineRow(false, "وجهتك", trip.dropoffAddress),
        ],
      ),
    );
  }

  Widget _buildInfolabel(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: TripDesign.primary),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            fontFamily: TripDesign.kFontFamily,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: TripDesign.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineRow(bool isStart, String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Icon(
              isStart ? Icons.radio_button_checked : Icons.location_on,
              color: isStart ? TripDesign.primary : TripDesign.error,
              size: 20,
            ),
            if (isStart) Container(width: 2, height: 30, color: Colors.grey[200]),
          ],
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontFamily: TripDesign.kFontFamily,
                  fontSize: 13,
                  color: Colors.grey,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  fontFamily: TripDesign.kFontFamily,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class ChatSheet extends StatefulWidget {
  final String tripId;

  const ChatSheet({super.key, required this.tripId});

  @override
  State<ChatSheet> createState() => _ChatSheetState();
}

class _ChatSheetState extends State<ChatSheet> {
  final TextEditingController _ctrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        children: [
          _buildHandle(),
          _buildHeader(),
          const Divider(),
          _buildMessageList(),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildHandle() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 15),
        width: 40,
        height: 4,
        decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
      ),
    );
  }

  Widget _buildHeader() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          Text(
            "المحادثة مع الكابتن",
            style: TextStyle(
              fontFamily: TripDesign.kFontFamily,
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: TripDesign.accent,
            ),
          ),
          Spacer(),
          Icon(Icons.message, color: TripDesign.primary),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    return Expanded(
      child: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection('ride_requests')
                .doc(widget.tripId)
                .collection('messages')
                .orderBy('createdAt', descending: true)
                .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) return _buildEmptyChat();
          return ListView.builder(
            reverse: true,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final d = docs[index].data() as Map<String, dynamic>;
              final isMe = d['senderId'] == FirebaseAuth.instance.currentUser?.uid;
              return _buildMessageBubble(d['text'] ?? '', isMe);
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyChat() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.chat_bubble_outline, size: 60, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text(
            "ماكو رسائل حالياً بعد",
            style: TextStyle(fontFamily: TripDesign.kFontFamily, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(String text, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isMe ? TripDesign.primary : Colors.grey[100],
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: isMe ? const Radius.circular(20) : Radius.zero,
            bottomRight: isMe ? Radius.zero : const Radius.circular(20),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontFamily: TripDesign.kFontFamily,
            color: isMe ? Colors.white : TripDesign.accent,
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    final quickMessages = [
      'أنا بباب البيت',
      'أنا بالشارع العام',
      'ثواني ونازل إلك',
      'الكابتن وين صرت؟',
      'تمام بالانتظار',
    ];

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 10,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, -5),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Quick Chips Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            reverse: true,
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: quickMessages.map((msg) {
                return Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: ActionChip(
                    label: Text(msg, style: const TextStyle(fontFamily: TripDesign.kFontFamily, fontSize: 11, fontWeight: FontWeight.w600)),
                    backgroundColor: const Color(0xFFE0F2F1),
                    labelStyle: const TextStyle(color: Color(0xFF004D40)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide.none),
                    onPressed: () {
                      _ctrl.text = msg;
                      _sendMessage();
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  textAlign: TextAlign.right,
                  decoration: InputDecoration(
                    hintText: "اكتب رسالة...",
                    hintStyle: TextStyle(fontFamily: TripDesign.kFontFamily, color: Colors.grey[400]),
                    filled: true,
                    fillColor: TripDesign.background,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              InkWell(
                onTap: _sendMessage,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(color: TripDesign.primary, shape: BoxShape.circle),
                  child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _sendMessage() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    FirebaseFirestore.instance
        .collection('ride_requests')
        .doc(widget.tripId)
        .collection('messages')
        .add({
          'text': text,
          'senderId': FirebaseAuth.instance.currentUser?.uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
    _ctrl.clear();
  }
}
