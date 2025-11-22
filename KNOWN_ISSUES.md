# Known Issues and Workarounds

## MediaPipe Timestamp Mismatch Errors

### Issue
You may see repeated errors in the console:
```
INVALID_ARGUMENT: Graph has errors:
Packet timestamp mismatch on a calculator receiving from stream "last_processed_modality_type". 
Current minimum expected timestamp is 66 but received 65.
```

### Cause
This is a known issue with the `flutter_gemma` library's MediaPipe implementation when processing LLM streams. It occurs due to timestamp ordering in the MediaPipe graph.

### Impact
- **Non-fatal**: The LLM continues to work correctly despite these errors
- **Noisy**: Creates console spam but doesn't affect functionality
- **Intermittent**: Occurs more frequently with longer generations

### Workaround
The app now handles these errors gracefully:
1. TaskExtractor catches `MediaPipe` errors specifically
2. Logs a single warning instead of spamming the console
3. Returns a safe fallback response if needed
4. Processing continues normally

### Future Fix
This will be resolved when `flutter_gemma` updates its MediaPipe integration. For now, these errors can be safely ignored.

## LLM Generation Hanging

### Issue
Sometimes the LLM appears to "hang" with no output generated.

### Causes
1. Model not properly initialized
2. TFLite runtime issues
3. Device resource constraints
4. Model incompatibility

### Solutions
1. **Auto-initialization**: TaskExtractor now automatically loads the last-used model
2. **Timeout**: 60-second timeout prevents infinite waiting
3. **Model selection**: Go to Settings → Active Model to select/reselect model
4. **Restart**: Hot restart the app if issues persist

## JSON Parsing Errors

### Issue
```
FormatException: Unexpected end of input
```

### Cause
LLM sometimes produces incomplete JSON due to:
- Token limits
- Generation cutoff
- Formatting issues

### Solutions
1. **JSON Repair**: Automatic brace-balancing repairs incomplete JSON
2. **Cleanup**: Strips markdown fences and backticks
3. **Validation**: Checks brace count before parsing
4. **Fallback**: Returns safe default if all repair attempts fail

## UI Not Updating After Notification

### Issue
New notifications processed but UI doesn't update.

### Cause
UI wasn't reading from Isar database.

### Solutions
1. **Isar Watchers**: Auto-detect database changes
2. **Reactive Getters**: `filteredFeed`, `filteredTodos`, `events` read directly from Isar
3. **Real-time Updates**: `notifyListeners()` called when data changes

## Channel Name Mismatch

### Issue
Android notifications not reaching Flutter.

### Cause
MethodChannel names didn't match between native and Flutter code.

### Solution
Fixed channel name to `com.personalized_ai.app/notifications` in both:
- MainActivity.kt
- NotificationDispatcher.dart

## LateInitializationError for ModelRepository

### Issue
```
LateInitializationError: Field '_modelRepository' has not been initialized
```

### Cause
UI components tried to access repository before AppState.init() completed.

### Solution
Made repositories nullable with defensive getters that throw clear error messages:
```dart
ModelRepository? _modelRepository;

ModelRepository get modelRepository {
  if (_modelRepository == null) {
    throw StateError('ModelRepository not initialized. Call init() first.');
  }
  return _modelRepository!;
}
```

## Best Practices

### 1. Always Initialize AppState
```dart
await context.read<AppState>().init();
```

### 2. Check Model Status
Use Debug LLM Screen to verify model initialization before processing notifications.

### 3. Monitor Logs
Look for these key success indicators:
```
[AppState] ✅ Initialization complete!
[NotificationDispatcher] ✅ Initialized and listening on channel: ...
[FeedService] ✅ FeedItem saved with ID: ...
[AppState] 🔄 FeedItems changed, notifying listeners...
```

### 4. Grant Permissions
Ensure notification access is granted:
- Settings → Active Model (select model)
- Settings → Notification Access (grant permission)

### 5. Test End-to-End
1. Send test notification
2. Check logs for processing
3. Verify UI updates in Home/Todo/Calendar
4. Confirm data persists after app restart
