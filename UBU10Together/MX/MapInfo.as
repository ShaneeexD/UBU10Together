// MX::MapInfo - Simple map information structure

namespace MX {

shared class MapInfo {
    string MapUid;  // Map UID for loading
    string Name;    // Map name
    int TrackID;    // TMX Track ID (optional)
    
    MapInfo() {}
    
    MapInfo(const string &in uid, const string &in name) {
        MapUid = uid;
        Name = name;
    }
    
    MapInfo(const Json::Value &in json) {
        try {
            if (json.HasKey("uid")) MapUid = string(json["uid"]);
            else if (json.HasKey("MapUid")) MapUid = string(json["MapUid"]);
            else if (json.HasKey("mapUid")) MapUid = string(json["mapUid"]);
            
            if (json.HasKey("name")) Name = string(json["name"]);
            else if (json.HasKey("Name")) Name = string(json["Name"]);
            else if (json.HasKey("mapName")) Name = string(json["mapName"]);
            
            if (json.HasKey("trackId")) TrackID = int(json["trackId"]);
            else if (json.HasKey("TrackID")) TrackID = int(json["TrackID"]);
        } catch {
            warn("[MapInfo] ❌ Error parsing MapInfo: " + getExceptionInfo());
        }
    }
    
    Json::Value ToJson() const {
        Json::Value j = Json::Object();
        j["MapUid"] = MapUid;
        j["Name"] = Name;
        if (TrackID > 0) j["TrackID"] = TrackID;
        return j;
    }
}

}
