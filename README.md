# TallyTap (First Prototype)

TallyTap is an ultra-fast, privacy-first expense logging utility built with a hybrid Flutter and Kotlin architecture. The goal of this prototype is to validate a near-zero friction capture flow using launcher app shortcuts, native overlays, and sensor-based gesture detection.

---

## 🌟 Core Philosophy
- **Frictionless Capture**: Reduce logs to under 2 seconds.
- **Local-First & Privacy-Focused**: No cloud sync, no tracking, and no external integrations.
- **Lightweight Architecture**: No splash screens, no load states, and instant autofocus.

---

## 🛠️ Hybrid Architecture

TallyTap uses a **Hybrid Architecture** to achieve high-fidelity system integrations:

### 1. Frontend Shell (Flutter + Material 3)
- Located in `lib/`.
- Manages branding presentation, step-by-step guides, settings storage, and future budget dashboarding.
- Provides a "Test Quick Popup" button communicating over custom MethodChannels.

### 2. Native System Integration (Kotlin + Jetpack Compose)
- Located in `android/app/src/main/kotlin/com/piyushram612/tallytap/`.
- **`PopupActivity`**: A dialog-themed, translucent Jetpack Compose activity that loads instantly, autofocuses input fields, presents quick selector categories, and dismisses on outside clicks.
- **`QuickActionActivity`**: An invisible, fast-redirect launcher target.
- **`BackTapService`**: A foreground service listening to `Sensor.TYPE_ACCELEROMETER` values. It processes Z-axis delta spikes through a high-frequency filter (`BackTapDetector`) to detect physical taps on the rear housing of the device.

---

## 🚀 How to Run the Project

### Prerequisites
- **Flutter SDK**: Installed and in your system PATH.
- **Android SDK (API 29+) & Emulator / Physical Device**: Enabled.
- **Java JDK (17+)**: Configured (`JAVA_HOME`).

### Build & Deploy
1. Start your Android Emulator or connect a physical device.
2. Run package resolutions:
   ```bash
   flutter pub get
   ```
3. Run the application:
   ```bash
   flutter run
   ```

---

## 🧪 How to Test Triggers

### Trigger Method 1: The Flutter Button
- Launch TallyTap from the application drawer.
- Press **"Test Quick Popup"**.
- The translucent Kotlin Jetpack Compose card will pop up instantly over a dimmed background. Type an amount and click **"Tap to Log"** or tap outside to dismiss.

### Trigger Method 2: Launcher App Shortcut
- Go to your home screen or application drawer.
- Long-press the **TallyTap** icon.
- Tap **"Quick Add"** from the static shortcuts menu.
- The translucent Compose card will render instantly without starting the main app shell first.

### Trigger Method 3: Built-in Double Back Tap (Hardware Gesture)
- Launch the main TallyTap app shell.
- Turn on **"Double Back Tap"** toggle switch.
- Double-tap the physical back housing of your phone with your finger (impact on the case).
- The accelerometer detects Z-axis impulse spikes and opens the transparent popup immediately, even when looking at other apps.

---

## 📱 OEM & Gesture Configurations

### 1. Google Pixel "Quick Tap"
- Open Android Settings -> **System** -> **Gestures** -> **Quick Tap**.
- Toggle it **On**.
- Select **Open App** -> tap the Gear settings icon next to TallyTap -> choose the **Quick Add** shortcut.
- Now, double-tapping the back of your Pixel triggers TallyTap instantly from anywhere in the OS.

### 2. Motorola Gesture Systems
- Open the Moto app -> select **Gestures** / **Actions**.
- Search for "Quick Launch" or custom tap actions.
- Bind the action to launch TallyTap's **Quick Add** shortcut activity.

### 3. Third-Party Apps (e.g. TapTap)
- For generic Android models lacking native gesture mapping, download the open-source **[TapTap](https://github.com/KieronQuinn/TapTap)** utility.
- Add a new Double Tap Action -> select **Launch Intent** -> map to target activity `com.piyushram612.tallytap.native.QuickActionActivity`.

---

## ⚠️ Known OEM Limitations
- **Background Aggression**: OEMs like Xiaomi, OnePlus, and Samsung run aggressive power-saving tasks that terminate long-running sensors. To maintain robust gesture capture, go to App Info -> Battery -> **Disable Battery Optimization** / set to **Unrestricted** for TallyTap.
- **Sensor Calibration**: Accelerometer sensitivites vary between glass, plastic, and metal backs. In `BackTapDetector.kt`, the parameter `tapThreshold` is set to `14.0f` by default. You can increase or decrease this value to optimize trigger sensitivity for your specific physical casing.
