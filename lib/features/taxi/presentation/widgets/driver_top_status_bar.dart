import 'package:flutter/material.dart';
import '../../domain/entities/driver_dashboard_models.dart';

/// الشريط العلوي لحالة الكابتن ورصيد المحفظة والتنبيهات والإعدادات
class DriverTopStatusBar extends StatelessWidget {
  final DriverProfileEntity? profile;
  final int unreadNotificationsCount;
  final bool isMyWayActive;
  final String? myWayDestination;
  final VoidCallback onToggleOnline;
  final VoidCallback onOpenNotifications;
  final VoidCallback onOpenWallet;
  final VoidCallback onToggleMyWay;
  final VoidCallback? onOpenSettings;

  const DriverTopStatusBar({
    super.key,
    required this.profile,
    required this.unreadNotificationsCount,
    required this.isMyWayActive,
    this.myWayDestination,
    required this.onToggleOnline,
    required this.onOpenNotifications,
    required this.onOpenWallet,
    required this.onToggleMyWay,
    this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    final isOnline = profile?.isOnline ?? false;
    final isOnTrip = profile?.isOnTrip ?? false;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // ── مفتاح الاتصال Online / Offline ──
          Expanded(
            child: InkWell(
              onTap: isOnTrip ? null : onToggleOnline,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: isOnline
                      ? const Color(0xFF10B981).withValues(alpha: 0.2)
                      : (isOnTrip ? Colors.blueAccent.withValues(alpha: 0.2) : Colors.white10),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isOnline
                        ? const Color(0xFF10B981)
                        : (isOnTrip ? Colors.blueAccent : Colors.white24),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isOnline
                            ? const Color(0xFF10B981)
                            : (isOnTrip ? Colors.blueAccent : Colors.grey),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        isOnTrip
                            ? 'في رحلة'
                            : (isOnline ? 'متصل' : 'غير متصل'),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11.5,
                          color: isOnline
                              ? const Color(0xFF10B981)
                              : (isOnTrip ? Colors.blueAccent : Colors.white70),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(width: 4),

          // ── درب الرجعة والمحفظة والإشعارات والإعدادات ──
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // درب الرجعة (MyWay)
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.all(5),
                constraints: const BoxConstraints(),
                icon: Icon(
                  Icons.alt_route_rounded,
                  size: 19,
                  color: isMyWayActive ? const Color(0xFFF59E0B) : Colors.white60,
                ),
                tooltip: 'درب الرجعة',
                onPressed: onToggleMyWay,
              ),

              const SizedBox(width: 4),

              // المحفظة
              InkWell(
                onTap: onOpenWallet,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF26A69A).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF26A69A).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF26A69A), size: 13),
                      const SizedBox(width: 3),
                      Text(
                        '${(profile?.walletBalance ?? 0.0).toStringAsFixed(0)} د.ع',
                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF26A69A)),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 4),

              // جرس الإشعارات
              Stack(
                children: [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.all(5),
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.notifications_none_rounded, size: 19, color: Colors.white),
                    onPressed: onOpenNotifications,
                  ),
                  if (unreadNotificationsCount > 0)
                    Positioned(
                      top: 1,
                      right: 1,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                        child: Text(
                          '$unreadNotificationsCount',
                          style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),

              if (onOpenSettings != null) ...[
                const SizedBox(width: 4),
                // زر الإعدادات المباشر
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.all(5),
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.settings_outlined, size: 19, color: Colors.white70),
                  tooltip: 'الإعدادات والحساب',
                  onPressed: onOpenSettings,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
