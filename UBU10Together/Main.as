// UBU10 Together - Main Entry Point

// Globals
UBU10Controller@ g_controller = null;

SettingsWindow@ g_settingsWindow = null;
GameWindow@ g_gameWindow = null;
EndWindow@ g_endWindow = null;
MedalOverlay@ g_medalOverlay = null;

PlayerTracker@ g_playerTracker = null;

[Setting category="UBU10 Together" name="Toggle Window Hotkey" description="Hotkey to toggle the settings window (F1-F12)"]
string g_hotkeySettings = "F1";

void Main() {
    trace("[UBU10Together] Plugin initializing...");
    
    @g_controller = UBU10Controller();
    @g_settingsWindow = SettingsWindow(g_controller);
    @g_gameWindow = GameWindow(g_controller);
    @g_endWindow = EndWindow(g_controller);
    @g_medalOverlay = MedalOverlay();
    @g_playerTracker = PlayerTracker(g_controller, g_gameWindow);
    
    g_controller.SetEndWindow(g_endWindow);
    g_controller.SetPlayerTracker(g_playerTracker);
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

void Render() {
    if (g_controller !is null) {
        g_controller.Update(0.016);
    }
    
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

void WatchHotkeyLoop() {
    bool wasPressed = false;
    while (true) {
        if (g_hotkeySettings.StartsWith("F")) {
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

void ToggleSettingsWindow() {
    if (g_controller !is null && g_controller.isRunning && !g_controller.runFinished) {
        if (g_gameWindow !is null) {
            g_gameWindow.isVisible = !g_gameWindow.isVisible;
        }
    } else {
        if (g_settingsWindow !is null) {
            g_settingsWindow.isOpen = !g_settingsWindow.isOpen;
        }
    }
}

void RenderMenu() {
    if (UI::MenuItem("\\$f80🏆\\$z UBU10 Together", "", g_settingsWindow !is null && g_settingsWindow.isOpen)) {
        ToggleSettingsWindow();
    }
    
    if (g_controller !is null && g_controller.isRunning && !g_controller.runFinished) {
        if (UI::MenuItem("\\$f80🏁\\$z UBU10 Session", "", g_gameWindow !is null && g_gameWindow.isVisible)) {
            if (g_gameWindow !is null) {
                g_gameWindow.isVisible = !g_gameWindow.isVisible;
            }
        }
    }
}
