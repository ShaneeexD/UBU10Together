// MapController - Simplified version using Firebase map list

class MapController {
    array<MX::MapInfo@> mapList;
    array<string> playedMapUids;
    
    MapController() {
        // Constructor
    }
    
    // Load map list from Firebase
    bool LoadMapList() {
        trace("[MapController] 📥 Fetching UBU10 maps from Firebase");
        
        try {
            // Fetch all medal data from Firebase
            dictionary@ allData = FirebaseClient::GetAllMedalData();
            
            if (allData is null) {
                warn("[MapController] ❌ Failed to fetch map data from Firebase");
                return false;
            }
            
            // Convert to MapInfo array
            auto keys = allData.GetKeys();
            for (uint i = 0; i < keys.Length; i++) {
                string uid = keys[i];
                MedalData@ data;
                allData.Get(uid, @data);
                
                if (data !is null && data.IsValid()) {
                    MX::MapInfo@ info = MX::MapInfo(uid, data.mapName);
                    info.TrackID = data.trackId;
                    mapList.InsertLast(info);
                }
            }
            
            if (mapList.Length == 0) {
                warn("[MapController] ❌ No valid maps found in Firebase");
                return false;
            }
            
            trace("[MapController] ✅ Loaded " + mapList.Length + " maps from Firebase");
            return true;
            
        } catch {
            warn("[MapController] ❌ Failed to load maps: " + getExceptionInfo());
            return false;
        }
    }
    
    // Get next map (randomized, avoiding current and played)
    MX::MapInfo@ GetNextMap(const string &in currentUid = "") {
        if (mapList.Length == 0) {
            warn("[MapController] ⚠ No maps available");
            return null;
        }
        
        // If all maps have been played, reset the played list
        if (playedMapUids.Length >= mapList.Length) {
            trace("[MapController] 🔄 All maps played - resetting rotation");
            playedMapUids.RemoveRange(0, playedMapUids.Length);
        }
        
        // Build list of available maps (not current, not played)
        array<MX::MapInfo@> availableMaps;
        for (uint i = 0; i < mapList.Length; i++) {
            MX::MapInfo@ info = mapList[i];
            string uid = info.MapUid;
            
            // Skip if it's the current map
            if (uid == currentUid) continue;
            
            // Skip if already played
            bool alreadyPlayed = false;
            for (uint j = 0; j < playedMapUids.Length; j++) {
                if (playedMapUids[j] == uid) {
                    alreadyPlayed = true;
                    break;
                }
            }
            if (alreadyPlayed) continue;
            
            availableMaps.InsertLast(info);
        }
        
        // If no available maps, force reset and try again
        if (availableMaps.Length == 0) {
            trace("[MapController] 🔄 Forcing rotation reset");
            playedMapUids.RemoveRange(0, playedMapUids.Length);
            
            for (uint i = 0; i < mapList.Length; i++) {
                if (mapList[i].MapUid != currentUid) {
                    availableMaps.InsertLast(mapList[i]);
                }
            }
        }
        
        if (availableMaps.Length == 0) {
            warn("[MapController] ❌ Still no available maps");
            return null;
        }
        
        // Pick random map from available
        uint index = Math::Rand(0, availableMaps.Length);
        MX::MapInfo@ selected = availableMaps[index];
        
        // Mark as played
        playedMapUids.InsertLast(selected.MapUid);
        
        trace("[MapController] 🎲 Selected random map: " + selected.Name + " (" + 
              availableMaps.Length + " available, " + playedMapUids.Length + " played)");
        
        return selected;
    }
    
    // Load map to room
    void LoadMapToRoom(MX::MapInfo@ mapInfo) {
        if (mapInfo is null) {
            warn("[MapController] ⚠ Cannot load null map");
            return;
        }
        
        trace("[MapController] 📥 Loading map: " + mapInfo.Name);
        
        try {
            // Try to load map by UID via PlaygroundClientScriptAPI
            auto app = cast<CTrackMania>(GetApp());
            if (app is null) {
                warn("[MapController] ⚠ Cannot get app");
                return;
            }
            
            // TODO: Implement proper map loading via room/playlist
            // For now, this requires manual map loading or room integration
            trace("[MapController] 📍 Map selected: " + mapInfo.MapUid);
            trace("[MapController] ⚠ Automatic map loading not yet implemented");
            
            // Note: Map loading typically requires:
            // - Room server integration
            // - Playlist management
            // - Or manual /add command
            
        } catch {
            warn("[MapController] ❌ Load exception: " + getExceptionInfo());
        }
    }
    
    // Get map count
    uint GetMapCount() {
        return mapList.Length;
    }
    
    // Get played count
    uint GetPlayedCount() {
        return playedMapUids.Length;
    }
    
    // Reset played list
    void ResetPlayed() {
        playedMapUids.RemoveRange(0, playedMapUids.Length);
        trace("[MapController] 🔄 Played list reset");
    }
}
