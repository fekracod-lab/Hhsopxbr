import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dalal_alqaim/shared/app_colors.dart' as app_colors;

class RestaurantHeaderBar extends StatelessWidget {
  final String restaurantName;
  final String cuisineType;
  final String? logoUrl;
  final bool isOnline;
  final String congestionStatus;
  final VoidCallback onCycleCongestion;
  final ValueChanged<bool> onToggleOnline;
  final VoidCallback onOpenDrawer;

  const RestaurantHeaderBar({
    super.key,
    required this.restaurantName,
    required this.cuisineType,
    required this.logoUrl,
    required this.isOnline,
    required this.congestionStatus,
    required this.onCycleCongestion,
    required this.onToggleOnline,
    required this.onOpenDrawer,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? app_colors.darkText : app_colors.textColor;
    final cardBg = isDark ? app_colors.darkCard : Colors.white;

    Color congestionColor = Colors.green.shade600;
    String congestionLabel = 'روقان وهدوء (20 د)';
    if (congestionStatus == 'active') {
      congestionColor = Colors.orange.shade700;
      congestionLabel = 'شغل حامي (35 د)';
    } else if (congestionStatus == 'busy') {
      congestionColor = Colors.red.shade700;
      congestionLabel = 'ازدحام فول (50 د)';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: cardBg.withValues(alpha: isDark ? 0.7 : 0.85),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: (isDark ? app_colors.darkBorder : app_colors.borderColor).withValues(alpha: 0.6),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: Row(
        children: [
          // 1. Drawer Button
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Material(
              color: app_colors.primaryColor.withValues(alpha: 0.1),
              child: InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onOpenDrawer();
                },
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(
                    Icons.menu_rounded,
                    color: app_colors.primaryColor,
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // 2. Avatar with Glowing Ring
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: app_colors.primaryColor.withValues(alpha: 0.5),
                width: 2,
              ),
              color: app_colors.primaryColor.withValues(alpha: 0.08),
              boxShadow: [
                BoxShadow(
                  color: app_colors.primaryColor.withValues(alpha: 0.15),
                  blurRadius: 8,
                ),
              ],
            ),
            child: logoUrl != null && logoUrl!.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: Image.network(
                      logoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) => const Icon(
                        Icons.storefront_rounded,
                        color: app_colors.primaryColor,
                        size: 22,
                      ),
                    ),
                  )
                : const Icon(
                    Icons.storefront_rounded,
                    color: app_colors.primaryColor,
                    size: 22,
                  ),
          ),
          const SizedBox(width: 10),

          // 3. Name & Congestion Pill
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  restaurantName,
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                    color: textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                GestureDetector(
                  onTap: onCycleCongestion,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: congestionColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: congestionColor.withValues(alpha: 0.35),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.bolt_rounded,
                          size: 12,
                          color: congestionColor,
                        ),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            congestionLabel,
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: congestionColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // 4. Online/Offline Status Switch
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isOnline ? 'مفتوح' : 'مغلق',
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                  color: isOnline ? Colors.green.shade600 : Colors.redAccent,
                ),
              ),
              Transform.scale(
                scale: 0.78,
                child: Switch.adaptive(
                  activeThumbColor: app_colors.primaryColor,
                  activeTrackColor: app_colors.primaryColor.withValues(alpha: 0.3),
                  value: isOnline,
                  onChanged: (val) {
                    HapticFeedback.mediumImpact();
                    onToggleOnline(val);
                  },
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => _confirmSignOut(context),
                tooltip: 'تسجيل الخروج',
                icon: const Icon(
                  Icons.logout_rounded,
                  color: Colors.redAccent,
                  size: 19,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    HapticFeedback.heavyImpact();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Row(
          children: [
            const Icon(Icons.logout_rounded, color: Colors.redAccent),
            const SizedBox(width: 8),
            Text(
              'تسجيل خروج المطعم',
              style: GoogleFonts.ibmPlexSansArabic(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        content: Text(
          'هل تريد بالتأكيد تسجيل الخروج؟ سيتوقف استقبال الطلبات التلقائي حتى تسجيل الدخول مرة أخرى.',
          style: GoogleFonts.ibmPlexSansArabic(fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'إلغاء',
              style: GoogleFonts.ibmPlexSansArabic(
                color: app_colors.subTextColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              'تسجيل الخروج',
              style: GoogleFonts.ibmPlexSansArabic(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      await FirebaseAuth.instance.signOut();
      if (context.mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/welcome', (route) => false);
      }
    }
  }
}
