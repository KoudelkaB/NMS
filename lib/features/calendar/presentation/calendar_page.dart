import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/date_time_utils.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/application/auth_controllers.dart';
import '../application/calendar_providers.dart';
import '../data/time_slot.dart';
import 'time_slot_tile.dart';

class CalendarPage extends HookConsumerWidget {
  const CalendarPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final focusDay = ref.watch(calendarFocusDayProvider);
    final weekStart = ref.watch(calendarWeekStartProvider);
    final daySlots = ref.watch(daySlotsProvider);
    final appUser = ref.watch(currentAppUserProvider);
    final firebaseUser = ref.watch(authStateProvider).value;

    final scrollController = useScrollController();
    final lastScrolledSlotIndex = useRef<int>(-1);
    final scrollTrigger =
        useState(0); // Used to force scroll even when already on today
    final lastFocusDay = useRef<DateTime?>(null);
    final currentSlotContext = useRef<BuildContext?>(null);

    final selectedDate = focusDay;
    final now = DateTimeUtils.nowInPrague;
    final isToday = selectedDate.year == now.year &&
        selectedDate.month == now.month &&
        selectedDate.day == now.day;
    final currentSlotIndex =
        isToday ? now.hour * 2 + (now.minute >= 30 ? 1 : 0) : -1;

    // Function to scroll to current slot (showing three past slots above)
    void scrollToCurrentSlot({bool immediate = false}) {
      if (!isToday || currentSlotIndex < 0) return;

      void doScroll() {
        if (scrollController.hasClients) {
          // First jump to approximate position to ensure the item is built
          const estimatedItemHeight = 100.0;
          final targetOffset = (currentSlotIndex * estimatedItemHeight).clamp(
            0.0,
            scrollController.position.maxScrollExtent,
          );
          scrollController.jumpTo(targetOffset);

          // Then in next frame, use ensureVisible with the correct context
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final context = currentSlotContext.value;
            if (context != null) {
              Scrollable.ensureVisible(
                context,
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeInOut,
                alignment: 0.0, // Scroll to top
              );
              lastScrolledSlotIndex.value = currentSlotIndex;
            }
          });
        }
      }

      if (immediate) {
        // For "Dnes" button when already on today - scroll immediately
        WidgetsBinding.instance.addPostFrameCallback((_) => doScroll());
      } else {
        // For day changes - add extra delay to ensure list is rebuilt
        Future.delayed(const Duration(milliseconds: 100), doScroll);
      }
    }

    // Detect app lifecycle changes (when user returns to the app)
    useEffect(() {
      if (!isToday) return null;

      final lifecycleListener = AppLifecycleListener(
        onResume: () {
          // Check if the time slot has changed since last scroll
          final now = DateTimeUtils.nowInPrague;
          final newSlotIndex = now.hour * 2 + (now.minute >= 30 ? 1 : 0);

          if (lastScrolledSlotIndex.value != newSlotIndex) {
            // Time slot has changed, scroll to current slot
            scrollToCurrentSlot();
          }
        },
      );

      return lifecycleListener.dispose;
    }, [
      isToday,
    ]);

    // Scroll to current slot whenever we switch to today's page
    useEffect(() {
      // Only scroll if the day has actually changed or trigger was incremented
      final dayChanged = lastFocusDay.value == null ||
          lastFocusDay.value!.day != focusDay.day ||
          lastFocusDay.value!.month != focusDay.month ||
          lastFocusDay.value!.year != focusDay.year;

      lastFocusDay.value = focusDay;

      if (isToday && dayChanged) {
        scrollToCurrentSlot();
      }
      return null;
    }, [
      focusDay,
      isToday,
      scrollTrigger
          .value, // Include trigger to force scroll even when already on today
    ]);

    // Auto-scroll when next 30-min slot starts (only if already near current position)
    useEffect(() {
      if (!isToday) return null;

      Timer? timer;

      void scheduleNextScroll() {
        final now = DateTimeUtils.nowInPrague;
        final nextSlotTime = DateTime(
          now.year,
          now.month,
          now.day,
          now.hour,
          now.minute >= 30 ? 30 : 0,
        ).add(const Duration(minutes: 30));

        final duration = nextSlotTime.difference(now);

        timer = Timer(duration, () {
          if (scrollController.hasClients) {
            final currentOffset = scrollController.offset;
            final newSlotIndex =
                nextSlotTime.hour * 2 + (nextSlotTime.minute >= 30 ? 1 : 0);

            // Use same calculation as main scroll: estimate based on scroll extent
            final targetIndex = newSlotIndex > 0 ? newSlotIndex + 1 : 0;
            final maxScrollExtent = scrollController.position.maxScrollExtent;
            final estimatedItemHeight = maxScrollExtent / 48;
            final targetOffset = (targetIndex * estimatedItemHeight).clamp(
              0.0,
              maxScrollExtent,
            );

            // Only auto-scroll if we're close to where we should be (within 3 items worth)
            final difference = (currentOffset - targetOffset).abs();
            final threeItemsHeight = estimatedItemHeight * 3;
            if (difference < threeItemsHeight) {
              scrollController.animateTo(
                targetOffset,
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeInOut,
              );
            }
          }

          // Schedule next scroll
          scheduleNextScroll();
        });
      }

      scheduleNextScroll();

      return () => timer?.cancel();
    }, [
      isToday,
    ]);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Společný kalendář modliteb'),
        actions: [
          IconButton(
            onPressed: () => context.push('/profile'),
            icon: const Icon(Icons.person_outline),
            tooltip: 'Profil uživatele',
          ),
          if (appUser?.isAdmin == true)
            IconButton(
              onPressed: () => context.push('/admin'),
              icon: const Icon(Icons.campaign_outlined),
              tooltip: 'Administrace oznámení',
            ),
          IconButton(
            onPressed: () =>
                ref.read(authControllerProvider.notifier).signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: firebaseUser != null && !firebaseUser.emailVerified
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: ListTile(
                  leading: const Icon(Icons.mark_email_unread_outlined),
                  title: const Text('Prosíme, ověřte svůj e-mail'),
                  subtitle: const Text(
                    'Na váš e-mail jsme odeslali ověřovací zprávu. Bez ověření nemusíte dostávat důležitá oznámení.',
                  ),
                  trailing: TextButton(
                    onPressed: () async {
                      await ref
                          .read(authRepositoryProvider)
                          .sendEmailVerification();
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Ověřovací e-mail byl znovu odeslán.'),
                        ),
                      );
                    },
                    child: const Text('Znovu odeslat'),
                  ),
                ),
              ),
            )
          : Column(
              children: [
                _CalendarWeekSelector(weekStart: weekStart, focusDay: focusDay),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        DateFormat('EEEE d. MMMM yyyy', 'cs_CZ').format(focusDay),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Row(
                        children: [
                          IconButton(
                            onPressed: () {
                              final previousWeek = focusDay.subtract(
                                const Duration(days: 7),
                              );
                              ref
                                  .read(calendarFocusDayProvider.notifier)
                                  .setFocusDay(previousWeek);
                            },
                            icon: const Icon(Icons.chevron_left),
                          ),
                          IconButton(
                            onPressed: () {
                              final nextWeek = focusDay.add(const Duration(days: 7));
                              ref
                                  .read(calendarFocusDayProvider.notifier)
                                  .setFocusDay(nextWeek);
                            },
                            icon: const Icon(Icons.chevron_right),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: AsyncValueWidget<List<TimeSlot>>(
                    value: daySlots,
                    builder: (slots) {
                      final timeSlotsById = {
                        for (final slot in slots) slot.id: slot,
                      };
                      final generatedSlots = _generateDaySlots(focusDay);
                      return ListView.builder(
                        key: PageStorageKey<String>(
                            'calendar_list_${focusDay.toIso8601String()}',),
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: generatedSlots.length,
                        itemBuilder: (context, index) {
                          final slotStart = generatedSlots[index];
                          final slotId = TimeSlot.buildId(slotStart);
                          final slot = timeSlotsById[slotId] ??
                              TimeSlot(
                                id: slotId,
                                start: slotStart,
                                end: slotStart.add(const Duration(minutes: 30)),
                                capacity: 10,
                                participants: const [],
                                participantIds: const [],
                                updatedAt: DateTimeUtils.nowInPrague,
                              );
                          final highlight = isToday && index == currentSlotIndex;
                          final isMine =
                              appUser != null && slot.containsUser(appUser.uid);
                          return Builder(
                            builder: (tileContext) {
                              if (highlight) {
                                currentSlotContext.value = tileContext;
                              }
                              return TimeSlotTile(
                                slot: slot,
                                highlighted: highlight,
                                isMine: isMine,
                                onTap: () => _onSlotTapped(context, ref, slot),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
      floatingActionButton: firebaseUser != null && firebaseUser.emailVerified
          ? FloatingActionButton.extended(
              onPressed: () {
                final wasAlreadyToday = isToday;
                ref
                    .read(calendarFocusDayProvider.notifier)
                    .setFocusDay(DateTimeUtils.nowInPrague);

                if (wasAlreadyToday) {
                  // If already on today, scroll immediately
                  scrollToCurrentSlot(immediate: true);
                } else {
                  // If switching from another day, increment trigger to force scroll
                  scrollTrigger.value++;
                }
              },
              icon: const Icon(Icons.today),
              label: const Text('Dnes'),
            )
          : null,
    );
  }

  Future<void> _onSlotTapped(
    BuildContext context,
    WidgetRef ref,
    TimeSlot slot,
  ) async {
    final bookingAction = ref.read(bookingActionProvider);
    final isAssigned = slot.containsUser(bookingAction.user.uid);
    var recurring = false;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(
                isAssigned
                    ? 'Zrušit účast?'
                    : 'Potvrdit účast v ${DateFormat('HH:mm').format(slot.start)}',
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isAssigned
                        ? 'Opravdu chcete opustit tento čas?'
                        : 'Potvrzením se zapíšete mezi účastníky. Kapacita je 10 osob.',
                  ),
                  if (!isAssigned) ...[
                    const SizedBox(height: 16),
                    CheckboxListTile(
                      value: recurring,
                      onChanged: (value) {
                        setState(() => recurring = value ?? false);
                      },
                      title: const Text('Opakovat každý týden'),
                      subtitle: const Text(
                        'Rezervace se vytvoří na dalších 12 týdnů',
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 16),
                    CheckboxListTile(
                      value: recurring,
                      onChanged: (value) {
                        setState(() => recurring = value ?? false);
                      },
                      title: const Text('Zrušit všechny budoucí opakování'),
                      subtitle: const Text(
                        'Zruší se rezervace na dalších 12 týdnů',
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Zrušit'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(isAssigned ? 'Odhlásit se' : 'Potvrdit'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirm != true) {
      return;
    }

    try {
      await bookingAction.toggleSlot(
        slot.start,
        weeklyRecurring: recurring,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isAssigned
                ? recurring
                    ? 'Účast byla zrušena včetně všech budoucích opakování.'
                    : 'Účast byla zrušena.'
                : recurring
                    ? 'Byli jste přidáni do tohoto času i na dalších 12 týdnů.'
                    : 'Byli jste úspěšně přidáni do tohoto času.',
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Akci se nepodařilo dokončit: $error')),
      );
    }
  }

  List<DateTime> _generateDaySlots(DateTime date) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    return List.generate(48, (index) {
      final minutesOffset = index * 30;
      return startOfDay.add(Duration(minutes: minutesOffset));
    });
  }
}

class _CalendarWeekSelector extends ConsumerWidget {
  const _CalendarWeekSelector({
    required this.weekStart,
    required this.focusDay,
  });

  final DateTime weekStart;
  final DateTime focusDay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days =
        List.generate(7, (index) => weekStart.add(Duration(days: index)));
    final dateFormat = DateFormat('E d. M.', 'cs_CZ');

    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ToggleButtons(
          isSelected: days
              .map(
                (day) => day.day == focusDay.day && day.month == focusDay.month,
              )
              .toList(),
          onPressed: (index) {
            ref
                .read(calendarFocusDayProvider.notifier)
                .setFocusDay(days[index]);
          },
          borderRadius: BorderRadius.circular(12),
          children: [
            for (final day in days)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Column(
                  children: [
                    Text(dateFormat.format(day)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
