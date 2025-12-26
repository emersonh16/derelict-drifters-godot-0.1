extends TileMapLayer

enum RequestType {
	BUBBLE,
	CONE,
	LASER
}

# Which tile to paint for fog (TileSet source + atlas coords)
@export var fog_source_id: int = 0
@export var fog_atlas: Vector2i = Vector2i(0, 0)
@export var buffer_tiles := 24
@export var forget_buffer_tiles := 24
var cleared_cells := {}


var last_center := Vector2i(999999, 999999)

# JS Port: Regrow configuration
@export var regrow_chance := 0.6 # 60% chance per check 
@export var regrow_delay_s := 1.0 # Wait 1 second before regrowing 


func _ready():
	add_to_group("miasma")


func _physics_process(_delta):
	var cam := get_viewport().get_camera_2d()
	if not cam:
		return

	var center := local_to_map(to_local(cam.global_position))

	var viewport_size := cam.get_viewport_rect().size
	var tile_size := tile_set.tile_size

	var radius_x := int(ceil(viewport_size.x / tile_size.x)) + buffer_tiles
	var radius_y := int(ceil(viewport_size.y / tile_size.y)) + buffer_tiles

	var forget_radius_x := radius_x + forget_buffer_tiles
	var forget_radius_y := radius_y + forget_buffer_tiles

	
	# JS Port: Process regrow every frame to simulate real-time fog rolling in
	_process_regrow()

	if center == last_center:
		return

	last_center = center
	var cam_world_pos := cam.global_position
	_fill_fog_rect(center, radius_x, radius_y, forget_radius_x, forget_radius_y, cam_world_pos)

func _process_regrow():
	if frontier.is_empty():
		return
		
	var current_time := Time.get_ticks_msec() / 1000.0
	
	# Create a temporary copy to avoid shifting indices during the loop
	var current_frontier = frontier.duplicate()
	# Randomize processing order to prevent directional bias in the "creep"
	current_frontier.shuffle()

	for cell in current_frontier:
		# CRITICAL: Re-verify this is still an edge before regrowing.
		# This prevents "floating" fog tiles from appearing in the middle of cleared areas.
		if not _is_boundary(cell):
			frontier.erase(cell)
			continue

		# Get timestamp from cleared_cells (world-space truth)
		var world_tile_coord := _cell_to_world_tile_coord(cell)
		var t_cleared = cleared_cells.get(world_tile_coord, 0.0)
		if t_cleared == 0.0 or (current_time - t_cleared < regrow_delay_s):
			continue
			
		if randf() < regrow_chance:
			_regrow_cell(cell)

func _regrow_cell(cell: Vector2i):
	# Remove from tracking (world-space)
	var world_tile_coord := _cell_to_world_tile_coord(cell)
	cleared_cells.erase(world_tile_coord)
	frontier.erase(cell)
	
	# Reset the tile to the fog sprite 
	set_cell(cell, fog_source_id, fog_atlas)
	
	# JS Port: Update neighbors because the boundary has shifted 
	_update_neighbors(cell)

func _update_neighbors(cell: Vector2i):
	var neighbors = [
		Vector2i(cell.x - 1, cell.y),
		Vector2i(cell.x + 1, cell.y),
		Vector2i(cell.x, cell.y - 1),
		Vector2i(cell.x, cell.y + 1)
	]
	for n in neighbors:
		# Check cleared_cells (world-space truth)
		var n_world_tile := _cell_to_world_tile_coord(n)
		if cleared_cells.has(n_world_tile):
			_update_frontier(n)


func _fill_fog_rect(center: Vector2i, radius_x: int, radius_y: int, forget_radius_x: int, forget_radius_y: int, camera_world_pos: Vector2) -> void:
	for y in range(center.y - radius_y, center.y + radius_y + 1):
		for x in range(center.x - radius_x, center.x + radius_x + 1):
			var cell := Vector2i(x, y)
			# Check cleared_cells (world-space truth) - skip drawing fog if cleared
			var world_tile_coord := _cell_to_world_tile_coord(cell)
			if cleared_cells.has(world_tile_coord):
				continue
			set_cell(cell, fog_source_id, fog_atlas)

	# Purge old cleared_cells entries (world coordinates)
	var camera_cell := local_to_map(to_local(camera_world_pos))
	var camera_world_tile := _cell_to_world_tile_coord(camera_cell)
	for world_tile in cleared_cells.keys():
		if abs(world_tile.x - camera_world_tile.x) > forget_radius_x or abs(world_tile.y - camera_world_tile.y) > forget_radius_y:
			cleared_cells.erase(world_tile)


# Performance and tracking variables from the JS build
var frontier := [] # Ported from JS 'frontier' Set
var clear_stats := {"calls": 0, "drawn_holes": 0}

# Request interface: Beams submit clearing requests via this function
func submit_request(shape_type: RequestType, world_pos: Vector2) -> void:
	# Detect tile coordinates: if values are small integers, treat as tile coords
	if abs(world_pos.x) < 10000 and abs(world_pos.y) < 10000 and world_pos.x == int(world_pos.x) and world_pos.y == int(world_pos.y):
		_clear_fog_at_cell(Vector2i(int(world_pos.x), int(world_pos.y)))
	else:
		_clear_fog_at_world(world_pos)

# Convert a local TileMap cell to world-space tile coordinate
# This ensures consistent coordinate mapping between clearing and checking
func _cell_to_world_tile_coord(cell: Vector2i) -> Vector2i:
	var cell_world_center := to_global(map_to_local(cell))
	var tile_size := tile_set.tile_size
	return Vector2i(
		int(floor(cell_world_center.x / float(tile_size.x))),
		int(floor(cell_world_center.y / float(tile_size.y)))
	)

func _clear_fog_at_cell(cell: Vector2i) -> void:
	# Convert cell to world-space tile coordinate (same path as _fill_fog_rect uses)
	var world_tile_coord := _cell_to_world_tile_coord(cell)
	var timestamp := Time.get_ticks_msec() / 1000.0
	
	if not cleared_cells.has(world_tile_coord):
		cleared_cells[world_tile_coord] = timestamp # Store world-space truth with timestamp
		print(cell)
		set_cell(cell, -1)
		clear_stats.calls += 1
		_update_frontier(cell)

func _clear_fog_at_world(world_pos: Vector2) -> void:
	var cell := local_to_map(to_local(world_pos))
	# Convert cell to world-space tile coordinate (same path as _fill_fog_rect uses)
	var world_tile_coord := _cell_to_world_tile_coord(cell)
	var timestamp := Time.get_ticks_msec() / 1000.0
	
	if not cleared_cells.has(world_tile_coord):
		cleared_cells[world_tile_coord] = timestamp # Store world-space truth with timestamp
		print(cell)
		set_cell(cell, -1)
		clear_stats.calls += 1
		_update_frontier(cell)

func _update_frontier(cell: Vector2i):
	# JS Port logic: only track cells that are on the boundary of the fog
	if _is_boundary(cell):
		if not cell in frontier:
			frontier.append(cell)
	else:
		frontier.erase(cell)

func _is_boundary(cell: Vector2i) -> bool:
	# Check 4-way neighbors against cleared_cells (world-space truth)
	var neighbors = [
		Vector2i(cell.x - 1, cell.y),
		Vector2i(cell.x + 1, cell.y),
		Vector2i(cell.x, cell.y - 1),
		Vector2i(cell.x, cell.y + 1)
	]
	for n in neighbors:
		# Convert neighbor cell to world-space tile coordinate
		var n_world_tile := _cell_to_world_tile_coord(n)
		# Check cleared_cells (world-space truth)
		if not cleared_cells.has(n_world_tile):
			return true
	return false
