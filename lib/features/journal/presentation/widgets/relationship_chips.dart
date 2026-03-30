import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/models/tracking_session.dart';
import 'package:obsession_tracker/core/models/treasure_hunt.dart';

/// Widget displaying relationship chips for a journal entry
/// Shows linked session, hunt, and/or location with option to add/remove
class RelationshipChips extends ConsumerWidget {
  const RelationshipChips({
    this.session,
    this.hunt,
    this.locationName,
    this.hasLocation = false,
    this.onAddSession,
    this.onRemoveSession,
    this.onAddHunt,
    this.onRemoveHunt,
    this.onAddLocation,
    this.onRemoveLocation,
    this.editable = true,
    super.key,
  });

  final TrackingSession? session;
  final TreasureHunt? hunt;
  final String? locationName;
  final bool hasLocation;

  final VoidCallback? onAddSession;
  final VoidCallback? onRemoveSession;
  final VoidCallback? onAddHunt;
  final VoidCallback? onRemoveHunt;
  final VoidCallback? onAddLocation;
  final VoidCallback? onRemoveLocation;

  final bool editable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        // Session chip
        if (session != null)
          _RelationshipChip(
            icon: Icons.route,
            label: session!.name,
            color: const Color(0xFF4CAF50), // Green
            onRemove: editable ? onRemoveSession : null,
            isDark: isDark,
          )
        else if (editable && onAddSession != null)
          _AddRelationshipChip(
            icon: Icons.route,
            label: 'Session',
            onTap: onAddSession!,
            isDark: isDark,
          ),

        // Hunt chip
        if (hunt != null)
          _RelationshipChip(
            icon: Icons.explore,
            label: hunt!.name,
            color: const Color(0xFFD4AF37), // Gold
            onRemove: editable ? onRemoveHunt : null,
            isDark: isDark,
          )
        else if (editable && onAddHunt != null)
          _AddRelationshipChip(
            icon: Icons.explore,
            label: 'Hunt',
            onTap: onAddHunt!,
            isDark: isDark,
          ),

        // Location chip
        if (hasLocation)
          _RelationshipChip(
            icon: Icons.location_on,
            label: locationName ?? 'Location',
            color: const Color(0xFF2196F3), // Blue
            onRemove: editable ? onRemoveLocation : null,
            isDark: isDark,
          )
        else if (editable && onAddLocation != null)
          _AddRelationshipChip(
            icon: Icons.location_on,
            label: 'Location',
            onTap: onAddLocation!,
            isDark: isDark,
          ),
      ],
    );
  }
}

/// Chip showing an existing relationship
class _RelationshipChip extends StatelessWidget {
  const _RelationshipChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.isDark,
    this.onRemove,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool isDark;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (onRemove != null) ...[
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onRemove,
              child: Icon(
                Icons.close,
                size: 16,
                color: color.withValues(alpha: 0.7),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Chip for adding a new relationship
class _AddRelationshipChip extends StatelessWidget {
  const _AddRelationshipChip({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.isDark,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.grey.shade800.withValues(alpha: 0.5)
                : Colors.grey.shade200.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.grey.shade700 : Colors.grey.shade400,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.add,
                size: 14,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
              const SizedBox(width: 4),
              Icon(
                icon,
                size: 14,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact version showing only icons for read-only display
class RelationshipIcons extends StatelessWidget {
  const RelationshipIcons({
    this.hasSession = false,
    this.hasHunt = false,
    this.hasLocation = false,
    this.sessionName,
    this.huntName,
    this.locationName,
    super.key,
  });

  final bool hasSession;
  final bool hasHunt;
  final bool hasLocation;
  final String? sessionName;
  final String? huntName;
  final String? locationName;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];

    if (hasSession) {
      items.add(Tooltip(
        message: sessionName ?? 'Linked to session',
        child: const Icon(
          Icons.route,
          size: 14,
          color: Color(0xFF4CAF50),
        ),
      ));
    }

    if (hasHunt) {
      items.add(Tooltip(
        message: huntName ?? 'Linked to hunt',
        child: const Icon(
          Icons.explore,
          size: 14,
          color: Color(0xFFD4AF37),
        ),
      ));
    }

    if (hasLocation) {
      items.add(Tooltip(
        message: locationName ?? 'Has location',
        child: const Icon(
          Icons.location_on,
          size: 14,
          color: Color(0xFF2196F3),
        ),
      ));
    }

    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < items.length; i++) ...[
          items[i],
          if (i < items.length - 1) const SizedBox(width: 4),
        ],
      ],
    );
  }
}
