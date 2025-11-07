// MedalOverlay - In-game overlay showing target medal times
// Visible to all players with the plugin, not just the host

class MedalOverlay {
    bool isVisible = false;
    MedalData@ currentMedalData = null;
    string currentMapUid = "";
    int lastFetchTime = 0;
    bool hasTriedFetch = false; // Only try once per map
    Net::HttpRequest@ pendingRequest = null; // Async request handling
    
    void Render() {
        // Check if in playground
        auto app = cast<CTrackMania>(GetApp());
        if (app is null || app.CurrentPlayground is null) {
            currentMapUid = "";
            return;
        }
        
        // Get current map UID
        string mapUid = GetCurrentMapUid();
        if (mapUid.Length == 0) return;
        
        // Update medal data if map changed
        if (mapUid != currentMapUid) {
            currentMapUid = mapUid;
            @currentMedalData = null;
            hasTriedFetch = false;
            @pendingRequest = null;
            FetchMedalDataAsync();
        } else if (currentMedalData is null && !hasTriedFetch && pendingRequest is null) {
            // Only retry once per map
            FetchMedalDataAsync();
        }
        
        // Check if async request completed
        CheckAsyncRequest();
        
        // Only show when have medal data (always visible for all players)
        if (currentMedalData is null) {
            return;
        }
        
        // Don't show if interface is hidden (optional)
        if (!UI::IsGameUIVisible()) return;
        
        int window_flags = UI::WindowFlags::NoTitleBar |
                           UI::WindowFlags::NoResize |
                           UI::WindowFlags::NoScrollbar |
                           UI::WindowFlags::NoScrollWithMouse |
                           UI::WindowFlags::AlwaysAutoResize |
                           UI::WindowFlags::NoDocking;
        
        // Prevent moving when overlay is not shown
        if (!UI::IsOverlayShown()) window_flags |= UI::WindowFlags::NoMove;
        
        if (UI::Begin("UBU10 Medal Times", window_flags)) {
            auto medalData = currentMedalData;
            int playerPB = GetPlayerPersonalBest();
            
            if (UI::BeginTable("##medals", 3)) {
                // Hardest medal row (first)
                if (medalData.hardestTime > 0) {
                    UI::TableNextRow();
                    
                    UI::TableNextColumn();
                    vec4 hardestColor = vec4(1.0, 0.2, 0.2, 1.0);  // Red
                    UI::PushStyleColor(UI::Col::Text, hardestColor);
                    UI::Text("●");
                    UI::PopStyleColor();
                    
                    UI::TableNextColumn();
                    UI::Text("Hardest");
                    
                    UI::TableNextColumn();
                    string timeText = Time::Format(medalData.hardestTime);
                    if (playerPB > 0 && playerPB != medalData.hardestTime) {
                        int delta = playerPB - medalData.hardestTime;
                        if (delta > 0) {
                            // PB is slower - show time needed to improve (red +)
                            timeText += "  \\$f77+" + Time::Format(delta);
                        } else {
                            // PB is faster - show time beaten by (blue -)
                            timeText += "  \\$77f-" + Time::Format(-delta);
                        }
                    }
                    UI::Text(timeText);
                }
                
                // Harder medal row (second)
                if (medalData.harderTime > 0) {
                    UI::TableNextRow();
                    
                    UI::TableNextColumn();
                    vec4 harderColor = vec4(0.9, 0.5, 0.0, 1.0);  // Orange
                    UI::PushStyleColor(UI::Col::Text, harderColor);
                    UI::Text("●");
                    UI::PopStyleColor();
                    
                    UI::TableNextColumn();
                    UI::Text("Harder");
                    
                    UI::TableNextColumn();
                    string timeText = Time::Format(medalData.harderTime);
                    if (playerPB > 0 && playerPB != medalData.harderTime) {
                        int delta = playerPB - medalData.harderTime;
                        if (delta > 0) {
                            // PB is slower - show time needed to improve (red +)
                            timeText += "  \\$f77+" + Time::Format(delta);
                        } else {
                            // PB is faster - show time beaten by (blue -)
                            timeText += "  \\$77f-" + Time::Format(-delta);
                        }
                    }
                    UI::Text(timeText);
                }
                
                UI::EndTable();
            }
            
            UI::End();
        }
    }
    
    void Show() {
        isVisible = true;
    }
    
    void Hide() {
        isVisible = false;
    }
    
    void Toggle() {
        isVisible = !isVisible;
    }
    
    string GetCurrentMapUid() {
        auto app = cast<CTrackMania>(GetApp());
        if (app is null || app.RootMap is null || app.RootMap.MapInfo is null) {
            return "";
        }
        return app.RootMap.MapInfo.MapUid;
    }
    
    void FetchMedalDataAsync() {
        lastFetchTime = Time::Now;
        hasTriedFetch = true;
        
        if (currentMapUid.Length == 0) return;
        
        // Check cache first (non-blocking)
        @currentMedalData = GetCachedMedalData(currentMapUid);
        if (currentMedalData !is null) {
            trace("[MedalOverlay] Cache hit for: " + currentMedalData.mapName);
            return;
        }
        
        // Start async Firebase request
        trace("[MedalOverlay] Starting async fetch for: " + currentMapUid);
        string url = "https://ubu10together-default-rtdb.europe-west1.firebasedatabase.app/ubu10/" + currentMapUid + ".json";
        @pendingRequest = Net::HttpGet(url);
    }
    
    void CheckAsyncRequest() {
        if (pendingRequest is null) return;
        
        // Check if request finished
        if (!pendingRequest.Finished()) return;
        
        // Process completed request
        try {
            if (pendingRequest.ResponseCode() == 200) {
                string jsonStr = pendingRequest.String();
                if (jsonStr.Length > 0 && jsonStr != "null") {
                    Json::Value data = Json::Parse(jsonStr);
                    if (data !is null) {
                        @currentMedalData = MedalData(data);
                        if (currentMedalData !is null && currentMedalData.IsValid()) {
                            trace("[MedalOverlay] Async loaded: " + currentMedalData.mapName);
                            CacheMedalData(currentMapUid, currentMedalData);
                        } else {
                            trace("[MedalOverlay] Invalid medal data for: " + currentMapUid);
                        }
                    }
                } else {
                    trace("[MedalOverlay] No data found for: " + currentMapUid);
                }
            } else {
                trace("[MedalOverlay] HTTP " + pendingRequest.ResponseCode() + " for: " + currentMapUid);
            }
        } catch {
            trace("[MedalOverlay] Exception processing response: " + getExceptionInfo());
        }
        
        // Clear pending request
        @pendingRequest = null;
    }
    
    // Simple cache functions (avoid FirebaseClient to prevent suspension issues)
    MedalData@ GetCachedMedalData(const string &in mapUid) {
        // For now, no caching to keep it simple and avoid suspension issues
        return null;
    }
    
    void CacheMedalData(const string &in mapUid, MedalData@ data) {
        // For now, no caching to keep it simple
    }
    
    int GetPlayerPersonalBest() {
        // Use MLFeed to get current player's best time
        auto raceData = MLFeed::GetRaceData_V4();
        if (raceData is null || raceData.SortedPlayers_TimeAttack is null) {
            return -1;
        }
        
        // Get current player's login with proper null checks
        auto app = cast<CTrackMania>(GetApp());
        if (app is null || app.CurrentPlayground is null) {
            return -1;
        }
        
        if (app.CurrentPlayground.GameTerminals.Length == 0) {
            return -1;
        }
        
        auto terminal = app.CurrentPlayground.GameTerminals[0];
        if (terminal is null || terminal.GUIPlayer is null) {
            return -1;
        }
        
        auto user = terminal.GUIPlayer.User;
        if (user is null) {
            return -1;
        }
        
        string currentLogin = user.Login;
        
        // Find current player in race data
        for (uint i = 0; i < raceData.SortedPlayers_TimeAttack.Length; i++) {
            auto player = cast<MLFeed::PlayerCpInfo_V4>(raceData.SortedPlayers_TimeAttack[i]);
            if (player is null) continue;
            
            if (player.Login == currentLogin) {
                return player.BestTime;
            }
        }
        
        return -1; // Player not found or no time set
    }
}
