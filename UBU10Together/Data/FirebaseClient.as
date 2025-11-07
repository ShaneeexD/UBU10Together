// FirebaseClient - Handles fetching medal data from Firebase

namespace FirebaseClient {
    // Firebase configuration
    string FIREBASE_BASE_URL = "https://ubu10together-default-rtdb.europe-west1.firebasedatabase.app/ubu10/";
    string FIREBASE_AUTH_TOKEN = "";  // Optional: Add if using authentication
    
    // Cache for medal data
    dictionary g_medalCache;
    bool g_cacheEnabled = true;
    
    // Configure Firebase URL
    void SetFirebaseUrl(const string &in url) {
        FIREBASE_BASE_URL = url;
        trace("[Firebase] 🔧 Base URL set to: " + url);
    }
    
    void SetAuthToken(const string &in token) {
        FIREBASE_AUTH_TOKEN = token;
        trace("[Firebase] 🔐 Auth token configured");
    }
    
    void ClearCache() {
        g_medalCache.DeleteAll();
        trace("[Firebase] 🧹 Cache cleared");
    }
    
    // Fetch medal data for a specific map UID
    MedalData@ GetMedalData(const string &in mapUid) {
        if (mapUid.Length == 0) {
            warn("[Firebase] ⚠ Empty map UID provided");
            return null;
        }
        
        // Check cache first
        if (g_cacheEnabled && g_medalCache.Exists(mapUid)) {
            trace("[Firebase] 💾 Cache hit for: " + mapUid);
            MedalData@ cached;
            g_medalCache.Get(mapUid, @cached);
            return cached;
        }
        
        trace("[Firebase] 📥 Fetching medal data for: " + mapUid);
        
        try {
            // Construct Firebase URL
            string url = FIREBASE_BASE_URL + mapUid + ".json";
            if (FIREBASE_AUTH_TOKEN.Length > 0) {
                url += "?auth=" + FIREBASE_AUTH_TOKEN;
            }
            
            // Make HTTP request
            Net::HttpRequest@ req = Net::HttpGet(url);
            
            // Wait for response (with timeout)
            int startTime = Time::Now;
            while (!req.Finished()) {
                yield();
                if (Time::Now - startTime > 10000) {  // 10s timeout
                    warn("[Firebase] ⏱ Request timeout for: " + mapUid);
                    return null;
                }
            }
            
            // Check response
            if (req.ResponseCode() != 200) {
                warn("[Firebase] ❌ HTTP " + req.ResponseCode() + " for: " + mapUid);
                return null;
            }
            
            // Parse JSON response
            string jsonStr = req.String();
            if (jsonStr.Length == 0 || jsonStr == "null") {
                warn("[Firebase] ⚠ No data found for: " + mapUid);
                return null;
            }
            
            Json::Value data = Json::Parse(jsonStr);
            if (data is null) {
                warn("[Firebase] ❌ Failed to parse JSON for: " + mapUid);
                return null;
            }
            
            // Create MedalData object
            MedalData@ medalData = MedalData(data);
            
            if (!medalData.IsValid()) {
                warn("[Firebase] ⚠ Invalid medal data for: " + mapUid);
                return null;
            }
            
            // Cache the result
            if (g_cacheEnabled) {
                g_medalCache.Set(mapUid, @medalData);
                trace("[Firebase] 💾 Cached: " + mapUid);
            }
            
            trace("[Firebase] ✅ Successfully loaded: " + medalData.mapName);
            return medalData;
            
        } catch {
            warn("[Firebase] ❌ Exception fetching data: " + getExceptionInfo());
            return null;
        }
    }
    
    // Batch fetch all UBU10 medal data (optional - for preloading)
    dictionary@ GetAllMedalData() {
        trace("[Firebase] 📥 Fetching all UBU10 medal data");
        
        try {
            string url = FIREBASE_BASE_URL + ".json";
            if (FIREBASE_AUTH_TOKEN.Length > 0) {
                url += "?auth=" + FIREBASE_AUTH_TOKEN;
            }
            
            Net::HttpRequest@ req = Net::HttpGet(url);
            
            int startTime = Time::Now;
            while (!req.Finished()) {
                yield();
                if (Time::Now - startTime > 30000) {  // 30s timeout for batch
                    warn("[Firebase] ⏱ Batch request timeout");
                    return null;
                }
            }
            
            if (req.ResponseCode() != 200) {
                warn("[Firebase] ❌ HTTP " + req.ResponseCode() + " for batch request");
                return null;
            }
            
            Json::Value data = Json::Parse(req.String());
            if (data is null || data.GetType() != Json::Type::Object) {
                warn("[Firebase] ❌ Invalid batch data format");
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
            
            trace("[Firebase] ✅ Loaded " + result.GetSize() + " maps");
            return result;
            
        } catch {
            warn("[Firebase] ❌ Exception in batch fetch: " + getExceptionInfo());
            return null;
        }
    }
    
    // Upload medal data (for testing/admin use)
    bool UploadMedalData(const string &in mapUid, Json::Value@ data) {
        if (mapUid.Length == 0 || data is null) {
            warn("[Firebase] ⚠ Invalid upload parameters");
            return false;
        }
        
        trace("[Firebase] 📤 Uploading medal data for: " + mapUid);
        
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
                    warn("[Firebase] ⏱ Upload timeout for: " + mapUid);
                    return false;
                }
            }
            
            if (req.ResponseCode() == 200) {
                trace("[Firebase] ✅ Upload successful: " + mapUid);
                return true;
            } else {
                warn("[Firebase] ❌ Upload failed HTTP " + req.ResponseCode());
                return false;
            }
            
        } catch {
            warn("[Firebase] ❌ Upload exception: " + getExceptionInfo());
            return false;
        }
    }
}
