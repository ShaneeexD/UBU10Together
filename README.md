# UBU10Together

**Play through the UBU10 map campaign together with friends in a structured medal-based progression system!**

UBU10Together is an OpenPlanet plugin for Trackmania that enables synchronized multiplayer sessions through the UBU10 map campaign, with automatic map progression, time tracking, and real-time medal overlays.

---

## 🎯 Features

### For Session Hosts
- **Medal-Based Progression**: Choose target medal (Author, Harder, or Hardest) for the session
- **Automatic Map Loading**: Maps load automatically when anyone in the room achieves the target medal
- **Session Timer**: Set custom session duration (5-240 minutes)
- **Player Tracking**: See which players have achieved medals in real-time
- **Room Management**: Built-in integration with BetterRoomManager for seamless map transitions

### For All Players (Host & Non-Host)
- **Medal Overlay**: See Harder and Hardest medal times for the current map
- **Personal Best Delta**: Real-time comparison of your PB vs medal times
  - Shows **+time** in red when you need to improve
  - Shows **-time** in blue when you've beaten the medal
- **Always Visible**: Medal overlay works even if you're not hosting
- **No Setup Required**: Just install and play - overlay appears automatically

### Quality of Life
- **Hotkey Toggle**: Press `F1` to toggle UI windows (customizable in settings)
- **Plugins Menu Integration**: Easy access via the in-game Plugins menu
- **Skip Cooldown**: 10-second cooldown between skip requests to prevent spam
- **Session End Screen**: Summary of achievements when time runs out

---

## 📦 Installation

1. Make sure you have [OpenPlanet](https://openplanet.dev/) installed
2. Install dependencies from OpenPlanet:
   - **MLFeedRaceData**
   - **BetterRoomManager**
3. Download **UBU10Together** from the OpenPlanet plugin directory
4. The plugin will load automatically when you launch Trackmania

---

## 🎮 How to Use

### For Session Hosts

1. **Join a Club Room**
   - Must be in a club room to host sessions
   - Must have room admin permissions

2. **Open Settings**
   - Click `Plugins` → `UBU10 Together`
   - Or press `F1` (default hotkey)

3. **Configure Session**
   - **Target Medal**: Choose Author, Harder, or Hardest
   - **Duration**: Set session time (5-240 minutes)

4. **Start Session**
   - Click `START SESSION`
   - Settings window closes, game window appears
   - Session timer starts counting down

5. **During Session**
   - Maps auto-load when anyone achieves the target medal
   - Click `Skip Map` to move to next map manually (10s cooldown)
   - Track player progress in the game window
   - Press `F1` to show/hide game window

6. **End Session**
   - Session ends automatically when timer reaches 0
   - End screen shows final achievements
   - Click `Close` to return to settings

### For Non-Host Players

1. **Install Plugin**
   - That's it! No configuration needed

2. **Join Host's Room**
   - Medal overlay appears automatically when you load a map

3. **Play & Compete**
   - See Harder and Hardest medal times
   - Track your PB delta in real-time
   - Work towards beating the medals

4. **Optional**
   - Press `F1` to toggle the overlay if needed
   - Access settings via `Plugins` menu

---

## 🏆 Medal Overlay

The medal overlay shows you the target times for the current map:

```
 🔴 Hardest    2:34.567  +0:12.345
 🟠 Harder     2:28.123  -0:03.456
```

### Reading the Delta Times
- **+time (red)**: How much time you need to cut to beat the medal
- **-time (blue)**: How much you beat the medal by
- **No delta**: You haven't set a PB yet, or PB equals medal time

The overlay updates automatically as you improve your times!

---

## ⌨️ Hotkey Controls

**Default: F3** (change in OpenPlanet Settings → UBU10Together)

- **Outside Session**: Toggles Settings Window
- **During Session**: Toggles Game Window
- **After Session**: Toggles Settings Window

You can also toggle windows via the Plugins menu at any time.

---

## 🔧 Requirements

- **Trackmania** (latest version)
- **OpenPlanet** (latest version)
- **MLFeedRaceData** plugin (for race data)
- **BetterRoomManager** plugin (for map loading)
- **Club Room Access** (for hosting sessions)

---

## 📝 Notes

- **Firebase Integration**: Medal data is fetched from Firebase Realtime Database
- **UBU10 Campaign**: Plugin is designed specifically for the UBU10 map pack
- **Room Permissions**: You must have admin permissions in the club room to host
- **Medal Overlay**: Works offline - fetches data once per map

---

## 🐛 Troubleshooting

**Medal overlay not showing?**
- Make sure you're in a map from the UBU10 campaign
- Check that Firebase can be reached (requires internet)

**Can't start session?**
- Verify you're in a club room
- Check that you have room admin permissions
- Ensure BetterRoomManager is installed

**Maps not auto-loading?**
- Verify BetterRoomManager is working
- Check console for error messages
- Make sure the target medal has been achieved

**Hotkey not working?**
- Go to OpenPlanet Settings → UBU10Together
- Set a different hotkey (F1-F12)
- Make sure no other plugin is using the same key

---

## 👨‍💻 Credits

**Author**: ShaneeexD  
**Category**: Multiplayer  
**Version**: 1.0.0

**Special Thanks**:
- OpenPlanet community
- uncleblowtorch (map creator)
- godis3mpty for plugin inspiration (u10stogether creator)
- MLFeed & BetterRoomManager developers

---

## 📄 License

This plugin is provided as-is for the Trackmania community. Feel free to report issues or suggest features!

---

**Enjoy playing UBU10 together! 🏎️💨**
