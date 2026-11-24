extends Node
## Automated play-through test. Run headless:
##   godot --headless --path . --fixed-fps 60 res://tests/test_runner.tscn
## With a display, pass `-- --shots=/abs/dir` to also save screenshots.

var main: Control
var failures := 0
var shots_dir := ""


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shots_dir = a.substr(8)
	await _run()
	print("\n%s: %d failure(s)" % ["PASS" if failures == 0 else "FAIL", failures])
	get_tree().quit(1 if failures else 0)


func check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		failures += 1
		print("  FAIL ", what)


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func shot(name: String) -> void:
	if shots_dir == "":
		return
	await frames(3)
	var img := get_viewport().get_texture().get_image()
	img.save_png(shots_dir.path_join(name + ".png"))


func wait_for_screen(screen: String, step: Callable, max_frames := 6000) -> bool:
	for i in max_frames:
		if main.current_name == screen:
			return true
		if step.is_valid():
			step.call()
		await get_tree().process_frame
	return false


func _run() -> void:
	GameState.wipe_save()
	GameState.settings.sound = false
	main = load("res://main.tscn").instantiate()
	add_child(main)
	await frames(5)

	print("Title")
	check(main.current_name == "title", "starts on title screen")
	await shot("01_title")

	print("Greenhouse")
	main.go("greenhouse")
	await frames(5)
	check(main.current.cards.size() == 6, "tray shows 6 seeds")
	await shot("02_greenhouse_empty")
	main.current._on_seed_dropped(0, "meera_sitar")
	main.current._on_seed_dropped(1, "kabir_cricket")
	main.current._on_seed_dropped(2, "tomas_letter")
	await frames(3)
	check(GameState.pots[0] == "meera_sitar", "seed planted by drop")
	check(main.current.cards.size() == 3, "planted seeds leave the tray")
	check(GameState.tutorial_step == 1, "tutorial advances after planting")
	main.current._on_card_tapped("lina_sea")
	main.current._on_pot_tapped(3)
	await frames(2)
	check(GameState.pots[3] == "lina_sea", "tap-to-select then tap-pot plants (accessible fallback)")
	main.current._on_unplant(3)
	check(GameState.pots[3] == "", "unplant returns the seed (easy reversal)")
	await shot("03_greenhouse_planted")

	print("Rhythm world")
	main.play_seed("meera_sitar")
	await frames(2)
	check(main.current_name == "rhythm", "rhythm seed opens the rhythm world")
	await frames(30)
	await shot("04_rhythm")
	var ok := await wait_for_screen("results", func():
		if main.current_name == "rhythm":
			main.current.autoplay_step())
	check(ok, "rhythm world finishes")
	check(GameState.stars.get("meera_sitar", 0) == 3, "perfect play earns 3 stars (got %d)" % GameState.stars.get("meera_sitar", 0))
	check(GameState.returned.has("meera_sitar"), "hour is returned home")
	await frames(90)
	await shot("05_results")

	print("Racing world")
	main.play_seed("kabir_cricket")
	await frames(2)
	check(main.current_name == "racing", "racing seed opens the racing world")
	await frames(200)
	await shot("06_racing")
	ok = await wait_for_screen("results", func():
		if main.current_name == "racing":
			main.current.autoplay_step())
	check(ok, "racing world finishes")
	check(GameState.stars.get("kabir_cricket", 0) >= 2, "good driving earns 2+ stars (got %d)" % GameState.stars.get("kabir_cricket", 0))

	print("Puzzle world")
	main.play_seed("tomas_letter")
	await frames(100)
	check(main.current_name == "puzzle", "puzzle seed opens the puzzle world")
	await shot("07_puzzle")
	main.current.autosolve()
	check(main.current.solved, "puzzle path connects when solved")
	ok = await wait_for_screen("results", Callable())
	check(ok, "puzzle finishes")
	check(GameState.stars.get("tomas_letter", 0) == 3, "optimal solve earns 3 stars")

	print("Generated puzzles are always solvable")
	var all_ok := true
	for i in 40:
		var p = load("res://genres/puzzle.gd").new()
		p.params = {"seed_id": "asha_garden"}
		p.seed_id = "test_%d" % i
		p._rng.seed = i
		p.seed = SeedData.get_seed("asha_garden")
		p.grid_n = 5
		p._generate()
		p.running = true
		p.autosolve()
		all_ok = all_ok and p.solved
		p.free()
	check(all_ok, "40 random puzzles all solvable")

	print("Graft")
	main.go("greenhouse")
	await frames(3)
	main.current._on_seed_dropped(1, "meera_sitar")  # rhythm onto racing pot
	await frames(3)
	check(GameState.pots[1] == "graft_skyline_beat", "racing + rhythm grafts into Skyline Beat")
	check(GameState.codex.has("graft_skyline_beat"), "graft recorded in the notebook")
	main.current._on_seed_dropped(2, "dev_wedding")  # rhythm onto puzzle: no graft yet
	check(GameState.pots[2] == "tomas_letter", "incompatible graft is refused safely")
	await shot("08_greenhouse_graft")
	main.play_seed("graft_skyline_beat")
	await frames(2)
	check(main.current_name == "racing" and main.current.beat_mode, "graft opens racing in beat mode")
	await frames(150)
	await shot("09_graft_world")
	ok = await wait_for_screen("results", func():
		if main.current_name == "racing":
			main.current.autoplay_step())
	check(ok, "graft world finishes")

	print("Notebook and settings")
	main.go("codex")
	await frames(3)
	check(main.current_name == "codex", "notebook opens")
	await shot("10_notebook")
	main.go("settings")
	await frames(3)
	check(main.current_name == "settings", "settings opens")

	print("Save and load")
	var before := GameState.to_dict()
	GameState.save_game()
	GameState.reset_state()
	GameState.load_game()
	check(GameState.light == before.light and GameState.light > 0, "Light survives save/load (%d)" % GameState.light)
	check(GameState.returned.size() == before.returned.size(), "returned hours survive save/load")
	check(GameState.pots == before.pots, "pots survive save/load")
	GameState.wipe_save()
