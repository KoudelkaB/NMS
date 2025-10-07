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

// Shared layout constants for week grid
const double _kWeekGridTimeColWidth = 72.0;
const double _kWeekGridCellWidth = 160.0;
const double _kWeekGridRowHeight = 56.0;

class CalendarPage extends HookConsumerWidget {
  const CalendarPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final focusDay = ref.watch(calendarFocusDayProvider);
    final weekStart = ref.watch(calendarWeekStartProvider);
    final daySlots = ref.watch(daySlotsProvider);
    final appUser = ref.watch(currentAppUserProvider);
    final firebaseUser = ref.watch(authStateProvider).value;

  final isWeekView = useState(false);
  // Controllers for week grid so FAB can programmatically scroll
  final weekVerticalController = useScrollController();
  final weekHorizontalBodyController = useScrollController();
  final weekHorizontalHeaderController = useScrollController();

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
            onPressed: () => isWeekView.value = !isWeekView.value,
            icon: Icon(isWeekView.value
                ? Icons.view_day_outlined
                : Icons.view_week_outlined),
            tooltip:
                isWeekView.value ? 'Zobrazit denní seznam' : 'Zobrazit týden',
          ),
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
                // Top selector: days for day-view, weeks-of-month for week-view
                if (isWeekView.value)
                  _MonthWeeksSelector(focusDay: focusDay)
                else
                  _CalendarWeekSelector(
                    weekStart: weekStart,
                    focusDay: focusDay,
                  ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (isWeekView.value)
                        Text(
                          DateFormat('LLLL yyyy', 'cs_CZ').format(
                            DateTime(focusDay.year, focusDay.month, 1),
                          ),
                          style: Theme.of(context).textTheme.titleLarge,
                        )
                      else
                        Text(
                          DateFormat('EEEE d. MMMM yyyy', 'cs_CZ')
                              .format(focusDay),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      Row(
                        children: [
                          IconButton(
                            onPressed: () {
                              if (isWeekView.value) {
                                final prevMonth = DateTime(
                                  focusDay.year,
                                  focusDay.month - 1,
                                  1,
                                );
                                ref
                                    .read(calendarFocusDayProvider.notifier)
                                    .setFocusDay(prevMonth);
                              } else {
                                final previousWeek = focusDay.subtract(
                                  const Duration(days: 7),
                                );
                                ref
                                    .read(calendarFocusDayProvider.notifier)
                                    .setFocusDay(previousWeek);
                              }
                            },
                            icon: const Icon(Icons.chevron_left),
                          ),
                          IconButton(
                            onPressed: () {
                              if (isWeekView.value) {
                                final nextMonth = DateTime(
                                  focusDay.year,
                                  focusDay.month + 1,
                                  1,
                                );
                                ref
                                    .read(calendarFocusDayProvider.notifier)
                                    .setFocusDay(nextMonth);
                              } else {
                                final nextWeek =
                                    focusDay.add(const Duration(days: 7));
                                ref
                                    .read(calendarFocusDayProvider.notifier)
                                    .setFocusDay(nextWeek);
                              }
                            },
                            icon: const Icon(Icons.chevron_right),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
        Expanded(
          child: isWeekView.value
            ? _WeekGrid(
              focusDay: focusDay,
              verticalController: weekVerticalController,
              gridHorizontalController: weekHorizontalBodyController,
              headerHorizontalController: weekHorizontalHeaderController,
            )
                      : AsyncValueWidget<List<TimeSlot>>(
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

                                final passedVelocity =
                                    velocity.abs() > velocityThreshold;
                                final passedDistance =
                                    horizontalDragDx.value.abs() >
                                        distanceThreshold;

                                if (passedVelocity || passedDistance) {
                                  if (velocity < 0 ||
                                      horizontalDragDx.value < 0) {
                                    // Swipe left -> next day
                                    final nextDay =
                                        focusDay.add(const Duration(days: 1));
                                    ref
                                        .read(calendarFocusDayProvider.notifier)
                                        .setFocusDay(nextDay);
                                  } else if (velocity > 0 ||
                                      horizontalDragDx.value > 0) {
                                    // Swipe right -> previous day
                                    final prevDay = focusDay
                                        .subtract(const Duration(days: 1));
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
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                cacheExtent: 4000,
                                itemCount: generatedSlots.length,
                                itemBuilder: (context, index) {
                                  final slotStart = generatedSlots[index];
                                  final slotId = TimeSlot.buildId(slotStart);
                                  final slot = timeSlotsById[slotId] ??
                                      TimeSlot(
                                        id: slotId,
                                        start: slotStart,
                                        end: slotStart
                                            .add(const Duration(minutes: 30)),
                                        capacity: 10,
                                        participants: const [],
                                        participantIds: const [],
                                        updatedAt:
                                            DateTimeUtils.nowInPrague,
                                      );
                                  final highlight = isToday &&
                                      index == currentSlotIndex;
                                  final isMine = appUser != null &&
                                      slot.containsUser(appUser.uid);
                                  return Container(
                                    key: itemKeys[index],
                                    child: TimeSlotTile(
                                      slot: slot,
                                      highlighted: highlight,
                                      isMine: isMine,
                                      onTap: () async {
                                        // Preserve current scroll offset to avoid viewport jump after booking
                                        final savedOffset = scrollController.hasClients
                                            ? scrollController.offset
                                            : null;
                                        await _onSlotTapped(context, ref, slot);
                                        if (!context.mounted || savedOffset == null) return;
                                        int attempts = 0;
                                        void reapply() {
                                          if (!scrollController.hasClients) {
                                            if (attempts < 20) {
                                              attempts++;
                                              Future.delayed(const Duration(milliseconds: 60), reapply);
                                            }
                                            return;
                                          }
                                          final pos = scrollController.position;
                                          final target = savedOffset.clamp(0.0, pos.maxScrollExtent);
                                          scrollController.jumpTo(target);
                                          // Stabilize across a couple frames in case list height changed
                                          if (attempts < 3) {
                                            attempts++;
                                            WidgetsBinding.instance.addPostFrameCallback((_) => reapply());
                                          }
                                        }
                                        WidgetsBinding.instance.addPostFrameCallback((_) => reapply());
                                      },
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
                final now = DateTimeUtils.nowInPrague;
                final wasAlreadyToday = isToday;
                // Always set focus to today
                ref
                    .read(calendarFocusDayProvider.notifier)
                    .setFocusDay(now);

                if (isWeekView.value) {
                  // Week view: scroll to current day column and row
                  void doScroll() {
                    if (!weekVerticalController.hasClients ||
                        !weekHorizontalBodyController.hasClients) {
                      // Try shortly later if controllers not attached yet
                      Future.delayed(const Duration(milliseconds: 60), doScroll);
                      return;
                    }
                    final rowIndex = now.hour * 2 + (now.minute >= 30 ? 1 : 0);
                    final colIndex = (now.weekday - 1).clamp(0, 6);

                    final vPos = weekVerticalController.position;
                    final targetV = (rowIndex * _kWeekGridRowHeight)
                        .clamp(0.0, vPos.maxScrollExtent);
                    weekVerticalController.animateTo(
                      targetV,
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeInOut,
                    );

                    final hPos = weekHorizontalBodyController.position;
                    final targetH = (colIndex * _kWeekGridCellWidth)
                        .clamp(0.0, hPos.maxScrollExtent);
                    weekHorizontalBodyController.animateTo(
                      targetH,
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeInOut,
                    );
                    // Refresh visuals immediately
                    timeTick.value++;
                  }
                  // Allow one frame for the week grid to rebuild for today
                  WidgetsBinding.instance.addPostFrameCallback((_) => doScroll());
                } else {
                  // Day view: retain previous behavior
                  if (!wasAlreadyToday) todayScrollTrigger.value++;
                  if (wasAlreadyToday) {
                    scrollToCurrentSlot(animate: true);
                    timeTick.value++;
                  }
                }
              },
              icon: const Icon(Icons.today),
              label: const Text('Nyní'),
            )
          : null,
    );
  }

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

class _WeekGrid extends HookConsumerWidget {
  const _WeekGrid({
    required this.focusDay,
    required this.verticalController,
    required this.gridHorizontalController,
    required this.headerHorizontalController,
  });

  final DateTime focusDay;
  final ScrollController verticalController;
  final ScrollController gridHorizontalController;
  final ScrollController headerHorizontalController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Trigger periodic rebuild so the red time bar moves
  final tick = useState(0);
    useEffect(() {
      final timer = Timer.periodic(const Duration(seconds: 30), (_) {
        tick.value++;
      });
      return timer.cancel;
    }, const []);
    final weekStart = ref.watch(calendarWeekStartProvider);
    final slotsAsync = ref.watch(weekSlotsProvider);
    final appUser = ref.watch(currentAppUserProvider);

  final days = List.generate(7, (i) => weekStart.add(Duration(days: i)));
  final rowCount = 48;
  final now = DateTimeUtils.nowInPrague;
  final isThisWeek =
    now.isAfter(weekStart.subtract(const Duration(days: 1))) &&
      now.isBefore(weekStart.add(const Duration(days: 8)));

    // Sync header horizontal scroll with body horizontal scroll
    useEffect(() {
      void onGridScroll() {
        if (!headerHorizontalController.hasClients ||
            !gridHorizontalController.hasClients) return;
        final pos = gridHorizontalController.position.pixels;
        if ((headerHorizontalController.position.pixels - pos).abs() > 0.5) {
          headerHorizontalController.jumpTo(pos);
        }
      }
      gridHorizontalController.addListener(onGridScroll);
      return () => gridHorizontalController.removeListener(onGridScroll);
    }, [gridHorizontalController, headerHorizontalController]);

    return AsyncValueWidget<List<TimeSlot>>(
      value: slotsAsync,
      builder: (slots) {
        // Map by start to quick lookup
        final byId = {for (final s in slots) s.id: s};

        // Build grid
  const timeColWidth = _kWeekGridTimeColWidth;
  const cellWidth = _kWeekGridCellWidth; // can scroll horizontally
  const rowHeight = _kWeekGridRowHeight;

        // Layout: Column
        //  - Row (pinned header): [time header] + [days header scrollable horizontally]
        //  - Expanded Row: [left time list (shares vertical scroll)] + [day grid (shares vertical scroll and horizontal scroll)]
        return Column(
          children: [
            // Pinned header
            Row(
              children: [
                Container(
                  height: 48,
                  width: timeColWidth,
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest,
                ),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    controller: headerHorizontalController,
                    child: Row(
                      children: [
                        for (final d in days)
                          Builder(builder: (context) {
                            final isCurrentDay = isThisWeek &&
                                d.year == now.year &&
                                d.month == now.month &&
                                d.day == now.day;
                            final bg = isCurrentDay
                                ? Theme.of(context)
                                    .colorScheme
                                    .secondaryContainer
                                : null;
                            final fg = isCurrentDay
                                ? Theme.of(context)
                                    .colorScheme
                                    .onSecondaryContainer
                                : Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.color;
                            return Container(
                              width: cellWidth,
                              height: 48,
                              color: bg,
                              alignment: Alignment.center,
                              child: Text(
                                DateFormat('d. MMMM', 'cs_CZ').format(d),
                                style: Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(color: fg),
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 1),
            // Body
            Expanded(
              child: Scrollbar(
                controller: verticalController,
                child: SingleChildScrollView(
                  controller: verticalController,
                  scrollDirection: Axis.vertical,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left fixed time column
                      SizedBox(
                        width: timeColWidth,
                        child: Column(
                          children: [
                            for (var row = 0; row < rowCount; row++)
                              Builder(builder: (context) {
                                final isCurrentRow = isThisWeek &&
                                    row == (now.hour * 2 +
                                        (now.minute >= 30 ? 1 : 0));
                                final bg = isCurrentRow
                                    ? Theme.of(context)
                                        .colorScheme
                                        .secondaryContainer
                                    : null;
                                final fg = isCurrentRow
                                    ? Theme.of(context)
                                        .colorScheme
                                        .onSecondaryContainer
                                    : Theme.of(context)
                                        .textTheme
                                        .labelLarge
                                        ?.color;
                                final frac = isCurrentRow
                                    ? (((now.minute % 30) * 60 + now.second) /
                                        (30 * 60))
                                    : null;
                                final top = frac != null
                                    ? (frac * rowHeight - 1.0)
                                        .clamp(0.0, rowHeight - 2.0)
                                    : null;
                                return Container(
                                  height: rowHeight,
                                  decoration: BoxDecoration(
                                    color: bg,
                                    border: Border(
                                      bottom: BorderSide(
                                        color:
                                            Theme.of(context).dividerColor,
                                      ),
                                    ),
                                  ),
                                  child: Stack(
                                    children: [
                                      if (top != null)
                                        Positioned(
                                          top: top.floorToDouble(),
                                          left: 0,
                                          right: 0,
                                          child: Container(
                                            height: 2,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .error,
                                          ),
                                        ),
                                      Align(
                                        alignment: Alignment.center,
                                        child: Text(
                                          DateFormat('HH:mm').format(
                                            DateTime(
                                              weekStart.year,
                                              weekStart.month,
                                              weekStart.day,
                                            ).add(
                                                Duration(minutes: row * 30)),
                                          ),
                                          style: () {
                                            // Use the background color for aura (blue-ish for current time row)
                                            final auraColor = bg ?? Theme.of(context).colorScheme.surface;
                                            // Build a 2px-wide aura using a ring of shadows around the text
                                            final List<Shadow>? aura = top != null
                                                ? [
                                                    // center soft fill
                                                    Shadow(color: auraColor, blurRadius: 1, offset: const Offset(0, 0)),
                                                    // ring at 1px
                                                    const Shadow(color: Colors.transparent, blurRadius: 0, offset: Offset(0, 0)),
                                                    Shadow(color: auraColor, blurRadius: 0, offset: const Offset(0, 1)),
                                                    Shadow(color: auraColor, blurRadius: 0, offset: const Offset(1, 0)),
                                                    Shadow(color: auraColor, blurRadius: 0, offset: const Offset(0, -1)),
                                                    Shadow(color: auraColor, blurRadius: 0, offset: const Offset(-1, 0)),
                                                    Shadow(color: auraColor, blurRadius: 0, offset: const Offset(1, 1)),
                                                    Shadow(color: auraColor, blurRadius: 0, offset: const Offset(-1, 1)),
                                                    Shadow(color: auraColor, blurRadius: 0, offset: const Offset(1, -1)),
                                                    Shadow(color: auraColor, blurRadius: 0, offset: const Offset(-1, -1)),
                                                    // ring at 2px for a thicker aura
                                                    Shadow(color: auraColor, blurRadius: 0, offset: const Offset(0, 2)),
                                                    Shadow(color: auraColor, blurRadius: 0, offset: const Offset(2, 0)),
                                                    Shadow(color: auraColor, blurRadius: 0, offset: const Offset(0, -2)),
                                                    Shadow(color: auraColor, blurRadius: 0, offset: const Offset(-2, 0)),
                                                    Shadow(color: auraColor, blurRadius: 0, offset: const Offset(2, 2)),
                                                    Shadow(color: auraColor, blurRadius: 0, offset: const Offset(-2, 2)),
                                                    Shadow(color: auraColor, blurRadius: 0, offset: const Offset(2, -2)),
                                                    Shadow(color: auraColor, blurRadius: 0, offset: const Offset(-2, -2)),
                                                  ]
                                                : null;
                                            return Theme.of(context)
                                                .textTheme
                                                .labelLarge
                                                ?.copyWith(
                                                  color: fg,
                                                  shadows: aura,
                                                );
                                          }(),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                          ],
                        ),
                      ),
                      // Right horizontally scrollable day grid
                      Expanded(
                        child: Scrollbar(
                          controller: gridHorizontalController,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            controller: gridHorizontalController,
                            child: SizedBox(
                              width: cellWidth * days.length,
                              child: Column(
                                children: [
                                  for (var row = 0; row < rowCount; row++)
                                    SizedBox(
                                      height: rowHeight,
                                      child: Row(
                                        children: [
                                          for (var c = 0; c < days.length; c++)
                                            _WeekCell(
                                              start: DateTime(
                                                days[c].year,
                                                days[c].month,
                                                days[c].day,
                                                0,
                                                0,
                                              ).add(
                                                  Duration(minutes: row * 30)),
                                              lookup: byId,
                                              width: cellWidth,
                                              height: rowHeight,
                                              onTap: (slot) async {
                                                // Preserve week grid scroll positions (vertical and horizontal)
                                                final savedV = verticalController.hasClients
                                                    ? verticalController.offset
                                                    : null;
                                                final savedH = gridHorizontalController.hasClients
                                                    ? gridHorizontalController.offset
                                                    : null;
                                                await _onSlotTapped(context, ref, slot);
                                                if (!context.mounted) return;
                                                int attempts = 0;
                                                void reapply() {
                                                  bool pending = false;
                                                  if (savedV != null) {
                                                    if (!verticalController.hasClients) {
                                                      pending = true;
                                                    } else {
                                                      final vPos = verticalController.position;
                                                      final vTarget = savedV.clamp(0.0, vPos.maxScrollExtent);
                                                      verticalController.jumpTo(vTarget);
                                                    }
                                                  }
                                                  if (savedH != null) {
                                                    if (!gridHorizontalController.hasClients) {
                                                      pending = true;
                                                    } else {
                                                      final hPos = gridHorizontalController.position;
                                                      final hTarget = savedH.clamp(0.0, hPos.maxScrollExtent);
                                                      gridHorizontalController.jumpTo(hTarget);
                                                    }
                                                  }
                                                  if (pending && attempts < 20) {
                                                    attempts++;
                                                    Future.delayed(const Duration(milliseconds: 60), reapply);
                                                  } else if (attempts < 3) {
                                                    attempts++;
                                                    WidgetsBinding.instance.addPostFrameCallback((_) => reapply());
                                                  }
                                                }
                                                WidgetsBinding.instance.addPostFrameCallback((_) => reapply());
                                              },
                                              isToday: isThisWeek &&
                                                  days[c].year == now.year &&
                                                  days[c].month == now.month &&
                                                  days[c].day == now.day &&
                                                  (now.hour * 2 +
                                                          (now.minute >= 30
                                                              ? 1
                                                              : 0)) ==
                                                      row,
                                              nowFraction: (isThisWeek &&
                                                      days[c].year ==
                                                          now.year &&
                                                      days[c].month ==
                                                          now.month &&
                                                      days[c].day == now.day &&
                                                      (now.hour * 2 +
                                                              (now.minute >=
                                                                      30
                                                                  ? 1
                                                                  : 0)) ==
                                                          row)
                                                  ? (((now.minute % 30) * 60 +
                                                          now.second) /
                                                      (30 * 60))
                                                  : null,
                                              isMine: (slot) => appUser !=
                                                      null &&
                                                  slot.containsUser(
                                                      appUser.uid),
                                            ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _WeekCell extends StatelessWidget {
  const _WeekCell({
    required this.start,
    required this.lookup,
    required this.width,
    required this.height,
    required this.onTap,
    required this.isToday,
    this.nowFraction,
    required this.isMine,
  });

  final DateTime start;
  final Map<String, TimeSlot> lookup;
  final double width;
  final double height;
  final void Function(TimeSlot slot) onTap;
  final bool isToday;
  // 0..1 within the 30-minute slot, null if not current slot
  final double? nowFraction;
  final bool Function(TimeSlot slot) isMine;

  @override
  Widget build(BuildContext context) {
    final id = TimeSlot.buildId(start);
    final slot = lookup[id] ?? TimeSlot(
      id: id,
      start: start,
      end: start.add(const Duration(minutes: 30)),
      capacity: 10,
      participants: const [],
      participantIds: const [],
      updatedAt: DateTimeUtils.nowInPrague,
    );

    final names = slot.participants.map((p) => p.fullName).toList();
    final display = names.take(3).join(', ');
    final extra = names.length > 3 ? ' +${names.length - 3}' : '';

    final mine = isMine(slot);

    return InkWell(
      onTap: slot.isPast ? null : () => onTap(slot),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(
              color: Theme.of(context).dividerColor,
            ),
            bottom: BorderSide(
              color: Theme.of(context).dividerColor,
            ),
          ),
          color: isToday
              ? Theme.of(context).colorScheme.secondaryContainer
              : null,
        ),
        padding: const EdgeInsets.all(8),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (mine)
                    Container(
                      width: 6,
                      height: 20,
                      margin: const EdgeInsets.only(right: 6, top: 2),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  Expanded(
                    child: Text(
                      names.isEmpty ? '' : '$display$extra',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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

class _MonthWeeksSelector extends ConsumerWidget {
  const _MonthWeeksSelector({
    required this.focusDay,
  });

  final DateTime focusDay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monthStart = DateTime(focusDay.year, focusDay.month, 1);
    final monthEnd = DateTime(focusDay.year, focusDay.month + 1, 1)
        .subtract(const Duration(days: 1));

    // Find Monday on/before monthStart
    final firstWeekStart = monthStart.subtract(
      Duration(days: (monthStart.weekday - 1)),
    );

    // Collect week starts intersecting the month
    final List<DateTime> weekStarts = [];
    var w = firstWeekStart;
    while (!w.isAfter(monthEnd)) {
      weekStarts.add(w);
      w = w.add(const Duration(days: 7));
    }

    bool isFocusInWeek(DateTime weekStart) {
      final weekEnd = weekStart.add(const Duration(days: 6));
      return !focusDay.isBefore(weekStart) && !focusDay.isAfter(weekEnd);
    }

    String labelFor(DateTime weekStart) {
      final weekEnd = weekStart.add(const Duration(days: 6));
      final startInMonth = weekStart.isBefore(monthStart) ? monthStart : weekStart;
      final endInMonth = weekEnd.isAfter(monthEnd) ? monthEnd : weekEnd;
      return '${startInMonth.day}.–${endInMonth.day}.';
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ToggleButtons(
          isSelected: weekStarts.map(isFocusInWeek).toList(),
          onPressed: (index) {
            final weekStart = weekStarts[index];
            ref
                .read(calendarFocusDayProvider.notifier)
                .setFocusDay(weekStart);
          },
          borderRadius: BorderRadius.circular(12),
          children: [
            for (final ws in weekStarts)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Column(
                  children: [
                    Text(labelFor(ws)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
