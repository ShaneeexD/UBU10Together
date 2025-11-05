// UBU10 Together Plugin - Main Entry Point
// Provides medal-based progression through UBU10 maps with Firebase integration

// Global controller instance
UBU10Controller@ g_controller = null;

// Global UI windows
SettingsWindow@ g_settingsWindow = null;
GameWindow@ g_gameWindow = null;
EndWindow@ g_endWindow = null;

// Global player tracker
PlayerTracker@ g_playerTracker = null;

void Main() {
    trace("[UBU10Together] 🎮 Plugin initializing...");
    
    // Initialize controller
    @g_controller = UBU10Controller();
    
    // Initialize UI windows
    @g_settingsWindow = SettingsWindow(g_controller);
    @g_gameWindow = GameWindow(g_controller);
    @g_endWindow = EndWindow(g_controller);
    
    // Initialize player tracker
    @g_playerTracker = PlayerTracker(g_controller, g_gameWindow);
    
    // Connect components
    g_controller.SetEndWindow(g_endWindow);
    g_controller.SetPlayerTracker(g_playerTracker);
    
    trace("[UBU10Together] ✅ Plugin initialized successfully");
}

void OnDestroyed() {
    trace("[UBU10Together] 🛑 Plugin shutting down");
}

void OnDisabled() {
    trace("[UBU10Together] ⏸ Plugin disabled");
}

void OnEnabled() {
    trace("[UBU10Together] ▶ Plugin enabled");
}

// Main render loop - called every frame
void Render() {
    // Update controller
    if (g_controller !is null) {
        g_controller.Update(0.016); // ~60fps frame time
    }
    
    // Render UI windows
    if (g_settingsWindow !is null) {
        g_settingsWindow.Render();
    }
    
    if (g_gameWindow !is null) {
        g_gameWindow.Render();
    }
    
    if (g_endWindow !is null) {
        g_endWindow.Render();
    }
}

// Settings menu integration
void RenderMenu() {
    if (UI::MenuItem("\\$f80🏆\\$z UBU10 Together", "", g_settingsWindow !is null && g_settingsWindow.isOpen)) {
        if (g_settingsWindow !is null) {
            g_settingsWindow.isOpen = !g_settingsWindow.isOpen;
        }
    }
}
