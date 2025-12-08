import 'package:chorezilla/models/assignment.dart';
import 'package:chorezilla/models/common.dart';
import 'package:flutter/material.dart';

// ignore: unused_element
class _KidTodayCard extends StatelessWidget {
  const _KidTodayCard({required this.summary});

  final _KidTodaySummary summary;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;

    final total = summary.total;
    final completed = summary.completed;
    final pending = summary.pending;
    final rejected = summary.rejected;
    final remaining = total - completed;

    final progress = total > 0 ? completed / total : 0.0;
    final isAllDone = total > 0 && completed == total;

    final avatarRadius = 22.0;
    final emojiSize = avatarRadius * 1.2;

    // Status pill
    final String statusText = isAllDone ? 'All done' : '$remaining left';
    final Color statusColor = isAllDone
        ? cs.primary.withValues(alpha: 0.14)
        : cs.secondaryContainer.withValues(alpha: 0.35);
    final Color statusTextColor = isAllDone
        ? cs.primary
        : cs.onSecondaryContainer;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        _showKidDetailsBottomSheet(context, summary);
      },
      child: Card(
        elevation: isAllDone ? 2 : 0,
        margin: EdgeInsets.zero,
        color: isAllDone
            ? cs.primaryContainer.withValues(alpha: 0.25)
            : cs.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: isAllDone ? cs.primary : cs.outlineVariant,
            width: isAllDone ? 2 : 1,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            // subtle top-to-bottom tint so it feels less flat
            gradient: LinearGradient(
              colors: [
                cs.surfaceContainerHighest.withValues(alpha: 0.24),
                cs.surface,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row: avatar + name + status pill
              Row(
                children: [
                  CircleAvatar(
                    radius: avatarRadius,
                    backgroundColor: cs.primaryContainer,
                    child:
                        (summary.avatarKey != null &&
                            summary.avatarKey!.isNotEmpty)
                        ? Text(
                            summary.avatarKey!,
                            style: TextStyle(
                              fontSize: emojiSize,
                              color: cs.onPrimaryContainer,
                            ),
                          )
                        : Text(
                            _initialsFor(summary.name),
                            style: TextStyle(
                              fontSize: avatarRadius,
                              fontWeight: FontWeight.bold,
                              color: cs.onPrimaryContainer,
                            ),
                          ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      summary.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ts.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isAllDone
                              ? Icons.check_circle_rounded
                              : Icons.list_alt_rounded,
                          size: 14,
                          color: statusTextColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          statusText,
                          style: ts.labelSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: statusTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Progress bar + count
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: cs.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$completed / $total',
                    style: ts.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Chips row
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  _StatChip(
                    icon: Icons.checklist_rtl_rounded,
                    label: 'Left',
                    value: remaining,
                    color: remaining == 0
                        ? cs.primary.withValues(alpha: 0.16)
                        : cs.secondaryContainer.withValues(alpha: 0.6),
                    textColor: remaining == 0
                        ? cs.primary
                        : cs.onSecondaryContainer,
                  ),
                  _StatChip(
                    icon: Icons.hourglass_bottom_rounded,
                    label: 'Pending',
                    value: pending,
                    color: cs.tertiaryContainer.withValues(alpha: 0.8),
                    textColor: cs.onTertiaryContainer,
                  ),
                  _StatChip(
                    icon: Icons.close_rounded,
                    label: 'Rejected',
                    value: rejected,
                    color: rejected > 0
                        ? cs.errorContainer.withValues(alpha: 0.9)
                        : cs.surfaceContainerHighest.withValues(alpha: 0.7),
                    textColor: rejected > 0
                        ? cs.onErrorContainer
                        : cs.onSurfaceVariant,
                  ),
                ],
              ),

              const SizedBox(height: 6),
              const Spacer(),

              // Footer hint
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'View today',
                    style: ts.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 10,
                    color: cs.onSurfaceVariant,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showKidDetailsBottomSheet(
    BuildContext context,
    _KidTodaySummary summary,
  ) {
    // (unchanged)
    final assignments = [...summary.assignments];
    assignments.sort(
      (a, b) => (a.due ?? DateTime(2100)).compareTo(b.due ?? DateTime(2100)),
    );

    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final maxListHeight = MediaQuery.of(ctx).size.height * 0.6;

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              // Header row
              Row(
                children: [
                  Text(
                    '${summary.name} – today',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${summary.completed}/${summary.total} done',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Scrollable list, but only up to 60% of screen height.
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxListHeight),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: assignments.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 4),
                  itemBuilder: (ctx, i) {
                    final a = assignments[i];
                    final status = a.status;
                    Color? tileColor;
                    BorderSide? side;

                    switch (status) {
                      case AssignmentStatus.assigned:
                        tileColor = null;
                        side = null;
                        break;
                      case AssignmentStatus.pending:
                        tileColor = cs.tertiaryContainer.withValues(alpha: 0.3);
                        side = BorderSide(color: cs.tertiary, width: 2);
                        break;
                      case AssignmentStatus.rejected:
                        tileColor = cs.error.withValues(alpha: 0.12);
                        side = BorderSide(color: cs.error, width: 1.5);
                        break;
                      case AssignmentStatus.completed:
                        tileColor = cs.surfaceContainerHighest.withValues(
                          alpha: 0.2,
                        );
                        side = null;
                        break;
                    }

                    final titleStyle = theme.textTheme.titleMedium?.copyWith(
                      decoration: status == AssignmentStatus.completed
                          ? TextDecoration.lineThrough
                          : null,
                    );

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Text(
                        (a.choreIcon?.isNotEmpty ?? false)
                            ? a.choreIcon!
                            : '🧩',
                        style: const TextStyle(fontSize: 26),
                      ),
                      title: Text(
                        a.choreTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: titleStyle,
                      ),
                      subtitle: Text(
                        a.status.label,
                        style: theme.textTheme.bodySmall,
                      ),
                      tileColor: tileColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: side ?? BorderSide.none,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _initialsFor(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }
}


class _KidTodaySummary {
  _KidTodaySummary({
    required this.memberId,
    required this.name,
    required this.avatarKey,
    required this.total,
    required this.completed,
    required this.pending,
    required this.rejected,
    required this.assigned,
    required this.assignments,
  });

  final String memberId;
  final String name;
  final String? avatarKey;
  final int total;
  final int completed;
  final int pending;
  final int rejected;
  final int assigned;
  final List<Assignment> assignments;
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.textColor,
  });

  final IconData icon;
  final String label;
  final int value;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final ts = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 4),
          Text(
            '$value',
            style: ts.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          const SizedBox(width: 2),
          Text(
            label,
            style: ts.labelSmall?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
