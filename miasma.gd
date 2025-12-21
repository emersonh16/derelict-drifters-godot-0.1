extends TileMapLayer

# Which tile to paint for fog (TileSet source + atlas coords)
@export var fog_source_id: int = 0
@export var fog_atlas: Vector2i = Vector2i(0, 0)
@export var buffer_tiles := 24
@export var forget_buffer_tiles := 24



var last_center := Vector2i(999999, 999999)

# JS Port: Regrow configuration
@export var regrow_chance := 0.6 # 60% chance per check 
@export var regrow_delay_s := 1.0 # Wait 1 second before regrowing 
@export var max_regrow_per_frame := 10 # Budget to prevent lag 

# Cells we have "carved out" (world-anchored)
# Dictionary: Vector2i -> float (timestamp) 
var cleared := {}

func _ready():
	add_to_group("miasma")


func _physics_process(_delta):
	var cam: Camera2D = get_viewport().get_camera_2d()
	if not cam:
		return

	var center: Vector2i = local_to_map(to_local(cam.global_position))

	var viewport_size: Vector2 = cam.get_viewport_rect().size
	var tile_size: Vector2i = tile_set.tile_size

	var radius_x: int = int(ceil(viewport_size.x / tile_size.x)) + buffer_tiles
	var radius_y: int = int(ceil(viewport_size.y / tile_size.y)) + buffer_tiles

	var forget_radius_x: int = radius_x + forget_buffer_tiles
	var forget_radius_y: int = radius_y + forget_buffer_tiles

	
	# JS Port: Process regrow every frame to simulate real-time fog rolling in
	_process_regrow()

	if center == last_center:
		return

	last_center = center
	_fill_fog_rect(center, radius_x, radius_y, forget_radius_x, forget_radius_y)



func _regrow_cell(cell: Vector2i):
	# Remove from tracking
	cleared.erase(cell)
	frontier.erase(cell)
	
	# Reset the tile to the fog sprite 
	set_cell(cell, fog_source_id, fog_atlas)
	
	# JS Port: Update neighbors because the boundary has shifted 
	_update_neighbors(cell)

func _update_neighbors(cell: Vector2i):
	var neighbors: Array = [
		Vector2i(cell.x - 1, cell.y),
		Vector2i(cell.x + 1, cell.y),
		Vector2i(cell.x, cell.y - 1),
		Vector2i(cell.x, cell.y + 1)
	]
	for n in neighbors:
		if cleared.has(n):
			_update_frontier(n)


func _fill_fog_rect(center: Vector2i, radius_x: int, radius_y: int, forget_radius_x: int, forget_radius_y: int) -> void:
	for y in range(center.y - radius_y, center.y + radius_y + 1):
		for x in range(center.x - radius_x, center.x + radius_x + 1):
			var cell: Vector2i = Vector2i(x, y)
			if cleared.has(cell):
				continue
			set_cell(cell, fog_source_id, fog_atlas)

	for cell in cleared.keys():
		if abs(cell.x - center.x) > forget_radius_x or abs(cell.y - center.y) > forget_radius_y:
			cleared.erase(cell)


# Performance and tracking variables from the JS build
var frontier := {} # Changed from Array to Dictionary for O(1) performance
var clear_stats := {"calls": 0, "drawn_holes": 0}


func _update_frontier(cell: Vector2i):
	# JS Port logic: only track cells that are on the boundary of the fog
	if _is_boundary(cell):
		# Dictionaries use assignment, not .append()
		frontier[cell] = true
	else:
		frontier.erase(cell)

func _is_boundary(cell: Vector2i) -> bool:
	# Ported from JS isBoundary(): check 4-way neighbors
	var neighbors: Array = [
		Vector2i(cell.x - 1, cell.y),
		Vector2i(cell.x + 1, cell.y),
		Vector2i(cell.x, cell.y - 1),
		Vector2i(cell.x, cell.y + 1)
	]
	for n in neighbors:
		if not cleared.has(n):
			return true
	return false
	

		
# Fixed elliptical clearing for isometric 2:1 matching
func clear_circle(world_pos: Vector2, radius_px: float):
	var local_pos: Vector2 = to_local(world_pos)
	var center_cell: Vector2i = local_to_map(local_pos)
	
	# Scale tile radius to match the 16:8 (2:1) isometric grid ratio
	var tile_r_x: int = int(ceil(radius_px / 16.0))
	var tile_r_y: int = int(ceil(float(tile_r_x) * 0.5))
	
	for dy in range(-tile_r_y, tile_r_y + 1):
		for dx in range(-tile_r_x, tile_r_x + 1):
			var normalized_x: float = float(dx) / float(tile_r_x) if tile_r_x > 0 else 0.0
			var normalized_y: float = float(dy) / float(tile_r_y) if tile_r_y > 0 else 0.0
			
			# Elliptical distance check
			if (normalized_x * normalized_x) + (normalized_y * normalized_y) <= 1.0:
				var target_cell: Vector2i = center_cell + Vector2i(dx, dy)
				clear_fog_at_cell(target_cell)


func _process_regrow():
	var keys: Array = frontier.keys()
	var key_count: int = keys.size()
	if key_count == 0:
		return

	var current_time: float = Time.get_ticks_msec() / 1000.0
	var regrown_count := 0

	# Avoid shuffling the whole frontier every frame.
	# Sample a bounded number of candidates; this keeps cost stable.
	var max_attempts: int = min(key_count, max_regrow_per_frame * 4)

	for _i in range(max_attempts):
		if regrown_count >= max_regrow_per_frame:
			break

		var cell: Vector2i = keys[randi() % key_count]

		if not _is_boundary(cell):
			frontier.erase(cell)
			continue

		var t_cleared: float = float(cleared.get(cell, 0.0))
		if current_time - t_cleared < regrow_delay_s:
			continue

		if randf() < regrow_chance:
			_regrow_cell(cell)
			regrown_count += 1


func clear_fog_at_world(world_pos: Vector2) -> void:
	var cell: Vector2i = local_to_map(to_local(world_pos))
	clear_fog_at_cell(cell)


func clear_path(start_world: Vector2, end_world: Vector2, radius_px: float):
	var dist: float = start_world.distance_to(end_world)
	var dir: Vector2 = start_world.direction_to(end_world)

	# Step by half a tile to ensure no gaps are missed
	var step_size: float = (tile_set.tile_size.x * 0.5)
	var steps: int = int(dist / step_size)

	for i in range(steps + 1):
		var stamp_pos: Vector2 = start_world + (dir * i * step_size)
		clear_circle(stamp_pos, radius_px)


func clear_fog_at_cell(cell: Vector2i) -> void:
	if not cleared.has(cell):
		cleared[cell] = Time.get_ticks_msec() / 1000.0
		set_cell(cell, -1)
		clear_stats["calls"] += 1
		_update_frontier(cell)
