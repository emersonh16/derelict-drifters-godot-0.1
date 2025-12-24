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
@export var max_regrow_per_frame := 10 # Budget to prevent lag 

# Cells we have "carved out" (world-anchored)
# Dictionary: Vector2i -> float (timestamp) 
var cleared := {}

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
	_fill_fog_rect(center, radius_x, radius_y, forget_radius_x, forget_radius_y)

func _process_regrow():
	if frontier.is_empty():
		return
		
	var current_time := Time.get_ticks_msec() / 1000.0
	var regrown_count := 0
	
	# Create a temporary copy to avoid shifting indices during the loop
	var current_frontier = frontier.duplicate()
	# Randomize processing order to prevent directional bias in the "creep"
	current_frontier.shuffle()

	for cell in current_frontier:
		if regrown_count >= max_regrow_per_frame:
			break
			
		# CRITICAL: Re-verify this is still an edge before regrowing.
		# This prevents "floating" fog tiles from appearing in the middle of cleared areas.
		if not _is_boundary(cell):
			frontier.erase(cell)
			continue

		var t_cleared = cleared.get(cell, 0.0)
		if current_time - t_cleared < regrow_delay_s:
			continue
			
		if randf() < regrow_chance:
			_regrow_cell(cell)
			regrown_count += 1

func _regrow_cell(cell: Vector2i):
	# Remove from tracking
	cleared.erase(cell)
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
		if cleared.has(n):
			_update_frontier(n)


func _fill_fog_rect(center: Vector2i, radius_x: int, radius_y: int, forget_radius_x: int, forget_radius_y: int) -> void:
	for y in range(center.y - radius_y, center.y + radius_y + 1):
		for x in range(center.x - radius_x, center.x + radius_x + 1):
			var cell := Vector2i(x, y)
			if cleared.has(cell):
				continue
			set_cell(cell, fog_source_id, fog_atlas)

	for cell in cleared.keys():
		if abs(cell.x - center.x) > forget_radius_x or abs(cell.y - center.y) > forget_radius_y:
			cleared.erase(cell)


# Performance and tracking variables from the JS build
var frontier := [] # Ported from JS 'frontier' Set
var clear_stats := {"calls": 0, "drawn_holes": 0}

# Request interface: Beams submit clearing requests via this function
func submit_request(shape_type: RequestType, world_pos: Vector2) -> void:
	_clear_fog_at_world(world_pos)

# Convert world position to world-space tile coordinate
func _world_pos_to_tile_coord(world_pos: Vector2) -> Vector2i:
	var tile_size := tile_set.tile_size
	return Vector2i(
		int(floor(world_pos.x / float(tile_size.x))),
		int(floor(world_pos.y / float(tile_size.y)))
	)

func _clear_fog_at_world(world_pos: Vector2) -> void:
	var cell := local_to_map(to_local(world_pos))
	var world_tile_coord := _world_pos_to_tile_coord(world_pos)
	
	if not cleared.has(cell):
		cleared[cell] = Time.get_ticks_msec() / 1000.0 # Ported JS timestamping
		cleared_cells[world_tile_coord] = true # Store world-space truth
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
	# Ported from JS isBoundary(): check 4-way neighbors
	var neighbors = [
		Vector2i(cell.x - 1, cell.y),
		Vector2i(cell.x + 1, cell.y),
		Vector2i(cell.x, cell.y - 1),
		Vector2i(cell.x, cell.y + 1)
	]
	for n in neighbors:
		if not cleared.has(n):
			return true
	return false
