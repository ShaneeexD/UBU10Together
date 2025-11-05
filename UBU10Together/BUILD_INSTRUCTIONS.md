# UBU10 Together - Build & Installation Instructions

## ✅ Plugin Status: MVP Complete

The minimum viable plugin is now complete with all core features:
- Firebase integration for medal times
- Map fetching and rotation from TMX
- Medal-based progression (Author/Harder/Hardest)
- Player tracking and leaderboard
- Session timing and management
- Three UI windows (Settings, Game, End)

## 🔧 Before Building

### 1. Verify Firebase Configuration

Check that `Data/FirebaseClient.as` has your Firebase URL:
```angelscript
string FIREBASE_BASE_URL = "https://ubu10together-default-rtdb.europe-west1.firebasedatabase.app/ubu10/";
```

### 2. Required Dependencies

The plugin requires these OpenPlanet libraries (should be auto-detected):
- `Icons.as` - UI icons
- `Regex.as` - Text pattern matching
- `MX.as` - Trackmania Exchange integration

## 📦 Building the Plugin

### Method 1: Using OpenPlanet Developer Mode

1. Open Trackmania 2020
2. Launch OpenPlanet (F3)
3. Go to **Developer** menu
4. Click **Load Dev Plugin**
5. Navigate to: `UBU10Together` folder
6. Select the `info.toml` file
7. Plugin will load immediately

### Method 2: Building .op file

1. In OpenPlanet, go to **Developer** → **Build Plugin**
2. Select the `UBU10Together` folder
3. This creates `UBU10Together.op` file
4. Copy to: `%USERPROFILE%\OpenPlanet\Plugins\`
5. Restart Trackmania or reload plugins

## 🎮 Usage

1. **Launch Trackmania 2020** with OpenPlanet
2. Press **F3** to open OpenPlanet menu
3. Go to **Plugins** → **UBU10 Together**
4. Click the **Trophy icon** to open settings

### Settings Window

- **Target Medal**: Choose Author, Harder, or Hardest
- **Session Duration**: Set runtime in minutes (5-240)
- **Club/Room IDs**: Enter server information
- Click **START SESSION** to begin

### In-Game Window

During session:
- Shows current map and target medal time
- Live countdown timer with progress bar
- Real-time leaderboard (top 10)
- Stop button to end session early

### End Screen

When time expires:
- Displays session winner
- Shows total maps won
- Return to menu button

## 🗂️ File Structure

```
UBU10Together/
├── info.toml                    # Plugin metadata
├── Main.as                      # Entry point
├── Controller/
│   ├── UBU10Controller.as       # Main session controller
│   ├── MapController.as         # Map fetching & rotation
│   ├── MedalController.as       # Medal progression logic
│   └── PlayerTracker.as         # Player time tracking
├── Data/
│   ├── MedalData.as            # Medal time structure
│   └── FirebaseClient.as        # Firebase integration
└── UI/
    ├── SettingsWindow.as        # Configuration UI
    ├── GameWindow.as            # In-game HUD
    └── EndWindow.as             # End screen
```

## 🐛 Troubleshooting

### Plugin Won't Load
- Check OpenPlanet console (F3 → Developer → Console) for errors
- Verify all `.as` files are present
- Make sure `info.toml` is valid

### Firebase Connection Fails
- Verify URL in `FirebaseClient.as`
- Check Firebase database rules (`.read: true`)
- Test connection: https://your-url.firebaseio.com/ubu10.json

### Maps Won't Load
- Check internet connection
- Verify TMX (trackmania.exchange) is accessible
- Check OpenPlanet logs for API errors

### Leaderboard Not Updating
- Make sure you're in a multiplayer server
- Check that players are finishing races
- Verify medal times are loaded from Firebase

## 📝 Known Limitations (MVP)

- Club/Room auto-detect not fully implemented
- No persistent player stats across sessions
- Basic UI styling (functional but minimal)
- Limited error recovery for network issues

## 🚀 Future Enhancements

Potential improvements for v2:
- Enhanced UI with animations and better styling
- Room detection via server info
- Cross-session player statistics
- Admin controls for hosts
- Custom medal time adjustments
- Export/import session data

## 💡 Development Notes

### Testing Locally

1. Load plugin in dev mode
2. Open Settings window
3. Set a short duration (5 minutes)
4. Use dummy Club/Room IDs for testing
5. Start session
6. Check console for errors

### Debugging

Enable trace logging:
```angelscript
trace("[ComponentName] Your debug message");
```

View logs in: OpenPlanet → Developer → Console

### Modifying Medal Times

To update medal times:
1. Regenerate JSON with Python tool
2. Upload to Firebase
3. Plugin automatically fetches new data per map

## 📞 Support

If you encounter issues:
1. Check OpenPlanet console for errors
2. Verify Firebase data is uploaded correctly
3. Test with a single map first
4. Check that medal times exist for UBU10 maps

## 🎉 Credits

- **Plugin**: UBU10 Together
- **Author**: ShaneeexD
- **Medal Times**: Generated from trackmania.io leaderboards
- **Maps**: UBU10 series by OstrichEnforcer

Enjoy your Together sessions! 🏁
