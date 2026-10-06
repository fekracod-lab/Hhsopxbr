import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

const Color _primary = Color(0xFF26A69A);
const Color _accent = Color(0xFF00796B);
const Color _darkCard = Color(0xFF113033);
const Color _darkText = Color(0xFFE0F2F1);
const Color _textColor = Color(0xFF1A1A1A);
const Color _darkSubText = Color(0xFF80CBC4);
const Color _subText = Color(0xFF616161);

/// شريط السلة الجماعية النشطة (Shared Group Cart Active Banner Widget)
class GroupCartBannerWidget extends StatelessWidget {
  final String groupCartCode;
  final String hostName;
  final bool isHost;
  final bool isDark;
  final VoidCallback onLeaveOrEnd;

  const GroupCartBannerWidget({
    super.key,
    required this.groupCartCode,
    required this.hostName,
    required this.isHost,
    required this.isDark,
    required this.onLeaveOrEnd,
  });

  @override
  Widget build(BuildContext context) {
    if (groupCartCode.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 8.h),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF113033), const Color(0xFF0F2323)]
              : [const Color(0xFFE0F2F1), Colors.white],
        ),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: _primary.withValues(alpha: 0.3),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: _primary.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8.r),
            decoration: BoxDecoration(
              color: _primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.group_rounded,
              color: _primary,
              size: 20.r,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isHost ? 'سلة الربع مالتك مشتغلة هسة' : 'داخل بسلة $hostName ويا الربع',
                  style: TextStyle(
                    fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.bold,
                    color: isDark ? _darkText : _textColor,
                  ),
                ),
                SizedBox(height: 3.h),
                Row(
                  children: [
                    Text(
                      'رمز السلة:',
                      style: TextStyle(
                        fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily,
                        fontSize: 11.sp,
                        color: isDark ? _darkSubText : _subText,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: groupCartCode));
                        HapticFeedback.mediumImpact();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('نسخنا الرمز $groupCartCode وتدلل'),
                            backgroundColor: _accent,
                          ),
                        );
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                        decoration: BoxDecoration(
                          color: _primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Row(
                          children: [
                            Text(
                              groupCartCode,
                              style: TextStyle(
                                fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily,
                                fontSize: 11.sp,
                                fontWeight: FontWeight.bold,
                                color: _primary,
                              ),
                            ),
                            SizedBox(width: 4.w),
                            Icon(Icons.copy_rounded, color: _primary, size: 12.r),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => GroupCartLeaveDialog(
                  isHost: isHost,
                  isDark: isDark,
                  onConfirm: onLeaveOrEnd,
                ),
              );
            },
            icon: Icon(
              isHost ? Icons.power_settings_new_rounded : Icons.exit_to_app_rounded,
              color: Colors.redAccent,
              size: 22.r,
            ),
          ),
        ],
      ),
    );
  }
}

/// نافذة خيارات السلة الجماعية السفلية (Group Cart Options Bottom Sheet)
class GroupCartOptionsSheet extends StatelessWidget {
  final bool isDark;
  final VoidCallback onCreateGroup;
  final VoidCallback onJoinGroup;

  const GroupCartOptionsSheet({
    super.key,
    required this.isDark,
    required this.onCreateGroup,
    required this.onJoinGroup,
  });

  static Future<void> show({
    required BuildContext context,
    required bool isDark,
    required VoidCallback onCreateGroup,
    required VoidCallback onJoinGroup,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => GroupCartOptionsSheet(
        isDark: isDark,
        onCreateGroup: onCreateGroup,
        onJoinGroup: onJoinGroup,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: EdgeInsets.all(24.r),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F2323) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(30.r),
            topRight: Radius.circular(30.r),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 15,
              offset: const Offset(0, -5),
            )
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.grey[300],
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
            SizedBox(height: 20.h),
            Text(
              'لمة وجمعة وسلة وحدة',
              style: TextStyle(
                fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily,
                fontSize: 16.sp,
                fontWeight: FontWeight.w900,
                color: isDark ? _darkText : _textColor,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'تقدر تشارك سلتك ويا ربعك أو أهلك وتطلبون سوا بطلب واحد وتوصيل واحد!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily,
                fontSize: 11.5.sp,
                color: isDark ? _darkSubText : _subText,
                height: 1.4,
              ),
            ),
            SizedBox(height: 24.h),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      Navigator.pop(context);
                      onCreateGroup();
                    },
                    child: Container(
                      padding: EdgeInsets.all(16.r),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [_primary, _accent],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20.r),
                        boxShadow: [
                          BoxShadow(
                            color: _primary.withValues(alpha: 0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.add_circle_outline_rounded, color: Colors.white, size: 28.r),
                          SizedBox(height: 8.h),
                          Text(
                            'سوي سلة ويا ربعك',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily,
                              fontSize: 12.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 14.w),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      onJoinGroup();
                    },
                    child: Container(
                      padding: EdgeInsets.all(16.r),
                      decoration: BoxDecoration(
                        color: isDark ? _darkCard : Colors.white,
                        borderRadius: BorderRadius.circular(20.r),
                        border: Border.all(
                          color: isDark ? Colors.white10 : _primary.withValues(alpha: 0.2),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.key_rounded, color: _primary, size: 28.r),
                          SizedBox(height: 8.h),
                          Text(
                            'ادخل برمز السلة',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily,
                              fontSize: 12.sp,
                              fontWeight: FontWeight.bold,
                              color: isDark ? _darkText : _textColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 10.h),
          ],
        ),
      ),
    );
  }
}

/// نافذة إدخال رمز الانضمام للسلة الجماعية (Group Cart Join Dialog)
class GroupCartJoinDialog extends StatefulWidget {
  final bool isDark;
  final Function(String code) onJoin;

  const GroupCartJoinDialog({
    super.key,
    required this.isDark,
    required this.onJoin,
  });

  static Future<void> show({
    required BuildContext context,
    required bool isDark,
    required Function(String code) onJoin,
  }) {
    return showDialog(
      context: context,
      builder: (_) => GroupCartJoinDialog(isDark: isDark, onJoin: onJoin),
    );
  }

  @override
  State<GroupCartJoinDialog> createState() => _GroupCartJoinDialogState();
}

class _GroupCartJoinDialogState extends State<GroupCartJoinDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: widget.isDark ? const Color(0xFF0F2323) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r)),
        title: Text(
          'انضمام لسلة الربع',
          style: TextStyle(
            fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily,
            fontSize: 15.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'اكتب رمز السلة المكون من 5 أرقام وتدلل عيوني.',
              style: TextStyle(
                fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily,
                fontSize: 11.5.sp,
                color: widget.isDark ? _darkSubText : _subText,
              ),
            ),
            SizedBox(height: 16.h),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              maxLength: 5,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
                color: _primary,
              ),
              decoration: InputDecoration(
                counterText: '',
                hintText: '12345',
                hintStyle: TextStyle(
                  color: widget.isDark ? Colors.white10 : Colors.grey[300],
                  letterSpacing: 2,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16.r),
                  borderSide: BorderSide(
                    color: widget.isDark ? Colors.white.withValues(alpha: 0.2) : Colors.grey[300]!,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16.r),
                  borderSide: const BorderSide(color: _primary, width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'إلغاء',
              style: TextStyle(
                fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily,
                color: widget.isDark ? _darkSubText : Colors.grey,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              final code = _controller.text.trim();
              if (code.length == 5) {
                Navigator.pop(context);
                widget.onJoin(code);
              } else {
                HapticFeedback.vibrate();
              }
            },
            child: Text(
              'ادخل وياهم',
              style: TextStyle(
                fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily,
                color: _accent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// نافذة تأكيد الخروج أو إنهاء السلة الجماعية (Group Cart Leave Confirmation Dialog)
class GroupCartLeaveDialog extends StatelessWidget {
  final bool isHost;
  final bool isDark;
  final VoidCallback onConfirm;

  const GroupCartLeaveDialog({
    super.key,
    required this.isHost,
    required this.isDark,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF0F2323) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r)),
      title: Text(
        isHost ? 'تريد تنهي سلة الربع؟' : 'تريد تطلع من سلة الربع؟',
        style: TextStyle(
          fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Text(
        isHost
            ? 'إذا تنهي السلة راح تنلغي يم الكل عيوني.'
            : 'متأكد تريد تطلع وترجع لسلتك الخاصة؟',
        style: TextStyle(
          fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily,
          color: isDark ? _darkSubText : _subText,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'إلغاء',
            style: TextStyle(
              fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily,
              color: isDark ? _darkSubText : Colors.grey,
            ),
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            onConfirm();
          },
          child: Text(
            isHost ? 'أنهي السلة' : 'اطلع',
            style: TextStyle(
              fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily,
              color: Colors.redAccent,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
