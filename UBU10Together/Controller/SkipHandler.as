// SkipHandler

namespace SkipHandler {
    void SkipCurrentMap() {
        if (g_controller is null) {
            warn("[SkipHandler] Controller is null");
            return;
        }
        
        if (!g_controller.isRunning || g_controller.isPaused) {
            warn("[SkipHandler] Cannot skip - run not active");
            return;
        }
        
        //trace("[SkipHandler] Skip map requested");
        
        string currentUid = "";
        auto app = cast<CTrackMania>(GetApp());
        if (app !is null && app.RootMap !is null && app.RootMap.MapInfo !is null) {
            currentUid = app.RootMap.MapInfo.MapUid;
        }
        
        MX::MapInfo@ nextMap = null;
        if (g_controller.mapController !is null) {
            @nextMap = g_controller.mapController.GetNextMap(currentUid);
        }
        
        if (nextMap is null) {
            warn("[SkipHandler] ❌ No next map available");
            return;
        }
        
        //trace("[SkipHandler] Next map: " + nextMap.Name + " (" + nextMap.MapUid + ")");
        
        g_controller.PauseRun();
        g_controller.SwitchToSpecificMap(nextMap);
        
        //trace("[SkipHandler] Map skip initiated");
    }
}
