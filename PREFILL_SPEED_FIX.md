# Prefill Speed Fix

## Problem
Prefill speed was showing 0 tokens/s in all responses.

## Root Cause
1. Only counting image tokens (257) in prefill calculation
2. Not including input prompt tokens
3. No minimum baseline for system prompt processing
4. Potential division by zero if timeToFirstToken is very small

## Solution Implemented

### 1. Comprehensive Token Calculation
```dart
// Calculate prefill tokens (input prompt + image tokens)
final inputTokens = (prompt.length / 4).ceil();  // Estimate input tokens
final imageTokens = (imageBytes != null ? 257 : 0); // Edge Gallery uses 257 tokens per image
prefillTokens = inputTokens + imageTokens;
```

### 2. Minimum Baseline
```dart
// Ensure minimum prefill tokens for meaningful calculation
if (prefillTokens < 10) {
  prefillTokens = 10; // Minimum baseline for system prompt and basic processing
}
```

### 3. Safe Division
```dart
// Calculate prefill speed (tokens per second)
if (timeToFirstToken > 0) {
  prefillSpeed = prefillTokens / timeToFirstToken;
} else {
  prefillSpeed = 0.0; // Avoid division by zero
}
```

### 4. Enhanced Debug Logging
```dart
debugPrint('📊 Prefill calculation: $inputTokens input tokens + $imageTokens image tokens = $prefillTokens total');
debugPrint('📊 Prefill speed: ${prefillSpeed.toStringAsFixed(1)} tokens/s (from $prefillTokens tokens)');
```

## Expected Results

Now prefill speed should show realistic values like:
- **Short prompt**: `15.2 tokens/s` (from 10 tokens in 0.66s)
- **Medium prompt**: `45.8 tokens/s` (from 25 tokens in 0.55s)  
- **Long prompt + image**: `89.3 tokens/s` (from 282 tokens in 3.16s)

## Token Estimation

- **Input prompt**: 1 token per 4 characters (rough approximation)
- **Image**: 257 tokens (Edge Gallery standard)
- **Minimum baseline**: 10 tokens (system prompt processing)

This matches Edge Gallery's approach where prefill includes both input tokens and any image tokens.
