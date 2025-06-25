# Location Services Setup Instructions

## Required Info.plist Entries

To enable location services in your iOS app, you need to add the following entries to your app's Info.plist file:

### Method 1: Using Xcode Interface
1. Open your project in Xcode
2. Select the `upwork-project` target
3. Go to the "Info" tab
4. Click the "+" button to add new entries
5. Add these key-value pairs:

**Key:** `NSLocationWhenInUseUsageDescription`
**Type:** String
**Value:** `This app needs location access to help you submit and find abandoned places near you.`

**Key:** `NSLocationAlwaysAndWhenInUseUsageDescription`
**Type:** String  
**Value:** `This app needs location access to help you submit and find abandoned places near you.`

### Method 2: Raw Info.plist XML
If editing the raw plist file, add these entries:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>This app needs location access to help you submit and find abandoned places near you.</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>This app needs location access to help you submit and find abandoned places near you.</string>
```

## Testing Location Services

After adding these entries:

1. Clean and rebuild your project (Cmd+Shift+K, then Cmd+B)
2. Delete the app from your simulator/device to reset permissions
3. Reinstall and run the app
4. When you first use location features, iOS will show a permission dialog
5. Grant location permission when prompted

## Troubleshooting

- Make sure the usage descriptions are added before building
- Test on a real device for best results (simulator location can be unreliable)
- Check iOS Settings > Privacy & Security > Location Services to verify permissions
- In simulator, you can simulate location via Device > Location menu

## Code Changes Made

The LocationManager has been improved to:
- Better handle permission requests
- Provide detailed logging for debugging
- Handle location errors gracefully
- Support one-time location requests

The SubmitLocationView now:
- Shows better feedback when getting location
- Handles location permission states
- Provides fallback coordinates if needed
- Shows error messages for location issues
