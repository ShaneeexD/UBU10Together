// EndWindow

class EndWindow {
    bool isOpen = false;
    UBU10Controller@ controller;
    
    string winnerName = "";
    int winnerCount = 0;
    
    EndWindow(UBU10Controller@ ctrl) {
        @controller = ctrl;
    }
    
    void Open() {
        isOpen = true;
        LoadWinnerData();
    }
    
    void Render() {
        if (!isOpen) return;
        
        UI::SetNextWindowSize(600, 400, UI::Cond::FirstUseEver);
        UI::SetNextWindowPos(int(Draw::GetWidth() / 2) - 300, int(Draw::GetHeight() / 2) - 200, UI::Cond::FirstUseEver);
        
        int flags = UI::WindowFlags::NoCollapse;
        if (UI::Begin("Session Complete!", isOpen, flags)) {
            UI::Dummy(vec2(0, 20));
            
            UI::PushFont(g_fontHeader);
            UI::SetCursorPos(vec2(UI::GetWindowSize().x / 2 - 150, UI::GetCursorPos().y));
            UI::Text("\\$0f0SESSION COMPLETE!");
            UI::PopFont();
            
            UI::Dummy(vec2(0, 30));
            UI::Separator();
            UI::Dummy(vec2(0, 20));
            
            if (winnerName.Length > 0) {
                UI::PushFont(g_fontHeader);
                UI::Text("\\$ff0 🏆 Winner:");
                UI::PopFont();
                
                UI::Dummy(vec2(0, 10));
                
                UI::PushFont(g_fontHeader);
                UI::PushStyleColor(UI::Col::Text, vec4(1.0, 0.84, 0.0, 1.0));
                UI::Text("    " + winnerName);
                UI::PopStyleColor();
                UI::PopFont();
                
                UI::Dummy(vec2(0, 10));
                UI::Text("Maps won: " + winnerCount);
            } else {
                UI::Text("No winner data available");
            }
            
            UI::Dummy(vec2(0, 30));
            UI::Separator();
            UI::Dummy(vec2(0, 20));
            
            UI::Text("\\$fffSession Statistics:");
            UI::Text("  Target Medal: " + controller.GetMedalName(controller.selectedMedal));
            UI::Text("  Duration: " + controller.FormatDuration(controller.runTimeMinutes));
            
            UI::Dummy(vec2(0, 30));
            
            UI::SetCursorPos(vec2(UI::GetWindowSize().x / 2 - 100, UI::GetCursorPos().y));
            if (UI::Button("Return to Menu", vec2(200, 40))) {
                isOpen = false;
                controller.runFinished = false;
            }
            
            UI::End();
        }
    }
    
    void LoadWinnerData() {
        if (controller is null || controller.playerTracker is null) {
            winnerName = "No data";
            winnerCount = 0;
            return;
        }
        
        controller.playerTracker.GetWinner(winnerName, winnerCount);
    }
}
