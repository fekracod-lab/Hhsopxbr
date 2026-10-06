import 'package:flutter/material.dart';
import 'package:dalal_alqaim/models/parcel_delivery_request.dart';
import 'package:dalal_alqaim/services/parcel_delivery_service.dart';
import 'package:dalal_alqaim/shared/app_colors.dart' as app_colors;
import 'package:dalal_alqaim/features/delivery/presentation/pages/parcel_tracking_page.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ActiveShipmentsStrip extends StatefulWidget {
  final Function(String)? onTrackPressed;
  const ActiveShipmentsStrip({super.key, this.onTrackPressed});

  @override
  State<ActiveShipmentsStrip> createState() => _ActiveShipmentsStripState();
}

class _ActiveShipmentsStripState extends State<ActiveShipmentsStrip> {
  Stream<List<ParcelDeliveryRequest>>? _requestsStream;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _requestsStream = ParcelDeliveryService().getUserRequestsStream(user.uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _requestsStream == null) return const SizedBox.shrink();

    return StreamBuilder<List<ParcelDeliveryRequest>>(
      stream: _requestsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildFixedHeightContainer(
            _buildEmptyState('حدث خطأ أثناء تحميل البيانات: ${snapshot.error}'),
          );
        }

        if (!snapshot.hasData) {
          return _buildFixedHeightContainer(
            const Center(child: CircularProgressIndicator(color: app_colors.primaryColor)),
          );
        }

        final requests = snapshot.data!;
        if (requests.isEmpty) {
          return _buildFixedHeightContainer(_buildEmptyState('ماكو طلبات حالياً جارية'));
        }

        return _buildFixedHeightContainer(
          ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: requests.length,
            itemBuilder: (context, index) => _buildShipmentCard(context, requests[index]),
          ),
        );
      },
    );
  }

  Widget _buildFixedHeightContainer(Widget child) {
    return SizedBox(height: 160, child: child);
  }

  Widget _buildShipmentCard(BuildContext context, ParcelDeliveryRequest req) {
    final String displayId =
        req.id.length > 6
            ? req.id.substring(req.id.length - 6).toUpperCase()
            : req.id.toUpperCase();

    return GestureDetector(
      onTap: () {
        if (widget.onTrackPressed != null) {
          widget.onTrackPressed!(req.id);
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ParcelTrackingPage(requestId: req.id)),
          );
        }
      },
      child: Container(
        width: 280,
        margin: const EdgeInsets.only(left: 15),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: app_colors.darkCard,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: app_colors.primaryColor.withValues(alpha: 0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '#$displayId',
                  style: const TextStyle(
                    color: app_colors.darkSubText,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color:
                        req.status == 'delivered'
                            ? app_colors.successColor.withValues(alpha: 0.1)
                            : app_colors.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _getStatusArabic(req.status),
                    style: TextStyle(
                      color:
                          req.status == 'delivered'
                              ? app_colors.successColor
                              : app_colors.primaryColor,
                      fontSize: 9,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              req.dropoffAddress,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: app_colors.darkText, fontSize: 11),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: req.status == 'delivered' ? 1.0 : (req.status == 'picked_up' ? 0.7 : 0.4),
              backgroundColor: Colors.white10,
              color: req.status == 'delivered' ? app_colors.successColor : app_colors.primaryColor,
              minHeight: 3,
              borderRadius: BorderRadius.circular(10),
            ),
          ],
        ),
      ),
    );
  }

  String _getStatusArabic(String status) {
    switch (status) {
      case 'pending':
        return 'انتظار';
      case 'accepted':
        return 'تنفيذ';
      case 'picked_up':
        return 'استلام';
      case 'delivered':
        return 'توصيل';
      default:
        return 'نشط';
    }
  }

  Widget _buildEmptyState(String msg) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: app_colors.darkCard,
        borderRadius: BorderRadius.circular(25),
      ),
      child: Center(
        child: Text(
          msg,
          style: const TextStyle(color: app_colors.darkSubText),
        ),
      ),
    );
  }
}
