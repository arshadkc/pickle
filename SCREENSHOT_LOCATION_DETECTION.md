# Screenshot Location Detection Logic

## Overview
This document explains how the app detects the current macOS screenshot save location and why it handles stale preferences correctly.

## Background

### macOS Preference Domains
macOS stores screenshot location preferences in two domains:

1. **Global Domain** (`kCFPreferencesAnyHost`) - User-wide setting that applies across all Macs logged into the same iCloud account
2. **ByHost Domain** (`kCFPreferencesCurrentHost`) - Machine-specific setting that applies only to the current computer

### macOS Default Behavior
- **Desktop is the default** screenshot location in macOS
- When you set Desktop via Cmd+Shift+5, macOS **does NOT write a preference** (since it's the default)
- When you set a custom location, macOS writes a preference entry
- If preferences are deleted or don't exist, macOS falls back to Desktop

## Detection Logic (Priority Order)

### Step 1: Check Global Domain First
```swift
// Read from global domain (user-wide preference)
let globalValue = CFPreferencesCopyValue(key, domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
```
- Reads `com.apple.screencapture` → `location` from the global domain
- If a value exists, macOS uses this as the active preference
- Expands `~` shorthand to full home directory path

### Step 2: If Global is Empty → Desktop is Active
```swift
if globalValue == nil {
    return desktopURL  // Desktop is the default
}
```
**Critical Logic:** 
- If global domain is empty (`nil`), Desktop is the active location
- **ByHost is ignored** if global is empty (even if it has a value)
- This prevents using stale ByHost data when Desktop is actually active

### Step 3: Use Global Preference (If Valid)
```swift
if let globalPath = globalValue {
    let url = URL(fileURLWithPath: globalPath).standardizedFileURL
    if isExistingDirectory(url) {
        return url  // Use the global preference
    }
}
```
- If global exists and points to a valid directory, use it
- This handles cases like `~/Pictures/Screenshots` or any custom path

### Step 4: Fallback to ByHost
```swift
if let byHostPath = byHostValue {
    let url = URL(fileURLWithPath: byHostPath).standardizedFileURL
    if isExistingDirectory(url) {
        return url  // Use ByHost as fallback
    }
}
```
- Only used if global exists but points to an invalid directory
- Validates directory exists before using it

### Step 5: Final Fallback
```swift
return desktopURL  // Default to Desktop
```
- Returns Desktop if no valid preferences found

## Why This Logic Works

### The Problem
When you set Desktop via Cmd+Shift+5:
- macOS doesn't write a global preference (since Desktop is default)
- ByHost domain might still contain an old value (e.g., `/Users/.../Pictures/Screenshots`)
- Old logic would read stale ByHost data and incorrectly detect Pictures/Screenshots

### The Solution
By checking global domain first:
- If global is empty → Desktop is active (regardless of ByHost)
- If global exists → Use it (it's the user's current choice)
- Only use ByHost as a fallback if global is invalid

This correctly detects Desktop even when ByHost has stale data.

## Example Scenarios

| Scenario | Global Domain | ByHost Domain | Detected Location | Why |
|----------|---------------|---------------|-------------------|-----|
| Desktop (set via Cmd+Shift+5) | Empty | `/Users/.../Pictures/Screenshots` (stale) | ✅ Desktop | Global empty = Desktop active |
| Custom path set | `/Users/.../MyFolder` | (any) | ✅ `/Users/.../MyFolder` | Global preference takes priority |
| No preferences | Empty | Empty | ✅ Desktop | No preferences = default Desktop |
| Invalid global preference | `/Invalid/Path` | `/Users/.../Pictures/Screenshots` | ✅ `/Users/.../Pictures/Screenshots` | Falls back to valid ByHost |

## Code Flow Diagram

```
┌─────────────────────────────────┐
│  Check Global Domain             │
└──────────┬───────────────────────┘
           │
           ├─→ Empty? ──→ ✅ Desktop (ignore ByHost)
           │
           └─→ Exists?
                  │
                  ├─→ Valid Directory? ──→ ✅ Use Global
                  │
                  └─→ Invalid?
                         │
                         └─→ Check ByHost
                                │
                                ├─→ Valid? ──→ ✅ Use ByHost
                                │
                                └─→ Invalid ──→ ✅ Desktop (fallback)
```

## Implementation Details

### Preference Reading
- Uses `CFPreferencesCopyValue` to read from macOS preference system
- Handles both String paths and URL objects
- Expands `~` to full home directory path using `NSString.expandingTildeInPath`

### Path Normalization
- Uses `URL.standardizedFileURL` to normalize paths (removes `..`, `.`, symlinks)
- Validates directory exists using `FileManager.fileExists`

### Debug Logging
The detection logic includes debug prints to help troubleshoot:
- `📍 No global preference, Desktop is active`
- `📍 Using global preference: <path>`
- `📍 Using ByHost preference: <path>`
- `📍 No valid preference found, using Desktop`

## User Interaction: "Not Now" Button

### What Happens When You Click "Not Now"

When a user clicks the "Not Now" button on the screenshot location prompt banner:

1. **Sets Suppression Flag**: `suppressLocationPromptPermanently = true`
   - This is stored in `AppStorage`, so it persists across app restarts
   - Prevents the prompt from showing again permanently

2. **Dismisses the Prompt**: The banner animates out with a smooth transition

3. **Never Shows Again**: The prompt will never appear again, even if:
   - You close and reopen the menu
   - You restart the app
   - You take new screenshots
   - Screenshots are still saved to Desktop

### The Logic Behind It

The suppression flag is checked in `MenuBarView.checkForLocationChanges()`:

```swift
if isDesktop && !suppressLocationPromptPermanently {
    showLocationPrompt = true  // Only show if NOT suppressed
}
```

Since the flag is stored permanently (via `@AppStorage`), once set, it prevents the prompt from appearing again.

### Current Behavior

**Important Note**: The suppression flag does NOT reset automatically if:
- You change the location away from Desktop and then back to Desktop
- You manually set Desktop via Cmd+Shift+5 again
- You change it to another folder and then back

Once "Not Now" is clicked, the banner is permanently suppressed for that user.

## Settings View vs Menu Bar Banner

### Differences in Behavior

There are two places where users can interact with screenshot location settings:

| Location | Shows When | Respects Suppression Flag? |
|----------|-----------|---------------------------|
| **Menu Bar Banner** | Desktop + not suppressed | ✅ Yes — checks `suppressLocationPromptPermanently` |
| **Settings Section** | Desktop only | ❌ No — always shows if Desktop is detected |

### Menu Bar Banner
- Shown at the top of the main menu view
- Checks both conditions:
  1. `locationManager.isCurrentLocationDesktop()` — Desktop detected
  2. `!suppressLocationPromptPermanently` — User hasn't suppressed it
- Hidden permanently if user clicks "Not Now"

### Settings Section
- Shown in the Settings view
- Only checks:
  1. `locationManager.isCurrentLocationDesktop()` — Desktop detected
- **Does NOT check** the suppression flag
- **Always shows** when Desktop is detected, regardless of user's "Not Now" choice

### Code Reference

**MenuBarView.swift** (Line 1317):
```swift
if isDesktop && !suppressLocationPromptPermanently {
    showLocationPrompt = true  // Respects suppression
}
```

**SettingsView.swift** (Line 110):
```swift
if locationManager.isCurrentLocationDesktop() {
    // Shows section - does NOT check suppression flag
}
```

### Why This Design?

The Settings view serves as a **persistent control**:
- Users who dismissed the banner can still access the option in Settings
- Provides a consistent place to change screenshot location
- The banner is meant to be a one-time prompt, while Settings is always available

### Result

If a user clicks "Not Now" in the banner:
- ✅ The banner stops appearing in the menu bar view
- ✅ The Settings section still appears (if Desktop is detected)
- ✅ User can still move screenshots via Settings if they change their mind

## Related Files
- `Sources/Services/ScreenshotLocationManager.swift` - Contains the detection logic
- `Sources/Views/MenuBarView.swift` - Uses detection to show location prompt and handles suppression flag
- `Sources/Views/SettingsView.swift` - Shows location option in settings (doesn't check suppression)
- `Sources/Views/ScreenshotLocationPromptView.swift` - The banner component with "Not Now" button

