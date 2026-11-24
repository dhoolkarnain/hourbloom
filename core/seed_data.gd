class_name SeedData
## Every seed is one citizen's unlived hour.
## owner + wish + emotion decide the genre, mood and difficulty (wish-to-genre engine).

const GENRES := {
	"rhythm": {"name": "Rhythm", "icon": "♪", "color": Color("#b07cff")},
	"racing": {"name": "Racing", "icon": "»", "color": Color("#ff8a5c")},
	"puzzle": {"name": "Puzzle", "icon": "◇", "color": Color("#4fd1c5")},
	"graft_racing_rhythm": {"name": "Racing × Rhythm", "icon": "»♪", "color": Color("#ffd36b")},
}

const EMOTIONS := {
	"joy": {"tint": Color("#ffd36b"), "difficulty": 1.0},
	"longing": {"tint": Color("#ff9e7a"), "difficulty": 1.0},
	"regret": {"tint": Color("#7fb2ff"), "difficulty": 1.1},
	"calm": {"tint": Color("#8fe3b0"), "difficulty": 0.9},
}

const SEEDS := [
	{
		"id": "meera_sitar",
		"owner": "Meera, 31, accountant",
		"wish": "Play her old sitar again",
		"emotion": "joy",
		"genre": "rhythm",
		"before": "Meera's sitar has been in its case for six years. The Scheduler filed her evenings under 'overtime'.",
		"after": "Meera opened the case tonight. Her fingers remembered the raag before she did. Her neighbours opened their windows to listen.",
	},
	{
		"id": "kabir_cricket",
		"owner": "Kabir, 46, bus driver",
		"wish": "Watch his daughter's cricket final",
		"emotion": "longing",
		"genre": "racing",
		"before": "Kabir traded his Sunday for an extra shift. His daughter's final went on without him.",
		"after": "Kabir took the evening off. He made it for the last over, just in time to see her hit a six.",
	},
	{
		"id": "tomas_letter",
		"owner": "Tomás, 68, retired clockmaker",
		"wish": "Finish an apology letter to his brother",
		"emotion": "regret",
		"genre": "puzzle",
		"before": "Tomás started the letter eleven years ago. Every time, the Scheduler found something more productive for him to do.",
		"after": "The letter is posted. Tomás's brother called the same evening, and neither of them mentioned the eleven years.",
	},
	{
		"id": "dev_wedding",
		"owner": "Dev, 24, software tester",
		"wish": "Dance at his cousin's wedding",
		"emotion": "joy",
		"genre": "rhythm",
		"before": "Dev watched the wedding on a video call from his desk, muted, during a release.",
		"after": "At the reception Dev danced first and worst, and everyone loved it.",
	},
	{
		"id": "lina_sea",
		"owner": "Lina, 19, student",
		"wish": "Ride her bicycle to the sea at sunrise",
		"emotion": "calm",
		"genre": "racing",
		"before": "Lina has lived forty minutes from the sea her whole life. She has seen it twice.",
		"after": "Lina reached the shore as the sun came up. She didn't take a photo. She just stayed.",
	},
	{
		"id": "asha_garden",
		"owner": "Asha, 52, night-shift nurse",
		"wish": "Relay her mother's garden path",
		"emotion": "calm",
		"genre": "puzzle",
		"before": "Asha's mother planted the garden. After she passed, the stones scattered and the weeds won.",
		"after": "The path is whole again. Asha drinks her morning tea at the end of it, where her mother used to sit.",
	},
]

## Grafts: two seed genres fuse into a hybrid genre.
const GRAFTS := {
	"racing+rhythm": {
		"id": "graft_skyline_beat",
		"genre": "graft_racing_rhythm",
		"title": "Skyline Beat",
		"rule": "The track only appears on the beat.",
	},
}


static func get_seed(id: String) -> Dictionary:
	for s in SEEDS:
		if s.id == id:
			return s
	if id.begins_with("graft_"):
		for g in GRAFTS.values():
			if g.id == id:
				return {
					"id": g.id,
					"owner": "Two hours, grafted",
					"wish": g.title + ": " + g.rule,
					"emotion": "joy",
					"genre": g.genre,
					"before": "Two lost hours, fused into a world nobody has played before.",
					"after": "The grafted hour returned home in two directions at once. Somewhere, two strangers both smiled.",
				}
	return {}


static func graft_key(genre_a: String, genre_b: String) -> String:
	var pair := [genre_a, genre_b]
	pair.sort()
	return pair[0] + "+" + pair[1]


static func find_graft(genre_a: String, genre_b: String) -> Dictionary:
	return GRAFTS.get(graft_key(genre_a, genre_b), {})
