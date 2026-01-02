// MedalData

class MedalData {
    string mapUid = "";
    int trackId = 0;
    string mapName = "";
    
    int bronzeTime = -1;
    int silverTime = -1;
    int goldTime = -1;
    int authorTime = -1;
    int harderTime = -1;
    int hardestTime = -1;
    int wrTime = -1;
    int recordsCount = 0;
    string method = "";
    
    MedalData() {}
    
    MedalData(Json::Value@ data) {
        if (data is null) return;
        
        try {
            if (data.HasKey("uid")) mapUid = string(data["uid"]);
            if (data.HasKey("trackId")) trackId = int(data["trackId"]);
            if (data.HasKey("name")) mapName = string(data["name"]);
            
            if (data.HasKey("authorTime_ms")) authorTime = int(data["authorTime_ms"]);
            if (data.HasKey("wrTime_ms")) wrTime = int(data["wrTime_ms"]);
            if (data.HasKey("recordsCount")) recordsCount = int(data["recordsCount"]);
            
            if (data.HasKey("computed")) {
                Json::Value computed = data["computed"];
                if (computed.HasKey("harderTime_ms")) harderTime = int(computed["harderTime_ms"]);
                if (computed.HasKey("medalTime_ms")) hardestTime = int(computed["medalTime_ms"]);
                if (computed.HasKey("method")) method = string(computed["method"]);
            }
            
            //trace("[MedalData] Loaded: " + mapName + " (AT=" + authorTime + " Harder=" + harderTime + " Hardest=" + hardestTime + ")");
        } catch {
            warn("[MedalData] Failed to parse medal data: " + getExceptionInfo());
        }
    }
    
    bool IsValid() {
        return mapUid.Length > 0 && authorTime > 0;
    }
    
    int GetMedalTime(uint medal) {
        switch (medal) {
            case 0: return bronzeTime;
            case 1: return silverTime;
            case 2: return goldTime;
            case 3: return authorTime;
            case 4: return harderTime;
            case 5: return hardestTime;
        }
        return -1;
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
}
