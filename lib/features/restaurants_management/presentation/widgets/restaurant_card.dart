import 'package:flutter/material.dart';
import '../../../../pages/restaurant_details_page.dart';
import '../../domain/entities/restaurant_management_models.dart';
import 'restaurant_edit_dialog.dart';
import 'restaurant_owner_password_dialog.dart';

/// بطاقة عرض المطعم وقائمة الإجراءات الإدارية (Restaurant Card Widget)
class RestaurantCard extends StatelessWidget {
  final RestaurantRecord restaurant;
  final Future<bool> Function(RestaurantRecord restaurant) onToggleSuspend;
  final Future<bool> Function({
    required RestaurantRecord restaurant,
    required String name,
    required String imageUrl,
    required String status,
  }) onUpdateRestaurant;
  final Future<bool> Function(RestaurantRecord restaurant) onDeleteRestaurant;
  final Future<RestaurantOwnerRecord?> Function(String ownerId) onFetchOwner;
  final Future<bool> Function(String ownerId, String newPassword) onChangeOwnerPassword;

  const RestaurantCard({
    super.key,
    required this.restaurant,
    required this.onToggleSuspend,
    required this.onUpdateRestaurant,
    required this.onDeleteRestaurant,
    required this.onFetchOwner,
    required this.onChangeOwnerPassword,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSuspended = restaurant.isSuspended;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isSuspended ? Border.all(color: Colors.red.shade300, width: 2) : null,
        boxShadow: [
          BoxShadow(
            color: isSuspended ? Colors.red.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => RestaurantDetailsPage(
                  restaurantId: restaurant.ownerId,
                  restaurantName: restaurant.name,
                  imageUrl: restaurant.imageUrl,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Image Section
                Stack(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.grey.shade200,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: restaurant.imageUrl.isNotEmpty
                            ? Image.network(
                                restaurant.imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Icon(
                                  Icons.restaurant,
                                  size: 40,
                                  color: Colors.grey.shade400,
                                ),
                              )
                            : Icon(
                                Icons.restaurant,
                                size: 40,
                                color: Colors.grey.shade400,
                              ),
                      ),
                    ),
                    if (isSuspended)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.block_rounded,
                            color: Colors.red,
                            size: 32,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 16),

                // Info Section
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              restaurant.name,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.grey.shade900,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isSuspended)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.red.shade200),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.block, size: 12, color: Colors.red.shade700),
                                  const SizedBox(width: 4),
                                  Text(
                                    'محظور',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.person_outline, size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'المالك: ${restaurant.ownerId}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (restaurant.rating > 0) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.star_rounded, size: 16, color: Colors.amber.shade600),
                            const SizedBox(width: 4),
                            Text(
                              restaurant.rating.toStringAsFixed(1),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber.shade700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                // Actions Menu
                PopupMenuButton<String>(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.more_vert_rounded, color: Colors.grey.shade700),
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onSelected: (value) => _handleMenuAction(context, value),
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 20, color: Colors.blue.shade600),
                          const SizedBox(width: 12),
                          const Text('تعديل البيانات', style: TextStyle()),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'suspend',
                      child: Row(
                        children: [
                          Icon(
                            isSuspended ? Icons.check_circle_outline : Icons.block_outlined,
                            size: 20,
                            color: isSuspended ? Colors.green.shade600 : Colors.orange.shade600,
                          ),
                          const SizedBox(width: 12),
                          Text(isSuspended ? 'تفعيل المطعم' : 'حظر مؤقت', style: const TextStyle()),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'password',
                      child: Row(
                        children: [
                          Icon(Icons.lock_reset_rounded, size: 20, color: Colors.deepPurple.shade600),
                          const SizedBox(width: 12),
                          const Text('تغيير كلمة مرور المالك', style: TextStyle()),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, size: 20, color: Colors.red.shade600),
                          const SizedBox(width: 12),
                          Text('حذف نهائي', style: TextStyle(color: Colors.red.shade600)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleMenuAction(BuildContext context, String action) async {
    final messenger = ScaffoldMessenger.of(context);

    if (action == 'edit') {
      RestaurantEditDialog.show(
        context,
        restaurant: restaurant,
        onSave: onUpdateRestaurant,
      );
    } else if (action == 'suspend') {
      final success = await onToggleSuspend(restaurant);
      if (success) {
        messenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(!restaurant.isSuspended ? Icons.block : Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Text(!restaurant.isSuspended ? 'تم حظر المطعم مؤقتاً' : 'تم تفعيل المطعم', style: const TextStyle()),
              ],
            ),
            backgroundColor: !restaurant.isSuspended ? Colors.orange : Colors.green,
            behavior: SnackBarBehavior.fixed,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } else if (action == 'password') {
      if (restaurant.ownerId.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(content: Text('معرف المالك غير متوفر لهذا المطعم', style: TextStyle())),
        );
        return;
      }

      final ownerRecord = await onFetchOwner(restaurant.ownerId);
      if (ownerRecord == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('لم يتم العثور على حساب المالك في قاعدة البيانات', style: TextStyle())),
        );
        return;
      }

      if (context.mounted) {
        RestaurantOwnerPasswordDialog.show(
          context,
          ownerId: restaurant.ownerId,
          restaurantName: restaurant.name,
          ownerRecord: ownerRecord,
          onChangePassword: onChangeOwnerPassword,
        );
      }
    } else if (action == 'delete') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                child: Icon(Icons.delete_outline, color: Colors.red.shade700),
              ),
              const SizedBox(width: 12),
              const Text('تأكيد الحذف', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text(
            'متأكد تريد تحذف هذا المطعم نهائياً؟ لا يمكن التراجع عن هذا الإجراء.',
            style: TextStyle(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء', style: TextStyle()),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              child: const Text('حذف نهائي', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );

      if (ok == true) {
        final success = await onDeleteRestaurant(restaurant);
        if (success) {
          messenger.showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 12),
                  Text('تم حذف المطعم بنجاح', style: TextStyle()),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.fixed,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    }
  }
}
