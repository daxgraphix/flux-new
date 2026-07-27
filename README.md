# 🎵 Flux Radio - Global AM/FM Radio & Podcasts

[![Flutter](https://img.shields.io/badge/Flutter-3.11.5-blue.svg)](https://flutter.dev/)
[![Dart](https://img.shields.io/badge/Dart-3.0-blue.svg)](https://dart.dev/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

**Flux Radio** is a professional-grade radio streaming application delivering over 100,000 global AM/FM stations and podcasts. Built with a focus on cross-platform responsiveness, audio engineering excellence, and Tanzanian local content, it offers a premium experience for both mobile and tablet users.

![Flux Radio](assets/images/app_icon.jpg)

## 🌟 Key Features

### 🎧 **Global Radio & Discovery**
- **Massive Directory**: Access 100,000+ stations worldwide powered by the Radio-Browser API.
- **Tanzania Priority**: Over 500 dedicated Tanzanian and East African stations with regional discovery.
- **Location-Aware**: GPS-powered "Nearby" station discovery to find local FM/AM content instantly.
- **Smart Categorization**: Browse by Trending, Music, News, Sports, Talk, and Global AM/FM.
- **Advanced Search**: Filter by name, country, genre, or language with recent search history tracking.

### 📱 **Professional Audio Engine**
- **High-Fidelity Playback**: Optimized buffering and 15s connection timeout handling for 320kbps streams.
- **Audio Effects**: Professional 5-band equalizer and digital loudness enhancer with persistent settings.
- **Enhanced Sleep Timer**: Features a **60-second linear volume fade-out** logic that gracefully silences audio, with robustness checks to prevent volume "jumps" if the user adjusts settings during the fade.
- **Recording**: Record live broadcasts directly to your device with background service support.
- **Region-Aware**: Smart error handling for 403 (Regional restrictions), 404 (Broken links), and SocketExceptions.

### 🖥️ **Responsive UI/UX (Redesign)**
- **Adaptive Layouts**: Seamlessly switches between `ListView` (Mobile) and high-density `GridView` (Tablet) using a 600dp threshold.
- **Multi-Column Grids**: Dynamic 2-column (small tablets) and 3-4 column (large tablets) layouts with a 3.5 aspect ratio for ergonomic browsing.
- **Ergonomic Constraints**: The `NowPlayingScreen` and modal bottom sheets (Equalizer, Timer, Recording) are width-constrained to **500-600dp** on tablets to ensure focus and usability.
- **Unified Navigation**: A global `NavigationWrapper` that provides a `BottomNavigationBar` on phones and a `NavigationRail` on tablets.

---

## 🔄 How It Works

### **1. Audio Playback Lifecycle**
*   **Station Identification**: Every station uses a unique ID. If a UUID is missing from the API, the engine generates a consistent 16-character ID via **SHA256 hashing** of the stream URL.
*   **Media Management**: Uses `audio_service` to provide full background playback support, including lock screen controls and persistent notifications with station metadata.
*   **Stream Security**: The engine validates stream URLs before playback and handles timeouts gracefully to maintain app stability.

### **2. The Responsive Engine**
The app utilizes `LayoutBuilder` and `MediaQuery` to detect screen dimensions:
*   **Mobile (< 600dp)**: Standard vertical lists optimized for one-handed use.
*   **Tablet (>= 600dp)**: Grid-based layouts that maximize screen real estate.
*   **Adaptive Navigation**: The navigation system automatically pivots between bottom and side-rail modes without losing application state.

### **3. Audio Effects Chain**
*   **Equalizer**: A 5-band digital equalizer that interfaces directly with the hardware-accelerated audio handler.
*   **Loudness Enhancer**: A post-processing effect to increase audio presence without distortion.
*   **Persistence**: All audio preferences (Bands, Loudness, Volume) are saved to local storage and restored on app launch.

### **4. Smart Storage (Hive)**
The app uses **Hive (NoSQL)** for lightning-fast performance:
*   **Favorites**: Stored as `FavoriteStation` objects with fast lookup by station ID.
*   **History**: Tracks recently played stations and search queries.
*   **Cache**: Efficiently manages station favicons and metadata to reduce data usage.

---

## 🏗️ Architecture

### **Project Structure**
```text
lib/
├── flux_engine/           # Core Logic
│   ├── radio_engine.dart  # Audio & State Orchestration
│   ├── radio_repository.dart # Data abstraction layer
│   ├── station_provider.dart # API Data fetching
│   ├── alarm_service.dart    # Scheduled playback
│   └── recording_service.dart # Stream capture
├── flux_hardware/         # API & Models
│   └── radio_service.dart # Radio Browser integration
├── flux_storage/          # Persistence
│   └── radio_storage.dart # Hive adapters & logic
└── flux_ui/              # Views & Screens
    ├── navigation_wrapper.dart # Adaptive Shell
    ├── main_screen.dart   # Dashboard
    ├── library_screen.dart # Responsive Library (Tabs)
    ├── now_playing_screen.dart # Full Player UI
    └── widgets/           # FluxImage, EnhancedMiniPlayer
```

---

## 🚀 Quick Start

1.  **Clone & Install**:
    ```bash
    git clone https://github.com/yourusername/flux-radio.git
    cd flux-radio
    flutter pub get
    ```
2.  **Generate Data Adapters**:
    ```bash
    flutter pub run build_runner build
    ```
3.  **Run**:
    ```bash
    flutter run
    ```

---

## 🎯 Recent Enhancements
- ✅ **Tablet Migration**: Refactored `LibraryScreen`, `RecentScreen`, and `StationsList` to support high-density grids.
- ✅ **Sleep Timer 2.0**: Implemented granular 60s fade-out with linear interpolation.
- ✅ **UI Ergonomics**: Constrained wide-screen content to 500-600dp to prevent UI "stretching" on tablets.
- ✅ **Stability**: Added SHA256 fallback for station IDs and enhanced stream timeout logic.

Built with ❤️ in Tanzania for a global audience.
