// SkipHandler - Handles skipping the current map

namespace SkipHandler {
    
    void SkipCurrentMap() {
        if (g_controller is null) {
            warn("[SkipHandler] ❌ Controller is null");
            return;
        }
        
        // Check if run is active
        if (!g_controller.isRunning || g_controller.isPaused) {
            warn("[SkipHandler] ❌ Cannot skip - run not active");
            return;
        }
        
        trace("[SkipHandler] 🔄 Skip map requested");
        
        // Get current map UID
        string currentUid = "";
        auto app = cast<CTrackMania>(GetApp());
        if (app !is null && app.RootMap !is null && app.RootMap.MapInfo !is null) {
            currentUid = app.RootMap.MapInfo.MapUid;
        }
        
        // Get next map from controller
        MX::MapInfo@ nextMap = null;
        if (g_controller.mapController !is null) {
            @nextMap = g_controller.mapController.GetNextMap(currentUid);
        }
        
        if (nextMap is null) {
            warn("[SkipHandler] ❌ No next map available");
            return;
        }
        
        trace("[SkipHandler] 🎯 Next map: " + nextMap.Name + " (" + nextMap.MapUid + ")");
        
        // Pause and switch to specific map
        g_controller.PauseRun();
        g_controller.SwitchToSpecificMap(nextMap);
        
        trace("[SkipHandler] ✅ Map skip initiated");
    }
}
