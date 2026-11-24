extends GenreBase
## Puzzle world (3D): rotate tiles on a garden table to reconnect a broken memory path.
## Every level is generated from the seed and is always solvable.
## Controls: tap / click a tile to rotate it. "Hint" highlights one wrong tile.

const N := 1
const E := 2
const S := 4
const W := 8
const ARM_ANGLE := {N: 0.0, E: -PI / 2, S: PI, W: PI / 2}

var grid_n := 5
var tiles: Array = []          # current mask per cell (index = y * grid_n + x)
var target: Array = []         # solved mask for path cells, -1 for decoys
var start_row := 0
var end_row := 0
var moves := 0
var optimal := 0
var solved := false
var lit: Dictionary = {}       # cells connected to the start
var _hint_cell := -1
var _rng := RandomNumberGenerator.new()
var _pipes: Array = []         # Node3D per cell holding hub + arms
var _slabs: Array = []
var _goal_flower: Node3D
var _mat_lit: StandardMaterial3D
var _mat_dim: StandardMaterial3D
var _mat_hint: StandardMaterial3D
var _mat_slab: StandardMaterial3D
var _mat_cursor: StandardMaterial3D
var _cursor := Vector2i(0, 0)
var _cursor_on := false        # shown once a keyboard / gamepad is used


func intro_hint() -> String:
	return "Tap tiles to reconnect the memory"


func music_track() -> String:
	return "hub"


func setup_world() -> void:
	grid_n = 4 if assist else 5
	_rng.seed = hash(seed_id)
	_generate()
	_cursor = Vector2i(0, start_row)
	if is_inside_tree():
		_build_board()
		camera.position = Vector3(0, 7.2, 4.6)
		camera.look_at(Vector3(0, 0, 0.3))
		var hint_btn := UI.button("Hint", _on_hint, 20, true)
		UI.place(hint_btn, Vector2(1, 1), Vector2(130, 64), Vector2(-30, -30))
		add_child(hint_btn)


func _generate() -> void:
	var count := grid_n * grid_n
	tiles.resize(count)
	target.resize(count)
	for i in count:
		target[i] = -1
	# Random self-avoiding walk from the left edge to the right edge.
	var path: Array = []
	for attempt in 200:
		path = _random_path()
		if path[-1].x == grid_n - 1 and path.size() >= grid_n + 2:
			break
	start_row = path[0].y
	end_row = path[-1].y
	for i in path.size():
		var c: Vector2i = path[i]
		var m := 0
		if i == 0:
			m |= W
		else:
			m |= _dir_mask(c, path[i - 1])
		if i == path.size() - 1:
			m |= E
		else:
			m |= _dir_mask(c, path[i + 1])
		target[_idx(c)] = m
	var decoys := [N | S, N | E, N | E | S, N | E]
	for i in count:
		tiles[i] = target[i] if target[i] != -1 else decoys[_rng.randi_range(0, decoys.size() - 1)]
	optimal = 0
	for i in count:
		var r := _rng.randi_range(0, 3)
		for k in r:
			tiles[i] = _rot(tiles[i])
		if target[i] != -1:
			optimal += _min_rot(tiles[i], target[i])
	if optimal == 0:
		var first := _idx(path[0])
		tiles[first] = _rot(tiles[first])
		optimal = _min_rot(tiles[first], target[first])
	_update_lit()


func _random_path() -> Array:
	var cur := Vector2i(0, _rng.randi_range(0, grid_n - 1))
	var path: Array = [cur]
	var seen := {cur: true}
	var guard := 0
	while cur.x < grid_n - 1 and guard < 200:
		guard += 1
		var opts: Array = []
		for d in [Vector2i(1, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx: Vector2i = cur + d
			if nx.x >= 0 and nx.x < grid_n and nx.y >= 0 and nx.y < grid_n and not seen.has(nx):
				opts.append(nx)
		if opts.is_empty():
			return path
		cur = opts[_rng.randi_range(0, opts.size() - 1)]
		seen[cur] = true
		path.append(cur)
	return path


func _dir_mask(from: Vector2i, to: Vector2i) -> int:
	var d := to - from
	if d == Vector2i(0, -1):
		return N
	if d == Vector2i(1, 0):
		return E
	if d == Vector2i(0, 1):
		return S
	return W


func _idx(c: Vector2i) -> int:
	return c.y * grid_n + c.x


func _rot(m: int) -> int:
	return ((m << 1) | (m >> 3)) & 15


func _min_rot(from: int, to: int) -> int:
	var m := from
	for k in 4:
		if m == to:
			return k
		m = _rot(m)
	return 0


# ---------------------------------------------------------------- 3D board

func _cell_pos(c: Vector2i) -> Vector3:
	var half := (grid_n - 1) / 2.0
	return Vector3(c.x - half, 0, c.y - half)


func _build_board() -> void:
	_mat_lit = Stage.flat_material(UI.GOLD, 1.6)
	_mat_dim = Stage.flat_material(Color("#d9cfe8"))
	_mat_hint = Stage.flat_material(UI.TEAL, 0.8)
	_mat_slab = Stage.flat_material(Color("#2e2648"))
	_mat_cursor = Stage.flat_material(Color("#5a4b8a"), 0.4)
	var table := Stage.box(Vector3(grid_n + 3.2, 0.3, grid_n + 1.2), Color("#6b4f45"))
	table.position = Vector3(0, -0.16, 0)
	world.add_child(table)
	var cloth := Stage.box(Vector3(grid_n + 0.5, 0.02, grid_n + 0.5), Color("#1f1a33"))
	cloth.position = Vector3(0, 0.0, 0)
	world.add_child(cloth)
	for y in grid_n:
		for x in grid_n:
			var c := Vector2i(x, y)
			var slab := Stage.model("tile_slab")
			slab.position = _cell_pos(c)
			world.add_child(slab)
			_slabs.append(slab)
			var pipes := Node3D.new()
			pipes.position = _cell_pos(c)
			world.add_child(pipes)
			_pipes.append(pipes)
	for i in tiles.size():
		_rebuild_pipes(i, false)
	# entry orb (where the memory starts) and the goal flower (where it leads)
	var orb := Stage.model("orb")
	orb.position = _cell_pos(Vector2i(0, start_row)) + Vector3(-1.1, 0.3, 0)
	world.add_child(orb)
	var feed := Stage.box(Vector3(0.6, 0.12, 0.16), UI.GOLD, 1.6)
	feed.position = _cell_pos(Vector2i(0, start_row)) + Vector3(-0.75, 0.22, 0)
	world.add_child(feed)
	_goal_flower = Stage.model("flower")
	_goal_flower.position = _cell_pos(Vector2i(grid_n - 1, end_row)) + Vector3(1.2, 0, 0)
	_goal_flower.scale = Vector3.ONE * 0.5
	Stage.tint(_goal_flower, "Petals", Color("#7fb2ff") if seed.emotion == "regret" else Color("#8fe3b0"), 0.3)
	world.add_child(_goal_flower)
	var pot := Stage.model("pot")
	pot.position = _goal_flower.position + Vector3(0, -0.78 * 0.5, 0)
	pot.scale = Vector3.ONE * 0.5
	world.add_child(pot)
	_goal_flower.position.y += 0.0
	_refresh_colors()


func _rebuild_pipes(i: int, animate: bool) -> void:
	if _pipes.is_empty():
		return
	var holder: Node3D = _pipes[i]
	for ch in holder.get_children():
		ch.queue_free()
	var hub := Stage.model("tile_hub")
	holder.add_child(hub)
	var m: int = tiles[i]
	for bit in [N, E, S, W]:
		if m & bit:
			var arm := Stage.model("tile_arm")
			arm.rotation.y = ARM_ANGLE[bit]
			holder.add_child(arm)
	if animate:
		holder.rotation.y = PI / 2  # previous orientation, then spin clockwise into place
		create_tween().tween_property(holder, "rotation:y", 0.0, 0.16).set_trans(Tween.TRANS_BACK)


func _paint(node: Node, m: Material) -> void:
	for ch in node.get_children():
		if ch is MeshInstance3D:
			ch.material_override = m
		_paint(ch, m)


func _refresh_colors() -> void:
	if _pipes.is_empty():
		return
	for y in grid_n:
		for x in grid_n:
			var c := Vector2i(x, y)
			var i := _idx(c)
			_paint(_pipes[i], _mat_lit if lit.has(c) else _mat_dim)
			var slab_mat := _mat_slab
			if i == _hint_cell:
				slab_mat = _mat_hint
			elif _cursor_on and c == _cursor:
				slab_mat = _mat_cursor
			_paint(_slabs[i], slab_mat)


func _update_lit() -> void:
	lit.clear()
	var start := Vector2i(0, start_row)
	if tiles[_idx(start)] & W:
		var queue: Array = [start]
		lit[start] = true
		var dirs := {N: Vector2i(0, -1), E: Vector2i(1, 0), S: Vector2i(0, 1), W: Vector2i(-1, 0)}
		var opposite := {N: S, E: W, S: N, W: E}
		while not queue.is_empty():
			var c: Vector2i = queue.pop_front()
			var m: int = tiles[_idx(c)]
			for bit in dirs.keys():
				if not (m & bit):
					continue
				var nc: Vector2i = c + dirs[bit]
				if nc.x < 0 or nc.y < 0 or nc.x >= grid_n or nc.y >= grid_n or lit.has(nc):
					continue
				if tiles[_idx(nc)] & opposite[bit]:
					lit[nc] = true
					queue.append(nc)
	var end := Vector2i(grid_n - 1, end_row)
	if lit.has(end) and (tiles[_idx(end)] & E) and not solved:
		solved = true
		_on_solved()


func rotate_cell(c: Vector2i) -> void:
	if solved or not running:
		return
	var i := _idx(c)
	tiles[i] = _rot(tiles[i])
	moves += 1
	if i == _hint_cell:
		_hint_cell = -1
	_rebuild_pipes(i, true)
	Sfx.play("rotate", 0.9 + _rng.randf() * 0.2)
	GameState.haptic(8)
	_update_lit()
	_refresh_colors()


func _on_hint() -> void:
	for i in tiles.size():
		if target[i] != -1 and tiles[i] != target[i]:
			_hint_cell = i
			Sfx.play("tap", 1.4)
			_refresh_colors()
			return


func _on_solved() -> void:
	Sfx.play("graft")
	flash("Memory restored", 1.0)
	if _goal_flower and is_inside_tree():
		create_tween().tween_property(_goal_flower, "scale", Vector3.ONE * 1.4, 0.6).set_trans(Tween.TRANS_BACK)
	var s := 1
	if moves <= optimal + 3:
		s = 3
	elif moves <= optimal + 10:
		s = 2
	finish(s, "Moves %d · Best possible %d" % [moves, optimal])


func _input(event: InputEvent) -> void:
	if running and not solved:
		var d := Vector2i.ZERO
		if Controls.pressed(event, "move_left"):
			d = Vector2i(-1, 0)
		elif Controls.pressed(event, "move_right"):
			d = Vector2i(1, 0)
		elif Controls.pressed(event, "move_up"):
			d = Vector2i(0, -1)
		elif Controls.pressed(event, "move_down"):
			d = Vector2i(0, 1)
		if d != Vector2i.ZERO:
			_cursor_on = true
			_cursor = Vector2i(clampi(_cursor.x + d.x, 0, grid_n - 1), clampi(_cursor.y + d.y, 0, grid_n - 1))
			Sfx.play("tap", 1.6)
			_refresh_colors()
			return
		if Controls.pressed(event, "confirm"):
			_cursor_on = true
			rotate_cell(_cursor)
			return
		if Controls.pressed(event, "hint"):
			_on_hint()
			return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if camera == null or event.position.y < 80:
			return
		var hit = Stage.screen_to_plane(camera, event.position, 0.2)
		if hit == null:
			return
		var half := grid_n / 2.0
		var c := Vector2i(int(floor(hit.x + half)), int(floor(hit.z + half)))
		if c.x >= 0 and c.y >= 0 and c.x < grid_n and c.y < grid_n:
			_cursor_on = false
			rotate_cell(c)


## Test hook: rotate every path tile to its solution.
func autosolve() -> void:
	for i in tiles.size():
		if target[i] != -1:
			while tiles[i] != target[i] and not solved:
				rotate_cell(Vector2i(i % grid_n, i / grid_n))


func _draw() -> void:
	draw_string(ThemeDB.fallback_font, Vector2(30, 112), "Moves %d" % moves, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, UI.INK)
