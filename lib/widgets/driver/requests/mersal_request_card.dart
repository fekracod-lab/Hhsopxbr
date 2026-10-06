import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/mersal_request.dart';
import 'package:dalal_alqaim/features/delivery/presentation/pages/mersal_order_details_page.dart';

const Color kPrimary = Color(0xFFFFD700);
const Color kCardBg = Color(0xFF161618);
const Color kTextWhite = Color(0xFFFFFFFF);
const Color kTextSub = Color(0xFFA1A1A6);

class MersalRequestCard extends StatelessWidget {
  final MersalRequest req;
  final Map<String, dynamic> driverData;
  final bool isDark;

  const MersalRequestCard({
    super.key,
    required this.req,
    required this.driverData,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.2), width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 20, spreadRadius: -5),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Column(
          children: [
            // Header
            _buildHeader(),
            
            // Content
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDescription(),
                  const SizedBox(height: 20),
                  _buildLocation(),
                  const SizedBox(height: 24),
                  _buildActionButton(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.05),
        border: Border(bottom: BorderSide(color: Colors.orange.withValues(alpha: 0.1))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: const Icon(Icons.shopping_bag_rounded, color: Colors.orange, size: 22),
              ),
              const SizedBox(width: 15),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('طلب مـرسال', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('خدمة التسوق الحر', style: TextStyle(color: kTextSub, fontSize: 10)),
                ],
              ),
            ],
          ),
          Text(req.userName, style: const TextStyle(color: kTextWhite, fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildDescription() {
    return Container(
      padding: const EdgeInsets.all(16),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Text(
        req.requestDescription,
        style: const TextStyle(color: kTextWhite, fontSize: 14, fontWeight: FontWeight.w500, height: 1.5),
      ),
    );
  }

  Widget _buildLocation() {
    return Row(
      children: [
        const Icon(Icons.location_on_rounded, color: Colors.redAccent, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            req.dropoffAddress,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: kTextSub, fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        Navigator.push(context, MaterialPageRoute(builder: (context) => MersalOrderDetailsPage(request: req, driverData: driverData)));
      },
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Colors.orange, Color(0xFFFF9100)]),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.orange.withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 5)),
          ],
        ),
        child: const Center(
          child: Text(
            'عرض الـتفاصيل والـقبول',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15),
          ),
        ),
      ),
    );
  }
}
