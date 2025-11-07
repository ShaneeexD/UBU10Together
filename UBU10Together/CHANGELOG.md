# Changelog - UBU10Together Plugin

## [Unreleased] - 2025-11-05

### Fixed
- **Map Switching Bug**: Fixed continuous map switching after first medal
  - **Root cause 1**: `PlayerTracker` was not being reset on map change - old medal data persisted in memory
  - **Root cause 2**: `PlayerTracker.SavePlayerInfo()` continuously wrote old medal data to the JSON file every second
  - **Root cause 3**: `MedalController` read this stale data and immediately detected "medals" on the new map
  - **Solution**:
    - Added `playerTracker.ResetForNewMap()` call in `SwitchMap()` to clear old times but preserve medal counts
    - Implemented 8-second cooldown in `MedalController` to allow data to stabilize after map change
    - Now each map starts with clean times but players keep their session medal counts
  - Added `lastMapChangeTime` timestamp and `MAP_CHANGE_COOLDOWN_MS` constant (8000ms)

- **Medal Counts Not Persisting**: Fixed medal counts resetting on each map change
  - Players' medal counts are now preserved across map changes
  - Added `PlayerTracker.ResetForNewMap()` method that clears times but keeps medal counts
  - Original `Reset()` method still clears everything when stopping the session
  - Medal counts now accumulate throughout the entire session

- **Server Timer Drift & Reset Bug**: Fixed timer resetting to full session time on map changes
  - **Root cause 1**: `Update()` calculated `runTimeRemainingMs = runTimeTotalMs - elapsed` every frame
  - **Root cause 2**: Since `runStartTime` was reset on resume, `elapsed` was tiny, making it look like full time remained
  - **Root cause 3**: This caused plugin timer to reset to max while server timer was correct
  - **Solution**: 
    - Added `runStartRemainingMs` to store remaining time when timer starts/resumes
    - Changed `Update()` to calculate `runTimeRemainingMs = runStartRemainingMs - elapsed`
    - Now calculates from remaining time at resume, not total session time
  - Timer now stays synchronized with server across map changes
  - Plugin timer and server timer now match perfectly

### Changed
- **Leaderboard Display**: Changed medal column from icons to medal counts
  - Now displays a number showing how many medals each player has won in the session
  - Matches the behavior of the ExampleTogetherPlugin
  - Medal count persists across maps during a session
  - Resets when the session is stopped or plugin is reloaded

### Changed (Latest)
- **Simplified Settings**: Removed unused Club ID and Room ID input fields
  - Plugin auto-detects current club room via `BRM::GetCurrentServerInfo()`
  - No manual room configuration needed - just join a club room and hit start!
  - Cleaner settings window with only necessary options (medal target and duration)
  - Settings file now only stores `runTimeMinutes` and `selectedMedal`

### Fixed (Latest)
- **Timer Double-Subtraction**: Fixed random time loss during map switches
  - Root cause: `PauseRun()` was recalculating elapsed time even though `Update()` already keeps `runTimeRemainingMs` accurate
  - This caused elapsed time to be subtracted TWICE, randomly losing minutes
  - Fixed by using current `runTimeRemainingMs` value directly in `PauseRun()`
  - Timer now stays accurate across all map switches (skip, medal trigger, etc.)

- **Session Complete Screen**: Fixed winner display showing "No data"
  - Added `GetWinner()` method to `PlayerTracker` to find player with most medals
  - Changed `EndWindow` to get winner data from `PlayerTracker` instead of non-existent JSON file
  - Fixed timing issue: EndWindow now opens BEFORE `StopRun()` clears medal data
  - Winner name and medal count now display correctly at session end
  - Shows proper display name (not login ID) and accurate medal count

- **Player Names Between Maps**: Fixed player names showing as login IDs when no time on current map
  - Added `playerNames` dictionary to persistently track login -> display name mapping
  - Names are stored whenever player data is processed from MLFeed
  - Players without current map times now show proper display names instead of login IDs
  - Names persist across map changes throughout the session

- **Instant Medal Display**: Medal counts now update in leaderboard immediately when awarded
  - Added `UpdateLeaderboard()` call in `IncrementPlayerMedalCount()`
  - No need to wait for next map or drive a new time to see medal count update
  
- **Persistent Leaderboard**: Players remain visible in leaderboard even without current map time
  - Modified `UpdateLeaderboard()` to show all players with medal counts
  - Players without times on current map display as "--:--.---"
  - Players with times appear first (sorted by time), then players without times
  - Fixed `PlayerEntry.opCmp()` to sort players without times to bottom

### Added
- **Skip Map Feature**: Added ability to skip the current map during a session
  - New "⏭ Skip Map" button in GameWindow above "Stop Session"
  - 10-second cooldown between skips to prevent spam
  - Visual feedback: button is blue when enabled, gray when disabled
  - Tooltip shows remaining cooldown time when hovering
  - Can only skip when session is running and not paused
  - Preserves remaining session time and medal counts
  - Implemented via `SkipHandler.as` and `SkipButtonGuard` namespace
  - Added `SwitchToSpecificMap()` method to controller for direct map switching

- **Session Medal Tracking**:
  - Added `playerMedalCounts` dictionary in `PlayerTracker` to track medals per player
  - Added `IncrementPlayerMedalCount()` method to increment a player's session medal count
  - Added `GetFirstWinnerLogin()` method in `MedalController` to get the winner's login
  - Added `medalCount` field to `PlayerEntry` class
  - Medal counts are now passed to the leaderboard UI

### Technical Details

**Medal Tracking:**
- When a player reaches the target medal, `MedalController.CreditFirstWinner()` now:
  1. Gets the winner's name and login
  2. Increments their win count in `UBU10_targets.json` (persistent)
  3. Increments their medal count in `PlayerTracker.playerMedalCounts` (session-only)
- The leaderboard UI now shows medal count in the "Medals" column
- Medal counts are reset when stopping a session or when PlayerTracker is reset

**Map Change Cooldown:**
- Added `MAP_CHANGE_COOLDOWN_MS` constant (8000ms) to prevent false medal detections
- Added `lastMapChangeTime` variable to track when map last changed
- `Reset()` now sets `lastMapChangeTime = Time::Now` to start cooldown
- `WatchLoop()` skips medal checking during cooldown period
- This allows MLFeed time to finish writing old map data before checking for new medals

**Medal Count Persistence:**
- Added `PlayerTracker.ResetForNewMap()` method separate from `Reset()`
- `ResetForNewMap()` clears `playerTimes` and JSON file but preserves `playerMedalCounts`
- `Reset()` clears everything including medal counts (used only on session stop)
- `SwitchMap()` now calls `ResetForNewMap()` instead of `Reset()`
- Players remain in leaderboard across maps with their accumulated medal counts

**Timer Synchronization Fix:**
- Added `runStartRemainingMs` variable to store remaining time when timer starts/resumes
- Added `pausedRemainingMs` variable to store exact remaining time during pauses
- `PauseRun()` calculates and stores remaining time: `pausedRemainingMs = runTimeRemainingMs`
- `ResumeRun()` restores both: `runTimeRemainingMs = pausedRemainingMs` AND `runStartRemainingMs = pausedRemainingMs`
- `Update()` now calculates: `runTimeRemainingMs = runStartRemainingMs - elapsed`
  - OLD (broken): `runTimeRemainingMs = runTimeTotalMs - elapsed` (always reset to max)
  - NEW (fixed): Calculates from remaining time at resume, not total time
- This prevents timer from resetting to full session time on map changes
- Server time limit is set once per map load with the stored remaining time

**Server Timer Integration:**
- Added `SetServerTimeLimit(int timeLimitSeconds)` method in `UBU10Controller`
  - Uses `BRM::CreateRoomBuilder().LoadCurrentSettingsAsync().SetTimeLimit().SaveRoom()`
  - Called when starting a session with the full session time
  - Called when resuming after map switch with remaining time
- Updated `MapController.LoadMapToRoom()` to accept `timeLimitSeconds` parameter
- Updated `MapController.LoadMapAsync()` to pass time limit to `GoToNextMapAndThenSetTimeLimit()`
- Timer now syncs with server countdown displayed in-game

## Testing Status
- ✅ Plugin loads and initializes correctly
- ✅ School maps (11 maps) load from Firebase successfully
- ✅ Maps are displayed in School
 room correctly
- ✅ Medal detection works properly
- ✅ Map switching triggers on medal achievement
- ⏳ Medal count tracking - ready for testing

## Known Issues
None currently

## Notes for Users
- Using School maps temporarily instead of UBU10 maps (no trusted dev status required)
- See `SWITCHING_MAP_SETS.md` for instructions on how to switch back to UBU10 maps later
- Medal counts show how many times a player has won in the current session
- Medal counts reset when you stop the session
