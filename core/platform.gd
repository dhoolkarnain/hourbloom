extends Node
## Platform services (autoload "Platform"): achievements now, cloud saves and
## leaderboards later. Uses Steam when the GodotSteam extension is present,
## otherwise keeps achievements locally (mobile, or dev builds).

signal achievement_unlocked(id: String, title: String)

## Data-driven list. Ids match the Steamworks achievement API names.
const ACHIEVEMENTS := {
	"FIRST_BLOOM": {"title": "First Bloom", "text": "Return your first hour home."},
	"FIRST_GRAFT": {"title": "Gardener of Genres", "text": "Graft two seeds into a new world."},
	"PERFECT_RHYTHM": {"title": "Not a Note Missed", "text": "Finish a rhythm world with 3 stars."},
	"ALL_HOURS": {"title": "The City Remembers", "text": "Return every hour in the prototype."},
	"GENTLE_TRY": {"title": "Rest Is Not Weakness", "text": "Finish a world in Assist mode."},
}

var steam: Object = null


func _ready() -> void:
	if Engine.has_singleton("Steam"):
		steam = Engine.get_singleton("Steam")
		var res = steam.call("steamInitEx", false)
		print("Steam init: ", res)


func unlock(id: String) -> void:
	if not ACHIEVEMENTS.has(id) or GameState.achievements.has(id):
		return
	GameState.achievements.append(id)
	GameState.save_game()
	if steam:
		steam.call("setAchievement", id)
		steam.call("storeStats")
	achievement_unlocked.emit(id, ACHIEVEMENTS[id].title)


## Called after every finished bloom.
func check_after_result(seed_id: String, stars: int, assisted: bool) -> void:
	if stars > 0:
		unlock("FIRST_BLOOM")
	if stars == 3 and SeedData.get_seed(seed_id).get("genre", "") == "rhythm":
		unlock("PERFECT_RHYTHM")
	if GameState.returned_count() >= GameState.total_hours():
		unlock("ALL_HOURS")
	if assisted and stars > 0:
		unlock("GENTLE_TRY")
