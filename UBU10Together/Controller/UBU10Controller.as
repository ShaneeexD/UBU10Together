// UBU10Controller - Main controller for the Together mode
// Manages session state, timing, map rotation, and medal progression

class UBU10Controller {
    // Run state
    bool isRunning = false;
    bool isPaused = false;
    bool isSwitchingMap = false;
    bool runFinished = false;
    bool isFirstMap = true;

    // Settings
    string clubId = "";
    string roomId = "";
    uint runTimeMinutes = 120;  // Default 120 minutes
    uint selectedMedal = 3;     // 0=Bronze, 1=Silver, 2=Gold, 3=Author, 4=Harder, 5=Hardest

    // Timing
    int runTimeRemainingMs = -1;
    int runStartTime = -1;
    int runTimeTotalMs = -1;
    int pausedRemainingMs = -1;  // Store remaining time when paused for map change

    // Current map
    MX::MapInfo@ currentMapInfo;
    MedalData@ currentMedalData;

    // Controllers
    MapController@ mapController;
    MedalController@ medalController;
    PlayerTracker@ playerTracker;
    
    // UI
    EndWindow@ endWindow;
    bool hasShownEndWindow = false;

    // Constructor
    UBU10Controller() {
        @medalController = MedalController(this);
        @mapController = MapController();
        LoadSettings();
    }
    
    void SetPlayerTracker(PlayerTracker@ tracker) {
        @playerTracker = tracker;
    }

    void SetEndWindow(EndWindow@ wnd) {
        @endWindow = wnd;
    }

    // ===== Settings Management =====
    void LoadSettings() {
        try {
            string path = IO::FromStorageFolder("UBU10_settings.json");
            if (IO::FileExists(path)) {
                Json::Value s = Json::FromFile(path);
                if (s.HasKey("clubId")) clubId = string(s["clubId"]);
                if (s.HasKey("roomId")) roomId = string(s["roomId"]);
                if (s.HasKey("runTimeMinutes")) runTimeMinutes = uint(int(s["runTimeMinutes"]));
                if (s.HasKey("selectedMedal")) selectedMedal = uint(int(s["selectedMedal"]));
                trace("[UBU10] ⚙ Settings loaded | club=" + clubId + " room=" + roomId + 
                      " time=" + runTimeMinutes + "min medal=" + selectedMedal);
            }
        } catch {
            warn("[UBU10] ❌ Failed to load settings: " + getExceptionInfo());
        }
    }

    void SaveSettings() {
        try {
            Json::Value s = Json::Object();
            s["clubId"] = clubId;
            s["roomId"] = roomId;
            s["runTimeMinutes"] = runTimeMinutes;
            s["selectedMedal"] = selectedMedal;
            string path = IO::FromStorageFolder("UBU10_settings.json");
            Json::ToFile(path, s);
            trace("[UBU10] 💾 Settings saved");
        } catch {
            warn("[UBU10] ❌ Failed to save settings: " + getExceptionInfo());
        }
    }

    // ===== Run Control =====
    void StartRun() {
        trace("[UBU10] ▶ Starting run");
        startnew(CoroutineFunc(this.PerformStartup));
    }

    void PerformStartup() {
        if (runFinished) {
            trace("[UBU10] 🚫 Cannot start - already finished");
            return;
        }

        // Clean up previous run
        ClearMapsFolder();
        LoadSettings();

        // Initialize map list
        trace("[UBU10] 📥 Loading UBU10 map list");
        if (!mapController.LoadMapList()) {
            warn("[UBU10] ❌ Failed to load map list");
            return;
        }

        trace("[UBU10] ✅ Map list loaded - " + mapController.GetMapCount() + " maps available");

        // Set up run state
        isRunning = true;
        isPaused = false;
        isSwitchingMap = false;
        hasShownEndWindow = false;
        isFirstMap = true;

        runTimeTotalMs = (runTimeMinutes == 0) ? -1 : int(runTimeMinutes) * 60 * 1000;
        runTimeRemainingMs = runTimeTotalMs;
        runStartTime = Time::Now;

        // Set server time limit via BRM
        if (runTimeMinutes > 0) {
            int timeLimitSeconds = int(runTimeMinutes) * 60;
            SetServerTimeLimit(timeLimitSeconds);
            trace("[UBU10] ⏱ Server time limit set to " + timeLimitSeconds + " seconds");
        }

        // Start medal controller
        medalController.Reset();
        medalController.StartWatching();

        // Show game window
        if (g_gameWindow !is null) {
            g_gameWindow.isVisible = true;
        }

        // Load first map
        SwitchMap();
    }

    void StopRun(bool isTimeExpired = false) {
        trace("[UBU10] 🛑 Stopping run - timeExpired=" + isTimeExpired);
        
        isRunning = false;
        isPaused = true;
        runFinished = isTimeExpired;
        @currentMapInfo = null;
        @currentMedalData = null;
        runStartTime = -1;

        // Stop controllers
        if (medalController !is null) {
            medalController.Reset();
        }
        
        if (playerTracker !is null) {
            playerTracker.Reset();
        }
        
        // Hide game window
        if (g_gameWindow !is null) {
            g_gameWindow.isVisible = false;
        }

        // Clean up
        CleanupJsonFiles();
        
        trace("[UBU10] ✅ Run stopped");
    }

    void PauseRun() {
        trace("[UBU10] ⏸ Pausing run");
        isPaused = true;
        
        // Store current remaining time before pausing
        if (runStartTime > 0 && runTimeTotalMs > 0) {
            int elapsed = Time::Now - runStartTime;
            runTimeRemainingMs = Math::Max(0, runTimeRemainingMs - elapsed);
            pausedRemainingMs = runTimeRemainingMs;  // Store for later resume
            trace("[UBU10] 💾 Stored remaining time: " + (pausedRemainingMs / 1000) + "s");
        }
        
        runStartTime = -1;
    }

    void ResumeRun() {
        trace("[UBU10] ▶ Resuming run");
        isPaused = false;
        
        // Restore the exact remaining time from when we paused
        if (pausedRemainingMs > 0) {
            runTimeRemainingMs = pausedRemainingMs;
            trace("[UBU10] ➡ Restored remaining time: " + (runTimeRemainingMs / 1000) + "s");
        }
        
        runStartTime = Time::Now;
        
        // Note: Server time limit is already set by LoadMapAsync
    }
    
    void SetServerTimeLimit(int timeLimitSeconds) {
        // Set the server time limit via BetterRoomManager
        try {
            BRM::ServerInfo@ serverInfo = BRM::GetCurrentServerInfo(cast<CTrackMania>(GetApp()), true);
            if (serverInfo is null || serverInfo.clubId == 0 || serverInfo.roomId == 0) {
                warn("[UBU10] ⚠ Cannot set time limit - not in a valid club room");
                return;
            }
            
            auto builder = BRM::CreateRoomBuilder(serverInfo.clubId, serverInfo.roomId);
            builder.LoadCurrentSettingsAsync()
                   .SetTimeLimit(timeLimitSeconds)
                   .SaveRoom();
            
            trace("[UBU10] ⏱ Server time limit updated: " + timeLimitSeconds + "s");
        } catch {
            warn("[UBU10] ❌ Failed to set time limit: " + getExceptionInfo());
        }
    }

    // ===== Map Management =====
    void SwitchMap() {
        if (isSwitchingMap) return;
        
        trace("[UBU10] 🔄 Switching map");
        isSwitchingMap = true;
        PauseRun();

        try {
            medalController.Reset();
            
            // Reset player tracker for new map (preserves medal counts)
            if (playerTracker !is null) {
                playerTracker.ResetForNewMap();
                trace("[UBU10] 🔄 Player tracker reset for new map (medals preserved)");
            }

            // Get current UID to avoid repeats
            string curUid = "";
            auto app = cast<CTrackMania>(GetApp());
            if (app !is null && app.RootMap !is null && app.RootMap.MapInfo !is null) {
                curUid = app.RootMap.MapInfo.MapUid;
            }

            // Get next map
            @currentMapInfo = mapController.GetNextMap(curUid);
            
            if (currentMapInfo is null) {
                warn("[UBU10] ❌ No map available");
                isSwitchingMap = false;
                return;
            }

            trace("[UBU10] ✅ Selected map: " + currentMapInfo.Name + " (" + currentMapInfo.MapUid + ")");

            // Load medal data from Firebase
            @currentMedalData = FirebaseClient::GetMedalData(currentMapInfo.MapUid);
            
            if (currentMedalData is null) {
                warn("[UBU10] ⚠ No medal data for map - using defaults");
                @currentMedalData = MedalData();  // Use defaults
            }

            // Load the map
            LoadMapAsync();
        } catch {
            warn("[UBU10] ❌ Map switch failed: " + getExceptionInfo());
            isSwitchingMap = false;
        }
    }

    void LoadMapAsync() {
        // Calculate remaining time in seconds to pass to map loader
        int timeLimitSeconds = -1;
        if (runTimeTotalMs > 0 && runTimeRemainingMs > 0) {
            timeLimitSeconds = runTimeRemainingMs / 1000;
        }
        
        // Load map to room with time limit
        mapController.LoadMapToRoom(currentMapInfo, timeLimitSeconds);

        const string wantUid = currentMapInfo.MapUid;
        uint startTime = Time::Now;
        bool activated = false;

        // Wait for map activation (30s timeout)
        while (Time::Now - startTime < 30000) {
            yield();

            auto app = cast<CTrackMania>(GetApp());
            if (app !is null && app.RootMap !is null && app.RootMap.MapInfo !is null) {
                if (app.RootMap.MapInfo.MapUid == wantUid) {
                    activated = true;
                    trace("[UBU10] ✅ Map activated");
                    break;
                }
            }
        }

        if (!activated) {
            warn("[UBU10] ⚠ Map activation timeout");
        }

        isSwitchingMap = false;
        
        if (isFirstMap) {
            isFirstMap = false;
            ResumeRun();
        } else {
            ResumeRun();
        }
    }

    // ===== Update Loop =====
    void Update(float dt) {
        if (!isRunning || isPaused || isSwitchingMap) return;

        // Update remaining time
        if (runTimeTotalMs > 0 && runStartTime > 0) {
            int elapsed = Time::Now - runStartTime;
            runTimeRemainingMs = runTimeTotalMs - elapsed;

            // Check if time expired
            if (runTimeRemainingMs <= 0 && !hasShownEndWindow) {
                StopRun(true);
                if (endWindow !is null) {
                    endWindow.Open();
                    hasShownEndWindow = true;
                }
            }
        }
        
        // Update player tracking
        if (playerTracker !is null) {
            playerTracker.Update();
        }
    }

    // ===== Helpers =====
    void ClearMapsFolder() {
        string folder = IO::FromStorageFolder("Maps/");
        if (!IO::FolderExists(folder)) return;
        
        auto files = IO::IndexFolder(folder, false);
        for (uint i = 0; i < files.Length; i++) {
            IO::Delete(files[i]);
        }
        trace("[UBU10] 🧹 Maps folder cleared");
    }

    void CleanupJsonFiles() {
        try {
            string[] files = {
                "UBU10_MapInfo.json",
                "UBU10_PlayerInfo.json",
                "UBU10_targets.json"
            };
            
            for (uint i = 0; i < files.Length; i++) {
                string path = IO::FromStorageFolder(files[i]);
                if (IO::FileExists(path)) {
                    IO::Delete(path);
                }
            }
            trace("[UBU10] 🧹 JSON files cleaned up");
        } catch {
            warn("[UBU10] ❌ Cleanup failed: " + getExceptionInfo());
        }
    }

    // ===== Medal Info =====
    string GetMedalName(uint medal) {
        switch (medal) {
            case 0: return "Bronze";
            case 1: return "Silver";
            case 2: return "Gold";
            case 3: return "Author";
            case 4: return "Harder";
            case 5: return "Hardest";
        }
        return "Unknown";
    }

    int GetMedalTime(uint medal) {
        if (currentMedalData is null) return -1;
        
        switch (medal) {
            case 0: return currentMedalData.bronzeTime;
            case 1: return currentMedalData.silverTime;
            case 2: return currentMedalData.goldTime;
            case 3: return currentMedalData.authorTime;
            case 4: return currentMedalData.harderTime;
            case 5: return currentMedalData.hardestTime;
        }
        return -1;
    }

    string FormatTime(int ms) {
        if (ms < 0) return "--:--.---";
        
        int totalSeconds = ms / 1000;
        int minutes = totalSeconds / 60;
        int seconds = totalSeconds % 60;
        int millis = ms % 1000;
        
        return tostring(minutes) + ":" + (seconds < 10 ? "0" : "") + tostring(seconds) + "." + 
               (millis < 100 ? "0" : "") + (millis < 10 ? "0" : "") + tostring(millis);
    }
}
