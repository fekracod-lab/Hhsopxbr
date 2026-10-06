import 'package:flutter/material.dart';
import 'package:dalal_alqaim/shared/app_colors.dart' as app_colors;

class VacancyFilterSheet extends StatefulWidget {
  final bool isDark;
  final String? initialExp;
  final String? initialWorkType;
  final String? initialCity;
  final String initialSalaryMin;
  final String initialSalaryMax;
  final Function({
    String? exp,
    String? workType,
    String? city,
    required String salaryMin,
    required String salaryMax,
  }) onApply;

  const VacancyFilterSheet({
    super.key,
    required this.isDark,
    this.initialExp,
    this.initialWorkType,
    this.initialCity,
    required this.initialSalaryMin,
    required this.initialSalaryMax,
    required this.onApply,
  });

  @override
  State<VacancyFilterSheet> createState() => _VacancyFilterSheetState();
}

class _VacancyFilterSheetState extends State<VacancyFilterSheet> {
  String? tempExp;
  String? tempWorkType;
  String? tempCity;
  late TextEditingController minCtr;
  late TextEditingController maxCtr;

  final List<String> _expLevels = ['مبتدئ', 'متوسط', 'خبير'];
  final List<String> _workTypes = ['دوام كامل', 'دوام جزئي', 'عن بعد', 'تدريب'];
  final Map<String, String> _workTypeIcons = {
    'دوام كامل': '',
    'دوام جزئي': '',
    'عن بعد': '',
    'تدريب': '',
  };
  final List<String> _cities = ['القائم', 'الرمادي', 'الفلوجة', 'هيت', 'حديثة', 'عانة', 'راوة', 'بغداد', 'البصرة', 'أربيل'];

  @override
  void initState() {
    super.initState();
    tempExp = widget.initialExp;
    tempWorkType = widget.initialWorkType;
    tempCity = widget.initialCity;
    minCtr = TextEditingController(text: widget.initialSalaryMin);
    maxCtr = TextEditingController(text: widget.initialSalaryMax);
  }

  @override
  void dispose() {
    minCtr.dispose();
    maxCtr.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        decoration: BoxDecoration(
          color: widget.isDark ? app_colors.darkCard : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'فلتر متقدم',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: widget.isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'الخبرة',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: widget.isDark ? Colors.white70 : Colors.black54,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _expLevels.map((e) {
                  final sel = tempExp == e;
                  return GestureDetector(
                    onTap: () => setState(() => tempExp = sel ? null : e),
                    child: Chip(
                      label: Text(
                        e,
                        style: TextStyle(
                          color: sel ? Colors.white : (widget.isDark ? Colors.white70 : Colors.black54),
                          fontSize: 12,
                        ),
                      ),
                      backgroundColor: sel
                          ? app_colors.primaryColor
                          : (widget.isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.shade100),
                      side: BorderSide.none,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              Text(
                'نوع الدوام',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: widget.isDark ? Colors.white70 : Colors.black54,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _workTypes.map((w) {
                  final sel = tempWorkType == w;
                  return GestureDetector(
                    onTap: () => setState(() => tempWorkType = sel ? null : w),
                    child: Chip(
                      label: Text(
                        '${_workTypeIcons[w] ?? ''} $w',
                        style: TextStyle(
                          color: sel ? Colors.white : (widget.isDark ? Colors.white70 : Colors.black54),
                          fontSize: 12,
                        ),
                      ),
                      backgroundColor: sel
                          ? const Color(0xFFEC4899)
                          : (widget.isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.shade100),
                      side: BorderSide.none,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              Text(
                'المدينة',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: widget.isDark ? Colors.white70 : Colors.black54,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _cities.map((c) {
                  final sel = tempCity == c;
                  return GestureDetector(
                    onTap: () => setState(() => tempCity = sel ? null : c),
                    child: Chip(
                      label: Text(
                        c,
                        style: TextStyle(
                          color: sel ? Colors.white : (widget.isDark ? Colors.white70 : Colors.black54),
                          fontSize: 12,
                        ),
                      ),
                      backgroundColor: sel
                          ? const Color(0xFF6366F1)
                          : (widget.isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.shade100),
                      side: BorderSide.none,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              Text(
                'نطاق الراتب',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: widget.isDark ? Colors.white70 : Colors.black54,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _field('من', Icons.attach_money, minCtr),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _field('إلى', Icons.attach_money, maxCtr),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        widget.onApply(
                          exp: null,
                          workType: null,
                          city: null,
                          salaryMin: '',
                          salaryMax: '',
                        );
                        Navigator.pop(context);
                      },
                      child: Container(
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: widget.isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          'مسح الفلتر',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: widget.isDark ? Colors.white70 : Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        widget.onApply(
                          exp: tempExp,
                          workType: tempWorkType,
                          city: tempCity,
                          salaryMin: minCtr.text,
                          salaryMax: maxCtr.text,
                        );
                        Navigator.pop(context);
                      },
                      child: Container(
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              app_colors.primaryColor,
                              app_colors.primaryColor.withValues(alpha: 0.8),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Text(
                          'تطبيق',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(String label, IconData icon, TextEditingController ctr) {
    return Container(
      decoration: BoxDecoration(
        color: widget.isDark ? Colors.white.withValues(alpha: 0.04) : app_colors.surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: widget.isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.shade200,
        ),
      ),
      child: TextField(
        controller: ctr,
        keyboardType: TextInputType.number,
        style: TextStyle(
          color: widget.isDark ? Colors.white : Colors.black87,
          fontSize: 14,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: widget.isDark ? Colors.white30 : Colors.grey.shade500,
            fontSize: 13,
          ),
          prefixIcon: Icon(icon, color: app_colors.primaryColor.withValues(alpha: 0.6), size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}
