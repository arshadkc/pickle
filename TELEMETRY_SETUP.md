# TelemetryDeck Analytics Setup Guide

TelemetryDeck has been integrated into Pickle to provide privacy-focused analytics. Follow these steps to complete the setup:

## 1. Get Your TelemetryDeck App ID

1. Go to [TelemetryDeck Dashboard](https://dashboard.telemetrydeck.com/)
2. Sign up or log in to your account
3. Create a new app or select an existing one
4. Copy your App ID from the dashboard

## 2. Configure the App ID

Open `Sources/Services/AnalyticsService.swift` and replace the placeholder with your actual App ID:

```swift
func initialize() {
    let configuration = TelemetryDeck.Config(appID: "YOUR_TELEMETRY_DECK_APP_ID")
    TelemetryDeck.initialize(config: configuration)
}
```

Replace `"YOUR_TELEMETRY_DECK_APP_ID"` with your actual App ID from step 1.

## 3. Build the Project

After updating the App ID, build the project:

```bash
make build
```

Or open `Pickle.xcodeproj` in Xcode and build normally (Cmd+B).

## Analytics Events Being Tracked

The app tracks the following privacy-focused events:

### App Lifecycle
- `app.launched` - App started
- `app.terminated` - App closed

### Screenshot Events
- `screenshot.detected` - New screenshot detected
- `screenshot.deleted` - Screenshot deleted
- `screenshot.shared` - Screenshot shared (with method: native_share or share_link)
- `screenshot.copied` - Screenshot copied to clipboard
- `screenshot.opened` - Screenshot opened in Quick Look

### Redaction Events
- `redaction.performed` - Redaction completed (includes count of sensitive items found)
- `redaction.enabled` - Redaction feature enabled
- `redaction.disabled` - Redaction feature disabled

### Settings Events
- `settings.opened` - Settings view opened
- `settings.launch_at_login` - Launch at login changed (enabled: true/false)
- `settings.grouping` - Screenshot grouping changed (enabled: true/false)
- `settings.location_changed` - Screenshot location changed (from/to folder names)

### Error Events
- `error.occurred` - Error encountered (includes error description and context)
- `permission.denied` - File system permission denied (includes folder name)

## Privacy

TelemetryDeck is designed with privacy in mind:
- **No personal data is collected** - never screenshots, file names, or paths
- **All data is anonymized** - no way to identify individual users
- **User IDs are hashed client-side** - before any data leaves the device
- **GDPR and privacy-law compliant** - respects European privacy regulations
- **User control** - Users can disable analytics anytime from Settings → Privacy
- **Transparent** - Users see a clear explanation of what's tracked

### What We Track
- Feature usage (which buttons are clicked, which features are used)
- Redaction statistics (how many items detected, not what they are)
- Error events (that something failed, not your data)
- Settings changes (that a setting changed, not personal preferences)

### What We NEVER Track
- ❌ Screenshot content or images
- ❌ File names or paths
- ❌ Personal information
- ❌ User-entered text
- ❌ Redacted content
- ❌ Browsing history or URLs you screenshot
- ❌ Any identifiable information

## User Privacy Control

Users can enable or disable analytics at any time from within the app:

1. Open Pickle from the menu bar
2. Click the Settings icon (⚙️)
3. Scroll to the "Privacy" section
4. Toggle "Help Improve Pickle" on or off

**Default:** Analytics is enabled by default, but users have full control.

When disabled, no analytics events are sent—period. The setting is stored locally and respected immediately.

## Disabling Analytics at Build Time (Optional)

If you want to completely remove analytics from your build, comment out the initialization in `Sources/PickleApp.swift`:

```swift
func applicationDidFinishLaunching(_ notification: Notification) {
    // Initialize analytics
    // AnalyticsService.shared.initialize()  // <-- Comment this out
    // AnalyticsService.shared.trackAppLaunch()  // <-- And this
    
    // ... rest of the code
}
```

## Testing

After setting up, run the app and check your TelemetryDeck dashboard. Events should appear within a few minutes.

## Support

- [TelemetryDeck Documentation](https://telemetrydeck.com/docs/)
- [TelemetryDeck Swift SDK](https://github.com/TelemetryDeck/SwiftSDK)

