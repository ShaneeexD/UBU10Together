// PlayerTracker - Tracks player times and medals

class PlayerTracker {
    UBU10Controller@ controller;
    GameWindow@ gameWindow;
    
    dictionary playerTimes;
    dictionary playerMedalCounts;
    dictionary playerNames;
    array<PlayerEntry@> sortedEntries;
    
    int lastUpdateTime = 0;
    int UPDATE_INTERVAL = 1000;
    bool playerDataDirty = false;
    int lastRecordTime = -1;
    
    PlayerTracker(UBU10Controller@ ctrl, GameWindow@ gw) {
        @controller = ctrl;
        @gameWindow = gw;
    }
    
    void Update() {
        if (!controller.isRunning) return;
        
        int now = Time::Now;
        if (now - lastUpdateTime < UPDATE_INTERVAL) return;
        lastUpdateTime = now;
        
        UpdatePlayerDataFromFeed();
        UpdateLeaderboard();
        SavePlayerInfo();
    }
    
    void UpdatePlayerDataFromFeed() {
        auto raceData = MLFeed::GetRaceData_V4();
        if (raceData is null || raceData.SortedPlayers_TimeAttack is null) return;
        
        if (raceData.LastRecordTime != lastRecordTime && raceData.LastRecordTime > 0) {
            lastRecordTime = raceData.LastRecordTime;
            playerDataDirty = true;
        }
        
        for (uint i = 0; i < raceData.SortedPlayers_TimeAttack.Length; i++) {
            auto player = cast<MLFeed::PlayerCpInfo_V4>(raceData.SortedPlayers_TimeAttack[i]);
            if (player is null) continue;
            
            if (!player.IsSpawned) continue;
            
            ProcessPlayerFromFeed(player);
        }
    }
    
    void ProcessPlayerFromFeed(MLFeed::PlayerCpInfo_V4@ player) {
        if (player is null || player.Name == "") return;
        
        string identifier = player.WebServicesUserId;
        if (identifier == "") identifier = player.Login;
        string name = player.Name;
        
        playerNames.Set(identifier, name);
        
        int bestTime = player.BestTime;
        if (bestTime <= 0) return;
        
        uint medal = CalculateMedal(bestTime);
        PlayerData@ data;
        if (playerTimes.Exists(identifier)) {
            playerTimes.Get(identifier, @data);
            
            if (bestTime < data.time) {
                data.time = bestTime;
                data.medal = medal;
                playerDataDirty = true;
            }
        } else {
            @data = PlayerData(name, identifier, bestTime, medal);
            playerTimes.Set(identifier, @data);
            playerDataDirty = true;
        }
    }
        
    uint CalculateMedal(int time) {
        if (controller.currentMedalData is null) {
            return 0;  // No medal
        }
        
        auto md = controller.currentMedalData;
        
        if (md.hardestTime > 0 && time <= md.hardestTime) return 5;
        if (md.harderTime > 0 && time <= md.harderTime) return 4;
        if (md.authorTime > 0 && time <= md.authorTime) return 3;
        if (md.goldTime > 0 && time <= md.goldTime) return 2;
        if (md.silverTime > 0 && time <= md.silverTime) return 1;
        if (md.bronzeTime > 0 && time <= md.bronzeTime) return 0;
        
        return 0;
    }
    
    void UpdateLeaderboard() {
        sortedEntries.RemoveRange(0, sortedEntries.Length);
        dictionary addedPlayers;
        
        auto timeKeys = playerTimes.GetKeys();
        for (uint i = 0; i < timeKeys.Length; i++) {
            PlayerData@ data;
            playerTimes.Get(timeKeys[i], @data);
            
            uint medalCount = 0;
            if (playerMedalCounts.Exists(data.login)) {
                int64 count;
                playerMedalCounts.Get(data.login, count);
                medalCount = uint(count);
            }
            
            PlayerEntry@ entry = PlayerEntry(data.name, data.time, data.medal, medalCount);
            sortedEntries.InsertLast(entry);
            addedPlayers.Set(data.login, true);
        }
        
        auto medalKeys = playerMedalCounts.GetKeys();
        for (uint i = 0; i < medalKeys.Length; i++) {
            string login = medalKeys[i];
            
            if (addedPlayers.Exists(login)) continue;
            
            string playerName = login;
            if (playerNames.Exists(login)) {
                playerNames.Get(login, playerName);
            }
            
            int64 count;
            playerMedalCounts.Get(login, count);
            uint medalCount = uint(count);
            
            PlayerEntry@ entry = PlayerEntry(playerName, -1, 0, medalCount);
            sortedEntries.InsertLast(entry);
        }
        
        sortedEntries.SortAsc();
        
        if (gameWindow !is null) {
            gameWindow.UpdateLeaderboard(sortedEntries);
        }
    }
    
    void SavePlayerInfo() {
        if (!playerDataDirty) return;
        playerDataDirty = false;
        
        string path = IO::FromStorageFolder(UBU10Files::PlayerInfo);
        
        Json::Value arr = Json::Array();
        
        auto keys = playerTimes.GetKeys();
        for (uint i = 0; i < keys.Length; i++) {
            PlayerData@ data;
            playerTimes.Get(keys[i], @data);
            
            Json::Value player = Json::Object();
            player["name"] = data.name;
            player["login"] = data.login;
            player["time"] = data.time;
            player["medal"] = int(data.medal);
            
            arr.Add(player);
        }
        
        Json::ToFile(path, arr);
    }
    
    void IncrementPlayerMedalCount(const string &in playerLogin) {
        int64 count = 0;
        if (playerMedalCounts.Exists(playerLogin)) {
            playerMedalCounts.Get(playerLogin, count);
        }
        count++;
        playerMedalCounts.Set(playerLogin, count);
        
        UpdateLeaderboard();
        //trace("[PlayerTracker] Medal awarded to " + playerLogin + " (total: " + count + ")");
    }
    
    void ResetForNewMap() {
        playerTimes.DeleteAll();
        sortedEntries.RemoveRange(0, sortedEntries.Length);
        
        string path = IO::FromStorageFolder(UBU10Files::PlayerInfo);
        if (IO::FileExists(path)) {
            IO::Delete(path);
        }
        
        //trace("[PlayerTracker] Reset for new map (medal counts preserved)");
    }
    
    void Reset() {
        playerTimes.DeleteAll();
        playerMedalCounts.DeleteAll();
        playerNames.DeleteAll();
        sortedEntries.RemoveRange(0, sortedEntries.Length);
        
        string path = IO::FromStorageFolder(UBU10Files::PlayerInfo);
        if (IO::FileExists(path)) {
            IO::Delete(path);
        }
        
        //trace("[PlayerTracker] Full reset");
    }
    
    void GetWinner(string &out name, int &out count) {
        name = "";
        count = 0;
        
        auto keys = playerMedalCounts.GetKeys();
        for (uint i = 0; i < keys.Length; i++) {
            string login = keys[i];
            int64 medalCount;
            playerMedalCounts.Get(login, medalCount);
            
            if (int(medalCount) > count) {
                count = int(medalCount);
                
                if (playerNames.Exists(login)) {
                    playerNames.Get(login, name);
                } else {
                    name = login;
                }
            }
        }
        
        if (name.Length == 0) {
            name = "No data";
            count = 0;
        }
    }
}

// Player data class
class PlayerData {
    string name;
    string login;
    int time;
    uint medal;
    
    PlayerData(const string &in n, const string &in l, int t, uint m) {
        name = n;
        login = l;
        time = t;
        medal = m;
    }
}
