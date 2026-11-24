extends GenreBase
## Puzzle world: rotate tiles to reconnect a broken memory path from left to right.
## Every level is generated from the seed, and is always solvable.
## Controls: tap / click a tile to rotate it. "Hint" highlights one wrong tile.

const N := 1
const E := 2
const S := 4
const W := 8

var grid_n := 5
var tile := 100.0
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
var _spin: Dictionary = {}     # cell -> rotation animation 0..1
var _solve_t := 0.0


func intro_hint() -> String:
	return "Tap tiles to reconnect the memory"


func setup_world() -> void:
	grid_n = 4 if assist else 5
	_rng.seed = hash(seed_id)
	_generate()
	var hint_btn := UI.button("Hint", _on_hint, 20, true)
	UI.place(hint_btn, Vector2(1, 1), Vector2(130, 64), Vector2(-30, -30))
	add_child(hint_btn)


func _origin() -> Vector2:
	return Vector2(size.x / 2.0 - tile * grid_n / 2.0, size.y / 2.0 - tile * grid_n / 2.0 + 30)


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
	# Fill: path tiles get their solved shape, decoys get random pieces.
	var decoys := [N | S, N | E, N | E | S, N | E]
	for i in count:
		tiles[i] = target[i] if target[i] != -1 else decoys[_rng.randi_range(0, decoys.size() - 1)]
	# Scramble every tile, and count the fewest rotations that solve the path.
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
			return path  # dead end: caller retries
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


func _update_lit() -> void:
	lit.clear()
	var start := Vector2i(0, start_row)
	if not (tiles[_idx(start)] & W):
		return
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
	_spin[i] = 1.0
	moves += 1
	if i == _hint_cell:
		_hint_cell = -1
	Sfx.play("rotate", 0.9 + _rng.randf() * 0.2)
	GameState.haptic(8)
	_update_lit()


func _on_hint() -> void:
	for i in tiles.size():
		if target[i] != -1 and tiles[i] != target[i]:
			_hint_cell = i
			Sfx.play("tap", 1.4)
			return


func _on_solved() -> void:
	Sfx.play("graft")
	flash("Memory restored", 1.0)
	var s := 1
	if moves <= optimal + 3:
		s = 3
	elif moves <= optimal + 10:
		s = 2
	finish(s, "Moves %d · Best possible %d" % [moves, optimal])


func tick(delta: float) -> void:
	for k in _spin.keys():
		_spin[k] = maxf(0.0, _spin[k] - delta * 6.0)
	if solved:
		_solve_t += delta


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var local: Vector2 = event.position - _origin()
		var c := Vector2i(int(floor(local.x / tile)), int(floor(local.y / tile)))
		if c.x >= 0 and c.y >= 0 and c.x < grid_n and c.y < grid_n:
			rotate_cell(c)


## Test hook: rotate every path tile to its solution.
func autosolve() -> void:
	for i in tiles.size():
		if target[i] != -1:
			while tiles[i] != target[i] and not solved:
				rotate_cell(Vector2i(i % grid_n, i / grid_n))


func _draw() -> void:
	var o := _origin()
	var board := Rect2(o - Vector2(14, 14), Vector2(tile * grid_n + 28, tile * grid_n + 28))
	draw_rect(board, Color(0.12, 0.1, 0.2, 0.7))
	# entry and exit markers
	var ey := o.y + tile * (start_row + 0.5)
	var xy := o.y + tile * (end_row + 0.5)
	draw_line(Vector2(o.x - 70, ey), Vector2(o.x, ey), UI.GOLD, 10.0)
	draw_circle(Vector2(o.x - 80, ey), 18, UI.GOLD)
	var exit_col := UI.GOLD if solved else Color(1, 1, 1, 0.35)
	draw_line(Vector2(o.x + tile * grid_n, xy), Vector2(o.x + tile * grid_n + 70, xy), exit_col, 10.0)
	draw_string(ThemeDB.fallback_font, Vector2(o.x + tile * grid_n + 84, xy + 10), "✉" if seed.emotion == "regret" else "✿", HORIZONTAL_ALIGNMENT_LEFT, -1, 36, exit_col)
	for y in grid_n:
		for x in grid_n:
			var c := Vector2i(x, y)
			var i := _idx(c)
			var r := Rect2(o + Vector2(x, y) * tile, Vector2(tile, tile)).grow(-5)
			var bg := Color(1, 1, 1, 0.07)
			if i == _hint_cell:
				bg = Color(UI.TEAL, 0.35)
			draw_rect(r, bg)
			var lit_now: bool = lit.has(c)
			var col := UI.GOLD if lit_now else Color("#d9cfe8")
			var w := 14.0 if lit_now else 10.0
			var center := r.get_center()
			var m: int = tiles[i]
			var half := tile / 2.0 - 5.0
			var wobble: float = _spin.get(i, 0.0) * 0.4
			for bit in [N, E, S, W]:
				if m & bit:
					var dir: Vector2 = {N: Vector2(0, -1), E: Vector2(1, 0), S: Vector2(0, 1), W: Vector2(-1, 0)}[bit]
					dir = dir.rotated(-wobble)
					draw_line(center, center + dir * half, col, w)
			draw_circle(center, w * 0.75, col)
	draw_string(ThemeDB.fallback_font, Vector2(30, 112), "Moves %d" % moves, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, UI.INK)
