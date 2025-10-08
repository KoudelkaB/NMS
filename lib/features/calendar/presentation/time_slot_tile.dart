import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/time_slot.dart';

class TimeSlotTile extends StatelessWidget {
  const TimeSlotTile({
    super.key,
    required this.slot,
    required this.onTap,
    this.highlighted = false,
    this.isMine = false,
  });

  final TimeSlot slot;
  final VoidCallback onTap;
  final bool highlighted;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final names = slot.participants.map((p) => p.fullName).toList();
    final hasExtra = names.length > 3;
    final displayNames = names.take(3).join(', ');
    final timeFormat = DateFormat('HH:mm');
    final isPast = slot.isPast;

    final backgroundColor = isPast
        ? Theme.of(context).colorScheme.surfaceContainerHighest
        : (highlighted
            ? Theme.of(context).colorScheme.secondaryContainer
            : null);
    final borderColor =
        isMine ? Theme.of(context).colorScheme.primary : Colors.transparent;

    final tooltip = names.isEmpty ? null : names.join('\n');
    Widget child = InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: isPast ? null : onTap, // Disable tap for past slots
      child: Opacity(
        opacity: isPast ? 0.5 : 1.0, // Make past slots semi-transparent
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${timeFormat.format(slot.start)} - ${timeFormat.format(slot.end)}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            decoration:
                                isPast ? TextDecoration.lineThrough : null,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      names.isEmpty
                          ? 'Volné místo'
                          : hasExtra
                              ? '$displayNames +${names.length - 3}'
                              : displayNames,
                      softWrap: true,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (isPast)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Proběhlý čas',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.6),
                              ),
                        ),
                      ),
                    if (isMine && !isPast)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Jste přihlášeni v tomto čase',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                children: [
                  Icon(
                    names.length >= slot.capacity
                        ? Icons.event_busy
                        : Icons.event_available,
                  ),
                  const SizedBox(height: 4),
                  Text('${names.length}/${slot.capacity}'),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (tooltip != null) {
      child = Tooltip(
        message: tooltip,
        waitDuration: const Duration(milliseconds: 400),
        child: child,
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: isMine ? 2 : 1),
      ),
      child: child,
    );
  }
}
