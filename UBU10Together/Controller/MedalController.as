// MedalController - Watches for target medal and triggers map changes

const int MAP_CHANGE_COOLDOWN_MS = 8000;

class MedalController {
    UBU10Controller@ controller;
    bool isWatching = false;
    
    bool isWaitingForSwitch = false;
    string currentMapUid = "";
    bool firstWinnerRecorded = false;
    int lastMapChangeTime = 0;
    
    MedalController(UBU10Controller@ ctrl) {
        @controller = ctrl;
    }
    
    void StartWatching() {
        if (isWatching) return;
        isWatching = true;
        startnew(CoroutineFunc(this.WatchLoop));
    }
    
    void Reset() {
        firstWinnerRecorded = false;
        isWaitingForSwitch = false;
        lastMapChangeTime = Time::Now;
        
        string playerInfoPath = IO::FromStorageFolder(UBU10Files::PlayerInfo);
        if (IO::FileExists(playerInfoPath)) {
            IO::Delete(playerInfoPath);
        }  
    }
    
    void WatchLoop() {
        while (isWatching) {
            yield();
            
            if (!controller.isRunning || controller.isPaused || controller.isSwitchingMap) {
                continue;
            }
            
            string uidNow = GetCurrentMapUid();
            if (uidNow.Length > 0 && uidNow != currentMapUid) {
                currentMapUid = uidNow;
                Reset();
            }
            
            int timeSinceMapChange = Time::Now - lastMapChangeTime;
            if (timeSinceMapChange < MAP_CHANGE_COOLDOWN_MS) {
                continue;
            }
            
            if (!isWaitingForSwitch && !firstWinnerRecorded) {
                if (CheckIfTargetMedalReached()) {
                    isWaitingForSwitch = true;
                    
                    CreditFirstWinner();
                    controller.SwitchMap();
                    startnew(CoroutineFunc(this.WaitForMapChange));
                }
            }
        }
    }
    
    void WaitForMapChange() {
        string fromUid = currentMapUid;
        int startTime = Time::Now;
        
        while (Time::Now - startTime < 15000) {
            yield();
            
            string uidNow = GetCurrentMapUid();
            if (uidNow.Length > 0 && uidNow != fromUid) {
                isWaitingForSwitch = false;
                return;
            }
        }
        
        isWaitingForSwitch = false;
    }
    
    bool CheckIfTargetMedalReached() {
        if (controller.playerTracker is null) return false;
        
        int targetMedal = int(controller.selectedMedal);
        auto playerTimes = controller.playerTracker.playerTimes;
        auto keys = playerTimes.GetKeys();
        
        for (uint i = 0; i < keys.Length; i++) {
            PlayerData@ data;
            playerTimes.Get(keys[i], @data);
            if (data !is null && int(data.medal) >= targetMedal) {
                return true;
            }
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
        
        IncrementWinCount(winnerName);
        
        if (controller.playerTracker !is null && winnerLogin.Length > 0) {
            controller.playerTracker.IncrementPlayerMedalCount(winnerLogin);
        }
    }
    
    string GetFirstWinnerName() {
        if (controller.playerTracker is null) return "";
        
        int targetMedal = int(controller.selectedMedal);
        auto playerTimes = controller.playerTracker.playerTimes;
        auto keys = playerTimes.GetKeys();
        
        for (uint i = 0; i < keys.Length; i++) {
            PlayerData@ data;
            playerTimes.Get(keys[i], @data);
            if (data !is null && int(data.medal) >= targetMedal) {
                return data.name;
            }
        }
        return "";
    }
    
    string GetFirstWinnerLogin() {
        if (controller.playerTracker is null) return "";
        
        int targetMedal = int(controller.selectedMedal);
        auto playerTimes = controller.playerTracker.playerTimes;
        auto keys = playerTimes.GetKeys();
        
        for (uint i = 0; i < keys.Length; i++) {
            PlayerData@ data;
            playerTimes.Get(keys[i], @data);
            if (data !is null && int(data.medal) >= targetMedal) {
                return data.login;
            }
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
