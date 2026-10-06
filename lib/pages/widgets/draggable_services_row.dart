// For ImageFilter
import 'package:flutter/material.dart';

import '../../pages/emergency_services_page.dart';
import '../../pages/vacancies_page.dart';
import '../../pages/real_estate_page.dart';
import '../../pages/complaints_page.dart';
import '../../pages/technical_support_chat_page.dart';

class DraggableServicesRow extends StatefulWidget {
  const DraggableServicesRow({super.key});

  @override
  State<DraggableServicesRow> createState() => _DraggableServicesRowState();
}

class _DraggableServicesRowState extends State<DraggableServicesRow> with TickerProviderStateMixin {
  final List<_ServiceItem> _services = [
    _ServiceItem(Icons.work_outline_rounded, 'الوظائف', page: const VacanciesPage()),
    _ServiceItem(Icons.apartment_rounded, 'العقارات', page: const RealEstatePage()),
    _ServiceItem(Icons.report_gmailerrorred_rounded, 'الشكاوي', page: const ComplaintsPage()),
    _ServiceItem(Icons.medical_services_outlined, 'الطوارئ', page: const EmergencyServicesPage()),
    _ServiceItem(Icons.contact_phone_outlined, 'الاتصال', action: _showContactDialog),
    _ServiceItem(Icons.help_outline_rounded, 'المساعدة', action: _showHelpDialog),
  ];

  late AnimationController _animationController;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack));
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  static void _showContactDialog(BuildContext context) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), // More boxy
        backgroundColor: theme.cardColor,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.phone_in_talk_rounded, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: 12),
            Text(
              'معلومات الاتصال',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: theme.textTheme.bodyLarge?.color,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildContactItem('الهاتف', '07819436408', Icons.phone_android_rounded, theme),
            const SizedBox(height: 12),
            _buildContactItem('البريد الإلكتروني', 'info@dalal.com', Icons.alternate_email_rounded, theme),
            const SizedBox(height: 12),
            _buildContactItem('العنوان', 'الأنبار - القائم', Icons.map_outlined, theme),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(
              'إغلاق',
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildContactItem(String title, String value, IconData icon, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12), // Engineering curve
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.primary, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 0.5,
                    color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                  ),
                ),
                if (value.isNotEmpty)
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.textTheme.bodyLarge?.color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static void _showHelpDialog(BuildContext context) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: theme.cardColor,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.support_rounded, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: 12),
            Text(
              'مركز المساعدة',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: theme.textTheme.bodyLarge?.color,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHelpItem('كيفية الاستخدام', Icons.menu_book_rounded, theme),
            const SizedBox(height: 8),
            _buildHelpItem('الأسئلة الشائعة', Icons.quiz_rounded, theme),
            const SizedBox(height: 8),
            _buildHelpItem(
              'الدعم الفني',
              Icons.headset_mic_rounded,
              theme,
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const TechnicalSupportChatPage(isAdminPersonalChat: true)),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'إغلاق',
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildHelpItem(String text, IconData icon, ThemeData theme, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Icon(icon, color: theme.colorScheme.primary, size: 20),
            const SizedBox(width: 12),
            Text(
              text,
              style: TextStyle(fontSize: 14, color: theme.textTheme.bodyLarge?.color),
            ),
            const Spacer(),
            Icon(Icons.arrow_forward_ios_rounded, size: 12, color: theme.disabledColor),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: 145, // Slightly increased height for the boxy design
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row with Technical Look
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 18,
                      decoration: BoxDecoration(
                        color: theme.primaryColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'الخدمات السريعة',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: theme.textTheme.bodyLarge?.color,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.drag_indicator_rounded, color: theme.primaryColor, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        'ترتيب',
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.textTheme.bodyMedium?.color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Draggable List
          Expanded(
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.3),
                end: Offset.zero,
              ).animate(_slideAnimation),
              child: ReorderableListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex--;
                    final item = _services.removeAt(oldIndex);
                    _services.insert(newIndex, item);
                  });
                },
                proxyDecorator: (child, index, animation) {
                  return Material(
                    color: Colors.transparent,
                    child: Transform.scale(
                      scale: 1.05,
                      child: Container(
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: theme.primaryColor.withValues(alpha: 0.2),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            )
                          ]
                        ),
                        child: child
                      ),
                    ),
                  );
                },
                children: [
                  for (int i = 0; i < _services.length; i++)
                    Padding(
                      key: ValueKey('${_services[i].title}_$i'),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: _ServiceCard(
                        icon: _services[i].icon,
                        title: _services[i].title,
                        isDark: isDark,
                        onTap: () {
                          final service = _services[i];
                          if (service.page != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => service.page!),
                            );
                          } else if (service.action != null) {
                            service.action!(context);
                          }
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ServiceItem {
  final IconData icon;
  final String title;
  final Widget? page;
  final void Function(BuildContext)? action;

  _ServiceItem(this.icon, this.title, {this.page, this.action});
}

class _ServiceCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool isDark;

  const _ServiceCard({
    required this.icon,
    required this.title,
    required this.onTap,
    required this.isDark,
  });

  @override
  State<_ServiceCard> createState() => _ServiceCardState();
}

class _ServiceCardState extends State<_ServiceCard> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.92,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.primaryColor;
    
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => _animationController.forward(),
      onTapUp: (_) => _animationController.reverse(),
      onTapCancel: () => _animationController.reverse(),
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: 85, // Slightly wider for boxy look
              margin: const EdgeInsets.symmetric(vertical: 4),
              // Technical Container Design
              decoration: BoxDecoration(
                color: widget.isDark 
                    ? const Color(0xFF252525) 
                    : Colors.white,
                borderRadius: BorderRadius.circular(14), // Squircle-like
                border: Border.all(
                  color: widget.isDark 
                      ? Colors.white.withValues(alpha: 0.08) 
                      : Colors.grey.withValues(alpha: 0.2),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: widget.isDark ? 0.3 : 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Icon Module
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: widget.isDark 
                          ? primary.withValues(alpha: 0.15) 
                          : primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10), // Matching curve
                      border: Border.all(
                        color: primary.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      widget.icon, 
                      color: primary, 
                      size: 22
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Label
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      widget.title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: theme.textTheme.bodyMedium?.color,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Technical accent line at bottom
                  Container(
                    width: 12,
                    height: 2,
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
