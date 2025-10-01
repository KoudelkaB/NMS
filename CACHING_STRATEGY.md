# Caching Strategy

This document describes the comprehensive caching implementation in the NMS application to minimize Firebase Firestore reads and optimize performance.

## Overview

The application uses Riverpod's caching capabilities with `keepAlive`, `autoDispose`, and cache invalidation to ensure:
- Data is cached and reused across the app
- Unnecessary database reads are minimized
- Caches are automatically cleaned up when not needed
- Data is refreshed only when it actually changes

## Key Components

### 1. Auth Providers (`lib/features/auth/application/auth_providers.dart`)

#### `authStateProvider`
- **Type**: `StreamProvider.autoDispose<User?>`
- **Caching**: KeepAlive with 30-minute timeout
- **Purpose**: Caches Firebase Auth state changes
- **Behavior**: Stays in memory for 30 minutes after last use, preventing unnecessary auth checks

#### `appUserProvider`
- **Type**: `StreamProvider.autoDispose<AppUser?>`
- **Caching**: KeepAlive with 30-minute timeout
- **Invalidation**: Watches `appUserInvalidatorProvider`
- **Purpose**: Caches user profile data from Firestore
- **Behavior**: Automatically refreshes when profile is updated via `AuthRepository`

#### `appUserInvalidatorProvider`
- **Type**: `NotifierProvider<int>`
- **Purpose**: Triggers cache invalidation for user data
- **Usage**: Called by `AuthRepository` when user profile is updated

### 2. Calendar Providers (`lib/features/calendar/application/calendar_providers.dart`)

#### `daySlotsProvider`
- **Type**: `StreamProvider.autoDispose<List<TimeSlot>>`
- **Caching**: KeepAlive with 5-minute timeout
- **Invalidation**: Watches `timeSlotsInvalidatorProvider`
- **Purpose**: Caches time slots for the focused day
- **Behavior**: Automatically refreshes when slots are modified via `BookingAction`

#### `userAssignmentsProvider`
- **Type**: `StreamProvider.autoDispose.family<List<TimeSlot>, String>`
- **Caching**: KeepAlive with 10-minute timeout
- **Invalidation**: Watches `timeSlotsInvalidatorProvider`
- **Purpose**: Caches user's reserved time slots
- **Key Feature**: Uses `.family` to avoid rebuilding when user changes
- **Fix**: Resolves infinite reload issue in profile page

#### `timeSlotsInvalidatorProvider`
- **Type**: `NotifierProvider<int>`
- **Purpose**: Triggers cache invalidation for time slot data
- **Usage**: Called by `BookingAction` when slots are toggled

### 3. Repository Integration

#### `AuthRepository`
```dart
AuthRepository(
  FirebaseAuth auth,
  FirebaseFirestore firestore, {
  VoidCallback? onUserUpdated,
})
```
- Accepts `onUserUpdated` callback
- Calls callback after `updateProfile()` and `syncEmailVerification()`
- Triggers cache invalidation in auth providers

#### `BookingAction`
```dart
BookingAction({
  required CalendarRepository repository,
  required AppUser user,
  VoidCallback? onSlotChanged,
})
```
- Accepts `onSlotChanged` callback
- Calls callback after `toggleSlot()`
- Triggers cache invalidation in calendar providers

## Cache Lifecycle

### KeepAlive Pattern
All providers use the following pattern:
```dart
final link = ref.keepAlive();
Timer? timer;
ref.onDispose(() => timer?.cancel());
ref.onCancel(() {
  timer = Timer(const Duration(minutes: X), link.close);
});
ref.onResume(() {
  timer?.cancel();
});
```

This ensures:
1. Data stays cached even when no widgets are watching
2. Automatic cleanup after inactivity timeout
3. Timer is cancelled if the provider is resumed before timeout

### Cache Timeouts
- **Auth data**: 30 minutes (changes infrequently)
- **User assignments**: 10 minutes (viewed less frequently)
- **Day slots**: 5 minutes (viewed more frequently, smaller queries)

## Cache Invalidation

### When User Profile Updates
1. User saves profile in `ProfilePage`
2. `AuthRepository.updateProfile()` is called
3. Repository calls `onUserUpdated()` callback
4. `appUserInvalidatorProvider.invalidate()` is called
5. `appUserProvider` watches invalidator and refreshes
6. UI updates with new data

### When Time Slots Change
1. User toggles slot in `CalendarPage`
2. `BookingAction.toggleSlot()` is called
3. Action calls `onSlotChanged()` callback
4. `timeSlotsInvalidatorProvider.invalidate()` is called
5. Both `daySlotsProvider` and `userAssignmentsProvider` refresh
6. UI updates across all pages using time slots

## Benefits

### Performance
- **Reduced Firestore reads**: Data is cached and reused across the app
- **Faster UI**: No unnecessary fetches when navigating between pages
- **Optimized queries**: Caching prevents duplicate queries for same data

### Cost Optimization
- **Lower Firebase costs**: Significant reduction in document reads
- **Smart invalidation**: Refreshes only when data actually changes
- **Automatic cleanup**: Old caches are disposed after timeout

### User Experience
- **No infinite reloads**: Fixed by using `.family` provider for user assignments
- **Instant navigation**: Cached data loads immediately
- **Consistent state**: Same data shown across different parts of the app

## Usage Examples

### Watching User Assignments
```dart
// OLD: Caused infinite reload
final assignments = ref.watch(userAssignmentsProvider);

// NEW: Stable, cached, no reload loop
final assignments = ref.watch(userAssignmentsProvider(user.uid));
```

### Updating Profile
```dart
// Cache is automatically invalidated
await authRepository.updateProfile(updatedUser);
// UI refreshes with new data
```

### Toggling Time Slot
```dart
// Cache is automatically invalidated
await bookingAction.toggleSlot(slotStart);
// All calendar views refresh with new data
```

## Testing Cache Behavior

To verify caching is working:
1. Open Firestore console and enable query monitoring
2. Navigate to profile page → should see 1 query for user assignments
3. Navigate away and back → should see 0 new queries (cached)
4. Wait for cache timeout → should see new query on next view
5. Update profile → should see 1 query to refresh user data
6. Toggle time slot → should see 1 query to refresh slot data

## Future Improvements

Potential enhancements:
- Add offline persistence with local database
- Implement optimistic updates for better UX
- Add background sync for time slot changes
- Cache time slots for entire week, not just day
- Add manual refresh mechanism for users

## Firestore Index Optimization

### Avoiding Composite Indexes

**Important**: In Firestore, using `array-contains` with ANY other filter (`where` or `orderBy`) requires a composite index.

The `watchUserAssignments` query avoids this by using only `array-contains` and performing all filtering and sorting in memory:

```dart
// ❌ REQUIRES COMPOSITE INDEX
query
  .where('participantIds', arrayContains: uid)
  .orderBy('start')  // <-- This requires an index!

// ❌ ALSO REQUIRES COMPOSITE INDEX
query
  .where('participantIds', arrayContains: uid)
  .where('start', isGreaterThanOrEqualTo: from)  // <-- This too!

// ✅ NO INDEX REQUIRED - Query only, then filter + sort in memory
query
  .where('participantIds', arrayContains: uid)
  .snapshots()
  .map((snapshot) {
    var slots = snapshot.docs.map(TimeSlot.fromDoc).toList();
    
    // Filter by date in memory
    if (from != null) {
      slots = slots.where((slot) => slot.start.isAfter(from)).toList();
    }
    
    // Sort by start time in memory
    slots.sort((a, b) => a.start.compareTo(b.start));
    
    return slots;
  })
```

**Why this works well:**
- ✅ No Firestore composite index needed
- ✅ Users typically have few assignments (10-50 documents max)
- ✅ Memory filtering and sorting is instant for small datasets
- ✅ Reduces Firestore index maintenance complexity
- ✅ Works immediately without waiting for index creation

## Common Issues and Solutions

### Issue: Infinite Reload in UI
**Symptom**: Section continuously reloads, showing loading spinner
**Cause**: Provider dependency chain causing rebuild loops
**Solution**: Use `.family` provider with stable parameter (UID) instead of watching entire user object

### Issue: Form Fields Not Populating
**Symptom**: TextFormFields show empty despite data being available
**Cause**: `useTextEditingController(text: value)` only sets initial value, doesn't update on data changes
**Solution**: Use `useEffect` to update controller text when data changes:
```dart
final controller = useTextEditingController();
useEffect(() {
  controller.text = user.firstName;
  return null;
}, [user]);
```

### Issue: Firestore Index Required Error
**Symptom**: Query fails with "requires an index" error
**Cause**: Complex query with array-contains + where + orderBy
**Solution**: Simplify query and filter in memory where possible

