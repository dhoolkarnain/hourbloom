extends Node
func _ready():
	GameState.wipe_save(); GameState.settings.sound = false
	var main = load("res://main.tscn").instantiate(); add_child(main)
	GameState.plant("meera_sitar",0); GameState.plant("kabir_cricket",1); GameState.plant("tomas_letter",2)
	GameState.record_result("meera_sitar",3)
	for pair in [["greenhouse",{}],["rhythm",{"seed_id":"meera_sitar","mode":""}],["racing",{"seed_id":"kabir_cricket","mode":""}],["title",{}]]:
		main.go(pair[0], pair[1])
		for i in 150: await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("/home/claude/shots/fix_%s.png" % pair[0])
	get_tree().quit()
