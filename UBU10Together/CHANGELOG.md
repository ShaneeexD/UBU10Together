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

- **Server Timer Drift**: Fixed timer increasing slightly on each map switch
  - **Root cause**: Recalculating remaining time on each resume caused drift
  - **Solution**: Store exact remaining time in `pausedRemainingMs` when pausing
  - On resume, restore the exact stored value instead of recalculating
  - Timer now maintains accurate countdown across map changes
  - Added `pausedRemainingMs` variable to track time during map switches

### Changed
- **Leaderboard Display**: Changed medal column from icons to medal counts
  - Now displays a number showing how many medals each player has won in the session
  - Matches the behavior of the ExampleTogetherPlugin
  - Medal count persists across maps during a session
  - Resets when the session is stopped or plugin is reloaded

### Added
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

**Timer Drift Prevention:**
- Added `pausedRemainingMs` variable to store exact remaining time during pauses
- `PauseRun()` calculates and stores remaining time before setting `runStartTime = -1`
- `ResumeRun()` restores the exact stored value instead of recalculating
- This prevents cumulative drift from repeated pause/resume cycles
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
