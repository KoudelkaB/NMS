import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
    // Triggers a scroll-to-current when Today button is used while switching to today
    final todayScrollTrigger = useState(0);
  // Remember last viewed top-visible slot index to keep when changing days (align by top)
  final activeSlotIndex = useRef<int>(0);
    // Track last focus day to detect changes
    final lastFocusDay = useRef<DateTime?>(null);
    // Detect first page open to auto-focus current slot once
    final firstOpen = useRef<bool>(true);
  // Inactivity tracking
    final inactivityTick = useState(0);
    final lastUserActivity = useRef<DateTime>(DateTimeUtils.nowInPrague);
  // Force rebuild on time changes (e.g., 30-minute boundaries)
  final timeTick = useState(0);
  // Track horizontal drag delta for day swipe navigation
  final horizontalDragDx = useRef<double>(0);

  final selectedDate = focusDay;
    final now = DateTimeUtils.nowInPrague;
    final isToday = selectedDate.year == now.year &&
        selectedDate.month == now.month &&
        selectedDate.day == now.day;
    final currentSlotIndex =
        isToday ? now.hour * 2 + (now.minute >= 30 ? 1 : 0) : -1;

    // Keep stable keys for each slot to compute precise offsets with variable heights
    final itemKeys = useMemoized(() => List.generate(48, (_) => GlobalKey()), const []);

    double? _topOffsetForIndex(int index) {
      if (index < 0 || index > 47) return null;
      final ctx = itemKeys[index].currentContext;
      if (ctx == null) return null;
      final renderObject = ctx.findRenderObject();
      if (renderObject == null) return null;
      final viewport = RenderAbstractViewport.of(renderObject);
      final reveal = viewport.getOffsetToReveal(renderObject, 0.0);
      return reveal.offset;
    }

    // Scroll to an arbitrary slot index
    void scrollToIndex(
      int index, {
      bool animate = false,
      int pastAbove = 0,
    }) {
      int attempts = 0;
      void doScroll() {
        if (!scrollController.hasClients) {
          if (attempts < 30) {
            attempts++;
            Future.delayed(const Duration(milliseconds: 60), doScroll);
          }
          return;
        }
        final position = scrollController.position;
        final totalExtent = position.maxScrollExtent + position.viewportDimension;
        // Phase 1: approximate jump to build target child
        final targetIndex = (index - pastAbove).clamp(0, 47);
        final avgItemExtent = totalExtent / 48.0;
        final approxOffset = (targetIndex * avgItemExtent).clamp(0.0, position.maxScrollExtent);
        scrollController.jumpTo(approxOffset);

        // Phase 2: precise adjust once child is laid out
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final precise = _topOffsetForIndex(targetIndex);
          if (precise == null) {
            if (attempts < 30) {
              attempts++;
              Future.delayed(const Duration(milliseconds: 60), doScroll);
            }
            return;
          }
          final clamped = precise.clamp(0.0, position.maxScrollExtent);
          if (animate) {
            scrollController.animateTo(
              clamped,
              duration: const Duration(milliseconds: 450),
              curve: Curves.easeInOut,
            );
          } else {
            scrollController.jumpTo(clamped);
          }

          // Stabilize: re-apply precise alignment for a couple more frames to account for late layout/data
          int stabilizations = 0;
          void stabilize() {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final p = _topOffsetForIndex(targetIndex);
              if (p != null) {
                final c = p.clamp(0.0, position.maxScrollExtent);
                scrollController.jumpTo(c);
              }
              if (++stabilizations < 2) {
                stabilize();
              }
            });
          }
          stabilize();
        });
      }

      // Delay slightly to let the list attach and layout
      Future.delayed(const Duration(milliseconds: 80), doScroll);
    }

    // Function to scroll to current slot. Aim to place it second from the top (one slot above) when possible.
    void scrollToCurrentSlot({bool animate = true}) {
      if (!isToday || currentSlotIndex < 0) return;
      scrollToIndex(
        currentSlotIndex,
        animate: animate,
        pastAbove: 1,
      );
      lastScrolledSlotIndex.value = currentSlotIndex;
      activeSlotIndex.value = currentSlotIndex;
    }

    // Removed center-preserving helper; we align by top using scrollToIndex

    // Track user activity and remember top-visible slot (robust for variable heights)
    useEffect(() {
      void onScroll() {
        lastUserActivity.value = DateTimeUtils.nowInPrague;
        if (!scrollController.hasClients) return;
        final pos = scrollController.position;
        final currentOffset = pos.pixels;
        int bestIndex = 0;
        double bestOffset = -double.infinity;
        for (var i = 0; i < 48; i++) {
          final off = _topOffsetForIndex(i);
          if (off == null) continue;
          if (off <= currentOffset + 1 && off > bestOffset) {
            bestOffset = off;
            bestIndex = i;
          }
        }
        activeSlotIndex.value = bestIndex;
      }

      scrollController.addListener(onScroll);
      return () => scrollController.removeListener(onScroll);
    }, [scrollController]);

    // Detect app lifecycle changes (when user returns to the app)
    useEffect(
      () {
        if (!isToday) return null;

        final lifecycleListener = AppLifecycleListener(
          onResume: () {
            // Check if the time slot has changed since last scroll
            final now = DateTimeUtils.nowInPrague;
            final newSlotIndex = now.hour * 2 + (now.minute >= 30 ? 1 : 0);

            if (lastScrolledSlotIndex.value != newSlotIndex) {
              // Time slot has changed, scroll to current slot
              scrollToCurrentSlot();
              // Force rebuild so highlights/isPast update immediately
              timeTick.value++;
            }
          },
        );

        return lifecycleListener.dispose;
      },
      [
        isToday,
      ],
    );

    // Handle day switching: keep same slot index across days except special today cases
    useEffect(
      () {
        // Only scroll if the day has actually changed
        final dayChanged = lastFocusDay.value == null ||
            lastFocusDay.value!.day != focusDay.day ||
            lastFocusDay.value!.month != focusDay.month ||
            lastFocusDay.value!.year != focusDay.year;

        lastFocusDay.value = focusDay;

        if (dayChanged) {
          if (isToday) {
            // Scroll to current only on first open or when explicitly requested via Today button
            final shouldScrollToCurrent =
                firstOpen.value || todayScrollTrigger.value > 0;
            if (shouldScrollToCurrent) {
              scrollToCurrentSlot();
              // Reset trigger after using it
              if (todayScrollTrigger.value > 0) todayScrollTrigger.value = 0;
              firstOpen.value = false;
            } else {
              // Keep the same top-visible slot (no animation), align its top to viewport top
              scrollToIndex(activeSlotIndex.value, animate: false, pastAbove: 0);
            }
          } else {
            // Non-today days: keep the same top-visible slot (no animation)
            scrollToIndex(activeSlotIndex.value, animate: false, pastAbove: 0);
            firstOpen.value = false;
          }
        } else if (firstOpen.value && isToday) {
          // First build with today selected: ensure we scroll
          scrollToCurrentSlot();
          firstOpen.value = false;
        }
        return null;
      },
      [
        focusDay,
        isToday,
        todayScrollTrigger.value,
      ],
    );

    // Inactivity watcher: after >1 minute of no user activity, always jump to today and scroll current slot
    useEffect(
      () {
        Timer? timer;

        void schedule() {
          timer?.cancel();
          timer = Timer(
            const Duration(minutes: 1),
            () {
              final last = lastUserActivity.value;
              final now = DateTimeUtils.nowInPrague;
              if (now.difference(last) >= const Duration(minutes: 1)) {
                if (isToday) {
                  // Already viewing today: just refocus to current slot
                  scrollToCurrentSlot();
                  timeTick.value++;
                } else {
                  // Not viewing today: behave like pressing "Dnes"
                  todayScrollTrigger.value++;
                  ref
                      .read(calendarFocusDayProvider.notifier)
                      .setFocusDay(DateTimeUtils.nowInPrague);
                }
              }
              schedule();
            },
          );
        }

        schedule();
        return () => timer?.cancel();
      },
      [isToday, inactivityTick.value],
    );

    // Auto-scroll when next 30-min slot starts
    // If not viewing today (e.g., after midnight rollover), behave like pressing "Dnes"
    useEffect(
      () {
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

          timer = Timer(
            duration,
            () {
              final currentNow = DateTimeUtils.nowInPrague;
              final viewingToday =
                  focusDay.year == currentNow.year &&
                  focusDay.month == currentNow.month &&
                  focusDay.day == currentNow.day;

              if (viewingToday) {
                // Refocus to the new current slot when it changes
                scrollToCurrentSlot();
                // Force rebuild so highlights and isPast update immediately
                timeTick.value++;
              } else {
                // Not viewing today: switch to today like pressing "Dnes"
                todayScrollTrigger.value++;
                ref
                    .read(calendarFocusDayProvider.notifier)
                    .setFocusDay(currentNow);
              }

              // Schedule next scroll
              scheduleNextScroll();
            },
          );
        }

        scheduleNextScroll();

        return () => timer?.cancel();
      },
      [
        focusDay,
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kalendář modliteb'),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        DateFormat('EEEE d. MMMM yyyy', 'cs_CZ')
                            .format(focusDay),
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
                              final nextWeek =
                                  focusDay.add(const Duration(days: 7));
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
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onHorizontalDragStart: (_) {
                          horizontalDragDx.value = 0;
                        },
                        onHorizontalDragUpdate: (details) {
                          horizontalDragDx.value += details.delta.dx;
                        },
                        onHorizontalDragEnd: (details) {
                          final velocity = details.primaryVelocity ?? 0;
                          const velocityThreshold = 250; // px/s
                          const distanceThreshold = 60; // px

                          final passedVelocity = velocity.abs() > velocityThreshold;
                          final passedDistance =
                              horizontalDragDx.value.abs() > distanceThreshold;

                          if (passedVelocity || passedDistance) {
                            if (velocity < 0 || horizontalDragDx.value < 0) {
                              // Swipe left -> next day
                              final nextDay = focusDay.add(const Duration(days: 1));
                              ref
                                  .read(calendarFocusDayProvider.notifier)
                                  .setFocusDay(nextDay);
                            } else if (velocity > 0 || horizontalDragDx.value > 0) {
                              // Swipe right -> previous day
                              final prevDay =
                                  focusDay.subtract(const Duration(days: 1));
                              ref
                                  .read(calendarFocusDayProvider.notifier)
                                  .setFocusDay(prevDay);
                            }
                          }
                        },
                        child: ListView.builder(
                          key: PageStorageKey<String>(
                            'calendar_list_${focusDay.toIso8601String()}',
                          ),
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          cacheExtent: 4000,
                          itemCount: generatedSlots.length,
                          itemBuilder: (context, index) {
                            final slotStart = generatedSlots[index];
                            final slotId = TimeSlot.buildId(slotStart);
                            final slot = timeSlotsById[slotId] ??
                                TimeSlot(
                                  id: slotId,
                                  start: slotStart,
                                  end:
                                      slotStart.add(const Duration(minutes: 30)),
                                  capacity: 10,
                                  participants: const [],
                                  participantIds: const [],
                                  updatedAt: DateTimeUtils.nowInPrague,
                                );
                            final highlight =
                                isToday && index == currentSlotIndex;
                            final isMine = appUser != null &&
                                slot.containsUser(appUser.uid);
                            return Container(
                              key: itemKeys[index],
                              child: TimeSlotTile(
                                slot: slot,
                                highlighted: highlight,
                                isMine: isMine,
                                onTap: () => _onSlotTapped(context, ref, slot),
                              ),
                            );
                          },
                        ),
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
                // Mark explicit request to focus current when switching to today
                if (!wasAlreadyToday) todayScrollTrigger.value++;
                ref
                    .read(calendarFocusDayProvider.notifier)
                    .setFocusDay(DateTimeUtils.nowInPrague);

                if (wasAlreadyToday) {
                  // If already on today, keep animation for autofocus
                  scrollToCurrentSlot(animate: true);
                  // Force immediate rebuild so highlight updates even without provider change
                  timeTick.value++;
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
