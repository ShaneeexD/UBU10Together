import json
import threading
from datetime import datetime
from tkinter import Tk, Label, Entry, Button, Text, END, DISABLED, NORMAL, messagebox, filedialog

import generate_times as gt

DEFAULT_UA = "Medal-Times-Generator/1.0"


def compute_and_render(author: str, prefix: str, ua: str, text_widget: Text, calculate_btn: Button):
    try:
        text_widget.config(state=NORMAL)
        text_widget.delete(1.0, END)
        text_widget.insert(END, f"Fetching maps for author='{author}', prefix='{prefix}'...\n")
        maps = gt.fetch_maps(author, prefix, ua, 1000)
        text_widget.insert(END, f"Found {len(maps)} map(s). Fetching leaderboards...\n")
        out = {
            "author": author,
            "prefix": prefix,
            "generated_at": datetime.utcnow().isoformat() + "Z",
            "maps": [],
        }
        for idx, m in enumerate(maps, start=1):
            track_id_val = m.get("MapId") or m.get("TrackID") or m.get("TrackId")
            try:
                track_id = int(track_id_val)
            except (TypeError, ValueError):
                text_widget.insert(END, f"[{idx}/{len(maps)}] Skipping map with invalid ID: {track_id_val}\n")
                text_widget.see(END)
                text_widget.update()
                continue
            uid = m.get("MapUid") or m.get("TrackUID")
            map_name = m.get("Name") or m.get("TrackName")
            text_widget.insert(END, f"[{idx}/{len(maps)}] Map {track_id} - {map_name} (uid={uid})\n")
            text_widget.see(END)
            text_widget.update()

            if not (isinstance(uid, str) and uid):
                text_widget.insert(END, f"[{idx}/{len(maps)}] Skipping map without UID (TMIO-only).\n")
                text_widget.see(END)
                text_widget.update()
                continue
            # TMIO-only computation
            t_at_tmio = gt.fetch_tmio_author_time(uid, ua) or 0
            tops = gt.fetch_tmio_leaderboard(uid, ua, 50)
            times = []
            for e in tops:
                t = e.get("time") if isinstance(e, dict) else None
                if t is None:
                    continue
                try:
                    times.append(int(t))
                except (TypeError, ValueError):
                    continue
            comp = gt.compute_from_times(int(t_at_tmio or 0), times)
            used_tmio = True

            entry = {
                "trackId": track_id,
                "uid": uid,
                "name": map_name,
                "author": m.get("Username") or (m.get("Uploader") or {}).get("Name"),
                "authorTime_ms": comp["authorTime_ms"],
                "wrTime_ms": comp["wrTime_ms"],
                "recordsCount": comp["recordsCount"],
                "computed": {
                    "timeA_ms": comp["timeA_ms"],
                    "timeB_ms": comp["timeB_ms"],
                    "harderTime_ms": comp["harderTime_ms"],
                    "medalTime_ms": comp["medalTime_ms"],
                    "method": comp["method"],
                },
                "source": {
                    "tmx_map_url": f"https://trackmania.exchange/maps/{track_id}",
                    "tmio_leaderboard_url": f"https://trackmania.io/api/leaderboard/map/{uid}?offset=0&length=50" if uid else None,
                    "tmio_map_url": f"https://trackmania.io/api/map/{uid}" if uid else None,
                    "api_search": "https://trackmania.exchange/api/maps",
                    "api_replays": "https://trackmania.exchange/api/replays",
                    "source_preference": "tmio" if used_tmio else "tmx",
                },
            }
            out["maps"].append(entry)
        text_widget.insert(END, "\nDone. Rendering JSON...\n\n")
        rendered = json.dumps(out, ensure_ascii=False, indent=2)
        text_widget.insert(END, rendered + "\n")
        text_widget.config(state=DISABLED)
        # Prompt to save
        save_path = filedialog.asksaveasfilename(
            title="Save output JSON",
            defaultextension=".json",
            filetypes=[("JSON files", ".json"), ("All files", ".*")],
            initialfile=f"{author}_{prefix}_times.json",
        )
        if save_path:
            with open(save_path, "w", encoding="utf-8") as f:
                f.write(rendered)
            messagebox.showinfo("Saved", f"Results saved to:\n{save_path}")
    except Exception as e:
        text_widget.config(state=NORMAL)
        text_widget.insert(END, f"\nError: {e}\n")
        text_widget.config(state=DISABLED)
        messagebox.showerror("Error", str(e))
    finally:
        calculate_btn.config(state=NORMAL)


def launch_ui():
    root = Tk()
    root.title("Medal Time Generator")

    Label(root, text="Author name:").grid(row=0, column=0, sticky="w", padx=6, pady=6)
    author_entry = Entry(root, width=40)
    author_entry.grid(row=0, column=1, sticky="we", padx=6, pady=6)

    Label(root, text="Map prefix:").grid(row=1, column=0, sticky="w", padx=6, pady=6)
    prefix_entry = Entry(root, width=40)
    prefix_entry.grid(row=1, column=1, sticky="we", padx=6, pady=6)

    Label(root, text="User-Agent (optional):").grid(row=2, column=0, sticky="w", padx=6, pady=6)
    ua_entry = Entry(root, width=40)
    ua_entry.insert(0, DEFAULT_UA)
    ua_entry.grid(row=2, column=1, sticky="we", padx=6, pady=6)

    output = Text(root, height=24, width=90, state=DISABLED)
    output.grid(row=3, column=0, columnspan=2, padx=6, pady=6, sticky="nsew")

    def on_calculate():
        author = author_entry.get().strip()
        prefix = prefix_entry.get().strip()
        ua = ua_entry.get().strip() or DEFAULT_UA
        if not author or not prefix:
            messagebox.showwarning("Missing input", "Please enter both author and prefix.")
            return
        output.config(state=NORMAL)
        output.delete(1.0, END)
        output.insert(END, "Starting... this may take a while for many maps.\n")
        output.config(state=DISABLED)
        calc_btn.config(state=DISABLED)
        t = threading.Thread(target=compute_and_render, args=(author, prefix, ua, output, calc_btn), daemon=True)
        t.start()

    calc_btn = Button(root, text="Calculate", command=on_calculate)
    calc_btn.grid(row=4, column=0, columnspan=2, pady=8)

    root.grid_columnconfigure(1, weight=1)
    root.grid_rowconfigure(3, weight=1)

    root.mainloop()


if __name__ == "__main__":
    launch_ui()
