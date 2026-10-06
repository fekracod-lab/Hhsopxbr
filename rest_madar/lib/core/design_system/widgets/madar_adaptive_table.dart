import 'package:flutter/material.dart';
import '../../responsive/madar_responsive.dart';
import '../madar_colors.dart';
import '../madar_radius.dart';
import '../madar_typography.dart';

/// عمود في جدول مدار التكيفي
class MadarTableColumn {
  final String label;
  final int flex;
  final Alignment alignment;
  final bool isSecondary; // إذا كان true، يُخفى في شاشات التابلت الضيقة

  const MadarTableColumn({
    required this.label,
    this.flex = 1,
    this.alignment = Alignment.centerRight,
    this.isSecondary = false,
  });
}

/// =====================================================================
///  Madar Design System — جدول البيانات المتكيف (Adaptive Data Table)
/// =====================================================================
class MadarAdaptiveTable<T> extends StatelessWidget {
  final List<MadarTableColumn> columns;
  final List<T> items;
  final List<Widget> Function(BuildContext context, T item, bool isCompact) rowBuilder;
  final ValueChanged<T>? onItemTap;
  final Widget? emptyState;

  const MadarAdaptiveTable({
    super.key,
    required this.columns,
    required this.items,
    required this.rowBuilder,
    this.onItemTap,
    this.emptyState,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty && emptyState != null) {
      return emptyState!;
    }

    final isCompact = !MadarResponsive.isDesktop(context);
    final activeColumns = isCompact
        ? columns.where((c) => !c.isSecondary).toList()
        : columns;

    return Container(
      decoration: BoxDecoration(
        color: MadarColors.card,
        borderRadius: MadarRadius.md,
        border: Border.all(color: MadarColors.border),
      ),
      child: Column(
        children: [
          // ── رأس الجدول الموحد ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: MadarColors.background,
              borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
              border: Border(bottom: BorderSide(color: MadarColors.border)),
            ),
            child: Row(
              children: activeColumns.map((col) {
                return Expanded(
                  flex: col.flex,
                  child: Align(
                    alignment: col.alignment,
                    child: Text(
                      col.label,
                      style: MadarTypography.caption(
                        color: MadarColors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // ── صفوف الجدول التفاعلية ──
          Expanded(
            child: ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, _) => const Divider(
                color: MadarColors.border,
                height: 1,
              ),
              itemBuilder: (ctx, idx) {
                final item = items[idx];
                final cells = rowBuilder(ctx, item, isCompact);

                return InkWell(
                  onTap: onItemTap != null ? () => onItemTap!(item) : null,
                  hoverColor: MadarColors.primarySoft.withValues(alpha: 0.5),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        for (int i = 0; i < activeColumns.length && i < cells.length; i++)
                          Expanded(
                            flex: activeColumns[i].flex,
                            child: Align(
                              alignment: activeColumns[i].alignment,
                              child: cells[i],
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
