# UBU10 Together Plugin - Development Progress

## ✅ Completed Components

### Core Files
- `info.toml` - Plugin metadata
- `Main.as` - Plugin entry point with render loop

### Controllers
- `Controller/UBU10Controller.as` - Main controller managing session state, timing, and coordination
- `Controller/MapController.as` - Map fetching from TMX and randomized rotation

### Data Structures
- `Data/MedalData.as` - Structure for holding medal times (Author, Harder, Hardest)
- `Data/FirebaseClient.as` - Firebase integration for fetching medal data

## 🚧 Components Still Needed

### Controllers
- `Controller/MedalController.as` - Watches for players reaching target medals
- `Controller/PlayerTracker.as` - Tracks player info and medal achievements

### UI Windows
- `UI/SettingsWindow.as` - Settings interface with:
  - Medal selection (Author/Harder/Hardest with icons)
  - Runtime slider (minutes)
  - Club ID and Room ID inputs
  - Check Room and Auto-Detect buttons
  - Start button

- `UI/GameWindow.as` - In-game interface with:
  - Current map name
  - Required medal with time goal
  - Live countdown timer
  - Real-time leaderboard
  - Stop button

- `UI/EndWindow.as` - End screen with:
  - Winner display
  - Final stats
  - GIF animation
  - Return to menu button

### Utilities
- `Util/Helpers.as` - Common utility functions

### Additional Features
- BRM Timer integration for timing (or custom timing system)
- Room/Club ID detection and validation
- Player persistence system
- Leaderboard tracking

## 📋 Configuration Required

### Firebase Setup
You need to update `Data/FirebaseClient.as` with your Firebase URLs:
```
string FIREBASE_BASE_URL = "https://your-firebase-project.firebaseio.com/ubu10/";
string FIREBASE_AUTH_TOKEN = "";  // Optional
```

### Python Tool Integration
Upload the JSON output from `generate_times.py` to Firebase:
- Structure: `/ubu10/{mapUid}.json`
- Each map's data includes: trackId, uid, name, authorTime_ms, computed.harderTime_ms, computed.medalTime_ms

## 🎯 Medal System

The plugin supports 6 medals:
1. **Bronze** (0) - Standard TM medal
2. **Silver** (1) - Standard TM medal
3. **Gold** (2) - Standard TM medal
4. **Author** (3) - Official author time
5. **Harder** (4) - 1/8 of the way from Author to WR
6. **Hardest** (5) - Computed Time_A (top 50 weighted) or Time_B (fallback)

## 📝 Next Steps

1. Create MedalController for watching player progress
2. Create PlayerTracker for player data management
3. Implement all three UI windows (Settings, Game, End)
4. Add BRM Timer or custom timing system
5. Implement Club/Room detection
6. Add player persistence
7. Create end screen with GIF support
8. Test with actual UBU10 maps

## 🔧 Testing Checklist

- [ ] Map fetching from TMX (OstrichEnforcer / UBU10)
- [ ] Firebase medal data retrieval
- [ ] Medal progression (target reached = next map)
- [ ] Session timing (configurable duration)
- [ ] Club/Room integration
- [ ] Settings persistence
- [ ] Player tracking across maps
- [ ] Leaderboard updates
- [ ] End screen display

## 📦 Dependencies

Required OpenPlanet libraries:
- `Icons.as` - For UI icons
- `Regex.as` - For ID validation
- `MX.as` - For Trackmania Exchange integration

## 🚀 Usage (Once Complete)

1. Configure Firebase URL in FirebaseClient.as
2. Upload medal times JSON to Firebase
3. Load plugin in OpenPlanet
4. Open settings via menu (Trophy icon)
5. Select target medal and runtime
6. Enter Club ID and Room ID
7. Click Start to begin session
8. Players race to reach target medal
9. Map changes when first player reaches target
10. Session ends when time expires

## 💡 Notes

- The plugin is designed for multiplayer with centralized control
- Map rotation is randomized to avoid repeats
- Medal fallback system if data unavailable (defaults to Author)
- All times are stored in milliseconds
- Firebase acts as central data source for all medal times
