import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/parcel_delivery_request.dart';

const Color kPrimary = Color(0xFFFFD700);
const Color kCardBg = Color(0xFF161618);
const Color kTextWhite = Color(0xFFFFFFFF);
const Color kTextSub = Color(0xFFA1A1A6);

class ParcelRequestCard extends StatelessWidget {
  final ParcelDeliveryRequest req;
  final Map<String, dynamic> driverData;
  final bool isDark;
  final Function(ParcelDeliveryRequest, Map<String, dynamic>) onShowDetails;

  const ParcelRequestCard({
    super.key,
    required this.req,
    required this.driverData,
    required this.isDark,
    required this.onShowDetails,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: const Color(0xFF50C878).withValues(alpha: 0.2), width: 1.5),
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
                  _buildLocations(),
                  const SizedBox(height: 20),
                  _buildInfoRow(),
                  const SizedBox(height: 24),
                  _buildActionButton(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    const Color emerald = Color(0xFF50C878);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      decoration: BoxDecoration(
        color: emerald.withValues(alpha: 0.05),
        border: Border(bottom: BorderSide(color: emerald.withValues(alpha: 0.1))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: emerald.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: const Icon(Icons.inventory_2_rounded, color: emerald, size: 22),
              ),
              const SizedBox(width: 15),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('طلب نقل طرد', style: TextStyle(color: emerald, fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(req.userName, style: const TextStyle(color: kTextSub, fontSize: 10)),
                ],
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(color: emerald.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: const Text('سريع', style: TextStyle(color: emerald, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildLocations() {
    return Column(
      children: [
        Row(
          children: [
            const Icon(Icons.my_location_rounded, color: Colors.blueAccent, size: 18),
            const SizedBox(width: 12),
            Expanded(child: Text(req.pickupAddress, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: kTextWhite, fontSize: 13))),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Icon(Icons.location_on_rounded, color: Colors.redAccent, size: 18),
            const SizedBox(width: 12),
            Expanded(child: Text(req.dropoffAddress, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: kTextSub, fontSize: 13))),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(15)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.local_shipping_rounded, size: 16, color: kTextSub),
              const SizedBox(width: 8),
              Text('المركبة: ${req.vehicleType}', style: const TextStyle(color: kTextSub, fontSize: 12)),
            ],
          ),
          const Text('قيد الاتفاق', style: TextStyle(color: Color(0xFF50C878), fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildActionButton() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onShowDetails(req, driverData);
      },
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF00E676), Color(0xFF00C853)]),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: const Color(0xFF00C853).withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 5)),
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
