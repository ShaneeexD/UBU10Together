// PlayerTracker - Tracks player progress and updates leaderboard
// Uses MLFeed for race data access

class PlayerTracker {
    UBU10Controller@ controller;
    GameWindow@ gameWindow;
    
    dictionary playerTimes;  // playerName -> PlayerData
    dictionary playerMedalCounts;  // playerLogin -> medal count for session
    dictionary playerNames;  // playerLogin -> display name
    array<PlayerEntry@> sortedEntries;
    
    int lastUpdateTime = 0;
    int UPDATE_INTERVAL = 1000;  // Update every second
    
    PlayerTracker(UBU10Controller@ ctrl, GameWindow@ gw) {
        @controller = ctrl;
        @gameWindow = gw;
    }
    
    void Update() {
        if (!controller.isRunning) return;
        
        int now = Time::Now;
        if (now - lastUpdateTime < UPDATE_INTERVAL) return;
        lastUpdateTime = now;
        
        // Get player data from MLFeed
        UpdatePlayerDataFromFeed();
        
        // Update leaderboard
        UpdateLeaderboard();
        
        // Save to JSON for MedalController
        SavePlayerInfo();
    }
    
    void UpdatePlayerDataFromFeed() {
        // Use MLFeed V4 to get race data
        auto raceData = MLFeed::GetRaceData_V4();
        if (raceData is null || raceData.SortedPlayers_TimeAttack is null) return;
        
        // Process each player in time attack
        for (uint i = 0; i < raceData.SortedPlayers_TimeAttack.Length; i++) {
            auto player = cast<MLFeed::PlayerCpInfo_V4>(raceData.SortedPlayers_TimeAttack[i]);
            if (player is null) continue;
            
            ProcessPlayerFromFeed(player);
        }
    }
    
    void ProcessPlayerFromFeed(MLFeed::PlayerCpInfo_V4@ player) {
        if (player is null || player.Name == "") return;
        
        string login = player.Login;
        string name = player.Name;
        
        // Store player name for this login (for persistent leaderboard display)
        playerNames.Set(login, name);
        
        // Get best time
        int bestTime = player.BestTime;
        if (bestTime <= 0) return;  // No valid time yet
        
        // Calculate medal achieved
        uint medal = CalculateMedal(bestTime);
        
        // Store or update player data
        PlayerData@ data;
        if (playerTimes.Exists(login)) {
            playerTimes.Get(login, @data);
            
            // Update if better time
            if (bestTime < data.time) {
                data.time = bestTime;
                data.medal = medal;
            }
        } else {
            @data = PlayerData(name, login, bestTime, medal);
            playerTimes.Set(login, @data);
        }
    }
    
    // Note: Fallback direct game API removed - MLFeed V4 is required for proper race data
    
    uint CalculateMedal(int time) {
        if (controller.currentMedalData is null) {
            return 0;  // No medal
        }
        
        auto md = controller.currentMedalData;
        
        // Check medals from highest to lowest
        if (md.hardestTime > 0 && time <= md.hardestTime) return 5;  // Hardest
        if (md.harderTime > 0 && time <= md.harderTime) return 4;    // Harder
        if (md.authorTime > 0 && time <= md.authorTime) return 3;    // Author
        if (md.goldTime > 0 && time <= md.goldTime) return 2;        // Gold
        if (md.silverTime > 0 && time <= md.silverTime) return 1;    // Silver
        if (md.bronzeTime > 0 && time <= md.bronzeTime) return 0;    // Bronze
        
        return 0;  // No medal
    }
    
    void UpdateLeaderboard() {
        // Clear sorted entries
        sortedEntries.RemoveRange(0, sortedEntries.Length);
        
        // Track which players we've already added from playerTimes
        dictionary addedPlayers;
        
        // First, add all players who have driven times on this map
        auto timeKeys = playerTimes.GetKeys();
        for (uint i = 0; i < timeKeys.Length; i++) {
            PlayerData@ data;
            playerTimes.Get(timeKeys[i], @data);
            
            // Get medal count for this player
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
        
        // Then, add players who have medal counts but no time on current map
        auto medalKeys = playerMedalCounts.GetKeys();
        for (uint i = 0; i < medalKeys.Length; i++) {
            string login = medalKeys[i];
            
            // Skip if already added
            if (addedPlayers.Exists(login)) continue;
            
            // Get player name from stored names (use login as fallback)
            string playerName = login;
            if (playerNames.Exists(login)) {
                playerNames.Get(login, playerName);
            }
            
            // Get medal count
            int64 count;
            playerMedalCounts.Get(login, count);
            uint medalCount = uint(count);
            
            // Create entry with no time (-1 will display as "--:--.---")
            PlayerEntry@ entry = PlayerEntry(playerName, -1, 0, medalCount);
            sortedEntries.InsertLast(entry);
        }
        
        // Sort by time (ascending, players without times go to bottom)
        sortedEntries.SortAsc();
        
        // Update game window
        if (gameWindow !is null) {
            gameWindow.UpdateLeaderboard(sortedEntries);
        }
    }
    
    void SavePlayerInfo() {
        string path = IO::FromStorageFolder("UBU10_PlayerInfo.json");
        
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
        // Increment the medal count for this player in the session
        int64 count = 0;
        if (playerMedalCounts.Exists(playerLogin)) {
            playerMedalCounts.Get(playerLogin, count);
        }
        count++;
        playerMedalCounts.Set(playerLogin, count);
        
        // Update leaderboard immediately to show new medal count
        UpdateLeaderboard();
        trace("[PlayerTracker] 🏅 Medal awarded to " + playerLogin + " (total: " + count + ")");
    }
    
    void ResetForNewMap() {
        // Clear times for new map but KEEP medal counts for the session
        playerTimes.DeleteAll();
        sortedEntries.RemoveRange(0, sortedEntries.Length);
        
        // Clear saved data
        string path = IO::FromStorageFolder("UBU10_PlayerInfo.json");
        if (IO::FileExists(path)) {
            IO::Delete(path);
        }
        
        trace("[PlayerTracker] 🔄 Reset for new map (medal counts preserved)");
    }
    
    void Reset() {
        // Full reset including medal counts (for session end)
        playerTimes.DeleteAll();
        playerMedalCounts.DeleteAll();
        playerNames.DeleteAll();
        sortedEntries.RemoveRange(0, sortedEntries.Length);
        
        // Clear saved data
        string path = IO::FromStorageFolder("UBU10_PlayerInfo.json");
        if (IO::FileExists(path)) {
            IO::Delete(path);
        }
        
        trace("[PlayerTracker] 🔄 Full reset");
    }
    
    // Get player with most medals for end screen
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
                
                // Get display name from playerNames
                if (playerNames.Exists(login)) {
                    playerNames.Get(login, name);
                } else {
                    name = login;  // Fallback to login
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
