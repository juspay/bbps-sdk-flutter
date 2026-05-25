# BBPS Flutter SDK

A Flutter plugin for integrating BBPS (Bharat BillPay System) bill payment capabilities into your Flutter applications. This plugin provides a unified Dart API that wraps the native BBPS SDKs for both Android and iOS platforms.

## Features

- Create and manage BBPS service instances
- Initiate BBPS sessions with merchant configuration
- Process various BBPS actions (payments, biller list, transaction history, etc.)
- Handle back navigation and session termination
- Real-time event streaming for payment callbacks
- Support for both Android and iOS platforms

## Requirements

- Flutter SDK: >=3.3.0
- Dart SDK: >=3.11.5
- Android: minSdkVersion 24 (Android 7.0)
- iOS: iOS 13.0 or higher

## Installation

### 1. Add Dependency

Add the following to your `pubspec.yaml`:

```yaml
dependencies:
  bbps_sdk_flutter: ^x.y.z  # Replace with latest version
```

Then run:

```bash
flutter pub get
```

### 2. Platform-Specific Setup

#### Android Setup

The BBPS Flutter SDK requires the `bbps.plugin` Gradle plugin to be applied in your app's `build.gradle`. This plugin downloads merchant-specific assets during the build process.

##### Step 1: Configure `settings.gradle.kts`

Add the Juspay Maven repository to your `android/settings.gradle.kts`:

```kotlin
dependencyResolutionManagement {
    repositories {
        google()
        mavenCentral()
        
        // Required for BBPS SDK dependencies
        maven("https://airborne.juspay.in/builds/hyper-sdk/") {
            content {
                includeGroup("in.juspay")
            }
        }
        
        maven("https://maven.juspay.in/jp-build-packages/hyper-sdk") {
            content {
                includeGroup("in.juspay")
            }
        }
    }
}
```

Also add the repository to `pluginManagement`:

```kotlin
pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
        maven("https://maven.juspay.in/hyper-sdk")
    }
}
```

##### Step 2: Configure `build.gradle` (App Level)

Update your `android/app/build.gradle`:

```gradle
buildscript {
    repositories {
        google()
        mavenCentral()
        maven { url "https://maven.juspay.in/hyper-sdk" }
    }
    dependencies {
        classpath "in.juspay:bbps.plugin:0.0.2"
    }
}

plugins {
    id "com.android.application"
    id "kotlin-android"
    id "dev.flutter.flutter-gradle-plugin"
}

apply plugin: "bbps.plugin"

repositories {
    google()
    mavenCentral()
    maven { url "https://airborne.juspay.in/builds/hyper-sdk/" }
    maven { url "https://maven.juspay.in/jp-build-packages/hyper-sdk" }
}

android {
    // Your existing Android configuration...
    
    compileOptions {
        sourceCompatibility JavaVersion.VERSION_17
        targetCompatibility JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }
}

// Configure BBPS plugin with your merchant details
bbps {
    clientId = "YOUR_CLIENT_ID"  // Replace with your client ID
    sdkVersion = "0.1.10"          // BBPS SDK version
}

flutter {
    source = "../.."
}
```

**Important Notes:**
- Replace `YOUR_CLIENT_ID` with your actual BBPS merchant client ID
- The `bbps {}` block configures build-time asset downloading specific to your merchant
- Ensure `sourceCompatibility` and `targetCompatibility` are set to `JavaVersion.VERSION_17`
- The `bbps.plugin` must be applied after the Flutter Gradle plugin

#### iOS Setup

##### Step 1: Configure Podfile (if needed)

If BBPSSDK is available via CocoaPods trunk, no manual Podfile changes are needed as the plugin handles it automatically. However, if using a specific branch or Git URL, add to your `ios/Podfile`:

```ruby
target 'Runner' do
  use_frameworks!
  
  # Optional: Only if BBPSSDK is not yet on CocoaPods trunk
  # pod 'BBPSSDK', :git => 'https://github.com/juspay/bbps-ios.git', :branch => 'bbps-ios_integration_changes'
  
  flutter_install_all_ios_pods File.dirname(File.realpath(__FILE__))
end
```

##### Step 2: Create BBPSConfig.json

Create a `BBPSConfig.json` file in your `ios/` directory (same level as `Podfile`):

```json
{
  "clientConfigs": {
    "YOUR_CLIENT_ID": {}
  }
}
```

Replace `YOUR_CLIENT_ID` with your actual BBPS merchant client ID. This configuration tells the BBPS asset downloader which merchant's assets to fetch during the build process.

**Example:**
```json
{
  "clientConfigs": {
    "fibe": {}
  }
}
```

##### Step 3: Build Script Setup (Optional)

The BBPS iOS SDK uses a pre-build script to download assets. Ensure your Xcode build phases include running the `Fuse.rb` script. This is typically handled automatically by the BBPSSDK pod, but verify in your Xcode project that a "Run Script" build phase exists for asset downloading.

## Usage

### Import the Package

```dart
import 'package:bbps_sdk_flutter/bbps_sdk_flutter.dart';
```

### Initialize BBPS Service

Before using any BBPS functionality, you must create the service:

```dart
Future<void> initializeBbps() async {
  try {
    final success = await BbpsFlutter.createService(
      params: {'clientId': 'YOUR_CLIENT_ID'},
    );
    if (success) {
      print('BBPS Service created successfully');
    }
  } catch (e) {
    print('Error creating BBPS service: $e');
  }
}
```

### Initiate BBPS Session

Start a BBPS session with merchant credentials:

```dart
Future<void> startBbpsSession() async {
  try {
    await BbpsFlutter.initiate(
      params: {
        'action': 'initiate',
        'agentId': 'YOUR_AGENT_ID',          // Your BBPS agent ID
        'mobile': 'USER_MOBILE_NUMBER',       // Customer mobile number
        'deviceId': 'UNIQUE_DEVICE_ID',       // Unique device identifier
        'clientId': 'YOUR_CLIENT_ID',         // Your BBPS client ID
        'authToken': 'YOUR_AUTH_TOKEN',       // Optional: Authentication token
        'issuingCou': 'yes_biz'
      },
    );
    print('BBPS Session initiated successfully');
  } catch (e) {
    print('Error initiating BBPS: $e');
  }
}
```

**Parameters (passed via `params` map):**
- `action` (required): Action type, typically `'initiate'`
- `agentId` (required): Your BBPS agent identifier
- `mobile` (required): Customer's mobile number
- `deviceId` (required): Unique device identifier for the session
- `clientId` (required): Your BBPS merchant client ID
- `authToken` (optional): JWT or OAuth token for authenticated sessions

### Process Actions

Execute BBPS actions after successful initialization:

```dart
Future<void> processPayment() async {
  try {
    final result = await BbpsFlutter.process(
      params: {
        'action': 'BBPS_PAYMENT',
        'agentId': 'YOUR_AGENT_ID',
        'authToken': 'YOUR_AUTH_TOKEN',
        // Additional payment parameters
      },
    );
    print('Payment result: $result');
  } catch (e) {
    print('Payment error: $e');
  }
}
```

**Supported Actions:**

| Action | Description |
|--------|-------------|
| `BBPS_PAYMENT` | Make a bill payment |
| `SET_TXN_STATUS` | Set transaction status |
| `BBPS_BILLERS_LIST` | Get list of available billers |
| `BBPS_LIST_TXN` | List transaction history |
| `BBPS_LIST_PENDING_BILLS` | Get pending bills |
| `GENERATE_KEY` | Generate encryption keys |

### Listen to Events

Subscribe to BBPS events for real-time updates:

```dart
StreamSubscription<BbpsEvent>? _eventSubscription;

void listenToBbpsEvents() {
  _eventSubscription = BbpsFlutter.eventStream.listen((event) {
    print('Event: ${event.event}');
    print('Payload: ${event.payload}');
    
    switch (event.event) {
      case 'initiate_result':
        handleInitiateResult(event.payload);
        break;
      case 'process_result':
        handleProcessResult(event.payload);
        break;
      case 'refresh_auth':
        handleAuthRefresh(event.payload);
        break;
      default:
        print('Unknown event: ${event.event}');
    }
  });
}

void handleInitiateResult(Map<String, dynamic>? payload) {
  if (payload != null) {
    print('Initiate success: ${payload['status']}');
  }
}

void handleProcessResult(Map<String, dynamic>? payload) {
  if (payload != null) {
    print('Process result: ${payload['status']}');
  }
}

void handleAuthRefresh(Map<String, dynamic>? payload) {
  print('Auth refresh triggered');
  // Refresh your auth token and re-initiate if needed
}
```

**Event Types:**

| Event | Description |
|-------|-------------|
| `initiate_result` | Session initiation result |
| `process_result` | Action processing result |
| `refresh_auth` | Authentication token refresh required |
| `DO_PAYMENT` | Handle Payment when this event is triggered |

### Handle Back Navigation

Handle hardware back button presses:

```dart
Future<bool> handleBackPress() async {
  try {
    final handled = await BbpsFlutter.onBackPressed();
    return handled;
  } catch (e) {
    print('Back press error: $e');
    return false;
  }
}
```

### Terminate Session

Clean up and terminate the BBPS service:

```dart
Future<void> cleanup() async {
  try {
    await BbpsFlutter.terminate();
    print('BBPS Service terminated');
  } catch (e) {
    print('Termination error: $e');
  }
}
```

### Dispose Resources

Always cancel event subscriptions when done:

```dart
@override
void dispose() {
  _eventSubscription?.cancel();
  super.dispose();
}
```

## Complete Example

```dart
import 'package:flutter/material.dart';
import 'package:bbps_sdk_flutter/bbps_sdk_flutter.dart';

class BbpsPaymentPage extends StatefulWidget {
  @override
  _BbpsPaymentPageState createState() => _BbpsPaymentPageState();
}

class _BbpsPaymentPageState extends State<BbpsPaymentPage> {
  bool _isInitialized = false;
  StreamSubscription<BbpsEvent>? _eventSubscription;
  String _status = 'Not initialized';

  @override
  void initState() {
    super.initState();
    _setupEventListener();
  }

  void _setupEventListener() {
    _eventSubscription = BbpsFlutter.eventStream.listen((event) {
      setState(() {
        _status = '${event.event}: ${event.payload}';
      });
    });
  }

  Future<void> _initialize() async {
    try {
      await BbpsFlutter.createService(params: {'clientId': 'YOUR_CLIENT_ID'});
      await BbpsFlutter.initiate(
        params: {
          'action': 'initiate',
          'agentId': 'YOUR_AGENT_ID',
          'mobile': '9876543210',
          'deviceId': 'device_${DateTime.now().millisecondsSinceEpoch}',
          'clientId': 'YOUR_CLIENT_ID',
          'authToken': 'YOUR_AUTH_TOKEN',
        },
      );
      setState(() => _isInitialized = true);
    } catch (e) {
      setState(() => _status = 'Error: $e');
    }
  }

  Future<void> _makePayment() async {
    if (!_isInitialized) return;
    
    try {
      final result = await BbpsFlutter.process(
        params: {
          'action': 'BBPS_PAYMENT',
          'agentId': 'YOUR_AGENT_ID',
          'authToken': 'YOUR_AUTH_TOKEN',
        },
      );
      print('Payment result: $result');
    } catch (e) {
      print('Payment error: $e');
    }
  }

  Future<void> _terminate() async {
    try {
      await BbpsFlutter.terminate();
      setState(() => _isInitialized = false);
    } catch (e) {
      print('Termination error: $e');
    }
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('BBPS Payment')),
      body: Column(
        children: [
          Text('Status: $_status'),
          ElevatedButton(
            onPressed: _isInitialized ? null : _initialize,
            child: Text('Initialize'),
          ),
          ElevatedButton(
            onPressed: _isInitialized ? _makePayment : null,
            child: Text('Make Payment'),
          ),
          ElevatedButton(
            onPressed: _isInitialized ? _terminate : null,
            child: Text('Terminate'),
          ),
        ],
      ),
    );
  }
}
```

## Configuration Reference

### Android `bbps {}` Block

```gradle
bbps {
    clientId = "YOUR_CLIENT_ID"     // Your BBPS merchant client ID
    sdkVersion = "0.1.10"             // BBPS SDK version to use
}
```

### iOS `BBPSConfig.json`

```json
{
  "clientConfigs": {
    "YOUR_CLIENT_ID": {}
  }
}
```

## Troubleshooting

### Android Issues

**Issue:** `Plugin [id: 'bbps.plugin'] was not found`

**Solution:** Ensure the Juspay Maven repository is added to `pluginManagement.repositories` in `settings.gradle.kts`:
```kotlin
pluginManagement {
    repositories {
        maven("https://maven.juspay.in/hyper-sdk")
    }
}
```

**Issue:** `clientId is required in bbps extension`

**Solution:** Add the `bbps {}` block with a valid `clientId` to your app's `build.gradle`:
```gradle
bbps {
    clientId = "YOUR_CLIENT_ID"
    sdkVersion = "0.1.10"
}
```

**Issue:** Build fails with `Compilation error`

**Solution:** Ensure Java/Kotlin compatibility:
```gradle
compileOptions {
    sourceCompatibility JavaVersion.VERSION_17
    targetCompatibility JavaVersion.VERSION_17
}
kotlinOptions {
    jvmTarget = "17"
}
```

### iOS Issues

**Issue:** `BBPSSDK/HyperSDK not found`

**Solution:** Run `pod install` after adding the plugin. If using a Git-based dependency, ensure the repository is accessible.

**Issue:** Assets not downloading during build

**Solution:** Verify `BBPSConfig.json` exists in your `ios/` directory and contains your client ID in `clientConfigs`.

**Issue:** Wrong merchant assets loaded

**Solution:** Ensure `BBPSConfig.json` contains only your client ID:
```json
{
  "clientConfigs": {
    "YOUR_CLIENT_ID": {}
  }
}
```

### General Issues

**Issue:** `createService` returns false

**Solution:** 
- Verify your `clientId` is correct
- Ensure network connectivity for asset downloading
- Check that all platform-specific setup is complete

**Issue:** Events not received

**Solution:** Ensure you subscribe to `BbpsFlutter.eventStream` before calling `initiate()`.

## Platform Channels

The plugin uses the following method channels:

- **Android:** `com.example.bbps_sdk_flutter`
- **iOS:** `bbps_sdk_flutter`


For help getting started with Flutter development:
- [Flutter Documentation](https://docs.flutter.dev)
- [Flutter Plugin Development](https://flutter.dev/to/develop-plugins)

## License

This project is licensed under the MIT License.

## Support

For technical support or issues, please contact Juspay support at support@juspay.in or visit the [Juspay Developer Portal](https://developer.juspay.in).
