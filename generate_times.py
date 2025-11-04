import argparse
import json
import sys
from datetime import datetime
from typing import Any, Dict, List, Optional

import requests


def http_get(url: str, params: Dict[str, Any], user_agent: str) -> Dict[str, Any]:
    headers = {"User-Agent": user_agent}
    r = requests.get(url, params=params, headers=headers, timeout=30)
    r.raise_for_status()
    return r.json()


def fetch_maps(author: str, prefix: str, user_agent: str, count: int = 100) -> List[Dict[str, Any]]:
    pfx = prefix.lower()
    auth_lower = author.lower()

    # Primary: TMX v2 /api/maps with cursor pagination (after)
    url = "https://trackmania.exchange/api/maps"
    # Be conservative with page size; docs default is 40.
    per_page = min(max(1, int(count)), 100)
    # Use explicit nested paths for required fields per API docs
    fields = (
        "MapId,MapUid,Name,Uploader.Name,Medals.Author,ReplayCount"
    )
    collected: List[Dict[str, Any]] = []
    after: Optional[int] = None
    while True:
        params: Dict[str, Any] = {
            "fields": fields,
            "name": prefix,
            "count": str(per_page),
        }
        if after is not None:
            params["after"] = str(after)
        data = http_get(url, params, user_agent)
        results = data.get("Results") or data.get("results") or []
        if not isinstance(results, list) or len(results) == 0:
            break
        collected.extend(results)
        # Prepare next cursor
        last = results[-1].get("MapId") or results[-1].get("TrackId")
        if last is None:
            break
        try:
            after = int(last)
        except (TypeError, ValueError):
            break
        if data.get("More") is False:
            break

    # Client-side strict filtering
    filtered: List[Dict[str, Any]] = []
    for m in collected:
        name_val = m.get("Name") or m.get("TrackName") or ""
        uploader = m.get("Uploader") or {}
        username_val = m.get("Username") or uploader.get("Name") or ""
        authors_arr = m.get("Authors") or []
        has_author_match = username_val.lower() == auth_lower
        if not has_author_match:
            for a in authors_arr:
                auser = a.get("User") if isinstance(a, dict) else None
                aname = (auser or {}).get("Name") if isinstance(auser, dict) else a.get("Name")
                if isinstance(aname, str) and aname.lower() == auth_lower:
                    has_author_match = True
                    break
        if not name_val:
            continue
        if not name_val.lower().startswith(pfx):
            continue
        if not has_author_match:
            continue
        filtered.append(m)

    if filtered:
        return filtered

    # Fallback: legacy mapsearch2 variants
    legacy_url = "https://trackmania.exchange/mapsearch2/search"
    out: List[Dict[str, Any]] = []
    name_keys = ["name", "mapname", "trackname"]
    for nk in name_keys:
        page = 1
        got_any = False
        while True:
            params = {
                "api": "on",
                "author": author,
                nk: prefix,
                "page": str(page),
                "length": str(per_page),
            }
            data = http_get(legacy_url, params, user_agent)
            results = data.get("results", [])
            if not results:
                break
            for m in results:
                name_val = m.get("Name", "")
                username_val = m.get("Username", "")
                if not name_val or not username_val:
                    continue
                if not name_val.lower().startswith(pfx):
                    continue
                if username_val.lower() != auth_lower:
                    continue
                out.append(m)
                got_any = True
            page += 1
            total = data.get("totalItemCount")
            if isinstance(total, int) and len(out) >= total:
                break
        if got_any:
            break

    if out:
        return out

    # Final fallback: legacy with 'count'
    for nk in name_keys:
        page = 1
        while True:
            params = {
                "api": "on",
                "author": author,
                nk: prefix,
                "page": str(page),
                "count": str(per_page),
            }
            data = http_get(legacy_url, params, user_agent)
            results = data.get("results", [])
            if not results:
                break
            for m in results:
                name_val = m.get("Name", "")
                username_val = m.get("Username", "")
                if not name_val or not username_val:
                    continue
                if not name_val.lower().startswith(pfx):
                    continue
                if username_val.lower() != auth_lower:
                    continue
                out.append(m)
            page += 1
            total = data.get("totalItemCount")
            if isinstance(total, int) and len(out) >= total:
                break
        if out:
            break
    return out


def fetch_replays(
    track_id: int,
    user_agent: str,
    per_page: int = 200,
) -> List[Dict[str, Any]]:
    """Fetch all replays for a map, using best=1 to get leaderboard (Position field)."""
    url = "https://trackmania.exchange/api/replays"
    base_params = {
        "mapId": str(track_id),
        "count": str(per_page),
        "best": "1",  # Get best replay per user (leaderboard)
    }
    collected: List[Dict[str, Any]] = []
    after: Optional[int] = None
    while True:
        params = dict(base_params)
        if after is not None:
            params["after"] = str(after)
        data = http_get(url, params, user_agent)
        page = data.get("Results", [])
        if page:
            collected.extend(page)
            last = page[-1].get("ReplayId")
        else:
            last = None
        more = data.get("More", False)
        if not more or not page or last is None:
            break
        try:
            after = int(last)
        except (TypeError, ValueError):
            break
    return collected


def fetch_replays_fallback_get(track_id: int, user_agent: str, amount: int = 25) -> List[Dict[str, Any]]:
    """Fallback to legacy endpoint to at least get top N replays if /api/replays yields none."""
    url = f"https://trackmania.exchange/api/replays/get_replays/{track_id}"
    params = {"amount": str(amount)}
    data = http_get(url, params, user_agent)
    if isinstance(data, list):
        return data
    return []


def fetch_tmio_leaderboard(uid: str, user_agent: str, length: int = 20) -> List[Dict[str, Any]]:
    """Fetch top N records from trackmania.io leaderboard for a map UID."""
    url = f"https://trackmania.io/api/leaderboard/map/{uid}"
    params = {"offset": "0", "length": str(max(1, min(length, 200)))}
    try:
        data = http_get(url, params, user_agent)
    except Exception:
        return []
    tops = data.get("tops") if isinstance(data, dict) else []
    return tops if isinstance(tops, list) else []


def fetch_tmio_author_time(uid: str, user_agent: str) -> Optional[int]:
    """Fetch author time (authorScore) in ms from trackmania.io for a map UID."""
    url = f"https://trackmania.io/api/map/{uid}"
    try:
        data = http_get(url, {}, user_agent)
    except Exception:
        return None
    val = data.get("authorScore") if isinstance(data, dict) else None
    try:
        return int(val) if val is not None else None
    except (TypeError, ValueError):
        return None


def compute_time_a(times_ms: List[int], c: float = 1.2, n: int = 20) -> Optional[float]:
    if len(times_ms) < n:
        return None
    top = times_ms[:n]
    num = 0.0
    den = 0.0
    for i in range(1, n + 1):
        w = c ** (21 - i)
        num += w * top[i - 1]
        den += w
    if den == 0:
        return None
    return num / den


def compute_time_b(t_at: int, t_wr: int, f: float = 0.5) -> float:
    diff = t_at - t_wr
    return t_at - f * diff


def compute_from_times(t_at: int, times: List[int]) -> Dict[str, Any]:
    """Compute Time_A/Time_B/Medal from author time and a list of top times (ms)."""
    times = [int(t) for t in times if isinstance(t, (int, float))]
    times.sort()
    records_count = len(times)
    t_wr = times[0] if records_count > 0 else t_at
    time_b = compute_time_b(int(t_at or 0), int(t_wr or 0), 0.5)
    time_a_val = compute_time_a(times, 1.2, 20) if records_count >= 20 else None
    if time_a_val is None:
        medal = time_b
        method = "Time_B"
    else:
        medal = min(time_a_val, time_b)
        method = "min(Time_A,Time_B)"
    return {
        "authorTime_ms": int(t_at or 0),
        "wrTime_ms": int(t_wr or 0),
        "recordsCount": records_count,
        "timeA_ms": int(round(time_a_val)) if time_a_val is not None else None,
        "timeB_ms": int(round(time_b)),
        "medalTime_ms": int(round(medal)),
        "method": method,
    }


def compute_for_map(m: Dict[str, Any], replays: List[Dict[str, Any]]) -> Dict[str, Any]:
    try:
        # Author time can be under AuthorTime (older) or Medals.Author (v2 maps)
        medals = m.get("Medals") or {}
        at_val = m.get("AuthorTime") if m.get("AuthorTime") is not None else medals.get("Author")
        try:
            t_at = int(at_val if at_val is not None else 0)
        except (TypeError, ValueError):
            t_at = 0
        
        # Filter for Position 0-19 (0-indexed top 20) and extract ReplayTime
        top_20_replays: List[Dict[str, Any]] = []
        for r in replays:
            pos = r.get("Position")
            if pos is None:
                continue
            try:
                pos_i = int(pos)
            except (TypeError, ValueError):
                continue
            # Use positions 1-20 (TMX/TMIO alignment)
            if 1 <= pos_i <= 20:
                top_20_replays.append(r)
        times: List[int] = []
        for r in top_20_replays:
            rt = r.get("ReplayTime")
            if rt is None:
                continue
            try:
                times.append(int(rt))
            except (TypeError, ValueError):
                continue
        # Sort ascending by time (should already be sorted by Position, but ensure)
        times.sort()
        records_count = len(times)
        if records_count > 0:
            t_wr = times[0]
        else:
            # No replays with Position 0-19; use AuthorTime as fallback
            t_wr = t_at
        time_b = compute_time_b(t_at, t_wr, 0.5)
        if records_count >= 20:
            time_a_val = compute_time_a(times, 1.2, 20)
        else:
            time_a_val = None
        if time_a_val is None:
            medal = time_b
            method = "Time_B"
        else:
            medal = min(time_a_val, time_b)
            method = "min(Time_A,Time_B)"
        return {
            "authorTime_ms": int(t_at),
            "wrTime_ms": int(t_wr),
            "recordsCount": records_count,
            "timeA_ms": int(round(time_a_val)) if time_a_val is not None else None,
            "timeB_ms": int(round(time_b)),
            "medalTime_ms": int(round(medal)),
            "method": method,
        }
    except Exception as e:
        return {
            "authorTime_ms": 0,
            "wrTime_ms": 0,
            "recordsCount": 0,
            "timeA_ms": None,
            "timeB_ms": 0.0,
            "medalTime_ms": 0.0,
            "method": f"Error: {str(e)}",
        }


def main(argv: List[str]) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--author", required=True)
    ap.add_argument("--prefix", required=True)
    ap.add_argument("--out", default="-")
    ap.add_argument("--user-agent", default="TMX-Times-Generator/1.0")
    ap.add_argument("--max-maps", type=int, default=100)
    args = ap.parse_args(argv)

    maps = fetch_maps(args.author, args.prefix, args.user_agent, args.max_maps)

    out = {
        "author": args.author,
        "prefix": args.prefix,
        "generated_at": datetime.utcnow().isoformat() + "Z",
        "maps": [],
    }

    for m in maps:
        # Force TMIO-only: require UID and compute exclusively from trackmania.io
        uid = m.get("MapUid") or m.get("TrackUID")
        if not isinstance(uid, str) or not uid:
            # Skip maps without a UID when forcing TMIO
            continue

        t_at_tmio = fetch_tmio_author_time(uid, args.user_agent) or 0
        tops = fetch_tmio_leaderboard(uid, args.user_agent, 20)
        times: List[int] = []
        for e in tops:
            t = e.get("time") if isinstance(e, dict) else None
            if t is None:
                continue
            try:
                times.append(int(t))
            except (TypeError, ValueError):
                continue
        comp = compute_from_times(int(t_at_tmio or 0), times)

        track_id_val = m.get("MapId") or m.get("TrackID") or m.get("TrackId")
        try:
            track_id = int(track_id_val)
        except (TypeError, ValueError):
            track_id = None

        entry = {
            "trackId": track_id,
            "uid": uid,
            "name": m.get("Name") or m.get("TrackName"),
            "author": m.get("Username") or (m.get("Uploader") or {}).get("Name"),
            "authorTime_ms": comp["authorTime_ms"],
            "wrTime_ms": comp["wrTime_ms"],
            "recordsCount": comp["recordsCount"],
            "computed": {
                "timeA_ms": comp["timeA_ms"],
                "timeB_ms": comp["timeB_ms"],
                "medalTime_ms": comp["medalTime_ms"],
                "method": comp["method"],
            },
            "source": {
                "tmx_map_url": f"https://trackmania.exchange/maps/{track_id}" if track_id is not None else None,
                "tmio_leaderboard_url": f"https://trackmania.io/api/leaderboard/map/{uid}?offset=0&length=20",
                "tmio_map_url": f"https://trackmania.io/api/map/{uid}",
                "api_search": "https://trackmania.exchange/api/maps",
                "source_preference": "tmio",
            },
        }
        out["maps"].append(entry)

    if args.out == "-":
        json.dump(out, sys.stdout, ensure_ascii=False, indent=2)
        sys.stdout.write("\n")
    else:
        with open(args.out, "w", encoding="utf-8") as f:
            json.dump(out, f, ensure_ascii=False, indent=2)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
