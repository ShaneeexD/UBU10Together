// MedalOverlay

class MedalOverlay {
    bool isVisible = false;
    MedalData@ currentMedalData = null;
    string currentMapUid = "";
    int lastFetchTime = 0;
    bool hasTriedFetch = false;
    Net::HttpRequest@ pendingRequest = null;
    
    void Render() {
        auto app = cast<CTrackMania>(GetApp());
        if (app is null || app.CurrentPlayground is null) {
            currentMapUid = "";
            return;
        }
        
        string mapUid = GetCurrentMapUid();
        if (mapUid.Length == 0) return;
        
        if (mapUid != currentMapUid) {
            currentMapUid = mapUid;
            @currentMedalData = null;
            hasTriedFetch = false;
            @pendingRequest = null;
            FetchMedalDataAsync();
        } else if (currentMedalData is null && !hasTriedFetch && pendingRequest is null) {
            FetchMedalDataAsync();
        }
        
        CheckAsyncRequest();
        
        if (currentMedalData is null) {
            return;
        }
        
        if (!UI::IsGameUIVisible()) return;
        
        int window_flags = UI::WindowFlags::NoTitleBar |
                           UI::WindowFlags::NoResize |
                           UI::WindowFlags::NoScrollbar |
                           UI::WindowFlags::NoScrollWithMouse |
                           UI::WindowFlags::AlwaysAutoResize |
                           UI::WindowFlags::NoDocking;
        
        if (!UI::IsOverlayShown()) window_flags |= UI::WindowFlags::NoMove;
        
        if (UI::Begin("UBU10 Medal Times", window_flags)) {
            auto medalData = currentMedalData;
            int playerPB = GetPlayerPersonalBest();
            
            if (UI::BeginTable("##medals", 3)) {
                if (medalData.hardestTime > 0) {
                    UI::TableNextRow();
                    
                    UI::TableNextColumn();
                    vec4 hardestColor = vec4(1.0, 0.2, 0.2, 1.0);
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
                            timeText += "  \\$f77+" + Time::Format(delta);
                        } else {
                            timeText += "  \\$77f-" + Time::Format(-delta);
                        }
                    }
                    UI::Text(timeText);
                }
                
                if (medalData.harderTime > 0) {
                    UI::TableNextRow();
                    
                    UI::TableNextColumn();
                    vec4 harderColor = vec4(0.9, 0.5, 0.0, 1.0);
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
                            timeText += "  \\$f77+" + Time::Format(delta);
                        } else {
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
        
        //trace("[MedalOverlay] Starting async fetch for: " + currentMapUid);
        string url = UBU10Files::FirebaseUrl + currentMapUid + ".json"; 
        @pendingRequest = Net::HttpGet(url);
    }
    
    void CheckAsyncRequest() {
        if (pendingRequest is null) return;
        
        if (!pendingRequest.Finished()) return;
        
        try {
            if (pendingRequest.ResponseCode() == 200) {
                string jsonStr = pendingRequest.String();
                if (jsonStr.Length > 0 && jsonStr != "null") {
                    Json::Value data = Json::Parse(jsonStr);
                    if (data !is null) {
                        @currentMedalData = MedalData(data);
                        if (currentMedalData !is null && currentMedalData.IsValid()) {
                            //trace("[MedalOverlay] Async loaded: " + currentMedalData.mapName);
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
        
        @pendingRequest = null;
    }
    
    int GetPlayerPersonalBest() {
        auto raceData = MLFeed::GetRaceData_V4();
        if (raceData is null || raceData.SortedPlayers_TimeAttack is null) {
            return -1;
        }
        
        for (uint i = 0; i < raceData.SortedPlayers_TimeAttack.Length; i++) {
            auto player = cast<MLFeed::PlayerCpInfo_V4>(raceData.SortedPlayers_TimeAttack[i]);
            if (player is null) continue;
            
            if (player.IsLocalPlayer) {
                return player.BestTime;
            }
        }
        
        return -1;
    }
}
