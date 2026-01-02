// GameWindow

namespace SkipButtonGuard {
    uint lastSkipTime = 0;
    const uint COOLDOWN_MS = 10000;
    
    bool IsCooldownActive(int &out msLeft) {
        if (lastSkipTime == 0) {
            msLeft = 0;
            return false;
        }
        int elapsed = int(Time::Now - lastSkipTime);
        msLeft = Math::Max(0, int(COOLDOWN_MS) - elapsed);
        return msLeft > 0;
    }
    
    void StampNow() {
        lastSkipTime = Time::Now;
    }
}

class GameWindow {
    UBU10Controller@ controller;
    bool isVisible = false;
    array<PlayerEntry@> leaderboard;
    
    GameWindow(UBU10Controller@ ctrl) {
        @controller = ctrl;
    }
    
    void Render() {
        if (!controller.isRunning || !isVisible) return;
        
        UI::SetNextWindowPos(int(Draw::GetWidth()) - 420, 20, UI::Cond::Always);
        UI::SetNextWindowSize(380, 540, UI::Cond::FirstUseEver);
        
        int flags = UI::WindowFlags::NoCollapse | UI::WindowFlags::NoResize;
        if (UI::Begin("UBU10 Together - Game", isVisible, flags)) {
            UI::PushFont(g_fontHeader);
            UI::Text("\\$f80UBU10 TOGETHER");
            UI::PopFont();
            UI::Separator();
            
            UI::Text("\\$fffMap:");
            if (controller.currentMapInfo !is null) {
                UI::Text("  " + controller.currentMapInfo.Name);
            } else {
                UI::Text("  Loading...");
            }
            
            UI::Text("\\$fffTarget:");
            string medalName = controller.GetMedalName(controller.selectedMedal);
            int targetTime = controller.GetMedalTime(controller.selectedMedal);
            string timeStr = controller.FormatTime(targetTime);
            vec4 medalColor = controller.GetMedalColor(controller.selectedMedal);
            
            UI::PushStyleColor(UI::Col::Text, medalColor);
            UI::Text(medalName + " - " + timeStr);
            UI::PopStyleColor();
            
            UI::Separator();
            
            UI::Text("\\$fffRemaining Time:");
            DrawCountdown();
            
            UI::Separator();
            
            UI::Text("\\$fffLeaderboard:");
            DrawLeaderboard();
            
            UI::Separator();
            
            int cdLeftMs = 0;
            bool cooldown = SkipButtonGuard::IsCooldownActive(cdLeftMs);
            bool canSkip = controller.isRunning && !controller.isPaused && !controller.isSwitchingMap && !cooldown;
            
            vec4 colEnabled = vec4(0.2f, 0.6f, 1.0f, 1.0f);
            vec4 colHovered = vec4(0.3f, 0.7f, 1.0f, 1.0f);
            vec4 colActive = vec4(0.1f, 0.5f, 0.9f, 1.0f);
            vec4 colDisabled = vec4(0.3f, 0.3f, 0.3f, 0.5f);
            
            UI::PushStyleColor(UI::Col::Button, canSkip ? colEnabled : colDisabled);
            UI::PushStyleColor(UI::Col::ButtonHovered, canSkip ? colHovered : colDisabled);
            UI::PushStyleColor(UI::Col::ButtonActive, canSkip ? colActive : colDisabled);
            
            if (!canSkip) UI::BeginDisabled();
            if (UI::Button("Skip Map", vec2(360, 30))) {
                SkipButtonGuard::StampNow();
                startnew(SkipHandler::SkipCurrentMap);
            }
            if (!canSkip) UI::EndDisabled();
            
            if (UI::IsItemHovered() && cooldown) {
                UI::BeginTooltip();
                UI::Text("Cooldown: " + (cdLeftMs / 1000 + 1) + "s remaining");
                UI::EndTooltip();
            }
            
            UI::PopStyleColor(3);
            
            if (UI::Button("⏹ Stop Session", vec2(360, 30))) {
                controller.StopRun(false);
            }
            
            UI::End();
        }
    }
    
    void DrawCountdown() {
        if (controller.runTimeRemainingMs < 0) {
            UI::Text("  Unlimited");
            return;
        }
        
        int remainingMs = controller.runTimeRemainingMs;
        int totalMs = controller.runTimeTotalMs;
        
        int seconds = remainingMs / 1000;
        int minutes = seconds / 60;
        int hours = minutes / 60;
        minutes = minutes % 60;
        seconds = seconds % 60;
        
        string timeText = (hours < 10 ? "0" : "") + tostring(hours) + ":" + 
                          (minutes < 10 ? "0" : "") + tostring(minutes) + ":" + 
                          (seconds < 10 ? "0" : "") + tostring(seconds);
        
        vec4 color;
        if (remainingMs < 60000) {
            color = vec4(1.0, 0.2, 0.2, 1.0);
        } else if (remainingMs < 300000) {
            color = vec4(1.0, 0.8, 0.0, 1.0);
        } else {
            color = vec4(0.2, 1.0, 0.2, 1.0);
        }
        
        UI::PushStyleColor(UI::Col::Text, color);
        UI::PushFont(g_fontHeader);
        UI::Text("  " + timeText);
        UI::PopFont();
        UI::PopStyleColor();
        
        float progress = totalMs > 0 ? float(remainingMs) / float(totalMs) : 0.0;
        UI::ProgressBar(progress, vec2(360, 20));
    }
    
    void DrawLeaderboard() {
        UI::BeginChild("Leaderboard", vec2(360, 200));
        
        if (leaderboard.Length == 0) {
            UI::TextDisabled("No times yet...");
        } else {
            UI::Columns(4, "lb_cols", true);
            UI::Text("Pos"); UI::NextColumn();
            UI::Text("Player"); UI::NextColumn();
            UI::Text("Time"); UI::NextColumn();
            UI::Text("Medals"); UI::NextColumn();
            UI::Separator();
            
            for (uint i = 0; i < leaderboard.Length && i < 10; i++) {
                PlayerEntry@ entry = leaderboard[i];
                
                UI::Text(tostring(i + 1)); UI::NextColumn();
                UI::Text(entry.name); UI::NextColumn();
                UI::Text(controller.FormatTime(entry.time)); UI::NextColumn();
                vec4 color = controller.GetMedalColor(entry.medal);
                UI::PushStyleColor(UI::Col::Text, color);
                UI::Text(tostring(entry.medalCount)); UI::NextColumn();
                UI::PopStyleColor();
            }
            
            UI::Columns(1);
        }
        
        UI::EndChild();
    }

    void UpdateLeaderboard(array<PlayerEntry@>@ entries) {
        leaderboard = entries;
    }
}

class PlayerEntry {
    string name;
    int time;
    uint medal;
    uint medalCount = 0;
    
    PlayerEntry(const string &in n, int t, uint m, uint mc = 0) {
        name = n;
        time = t;
        medal = m;
        medalCount = mc;
    }
    
    int opCmp(const PlayerEntry@ other) const {
        if (time < 0 && other.time >= 0) return 1;
        if (time >= 0 && other.time < 0) return -1;
        if (time < 0 && other.time < 0) return 0;
        
        if (time < other.time) return -1;
        if (time > other.time) return 1;
        return 0;
    }
}
