import 'package:flutter/material.dart';
import 'package:dalal_alqaim/utils/theme_constants.dart';

import 'package:dalal_alqaim/features/taxi/presentation/pages/captain/driver_settings_page.dart';

class DriverHeaderWidget extends StatelessWidget {
  final Map<String, dynamic> driverData;
  final String availability;
  final VoidCallback onToggleStatus;
  final bool isDark;

  const DriverHeaderWidget({
    super.key,
    required this.driverData,
    required this.availability,
    required this.onToggleStatus,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final double rating = (driverData['rating'] ?? 0.0).toDouble();
    final bool isOnline = availability == 'online';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 50, 20, 25),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F2323) : AppTheme.primaryColor,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'لوحة التحكم',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.settings_outlined, color: Colors.white, size: 22),
                onPressed:
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const DriverSettingsPage()),
                    ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Profile Section
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _getStatusColor(availability).withValues(alpha: 0.5),
                        width: 2,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.white10,
                      backgroundImage:
                          (driverData['imageUrl'] != null &&
                                  driverData['imageUrl'].toString().isNotEmpty)
                              ? NetworkImage(driverData['imageUrl'])
                              : null,
                      child:
                          (driverData['imageUrl'] == null ||
                                  driverData['imageUrl'].toString().isEmpty)
                              ? const Icon(Icons.person, size: 35, color: Colors.white)
                              : null,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        driverData['name'] ?? 'الكابتن',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  rating.toStringAsFixed(1),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            driverData['carType'] ?? 'تاكسي',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),

              // Status Toggle
              GestureDetector(
                onTap: onToggleStatus,
                child: Container(
                  height: 45,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: isOnline ? AppTheme.successColor : Colors.white10,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isOnline ? Colors.white24 : Colors.white12),
                  ),
                  child: Row(
                    children: [
                      Icon(_getStatusIcon(availability), size: 18, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(
                        _getStatusText(availability),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'online':
      case 'on_trip':
        return const Color(0xFF00E676);
      case 'offline':
        return const Color(0xFFFF5252);
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    return Icons.power_settings_new_rounded;
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'online':
      case 'on_trip':
        return 'متصل';
      case 'offline':
      default:
        return 'غير متصل';
    }
  }
}
