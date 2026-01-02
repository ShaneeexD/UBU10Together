// FirebaseClient

namespace FirebaseClient {
    string FIREBASE_BASE_URL = UBU10Files::FirebaseUrl;
    string FIREBASE_AUTH_TOKEN = "";
    dictionary g_medalCache;
    bool g_cacheEnabled = true;
    
    void SetFirebaseUrl(const string &in url) {
        FIREBASE_BASE_URL = url;
    }
    
    void SetAuthToken(const string &in token) {
        FIREBASE_AUTH_TOKEN = token;
    }
    
    void ClearCache() {
        g_medalCache.DeleteAll();
    }
    
    MedalData@ GetMedalData(const string &in mapUid) {
        if (mapUid.Length == 0) {
            warn("[Firebase] Empty map UID provided");
            return null;
        }
        
        if (g_cacheEnabled && g_medalCache.Exists(mapUid)) {
            MedalData@ cached;
            g_medalCache.Get(mapUid, @cached);
            return cached;
        }
                
        string url = FIREBASE_BASE_URL + mapUid + ".json";
        if (FIREBASE_AUTH_TOKEN.Length > 0) {
            url += "?auth=" + FIREBASE_AUTH_TOKEN;
        }
        
        Net::HttpRequest@ req = Net::HttpGet(url);
        
        int startTime = Time::Now;
        while (!req.Finished()) {
            yield();
            if (Time::Now - startTime > 10000) {
                warn("[Firebase] Request timeout for: " + mapUid);
                return null;
            }
        }
        
        if (req.ResponseCode() != 200) {
            warn("[Firebase] HTTP " + req.ResponseCode() + " for: " + mapUid);
            return null;
        }
        
        string jsonStr = req.String();
        if (jsonStr.Length == 0 || jsonStr == "null") {
            warn("[Firebase] No data found for: " + mapUid);
            return null;
        }
        
        Json::Value data = Json::Parse(jsonStr);
        if (data is null) {
            warn("[Firebase] Failed to parse JSON for: " + mapUid);
            return null;
        }
        
        MedalData@ medalData = MedalData(data);
        
        if (!medalData.IsValid()) {
            warn("[Firebase] Invalid medal data for: " + mapUid);
            return null;
        }
        
        if (g_cacheEnabled) {
            g_medalCache.Set(mapUid, @medalData);
        }
        
        return medalData;
        
    }
    
    dictionary@ GetAllMedalData() {
        try {
            string url = FIREBASE_BASE_URL + ".json";
            if (FIREBASE_AUTH_TOKEN.Length > 0) {
                url += "?auth=" + FIREBASE_AUTH_TOKEN;
            }
            
            Net::HttpRequest@ req = Net::HttpGet(url);
            
            int startTime = Time::Now;
            while (!req.Finished()) {
                yield();
                if (Time::Now - startTime > 30000) {
                    warn("[Firebase] Batch request timeout");
                    return null;
                }
            }
            
            if (req.ResponseCode() != 200) {
                warn("[Firebase] HTTP " + req.ResponseCode() + " for batch request");
                return null;
            }
            
            Json::Value data = Json::Parse(req.String());
            if (data is null || data.GetType() != Json::Type::Object) {
                warn("[Firebase] Invalid batch data format");
                return null;
            }
            
            dictionary result;
            auto keys = data.GetKeys();
            for (uint i = 0; i < keys.Length; i++) {
                string uid = keys[i];
                Json::Value mapData = data[uid];
                MedalData@ medalData = MedalData(mapData);
                if (medalData.IsValid()) {
                    result.Set(uid, @medalData);
                }
            }
            
            return result;
            
        } catch {
            warn("[Firebase] Exception in batch fetch: " + getExceptionInfo());
            return null;
        }
    }
    
    bool UploadMedalData(const string &in mapUid, Json::Value@ data) {
        if (mapUid.Length == 0 || data is null) {
            warn("Invalid upload parameters");
            return false;
        }
        
        trace("Uploading medal data for: " + mapUid);
        
        try {
            string url = FIREBASE_BASE_URL + mapUid + ".json";
            if (FIREBASE_AUTH_TOKEN.Length > 0) {
                url += "?auth=" + FIREBASE_AUTH_TOKEN;
            }
            
            string jsonStr = Json::Write(data);
            Net::HttpRequest@ req = Net::HttpPut(url, jsonStr);
            
            int startTime = Time::Now;
            while (!req.Finished()) {
                yield();
                if (Time::Now - startTime > 10000) {
                    warn("[Firebase] Upload timeout for: " + mapUid);
                    return false;
                }
            }
            
            if (req.ResponseCode() == 200) {
                trace("[Firebase] Upload successful: " + mapUid);
                return true;
            } else {
                warn("[Firebase] Upload failed HTTP " + req.ResponseCode());
                return false;
            }
            
        } catch {
            warn("[Firebase] Upload exception: " + getExceptionInfo());
            return false;
        }
    }
}
