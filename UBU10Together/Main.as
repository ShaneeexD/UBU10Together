// UBU10 Together Plugin - Main Entry Point
// Provides medal-based progression through UBU10 maps with Firebase integration

// Global controller instance
UBU10Controller@ g_controller = null;

// Global UI windows
SettingsWindow@ g_settingsWindow = null;
GameWindow@ g_gameWindow = null;
EndWindow@ g_endWindow = null;
MedalOverlay@ g_medalOverlay = null;

// Global player tracker
PlayerTracker@ g_playerTracker = null;

// Hotkey settings
[Setting category="General" name="Toggle Window Hotkey" description="Hotkey to toggle the settings window (F1-F12)"]
string g_hotkeySettings = "F1";

void Main() {
    trace("[UBU10Together] Plugin initializing...");
    
    // Initialize controller
    @g_controller = UBU10Controller();
    
    // Initialize UI windows
    @g_settingsWindow = SettingsWindow(g_controller);
    @g_gameWindow = GameWindow(g_controller);
    @g_endWindow = EndWindow(g_controller);
    @g_medalOverlay = MedalOverlay();
    
    // Initialize player tracker
    @g_playerTracker = PlayerTracker(g_controller, g_gameWindow);
    
    // Connect components
    g_controller.SetEndWindow(g_endWindow);
    g_controller.SetPlayerTracker(g_playerTracker);
    
    // Start hotkey watcher
    startnew(WatchHotkeyLoop);
    
    trace("[UBU10Together] Plugin initialized successfully");
}

void OnDestroyed() {
    trace("[UBU10Together] Plugin shutting down");
}

void OnDisabled() {
    trace("[UBU10Together] Plugin disabled");
}

void OnEnabled() {
    trace("[UBU10Together] Plugin enabled");
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
    
    if (g_medalOverlay !is null) {
        g_medalOverlay.Render();
    }
}

// Hotkey watcher coroutine
void WatchHotkeyLoop() {
    bool wasPressed = false;
    while (true) {
        if (g_hotkeySettings.StartsWith("F")) {
            // Parse F key number (F1-F12)
            int keyNum = Text::ParseInt(g_hotkeySettings.SubStr(1));
            if (keyNum >= 1 && keyNum <= 12) {
                UI::Key key = UI::Key(int(UI::Key::F1) + keyNum - 1);
                bool nowPressed = UI::IsKeyPressed(key);
                if (nowPressed && !wasPressed) {
                    ToggleSettingsWindow();
                }
                wasPressed = nowPressed;
            }
        }
        yield();
    }
}

// Toggle appropriate window based on session state
void ToggleSettingsWindow() {
    // During active session: toggle game window
    if (g_controller !is null && g_controller.isRunning && !g_controller.runFinished) {
        if (g_gameWindow !is null) {
            g_gameWindow.isVisible = !g_gameWindow.isVisible;
        }
    } else {
        // No session or session finished: toggle settings window
        if (g_settingsWindow !is null) {
            g_settingsWindow.isOpen = !g_settingsWindow.isOpen;
        }
    }
}

// Settings menu integration
void RenderMenu() {
    // Settings window toggle
    if (UI::MenuItem("\\$f80🏆\\$z UBU10 Together", "", g_settingsWindow !is null && g_settingsWindow.isOpen)) {
        ToggleSettingsWindow();
    }
    
    // Game window toggle (only show during active session)
    if (g_controller !is null && g_controller.isRunning && !g_controller.runFinished) {
        if (UI::MenuItem("\\$f80🏁\\$z UBU10 Session", "", g_gameWindow !is null && g_gameWindow.isVisible)) {
            if (g_gameWindow !is null) {
                g_gameWindow.isVisible = !g_gameWindow.isVisible;
            }
        }
    }
}
