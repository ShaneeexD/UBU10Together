// UBU10Controller - Main session controller

class UBU10Controller {
    bool isRunning = false;
    bool isPaused = false;
    bool isSwitchingMap = false;
    bool runFinished = false;
    bool isFirstMap = true;

    
    // Settings
    uint runTimeMinutes = 120;
    uint selectedMedal = 3;  // 0=Bronze, 1=Silver, 2=Gold, 3=Author, 4=Harder, 5=Hardest

    // Timing
    int runTimeRemainingMs = -1;
    int runStartTime = -1;
    int runTimeTotalMs = -1;
    int pausedRemainingMs = -1;
    int runStartRemainingMs = -1;

    // Current map
    MX::MapInfo@ currentMapInfo;
    MedalData@ currentMedalData;

    MapController@ mapController;
    MedalController@ medalController;
    PlayerTracker@ playerTracker;
    EndWindow@ endWindow;
    bool hasShownEndWindow = false;

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

    void LoadSettings() {
        try {
            string path = IO::FromStorageFolder(UBU10Files::Settings);
            if (IO::FileExists(path)) {
                Json::Value s = Json::FromFile(path);
                if (s.HasKey("runTimeMinutes")) runTimeMinutes = uint(int(s["runTimeMinutes"]));
                if (s.HasKey("selectedMedal")) selectedMedal = uint(int(s["selectedMedal"]));
            }
        } catch {
            warn("[UBU10] Failed to load settings: " + getExceptionInfo());
        }
    }

    void SaveSettings() {
        try {
            Json::Value s = Json::Object();
            s["runTimeMinutes"] = runTimeMinutes;
            s["selectedMedal"] = selectedMedal;
            string path = IO::FromStorageFolder(UBU10Files::Settings);
            Json::ToFile(path, s);
        } catch {
            warn("[UBU10] Failed to save settings: " + getExceptionInfo());
        }
    }

    void StartRun() {
        //trace("[UBU10] Starting run");
        startnew(CoroutineFunc(this.PerformStartup));
    }

    void PerformStartup() {
        if (runFinished) {
            trace("[UBU10] Cannot start - already finished");
            return;
        }

        ClearMapsFolder();
        LoadSettings();
        if (!mapController.LoadMapList()) {
            warn("[UBU10] Failed to load map list");
            return;
        }
        
        isRunning = true;
        isPaused = false;
        runStartTime = Time::Now;
        
        if (runTimeMinutes > 0) {
            runTimeTotalMs = runTimeMinutes * 60 * 1000;
            runTimeRemainingMs = runTimeTotalMs;
            runStartRemainingMs = runTimeTotalMs;
        }

        if (runTimeMinutes > 0) {
            int timeLimitSeconds = int(runTimeMinutes) * 60;
            SetServerTimeLimit(timeLimitSeconds);
            //trace("[UBU10] Server time limit set to " + timeLimitSeconds + " seconds");
        }

        medalController.Reset();
        medalController.StartWatching();

        if (g_gameWindow !is null) {
            g_gameWindow.isVisible = true;
        }
        if (g_medalOverlay !is null) {
            g_medalOverlay.Show();
        }

        SwitchMap();
    }

    void StopRun(bool isTimeExpired = false) {
        //trace("[UBU10] Stopping run - timeExpired=" + isTimeExpired);
        
        isRunning = false;
        isPaused = true;
        runFinished = isTimeExpired;
        @currentMapInfo = null;
        @currentMedalData = null;
        runStartTime = -1;

        if (medalController !is null) {
            medalController.Reset();
        }
        if (playerTracker !is null) {
            playerTracker.Reset();
        }
        
        if (g_gameWindow !is null) {
            g_gameWindow.isVisible = false;
        }
        if (g_medalOverlay !is null) {
            g_medalOverlay.Hide();
        }

        CleanupJsonFiles();
        
        //trace("[UBU10] Run stopped");
    }

    void PauseRun() {
        //trace("[UBU10] Pausing run");
        isPaused = true;
        
        if (runTimeRemainingMs > 0) {
            pausedRemainingMs = runTimeRemainingMs;
            //trace("[UBU10] Stored remaining time: " + (pausedRemainingMs / 1000) + "s");
        }
        
        runStartTime = -1;
    }

    void ResumeRun() {
        //trace("[UBU10] Resuming run");
        isPaused = false;
        
        if (pausedRemainingMs > 0) {
            runTimeRemainingMs = pausedRemainingMs;
            runStartRemainingMs = pausedRemainingMs;
            //trace("[UBU10] Restored remaining time: " + (runTimeRemainingMs / 1000) + "s");
        }
        
        runStartTime = Time::Now;
    }
    
    void SetServerTimeLimit(int timeLimitSeconds) {
        try {
            BRM::ServerInfo@ serverInfo = BRM::GetCurrentServerInfo(cast<CTrackMania>(GetApp()), true);
            if (serverInfo is null || serverInfo.clubId == 0 || serverInfo.roomId == 0) {
                warn("[UBU10] Cannot set time limit - not in a valid club room");
                return;
            }
            
            auto builder = BRM::CreateRoomBuilder(serverInfo.clubId, serverInfo.roomId);
            builder.LoadCurrentSettingsAsync()
                   .SetTimeLimit(timeLimitSeconds)
                   .SaveRoom();
            
            //trace("[UBU10] Server time limit updated: " + timeLimitSeconds + "s");
        } catch {
            warn("[UBU10] Failed to set time limit: " + getExceptionInfo());
        }
    }

    void SwitchMap() {
        if (isSwitchingMap) return;
        
        //trace("[UBU10] Switching map");
        isSwitchingMap = true;
        PauseRun();

        try {
            medalController.Reset();
            
            if (playerTracker !is null) {
                playerTracker.ResetForNewMap();
                //trace("[UBU10] Player tracker reset for new map (medals preserved)");
            }

            string curUid = "";
            auto app = cast<CTrackMania>(GetApp());
            if (app !is null && app.RootMap !is null && app.RootMap.MapInfo !is null) {
                curUid = app.RootMap.MapInfo.MapUid;
            }

            @currentMapInfo = mapController.GetNextMap(curUid);
            
            if (currentMapInfo is null) {
                warn("[UBU10] No map available");
                isSwitchingMap = false;
                return;
            }

            //trace("[UBU10] Selected map: " + currentMapInfo.Name + " (" + currentMapInfo.MapUid + ")");

            @currentMedalData = FirebaseClient::GetMedalData(currentMapInfo.MapUid);
            
            if (currentMedalData is null) {
                warn("[UBU10] No medal data for map - using defaults");
                @currentMedalData = MedalData();
            }

            LoadMapAsync();
        } catch {
            warn("[UBU10] Map switch failed: " + getExceptionInfo());
            isSwitchingMap = false;
        }
    }

    void LoadMapAsync() {
        int timeLimitSeconds = -1;
        if (runTimeTotalMs > 0 && runTimeRemainingMs > 0) {
            timeLimitSeconds = runTimeRemainingMs / 1000;
        }
        
        mapController.LoadMapToRoom(currentMapInfo, timeLimitSeconds);

        const string wantUid = currentMapInfo.MapUid;
        uint startTime = Time::Now;
        bool activated = false;

        while (Time::Now - startTime < 30000) {
            yield();

            auto app = cast<CTrackMania>(GetApp());
            if (app !is null && app.RootMap !is null && app.RootMap.MapInfo !is null) {
                if (app.RootMap.MapInfo.MapUid == wantUid) {
                    activated = true;
                    //trace("[UBU10] Map activated");
                    break;
                }
            }
        }

        if (!activated) {
            warn("[UBU10] Map activation timeout");
        }

        isSwitchingMap = false;
        
        if (isFirstMap) {
            isFirstMap = false;
            ResumeRun();
        } else {
            ResumeRun();
        }
    }
    
    void SwitchToSpecificMap(MX::MapInfo@ mapInfo) {
        if (isSwitchingMap) return;
        if (mapInfo is null) {
            warn("[UBU10] Cannot switch to null map");
            return;
        }
        
        //trace("[UBU10] Switching to specific map: " + mapInfo.Name);
        isSwitchingMap = true;
        
        try {
            medalController.Reset();
            
            if (playerTracker !is null) {
                playerTracker.ResetForNewMap();
                //trace("[UBU10] Player tracker reset for new map (medals preserved)");
            }
            
            @currentMapInfo = mapInfo;
            
            //trace("[UBU10] Selected map: " + currentMapInfo.Name + " (" + currentMapInfo.MapUid + ")");
            
            @currentMedalData = FirebaseClient::GetMedalData(currentMapInfo.MapUid);
            
            if (currentMedalData is null) {
                warn("[UBU10] No medal data for map - using defaults");
                @currentMedalData = MedalData();  // Use defaults
            }
            
            LoadMapAsync();
        } catch {
            warn("[UBU10] Map switch failed: " + getExceptionInfo());
            isSwitchingMap = false;
        }
    }

    void Update(float dt) {
        if (!isRunning || isPaused || isSwitchingMap) return;

        if (runTimeTotalMs > 0 && runStartTime > 0 && runStartRemainingMs > 0) {
            int elapsed = Time::Now - runStartTime;
            runTimeRemainingMs = runStartRemainingMs - elapsed;

            if (runTimeRemainingMs <= 0 && !hasShownEndWindow) {
                if (endWindow !is null) {
                    endWindow.Open();
                    hasShownEndWindow = true;
                }
                StopRun(true);
            }
        }
        
        if (playerTracker !is null) {
            playerTracker.Update();
        }
    }

    void ClearMapsFolder() {
        string folder = IO::FromStorageFolder("Maps/");
        if (!IO::FolderExists(folder)) return;
        
        auto files = IO::IndexFolder(folder, false);
        for (uint i = 0; i < files.Length; i++) {
            IO::Delete(files[i]);
        }
        //trace("[UBU10] Maps folder cleared");
    }

    void CleanupJsonFiles() {
        try {
            string[] files = {
                UBU10Files::MapInfo,
                UBU10Files::PlayerInfo,
                UBU10Files::Targets
            };
            
            for (uint i = 0; i < files.Length; i++) {
                string path = IO::FromStorageFolder(files[i]);
                if (IO::FileExists(path)) {
                    IO::Delete(path);
                }
            }
            //trace("[UBU10] JSON files cleaned up");
        } catch {
            warn("[UBU10] Cleanup failed: " + getExceptionInfo());
        }
    }

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

    vec4 GetMedalColor(uint medalId) {
        switch (medalId) {
            case 0: return vec4(0.8, 0.5, 0.3, 1.0);   // Bronze
            case 1: return vec4(0.75, 0.75, 0.75, 1.0); // Silver
            case 2: return vec4(1.0, 0.84, 0.0, 1.0);   // Gold
            case 3: return vec4(0.2, 1.0, 0.2, 1.0);    // Author
            case 4: return vec4(0.9, 0.5, 0.0, 1.0);    // Harder
            case 5: return vec4(1.0, 0.2, 0.2, 1.0);    // Hardest
        }
        return vec4(0.5, 0.5, 0.5, 1.0);
    }

    string FormatTime(int ms) {
        if (ms < 0) return "--:--.---";
        return Time::Format(ms);
    }

    string FormatDuration(uint minutes) {
        uint hours = minutes / 60;
        uint mins = minutes % 60;
        if (hours > 0) {
            return tostring(hours) + "h " + tostring(mins) + "m";
        }
        return tostring(minutes) + " minutes";
    }
}
