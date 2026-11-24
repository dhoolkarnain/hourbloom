extends Node
## Global game state and save system (autoload "GameState").
## Free players get every need here: resources, safe saves, fair rules (Maslow levels 1-2).

signal light_changed(value: int)
signal hours_changed(returned: int, total: int)

const SAVE_PATH := "user://hourbloom_save.json"
const POT_COUNT := 6
const BREAK_NUDGE_SECONDS := 90.0 * 60.0

var light: int = 0
var pots: Array = []            # seed id per pot, "" when empty
var stars: Dictionary = {}      # seed id -> best stars (0-3)
var returned: Array = []        # seed ids whose hour went home (first clear)
var codex: Array = []           # discovered graft ids
var tutorial_step: int = 0      # 0 plant, 1 bloom, 2 graft hint, 3 done
var achievements: Array = []
var fail_counts: Dictionary = {} # seed id -> failed attempts in a row (dynamic difficulty)
var settings := {"assist": false, "sound": true, "haptics": true, "battery_saver": false, "show_fps": false}

var session_seconds: float = 0.0
var break_nudged := false


func _ready() -> void:
	reset_state()
	load_game()
	apply_performance_settings()


func _process(delta: float) -> void:
	session_seconds += delta


func reset_state() -> void:
	light = 0
	pots = []
	for i in POT_COUNT:
		pots.append("")
	stars = {}
	returned = []
	codex = []
	tutorial_step = 0
	achievements = []
	fail_counts = {}
	settings = {"assist": false, "sound": true, "haptics": true, "battery_saver": false, "show_fps": false}


# ---------- Seeds ----------

func all_seed_ids() -> Array:
	var ids: Array = []
	for s in SeedData.SEEDS:
		ids.append(s.id)
	return ids


## Seeds still in the tray: not planted yet.
func tray_seeds() -> Array:
	var out: Array = []
	for id in all_seed_ids():
		if not pots.has(id) and not _consumed_by_graft(id):
			out.append(id)
	return out


func _consumed_by_graft(_id: String) -> bool:
	return false  # Grafting copies seeds in this prototype; originals stay playable.


func plant(seed_id: String, pot_index: int) -> bool:
	if pot_index < 0 or pot_index >= POT_COUNT:
		return false
	if pots[pot_index] != "":
		return false
	pots[pot_index] = seed_id
	if tutorial_step == 0:
		tutorial_step = 1
	save_game()
	return true


func unplant(pot_index: int) -> void:
	# Easy reversal of actions (Shneiderman).
	pots[pot_index] = ""
	save_game()


## Try to graft a tray seed onto a planted pot. Returns the graft dict or {}.
func try_graft(seed_id: String, pot_index: int) -> Dictionary:
	var other: String = pots[pot_index]
	if other == "" or other == seed_id:
		return {}
	var a := SeedData.get_seed(seed_id)
	var b := SeedData.get_seed(other)
	if a.is_empty() or b.is_empty():
		return {}
	var graft := SeedData.find_graft(a.genre, b.genre)
	if graft.is_empty():
		return {}
	pots[pot_index] = graft.id
	if not codex.has(graft.id):
		codex.append(graft.id)
	if tutorial_step < 3:
		tutorial_step = 3
	save_game()
	Platform.unlock("FIRST_GRAFT")
	return graft


# ---------- Results ----------

## Records a finished bloom. Returns a summary for the results screen.
func record_result(seed_id: String, earned_stars: int, assisted := false) -> Dictionary:
	var first_return := false
	if earned_stars == 0:
		fail_counts[seed_id] = int(fail_counts.get(seed_id, 0)) + 1
	else:
		fail_counts.erase(seed_id)
	var best: int = stars.get(seed_id, 0)
	var improved := earned_stars > best
	if improved:
		stars[seed_id] = earned_stars
	if earned_stars > 0 and not returned.has(seed_id):
		returned.append(seed_id)
		first_return = true
	var gained := earned_stars * 10 + (25 if first_return else 0)
	light += gained
	if tutorial_step == 1 and earned_stars > 0:
		tutorial_step = 2
	save_game()
	light_changed.emit(light)
	hours_changed.emit(returned_count(), total_hours())
	Platform.check_after_result(seed_id, earned_stars, assisted)
	return {
		"stars": earned_stars,
		"best": max(best, earned_stars),
		"improved": improved,
		"first_return": first_return,
		"light_gained": gained,
		"fails_in_a_row": int(fail_counts.get(seed_id, 0)),
	}


func returned_count() -> int:
	var n := 0
	for id in returned:
		if not String(id).begins_with("graft_"):
			n += 1
	return n


func total_hours() -> int:
	return SeedData.SEEDS.size()


## 0..1, how much of the city has bloomed. Drives the hub's colour shift.
func bloom_ratio() -> float:
	return float(returned_count()) / float(max(1, total_hours()))


func should_nudge_break() -> bool:
	if not break_nudged and session_seconds >= BREAK_NUDGE_SECONDS:
		break_nudged = true
		return true
	return false


# ---------- Save / load ----------

func to_dict() -> Dictionary:
	return {
		"version": 1,
		"light": light,
		"pots": pots,
		"stars": stars,
		"returned": returned,
		"codex": codex,
		"tutorial_step": tutorial_step,
		"achievements": achievements,
		"fail_counts": fail_counts,
		"settings": settings,
	}


func from_dict(d: Dictionary) -> void:
	reset_state()
	light = int(d.get("light", 0))
	var p: Array = d.get("pots", [])
	for i in min(p.size(), POT_COUNT):
		pots[i] = String(p[i])
	stars = d.get("stars", {})
	for k in stars.keys():
		stars[k] = int(stars[k])
	returned = d.get("returned", [])
	codex = d.get("codex", [])
	tutorial_step = int(d.get("tutorial_step", 0))
	achievements = d.get("achievements", [])
	fail_counts = d.get("fail_counts", {})
	var s: Dictionary = d.get("settings", {})
	for k in s.keys():
		settings[k] = s[k]


func save_game() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Could not save: %s" % FileAccess.get_open_error())
		return
	f.store_string(JSON.stringify(to_dict(), "\t"))


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		from_dict(parsed)


func wipe_save() -> void:
	reset_state()
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


## Battery saver: 30 fps cap, no real-time shadows (mobile thermal + battery guidance).
func apply_performance_settings() -> void:
	Engine.max_fps = 30 if settings.get("battery_saver", false) else 0


func shadows_enabled() -> bool:
	return not OS.has_feature("mobile") and not settings.get("battery_saver", false)


func haptic(ms: int = 25) -> void:
	if settings.get("haptics", true) and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)
