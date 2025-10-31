# Pickle 🥒

A beautiful macOS screenshot manager that lives in your menu bar, helping you organize and manage your screenshots with ease.

![macOS](https://img.shields.io/badge/macOS-13.0+-blue.svg)
![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)
![SwiftUI](https://img.shields.io/badge/SwiftUI-4.0+-green.svg)
![License](https://img.shields.io/badge/License-MIT-yellow.svg)

## ✨ Features

- **📸 Recent Screenshots**: View your latest screenshots in a clean, organized interface
- **⚙️ Smart Settings**: Comprehensive settings panel with launch preferences
- **📁 Location Management**: Easily move screenshots from Desktop to Pictures/Screenshots
- **🔄 Real-time Monitoring**: Automatically detects new screenshots as you take them
- **🎨 Native Design**: Beautiful, native macOS interface that feels right at home
- **🚀 Menu Bar Integration**: Quick access from your menu bar without cluttering your dock

## 🖼️ Screenshots

*Screenshots coming soon...*

## 🚀 Installation

### Prerequisites

- macOS 13.0 or later
- Xcode 15.0 or later (for building from source)

### Building from Source

1. Clone the repository:
```bash
git clone https://github.com/arshadkc/pickle.git
cd pickle
```

2. Open the project in Xcode:
```bash
open Pickle.xcodeproj
```

3. Build and run:
```bash
make build
```

Or use Xcode's build and run functionality.

## 📖 Usage

### Getting Started

1. **Launch Pickle**: The app will appear in your menu bar as a gear icon
2. **View Screenshots**: Click the menu bar icon to see your recent screenshots
3. **Access Settings**: Click the settings gear icon in the header

### Settings

Pickle offers several customization options:

#### General
- **Launch at Login**: Automatically start Pickle when you sign in to your Mac

#### Screenshot Location
- **Desktop Detection**: If screenshots are saved to Desktop, Pickle will suggest moving them to Pictures/Screenshots
- **One-Click Move**: Easily relocate your screenshots with a single button click

#### About
- **Version Info**: View app version and build number
- **Update Check**: Check for app updates (coming soon)

## 🛠️ Development

### Project Structure

```
Sources/
├── Model/
│   └── ScreenshotStore.swift          # Data model for screenshot management
├── Services/
│   ├── DirectoryWatcher.swift         # File system monitoring
│   ├── ScreenshotFolderResolver.swift # Screenshot location detection
│   └── ScreenshotLocationManager.swift # Location management
├── Views/
│   ├── MenuBarView.swift              # Main interface
│   ├── SettingsView.swift             # Settings panel
│   └── ScreenshotLocationPromptView.swift # Location change prompt
├── Preview/
│   └── QuickLookPreviewController.swift # Screenshot preview
├── PickleApp.swift                    # Main app entry point
├── Info.plist                         # App configuration
└── Pickle.entitlements               # App permissions
```

### Building

```bash
# Build the project
make build

# Clean build artifacts
make clean

# Run the app
make run
```

### Key Technologies

- **SwiftUI**: Modern, declarative UI framework
- **Combine**: Reactive programming for data flow
- **File System Events**: Real-time directory monitoring
- **App Storage**: Persistent user preferences
- **Menu Bar Extra**: Native menu bar integration

## 🤝 Contributing

We welcome contributions! Please feel free to submit a Pull Request. For major changes, please open an issue first to discuss what you would like to change.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Built with ❤️ using SwiftUI
- Inspired by the need for better screenshot organization on macOS
- Thanks to the Swift and macOS development community

## 📞 Support

If you encounter any issues or have questions:

1. Check the [Issues](https://github.com/arshadkc/pickle/issues) page
2. Create a new issue with detailed information
3. Include your macOS version and app version

---

**Pickle** - Making screenshot management simple and beautiful on macOS.
