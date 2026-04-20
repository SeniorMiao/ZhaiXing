import 'package:flutter/material.dart';

/// 底部 Tab 各页统一的顶部「蓝条」高度与内容区内边距。
class TabShellTokens {
  TabShellTokens._();

  /// 各 Tab 主列表页 [SliverAppBar.expandedHeight] 统一值。
  static const double headerExpandedHeight = 148;

  static const double horizontalPadding = 16;

  /// 头部下方第一块内容区的标准边距。
  static const EdgeInsets contentPaddingAfterHeader = EdgeInsets.fromLTRB(horizontalPadding, 12, horizontalPadding, 8);

  /// 列表区域左右边距（底部为 FAB 预留空间）。
  static const EdgeInsets listPadding = EdgeInsets.fromLTRB(horizontalPadding, 8, horizontalPadding, 100);
}

/// 与主题主色一致的渐变顶栏（各 Tab 统一）。
SliverAppBar tabShellSliverAppBar(
  BuildContext context, {
  required String title,
  required Widget expandedFooter,
  List<Widget>? actions,
}) {
  final cs = Theme.of(context).colorScheme;
  final primary = cs.primary;
  final onPrimary = cs.onPrimary;
  final gradientEnd = Color.alphaBlend(primary.withValues(alpha: 0.78), primary);

  return SliverAppBar(
    pinned: true,
    expandedHeight: TabShellTokens.headerExpandedHeight,
    backgroundColor: primary,
    foregroundColor: onPrimary,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    title: Text(title),
    actions: actions,
    flexibleSpace: DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primary, gradientEnd],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(TabShellTokens.horizontalPadding, 0, TabShellTokens.horizontalPadding, 14),
          child: Align(
            alignment: Alignment.bottomLeft,
            child: DefaultTextStyle.merge(
              style: TextStyle(color: onPrimary),
              child: expandedFooter,
            ),
          ),
        ),
      ),
    ),
  );
}

/// 展开区副标题样式（浅色字）。
TextStyle? tabShellSubtitleStyle(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  return Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: cs.onPrimary.withValues(alpha: 0.92),
      );
}

/// 固定在顶部的 Tab 头（与 [tabShellSliverAppBar] 视觉一致，不参与下方列表滚动）。
Widget fixedTabHeader(
  BuildContext context, {
  required String title,
  required Widget expandedFooter,
  List<Widget>? actions,
}) {
  final cs = Theme.of(context).colorScheme;
  final primary = cs.primary;
  final onPrimary = cs.onPrimary;
  final gradientEnd = Color.alphaBlend(primary.withValues(alpha: 0.78), primary);
  final topInset = MediaQuery.paddingOf(context).top;
  final totalH = topInset + TabShellTokens.headerExpandedHeight;

  return SizedBox(
    height: totalH,
    child: DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primary, gradientEnd],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(TabShellTokens.horizontalPadding, topInset + 8, TabShellTokens.horizontalPadding, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: onPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (actions != null) ...actions,
              ],
            ),
            const Spacer(),
            DefaultTextStyle.merge(
              style: TextStyle(color: onPrimary),
              child: expandedFooter,
            ),
          ],
        ),
      ),
    ),
  );
}
