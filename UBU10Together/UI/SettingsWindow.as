// SettingsWindow - Minimal configuration interface

class SettingsWindow {
    bool isOpen = true;  // Start visible so user can configure
    UBU10Controller@ controller;
    
    // Temp input buffers
    string clubIdInput = "";
    string roomIdInput = "";
    
    SettingsWindow(UBU10Controller@ ctrl) {
        @controller = ctrl;
        clubIdInput = controller.clubId;
        roomIdInput = controller.roomId;
    }
    
    void Render() {
        if (!isOpen) return;
        
        UI::SetNextWindowSize(500, 450, UI::Cond::FirstUseEver);
        if (UI::Begin("UBU10 Together - Settings", isOpen)) {
            // Title
            UI::PushFont(g_fontHeader);
            UI::Text("\\$f80 🏆 UBU10 TOGETHER");
            UI::PopFont();
            UI::Separator();
            
            // Medal Selection
            UI::Text("\\$fffTarget Medal:");
            UI::BeginGroup();
            
            if (MedalButton(3, "", "Author", controller.selectedMedal == 3)) {
                controller.selectedMedal = 3;
            }
            UI::SameLine();
            if (MedalButton(4, "", "Harder", controller.selectedMedal == 4)) {
                controller.selectedMedal = 4;
            }
            UI::SameLine();
            if (MedalButton(5, "", "Hardest", controller.selectedMedal == 5)) {
                controller.selectedMedal = 5;
            }
            
            UI::EndGroup();
            UI::Separator();
            
            // Runtime
            UI::Text("\\$fffSession Duration:");
            int minutes = int(controller.runTimeMinutes);
            UI::SetNextItemWidth(300);
            minutes = UI::SliderInt("Minutes", minutes, 5, 240);
            controller.runTimeMinutes = uint(minutes);
            UI::Text("Duration: " + FormatDuration(minutes));
            UI::Separator();
            
            // Club/Room IDs
            UI::Text("\\$fffClub & Room Configuration:");
            UI::SetNextItemWidth(300);
            clubIdInput = UI::InputText("Club ID", clubIdInput);
            UI::SetNextItemWidth(300);
            roomIdInput = UI::InputText("Room ID", roomIdInput);
            
            if (UI::Button("Check Room")) {
                CheckRoom();
            }
            UI::SameLine();
            if (UI::Button("Auto-Detect")) {
                AutoDetectRoom();
            }
            
            UI::Separator();
            
            // Start button
            UI::Dummy(vec2(0, 10));
            
            bool canStart = !controller.isRunning;
            if (!canStart) {
                UI::BeginDisabled();
            }
            
            if (UI::Button("\\$0f0 START SESSION", vec2(460, 40))) {
                StartSession();
            }
            
            if (!canStart) {
                UI::EndDisabled();
            }
            
            // Stop button (if running)
            if (controller.isRunning) {
                UI::Dummy(vec2(0, 5));
                if (UI::Button("\\$f00 STOP SESSION", vec2(460, 30))) {
                    controller.StopRun(false);
                    isOpen = false;
                }
            }
            
            UI::End();
        }
    }
    
    bool MedalButton(uint medalId, const string &in icon, const string &in label, bool selected) {
        vec4 color = GetMedalColor(medalId);
        
        if (selected) {
            UI::PushStyleColor(UI::Col::Button, color);
            UI::PushStyleColor(UI::Col::ButtonHovered, color * 1.2);
            UI::PushStyleColor(UI::Col::ButtonActive, color * 0.8);
        }
        
        bool clicked = UI::Button(icon + " " + label, vec2(140, 40));
        
        if (selected) {
            UI::PopStyleColor(3);
        }
        
        return clicked;
    }
    
    vec4 GetMedalColor(uint medalId) {
        switch (medalId) {
            case 3: return vec4(1.0, 0.84, 0.0, 1.0);  // Gold (Author)
            case 4: return vec4(0.9, 0.5, 0.0, 1.0);   // Orange (Harder)
            case 5: return vec4(1.0, 0.2, 0.2, 1.0);   // Red (Hardest)
        }
        return vec4(0.5, 0.5, 0.5, 1.0);
    }
    
    string FormatDuration(int minutes) {
        int hours = minutes / 60;
        int mins = minutes % 60;
        if (hours > 0) {
            return tostring(hours) + "h " + tostring(mins) + "m";
        }
        return tostring(mins) + " minutes";
    }
    
    void StartSession() {
        // Save inputs
        controller.clubId = clubIdInput;
        controller.roomId = roomIdInput;
        controller.SaveSettings();
        
        // Start the run
        controller.StartRun();
        
        // Close settings window
        isOpen = false;
    }
    
    void CheckRoom() {
        // TODO: Implement room checking via API
        trace("[Settings] Check room: club=" + clubIdInput + " room=" + roomIdInput);
    }
    
    void AutoDetectRoom() {
        // Try to detect from current server
        auto app = cast<CTrackMania>(GetApp());
        if (app is null || app.Network is null) {
            trace("[Settings] ⚠ Cannot detect - not in a server");
            return;
        }
        
        auto network = cast<CTrackManiaNetwork>(app.Network);
        if (network is null || network.ClientManiaAppPlayground is null) {
            trace("[Settings] ⚠ Cannot detect - playground not available");
            return;
        }
        
        // TODO: Extract club/room from server info if available
        trace("[Settings] Auto-detect attempted");
    }
}

// Font for header (initialize in Main.as if needed)
UI::Font@ g_fontHeader = null;
