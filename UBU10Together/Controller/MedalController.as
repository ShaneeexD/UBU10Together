// MedalController - Watches for players reaching target medals and triggers map changes

// Cooldown to prevent false medal detections right after map change
const int MAP_CHANGE_COOLDOWN_MS = 8000;

class MedalController {
    UBU10Controller@ controller;
    bool isWatching = false;
    
    // State tracking
    bool isWaitingForSwitch = false;
    string currentMapUid = "";
    bool firstWinnerRecorded = false;
    int lastMapChangeTime = 0;  // Time::Now when map last changed
    
    MedalController(UBU10Controller@ ctrl) {
        @controller = ctrl;
    }
    
    void StartWatching() {
        if (isWatching) return;
        isWatching = true;
        //trace("[MedalController] Started watching");
        startnew(CoroutineFunc(this.WatchLoop));
    }
    
    void Reset() {
        firstWinnerRecorded = false;
        isWaitingForSwitch = false;
        lastMapChangeTime = Time::Now;  // Set cooldown timestamp
        
        // Clear player info file to prevent false medal detections
        string playerInfoPath = IO::FromStorageFolder(UBU10Files::PlayerInfo);
        if (IO::FileExists(playerInfoPath)) {
            IO::Delete(playerInfoPath);
        }
        
        //trace("[MedalController] Reset for new map (cooldown: " + MAP_CHANGE_COOLDOWN_MS + "ms)");
    }
    
    void WatchLoop() {
        while (isWatching) {
            yield();
            
            if (!controller.isRunning || controller.isPaused || controller.isSwitchingMap) {
                continue;
            }
            
            // Check if map changed (auto-detect)
            string uidNow = GetCurrentMapUid();
            if (uidNow.Length > 0 && uidNow != currentMapUid) {
                currentMapUid = uidNow;
                Reset();
                //trace("[MedalController] Map changed: " + uidNow);
            }
            
            // Cooldown: prevent false detections right after map change
            // MLFeed writes player data asynchronously, which causes old map medals to appear on new map
            int timeSinceMapChange = Time::Now - lastMapChangeTime;
            if (timeSinceMapChange < MAP_CHANGE_COOLDOWN_MS) {
                continue;  // Still in cooldown period
            }
            
            if (!isWaitingForSwitch && !firstWinnerRecorded) {
                if (CheckIfTargetMedalReached()) {
                    //trace("[MedalController] Target medal reached!");
                    isWaitingForSwitch = true;
                    
                    // Credit winner
                    CreditFirstWinner();
                    
                    // Trigger map change
                    controller.SwitchMap();
                    
                    // Wait for map to change
                    startnew(CoroutineFunc(this.WaitForMapChange));
                }
            }
        }
    }
    
    void WaitForMapChange() {
        string fromUid = currentMapUid;
        int startTime = Time::Now;
        
        // Wait up to 15 seconds for map change
        while (Time::Now - startTime < 15000) {
            yield();
            
            string uidNow = GetCurrentMapUid();
            if (uidNow.Length > 0 && uidNow != fromUid) {
                //trace("[MedalController] Map change confirmed");
                isWaitingForSwitch = false;
                return;
            }
        }
        
        // Timeout - re-enable watching
        //trace("[MedalController] Map change timeout - re-enabling");
        isWaitingForSwitch = false;
    }
    
    bool CheckIfTargetMedalReached() {
        string path = IO::FromStorageFolder(UBU10Files::PlayerInfo);
        if (!IO::FileExists(path)) return false;
        
        try {
            Json::Value data = Json::FromFile(path);
            if (data.GetType() != Json::Type::Array) return false;
            
            int targetMedal = int(controller.selectedMedal);
            
            for (uint i = 0; i < data.Length; i++) {
                Json::Value player = data[i];
                if (player.GetType() != Json::Type::Object) continue;
                if (!player.HasKey("medal")) continue;
                
                int medal = int(player["medal"]);
                if (medal >= targetMedal) {
                    return true;
                }
            }
        } catch {
            warn("[MedalController] Error checking medals: " + getExceptionInfo());
        }
        
        return false;
    }
    
    void CreditFirstWinner() {
        if (firstWinnerRecorded) return;
        firstWinnerRecorded = true;
        
        string winnerName = GetFirstWinnerName();
        string winnerLogin = GetFirstWinnerLogin();
        if (winnerName.Length == 0) {
            winnerName = "Unknown";
        }
        
        // Increment win count in targets file
        IncrementWinCount(winnerName);
        
        // Increment session medal count in PlayerTracker
        if (controller.playerTracker !is null && winnerLogin.Length > 0) {
            controller.playerTracker.IncrementPlayerMedalCount(winnerLogin);
        }
        
        //trace("[MedalController] Winner credited: " + winnerName);
    }
    
    string GetFirstWinnerName() {
        string path = IO::FromStorageFolder(UBU10Files::PlayerInfo);
        if (!IO::FileExists(path)) return "";
        
        try {
            Json::Value data = Json::FromFile(path);
            if (data.GetType() != Json::Type::Array) return "";
            
            int targetMedal = int(controller.selectedMedal);
            
            // Find first player with target medal
            for (uint i = 0; i < data.Length; i++) {
                Json::Value player = data[i];
                if (player.GetType() != Json::Type::Object) continue;
                if (!player.HasKey("medal")) continue;
                
                int medal = int(player["medal"]);
                if (medal >= targetMedal) {
                    if (player.HasKey("name")) return string(player["name"]);
                    if (player.HasKey("playerName")) return string(player["playerName"]);
                    if (player.HasKey("login")) return string(player["login"]);
                }
            }
        } catch {
            warn("[MedalController] Error getting winner: " + getExceptionInfo());
        }
        
        return "";
    }
    
    string GetFirstWinnerLogin() {
        string path = IO::FromStorageFolder(UBU10Files::PlayerInfo);
        if (!IO::FileExists(path)) return "";
        
        try {
            Json::Value data = Json::FromFile(path);
            if (data.GetType() != Json::Type::Array) return "";
            
            int targetMedal = int(controller.selectedMedal);
            
            // Find first player with target medal
            for (uint i = 0; i < data.Length; i++) {
                Json::Value player = data[i];
                if (player.GetType() != Json::Type::Object) continue;
                if (!player.HasKey("medal")) continue;
                
                int medal = int(player["medal"]);
                if (medal >= targetMedal) {
                    if (player.HasKey("login")) return string(player["login"]);
                }
            }
        } catch {
            warn("[MedalController] Error getting winner login: " + getExceptionInfo());
        }
        
        return "";
    }
    
    void IncrementWinCount(const string &in playerName) {
        string path = IO::FromStorageFolder(UBU10Files::Targets);
        
        Json::Value data;
        if (IO::FileExists(path)) {
            try {
                data = Json::FromFile(path);
            } catch {
                data = Json::Object();
            }
        } else {
            data = Json::Object();
        }
        
        if (data.GetType() != Json::Type::Object) {
            data = Json::Object();
        }
        
        int currentCount = 0;
        if (data.HasKey(playerName)) {
            currentCount = int(data[playerName]);
        }
        
        data[playerName] = currentCount + 1;
        
        Json::ToFile(path, data);
    }
    
    string GetCurrentMapUid() {
        auto app = cast<CTrackMania>(GetApp());
        if (app is null || app.RootMap is null || app.RootMap.MapInfo is null) {
            return "";
        }
        return app.RootMap.MapInfo.MapUid;
    }
}
