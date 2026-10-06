import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart' as intl;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:dalal_alqaim/services/notification_service.dart';

class TechnicalSupportChatPage extends StatefulWidget {
  final String? userId; // Pass this if an admin is opening a specific chat
  final String? userName; // Optional pre-loaded user name
  final String? userPhone; // Optional pre-loaded user phone
  final bool isAdminPersonalChat; // Pass true to force personal user chat mode even if the user is an admin

  const TechnicalSupportChatPage({
    super.key,
    this.userId,
    this.userName,
    this.userPhone,
    this.isAdminPersonalChat = false,
  });

  @override
  State<TechnicalSupportChatPage> createState() => _TechnicalSupportChatPageState();
}

class _TechnicalSupportChatPageState extends State<TechnicalSupportChatPage> {
  final TextEditingController _msgController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  late String _currentUserId;
  bool _isAdmin = false;
  bool _isLoadingRole = true;
  bool _showTicketsList = false;
  String _searchQuery = '';

  // Active chat session variables (only set if in direct chat mode)
  String? _activeChatId;
  String _chatUserName = 'مستخدم مدار';
  String _chatUserPhone = '-';
  String _chatUserRole = 'user';

  // Premium Palette
  static const Color _primaryColor = Color(0xFF00BFA5); // Modern Teal
  static const Color _primaryDark = Color(0xFF00897B);
  static const Color _bgLight = Color(0xFFF8FAFC);
  static const Color _bgDark = Color(0xFF0F172A);
  static const Color _cardLight = Colors.white;
  static const Color _cardDark = Color(0xFF1E293B);
  static const Color _txtLight = Color(0xFF1E293B);
  static const Color _txtDark = Color(0xFFF8FAFC);
  static const Color _subTxtLight = Color(0xFF64748B);
  static const Color _subTxtDark = Color(0xFF94A3B8);

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    _checkUserRoleAndSession();
    
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _msgController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _checkUserRoleAndSession() async {
    if (_currentUserId.isEmpty) {
      if (mounted) setState(() => _isLoadingRole = false);
      return;
    }

    try {
      // 1. Get current user profile
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(_currentUserId).get();
      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        final role = data['role']?.toString().toLowerCase() ?? 'user';
        _isAdmin = (role == 'admin' || role == 'main_admin' || role == 'limited_admin' || role == 'governorate_manager' || role == 'support');
      }

      // 2. Determine whether to show the tickets list or direct chat
      if (_isAdmin && widget.userId == null && !widget.isAdminPersonalChat) {
        _showTicketsList = true;
      } else {
        _showTicketsList = false;
        // Direct chat mode: Determine target user
        _activeChatId = widget.userId ?? _currentUserId;
        _chatUserName = widget.userName ?? 'مستشار الدعم الفني';
        _chatUserPhone = widget.userPhone ?? '-';

        // Load details for the other party if not supplied
        if (widget.userId != null) {
          final targetDoc = await FirebaseFirestore.instance.collection('users').doc(widget.userId).get();
          if (targetDoc.exists) {
            final tData = targetDoc.data() as Map<String, dynamic>;
            _chatUserName = tData['username'] ?? tData['name'] ?? 'مستخدم مدار';
            _chatUserPhone = tData['phone'] ?? '-';
            _chatUserRole = tData['role'] ?? 'user';
          }
        } else {
          // Current user is chatting with support
          _chatUserName = 'الدعم الفني والمساندة';
          _chatUserPhone = ''; 
        }

        _markAsRead();
      }
    } catch (e) {
      debugPrint('Error loading support session: $e');
    }

    if (mounted) {
      setState(() => _isLoadingRole = false);
    }
  }

  Future<void> _markAsRead() async {
    if (_activeChatId == null) return;
    try {
      final updates = _isAdmin
          ? {'unreadByAdminCount': 0}
          : {'unreadByUserCount': 0};
      await FirebaseFirestore.instance.collection('support_chats').doc(_activeChatId).update(updates);
    } catch (_) {}
  }

  void _sendMessage({String? customText}) async {
    final text = (customText ?? _msgController.text).trim();
    if (text.isEmpty || _activeChatId == null) return;

    if (customText == null) {
      _msgController.clear();
    }

    try {
      // 1. Add to messages subcollection
      await FirebaseFirestore.instance
          .collection('support_chats')
          .doc(_activeChatId)
          .collection('messages')
          .add({
        'text': text,
        'senderId': _currentUserId,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // 2. Fetch sender info to update parent document
      String senderName = 'مستخدم مدار';
      String senderPhone = '-';
      String senderRole = 'user';

      final senderDoc = await FirebaseFirestore.instance.collection('users').doc(_currentUserId).get();
      if (senderDoc.exists) {
        final data = senderDoc.data() as Map<String, dynamic>;
        senderName = data['username'] ?? data['name'] ?? 'مستخدم';
        senderPhone = data['phone'] ?? '-';
        senderRole = data['role'] ?? 'user';
      }

      // 3. Update parent chat room document
      final chatRef = FirebaseFirestore.instance.collection('support_chats').doc(_activeChatId);
      final chatDoc = await chatRef.get();

      int unreadAdmin = 0;
      int unreadUser = 0;

      if (chatDoc.exists) {
        final chatData = chatDoc.data() as Map<String, dynamic>;
        unreadAdmin = (chatData['unreadByAdminCount'] as num? ?? 0).toInt();
        unreadUser = (chatData['unreadByUserCount'] as num? ?? 0).toInt();
      }

      await chatRef.set({
        'userId': _activeChatId,
        'userName': _isAdmin ? _chatUserName : senderName,
        'userPhone': _isAdmin ? _chatUserPhone : senderPhone,
        'userRole': _isAdmin ? _chatUserRole : senderRole,
        'lastMessage': text,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'unreadByAdminCount': _isAdmin ? 0 : (unreadAdmin + 1),
        'unreadByUserCount': _isAdmin ? (unreadUser + 1) : 0,
      }, SetOptions(merge: true));

      // 4. Send push notification to recipient
      try {
        if (_isAdmin) {
          // Admin replying to user: send direct user notification
          await NotificationService.emitEvent(
            type: 'user_notification',
            payload: {
              'user_id': _activeChatId,
              'title': 'الدعم الفني والمساندة',
              'body': text,
              'data': {
                'type': 'support_message',
                'senderId': _currentUserId,
              },
            },
          );
        } else {
          // User sending message to support admins
          await NotificationService.emitEvent(
            type: 'support_message',
            payload: {
              'user_id': _currentUserId,
              'user_name': senderName,
              'title': 'طلب دعم فني جديد',
              'body': '$senderName: $text',
              'data': {
                'type': 'support_request',
                'userId': _currentUserId,
              },
            },
          );
        }
      } catch (err) {
        debugPrint('Error sending support notification: $err');
      }

      _scrollToBottom();
    } catch (e) {
      debugPrint('Error sending support message: $e');
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? _bgDark : _bgLight;
    final cardBg = isDark ? _cardDark : _cardLight;
    final txtColor = isDark ? _txtDark : _txtLight;
    final subTxt = isDark ? _subTxtDark : _subTxtLight;

    if (_isLoadingRole) {
      return Scaffold(
        backgroundColor: bg,
        body: const Center(child: CircularProgressIndicator(color: _primaryColor)),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: cardBg,
          elevation: 2,
          iconTheme: IconThemeData(color: txtColor),
          titleSpacing: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: txtColor),
            onPressed: () {
              if (_isAdmin && !_showTicketsList && widget.userId == null) {
                setState(() {
                  _showTicketsList = true;
                  _activeChatId = null;
                });
              } else {
                Navigator.pop(context);
              }
            },
          ),
          title: _showTicketsList
              ? Text(
                  'تذاكر الدعم الفني',
                  style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, color: txtColor),
                )
              : Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: _primaryColor.withOpacity(0.1),
                      radius: 18.r,
                      child: Icon(
                        _isAdmin ? Icons.person_outline_rounded : Icons.support_agent_rounded,
                        color: _primaryColor,
                        size: 20.sp,
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _chatUserName,
                            style: TextStyle(color: txtColor, fontSize: 14.sp, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            _isAdmin ? 'مستخدم التطبيق - $_chatUserPhone' : 'مستشار الدعم الفني متصل الآن',
                            style: TextStyle(color: subTxt, fontSize: 9.sp),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
          actions: [
            if (!_showTicketsList && _isAdmin && _chatUserPhone != '-' && _chatUserPhone.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.phone_in_talk_rounded, color: Colors.green),
                onPressed: () async {
                  final url = Uri.parse("tel:$_chatUserPhone");
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url);
                  }
                },
              ),
            SizedBox(width: 8.w),
          ],
        ),
        body: _showTicketsList
            ? _buildTicketsList(isDark, txtColor, subTxt)
            : SafeArea(
                child: Column(
                  children: [
                    Expanded(child: _buildMessagesList(isDark, txtColor, subTxt)),
                    _buildQuickMessages(isDark),
                    _buildInputArea(cardBg, txtColor, isDark),
                  ],
                ),
              ),
      ),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // ── Admin: Active Tickets List ──
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Widget _buildTicketsList(bool isDark, Color txtColor, Color subTxt) {
    return Column(
      children: [
        // Search Bar for Tickets
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          color: isDark ? _cardDark : Colors.white,
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? _bgDark : Colors.grey[50],
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
            ),
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: txtColor, fontSize: 12.sp),
              decoration: InputDecoration(
                hintText: 'البحث عن تذكرة بالاسم أو الهاتف...',
                hintStyle: const TextStyle(color: Colors.grey),
                prefixIcon: const Icon(Icons.search, color: _primaryColor),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              ),
            ),
          ),
        ),

        // List View of support_chats
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('support_chats')
                .orderBy('lastMessageTime', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('حدث خطأ في تحميل التذاكر', style: TextStyle(color: txtColor)));
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: _primaryColor));
              }

              final docs = snapshot.data?.docs ?? [];
              final filteredDocs = docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final name = (data['userName'] ?? '').toString().toLowerCase();
                final phone = (data['userPhone'] ?? '').toString();
                return name.contains(_searchQuery) || phone.contains(_searchQuery);
              }).toList();

              if (filteredDocs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.support_agent_rounded, size: 64.sp, color: Colors.grey.withOpacity(0.2)),
                      SizedBox(height: 16.h),
                      Text('لا توجد تذاكر دعم فني نشطة حالياً', style: TextStyle(color: subTxt, fontSize: 13.sp)),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: EdgeInsets.all(16.r),
                itemCount: filteredDocs.length,
                separatorBuilder: (_, __) => SizedBox(height: 10.h),
                itemBuilder: (context, index) {
                  final doc = filteredDocs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final uId = doc.id;
                  final name = data['userName'] ?? 'مستخدم';
                  final lastMsg = data['lastMessage'] ?? '';
                  final timeStr = _formatTime(data['lastMessageTime']);
                  final unreadCount = (data['unreadByAdminCount'] as num? ?? 0).toInt();
                  final userRole = data['userRole'] ?? 'user';

                  return Card(
                    color: isDark ? _cardDark : Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                    elevation: 2,
                    child: ListTile(
                      contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                      leading: CircleAvatar(
                        backgroundColor: _primaryColor.withOpacity(0.1),
                        radius: 22.r,
                        child: Icon(
                          userRole == 'driver' ? Icons.delivery_dining : (userRole == 'merchant' ? Icons.storefront : Icons.person),
                          color: _primaryColor,
                        ),
                      ),
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp, color: txtColor),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (timeStr.isNotEmpty)
                            Text(timeStr, style: TextStyle(fontSize: 10.sp, color: Colors.grey)),
                        ],
                      ),
                      subtitle: Padding(
                        padding: EdgeInsets.only(top: 6.h),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                lastMsg,
                                style: TextStyle(fontSize: 11.sp, color: subTxt),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (unreadCount > 0)
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                child: Text(
                                  '$unreadCount',
                                  style: TextStyle(color: Colors.white, fontSize: 9.sp, fontWeight: FontWeight.bold),
                                ),
                              ),
                          ],
                        ),
                      ),
                      onTap: () {
                        setState(() {
                          _showTicketsList = false;
                          _activeChatId = uId;
                          _chatUserName = name;
                          _chatUserPhone = data['userPhone'] ?? '-';
                          _chatUserRole = userRole;
                        });
                        _markAsRead();
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // ── Direct Chat: Messages List ──
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Widget _buildMessagesList(bool isDark, Color txtColor, Color subTxt) {
    if (_activeChatId == null) return const SizedBox();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('support_chats')
          .doc(_activeChatId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('حدث خطأ في تحميل الرسائل', style: TextStyle(color: txtColor)));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _primaryColor));
        }

        final messages = snapshot.data?.docs ?? [];

        if (messages.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.support_agent_rounded, color: _primaryColor.withOpacity(0.2), size: 60.sp),
                SizedBox(height: 12.h),
                Text(
                  _isAdmin ? 'ماكو رسائل حالياً سابقة مع هذا المستخدم' : 'مرحباً بك! كيف يمكن لفريق الدعم الفني مساعدتك اليوم؟',
                  style: TextStyle(color: subTxt, fontSize: 12.sp, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          controller: _scrollController,
          reverse: true,
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final msg = messages[index].data() as Map<String, dynamic>;
            final isMe = msg['senderId'] == _currentUserId;
            final time = _formatTime(msg['timestamp']);

            return _buildChatBubble(msg['text'] ?? '', isMe, time, isDark);
          },
        );
      },
    );
  }

  Widget _buildChatBubble(String text, bool isMe, String time, bool isDark) {
    final bubbleBg = isMe
        ? _primaryColor
        : (isDark ? _cardDark : Colors.white);
    final bubbleTxtColor = isMe ? Colors.white : (isDark ? Colors.white : Colors.black87);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
            margin: const EdgeInsets.only(bottom: 2),
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: bubbleBg,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(18.r),
                topRight: Radius.circular(18.r),
                bottomLeft: isMe ? Radius.circular(18.r) : Radius.zero,
                bottomRight: isMe ? Radius.zero : Radius.circular(18.r),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              text,
              style: TextStyle(
                color: bubbleTxtColor,
                fontSize: 12.sp,
                height: 1.4,
              ),
            ),
          ),
          if (time.isNotEmpty)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
              child: Text(
                time,
                style: const TextStyle(color: Colors.grey, fontSize: 8.5),
              ),
            ),
          SizedBox(height: 8.h),
        ],
      ),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // ── Quick Chips for Pre-filled Questions ──
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Widget _buildQuickMessages(bool isDark) {
    final List<String> quickMsgs = _isAdmin
        ? [
            'مرحباً بك، كيف يمكنني مساعدتك؟',
            'تم استلام بلاغك وجاري التحقق الآن',
            'هل يمكنك تزويدي برقم الطلب؟',
            'تم حل المشكلة بنجاح، شكراً لتفهمك',
          ]
        : [
            'لدي مشكلة في طلبي الأخير',
            'مشكلة في شحن الرصيد أو الدفع',
            'كيف يمكنني تحديث بيانات حسابي؟',
            'شكراً جزيلاً لكم',
          ];

    return SizedBox(
      height: 44.h,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 12.w),
        itemCount: quickMsgs.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 4.h),
            child: ActionChip(
              backgroundColor: _primaryColor.withOpacity(0.08),
              side: BorderSide(color: _primaryColor.withOpacity(0.15)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
              label: Text(
                quickMsgs[index],
                style: TextStyle(color: _primaryColor, fontSize: 10.sp, fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                if (quickMsgs[index] == 'لدي مشكلة في طلبي الأخير') {
                  _showRecentOrdersBottomSheet(context, isDark);
                } else {
                  _sendMessage(customText: quickMsgs[index]);
                }
              },
            ),
          );
        },
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchRecentOrders() async {
    final uid = _currentUserId;
    if (uid.isEmpty) return [];

    try {
      final restSnap = await FirebaseFirestore.instance
          .collection('madar_orders')
          .doc(uid)
          .collection('orders')
          .orderBy('createdAt', descending: true)
          .limit(5)
          .get();

      final storeSnap = await FirebaseFirestore.instance
          .collection('madar_orders')
          .doc(uid)
          .collection('store_orders')
          .orderBy('createdAt', descending: true)
          .limit(5)
          .get();

      final List<Map<String, dynamic>> list = [];

      for (var doc in restSnap.docs) {
        final data = doc.data();
        list.add({
          'id': doc.id,
          'type': 'restaurant',
          'name': 'طلب مطعم #${doc.id.substring(0, doc.id.length > 5 ? 5 : doc.id.length)}',
          'total': (data['total'] ?? 0.0).toDouble(),
          'status': data['status'] ?? 'pending',
          'createdAt': data['createdAt'] as Timestamp?,
        });
      }

      for (var doc in storeSnap.docs) {
        final data = doc.data();
        list.add({
          'id': doc.id,
          'type': 'store',
          'name': data['storeName'] ?? 'متجر مدار',
          'total': (data['total'] ?? 0.0).toDouble(),
          'status': data['status'] ?? 'pending',
          'createdAt': data['createdAt'] as Timestamp?,
        });
      }

      list.sort((a, b) {
        final tA = a['createdAt'] as Timestamp?;
        final tB = b['createdAt'] as Timestamp?;
        if (tA == null && tB == null) return 0;
        if (tA == null) return 1;
        if (tB == null) return -1;
        return tB.compareTo(tA);
      });

      return list;
    } catch (e) {
      debugPrint('Error fetching recent orders for support: $e');
      return [];
    }
  }

  void _showRecentOrdersBottomSheet(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final bg = isDark ? _cardDark : Colors.white;
        final txtColor = isDark ? _txtDark : _txtLight;
        final subTxt = isDark ? _subTxtDark : _subTxtLight;

        return Directionality(
          textDirection: TextDirection.rtl,
          child: Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
            ),
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                  ),
                ),
                SizedBox(height: 16.h),
                Text(
                  'اختر الطلب الذي تواجه مشكلة فيه:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14.sp,
                    color: txtColor,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'سنقوم بإرسال تفاصيل هذا الطلب لفريق الدعم لمساعدتك فوراً',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: subTxt,
                  ),
                ),
                SizedBox(height: 16.h),
                Expanded(
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: _fetchRecentOrders(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: _primaryColor));
                      }
                      if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.shopping_basket_outlined, size: 48.sp, color: Colors.grey.withOpacity(0.3)),
                              SizedBox(height: 8.h),
                              Text(
                                'ماكو طلبات حالياً سابقة مسجلة في حسابك',
                                style: TextStyle(color: subTxt, fontSize: 12.sp),
                              ),
                            ],
                          ),
                        );
                      }

                      final orders = snapshot.data!;

                      return ListView.separated(
                        itemCount: orders.length,
                        separatorBuilder: (_, __) => SizedBox(height: 10.h),
                        itemBuilder: (context, index) {
                          final order = orders[index];
                          final total = order['total'] as double;
                          final status = order['status'] as String;
                          final type = order['type'] as String;
                          final name = order['name'] as String;

                          final dateStr = order['createdAt'] != null
                              ? intl.DateFormat('yyyy/MM/dd hh:mm a').format((order['createdAt'] as Timestamp).toDate())
                              : '';

                          Color statusColor = Colors.grey;
                          String statusArabic = status;
                          switch (status) {
                            case 'pending': statusColor = Colors.orange; statusArabic = 'قيد الانتظار'; break;
                            case 'accepted': statusColor = Colors.blue; statusArabic = 'مقبول'; break;
                            case 'delivering': statusColor = Colors.indigo; statusArabic = 'جاري التوصيل'; break;
                            case 'completed': statusColor = Colors.green; statusArabic = 'مكتمل'; break;
                            case 'cancelled': statusColor = Colors.red; statusArabic = 'ملغي'; break;
                          }

                          return Card(
                            color: isDark ? _bgDark : Colors.grey[50],
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16.r),
                              side: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade200),
                            ),
                            child: ListTile(
                              contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
                              leading: Container(
                                padding: EdgeInsets.all(8.r),
                                decoration: BoxDecoration(
                                  color: (type == 'store' ? Colors.orange : Colors.teal).withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  type == 'store' ? Icons.storefront_rounded : Icons.restaurant_rounded,
                                  color: type == 'store' ? Colors.orange : Colors.teal,
                                  size: 20.sp,
                                ),
                              ),
                              title: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      name,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12.sp,
                                        color: txtColor,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                                    decoration: BoxDecoration(
                                      color: statusColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8.r),
                                    ),
                                    child: Text(
                                      statusArabic,
                                      style: TextStyle(
                                        color: statusColor,
                                        fontSize: 9.sp,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Padding(
                                padding: EdgeInsets.only(top: 6.h),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      dateStr,
                                      style: TextStyle(fontSize: 10.sp, color: subTxt),
                                    ),
                                    Text(
                                      '${intl.NumberFormat('#,###').format(total)} د.ع',
                                      style: TextStyle(
                                        fontSize: 11.sp,
                                        fontWeight: FontWeight.bold,
                                        color: _primaryColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              onTap: () {
                                final msg = "بلاغ مشكلة في الطلب:\n"
                                    "- جهة الطلب: $name\n"
                                    "- رقم الطلب: ${order['id']}\n"
                                    "- القيمة: ${intl.NumberFormat('#,###').format(total)} د.ع\n"
                                    "- التاريخ: $dateStr\n"
                                    "- حالة الطلب: $statusArabic";

                                _sendMessage(customText: msg);
                                Navigator.pop(context);
                              },
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // ── Input Text Box & Send Button ──
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Widget _buildInputArea(Color cardBg, Color txtColor, bool isDark) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: cardBg,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w),
              decoration: BoxDecoration(
                color: isDark ? _bgDark : Colors.grey[50],
                borderRadius: BorderRadius.circular(24.r),
                border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
              ),
              child: TextField(
                controller: _msgController,
                style: TextStyle(color: txtColor, fontSize: 13.sp),
                decoration: const InputDecoration(
                  hintText: 'اكتب رسالتك للدعم الفني هنا...',
                  hintStyle: TextStyle(color: Colors.grey, fontSize: 12),
                  border: InputBorder.none,
                ),
                maxLines: 4,
                minLines: 1,
              ),
            ),
          ),
          SizedBox(width: 10.w),
          GestureDetector(
            onTap: () => _sendMessage(),
            child: Container(
              padding: EdgeInsets.all(10.r),
              decoration: BoxDecoration(
                color: _primaryColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _primaryColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
