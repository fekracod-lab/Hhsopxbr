import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:dalal_alqaim/services/rewards_service.dart';

class RewardsPage extends StatefulWidget {
  const RewardsPage({super.key});

  @override
  State<RewardsPage> createState() => _RewardsPageState();
}

class _RewardsPageState extends State<RewardsPage> {
  final RewardsService _rewardsService = RewardsService();
  final String _driverId = FirebaseAuth.instance.currentUser?.uid ?? '';

  bool _isRedeeming = false;

  void _redeemReward(Map<String, dynamic> reward, int currentPoints) async {
    if (currentPoints < reward['cost']) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('النقاط غير كافية لاستبدال هذه المكافأة'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تأكيد الاستبدال', style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text('هل أنت متأكد من استبدال ${reward['cost']} نقطة بـ "${reward['title']}"؟', style: const TextStyle()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('إلغاء', style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF26A69A)),
            onPressed: () => Navigator.pop(context, true),
            child: Text('تأكيد', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ) ?? false;

    if (!confirm) return;

    setState(() => _isRedeeming = true);

    final success = await _rewardsService.redeemPoints(_driverId, reward['cost'], reward['title']);

    setState(() => _isRedeeming = false);

    if (success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم استبدال المكافأة بنجاح! سيتم تطبيقها قريباً.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('حدث خطأ أثناء الاستبدال. حاول مرة ثانية بعد شوية.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_driverId.isEmpty) {
      return const Scaffold(body: Center(child: Text('سجّل دخولك أولاً')));
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('نظام المكافئات', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF26A69A),
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<int>(
        stream: _rewardsService.getRewardsPointsStream(_driverId),
        builder: (context, snapshot) {
          final int points = snapshot.data ?? 0;

          return CustomScrollView(
            slivers: [
              // Points Header
              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    color: Color(0xFF26A69A),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(30),
                      bottomRight: Radius.circular(30),
                    ),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.stars, size: 64, color: Colors.amber),
                      const SizedBox(height: 16),
                      Text(
                        'إجمالي النقاط المتاحة',
                        style: const TextStyle(fontSize: 16, color: Colors.white70),
                      ),
                      Text(
                        '$points نقطة',
                        style: const TextStyle(fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'احصل على 10 نقاط لكل رحلة مكتملة',
                        style: const TextStyle(fontSize: 14, color: Colors.white54),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Rewards List Title
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'المكافآت المتاحة',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              // Available Rewards Stream
              SliverToBoxAdapter(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _rewardsService.getAvailableRewardsStream(),
                  builder: (context, rewardsSnapshot) {
                    if (rewardsSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
                    }

                    if (!rewardsSnapshot.hasData || rewardsSnapshot.data!.docs.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text('لا توجد مكافآت متاحة حالياً', style: const TextStyle(color: Colors.grey)),
                        ),
                      );
                    }

                    final rewardsDocs = rewardsSnapshot.data!.docs;

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: EdgeInsets.zero,
                      itemCount: rewardsDocs.length,
                      itemBuilder: (context, index) {
                        final rewardData = rewardsDocs[index].data() as Map<String, dynamic>;
                        final int cost = (rewardData['cost'] as num?)?.toInt() ?? 0;
                        final String title = rewardData['title'] ?? 'مكافأة';
                        
                        final reward = {
                          'id': rewardsDocs[index].id,
                          'title': title,
                          'cost': cost,
                        };

                        final bool canAfford = points >= cost;

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Card(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 2,
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(16),
                              leading: CircleAvatar(
                                backgroundColor: Colors.amber.shade100,
                                radius: 28,
                                child: const Icon(Icons.card_giftcard, color: Colors.amber, size: 28),
                              ),
                              title: Text(
                                title,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              subtitle: Text(
                                'التكلفة: $cost نقطة',
                                style: TextStyle(color: canAfford ? const Color(0xFF26A69A) : Colors.red,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              trailing: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: canAfford ? const Color(0xFF26A69A) : Colors.grey[300],
                                  foregroundColor: canAfford ? Colors.white : Colors.grey[600],
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: _isRedeeming || !canAfford
                                    ? null
                                    : () => _redeemReward(reward, points),
                                child: _isRedeeming
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : Text('استبدال', style: const TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

              // Transactions History Title
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(left: 20, right: 20, top: 32, bottom: 8),
                  child: Text(
                    'سجل العمليات',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              // Transactions Stream
              SliverToBoxAdapter(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _rewardsService.getTransactionsStream(_driverId),
                  builder: (context, txSnapshot) {
                    if (txSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
                    }

                    if (!txSnapshot.hasData || txSnapshot.data!.docs.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(40),
                          child: Text('ماكو عمليات حالياً سابقة', style: const TextStyle(color: Colors.grey)),
                        ),
                      );
                    }

                    final docs = txSnapshot.data!.docs;

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: EdgeInsets.zero,
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final data = docs[index].data() as Map<String, dynamic>;
                        final bool isEarned = data['type'] == 'earned';
                        final String sign = isEarned ? '+' : '';
                        final Color color = isEarned ? Colors.green : Colors.red;

                        // Formatting Date
                        final createdAt = data['createdAt'] as Timestamp?;
                        final dateStr = createdAt != null 
                            ? '${createdAt.toDate().day}/${createdAt.toDate().month}/${createdAt.toDate().year}' 
                            : '';

                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: ListTile(
                            leading: Icon(
                              isEarned ? Icons.add_circle : Icons.remove_circle,
                              color: color,
                            ),
                            title: Text(data['reason'] ?? 'عملية', style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text(dateStr, style: const TextStyle(fontSize: 12)),
                            trailing: Text(
                              '$sign${data['amount']} نقطة',
                              style: TextStyle(color: color,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          );
        },
      ),
    );
  }
}
