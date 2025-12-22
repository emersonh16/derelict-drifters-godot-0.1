extends TileMapLayer

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

# Clearing request queue and budget
var clear_queue: Array = []
@export var max_clears_per_frame := 50 # Budget to ensure 60 FPS

@export var wind_velocity := Vector2(0.5, 0.0) # Drift speed in pixels/sec
var miasma_offset := Vector2.ZERO # Cumulative drift offset in pixels

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

	
	# Process clearing requests (budgeted)
	_process_clear_queue()
	
	# JS Port: Process regrow every frame to simulate real-time fog rolling in
	_process_regrow()

	if center == last_center:
		return

	last_center = center
	_fill_fog_rect(center, radius_x, radius_y, forget_radius_x, forget_radius_y)

func _process_regrow():
	var keys = frontier.keys()
	if keys.is_empty():
		return
		
	var current_time := Time.get_ticks_msec() / 1000.0
	var regrown_count := 0
	
	keys.shuffle() # Prevent directional bias

	for cell in keys:
		if regrown_count >= max_regrow_per_frame:
			break
			
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
var frontier := {} # Changed from Array to Dictionary for O(1) performance
var clear_stats := {"calls": 0, "drawn_holes": 0}

# DEPRECATED: Use submit_request() instead
func clear_fog_at_world(world_pos: Vector2) -> void:
	var cell := local_to_map(to_local(world_pos))
	clear_fog_at_cell(cell)

func _update_frontier(cell: Vector2i):
	# JS Port logic: only track cells that are on the boundary of the fog
	if _is_boundary(cell):
		# Dictionaries use assignment, not .append()
		frontier[cell] = true
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
	
# DEPRECATED: Use submit_request() instead
func clear_path(start_world: Vector2, end_world: Vector2, radius_px: float):
	submit_request("laser", {
		"origin_world": start_world,
		"aim_angle": start_world.direction_to(end_world).angle(),
		"focus": 1.0
	})

# DEPRECATED: Use submit_request() instead  
func clear_circle(world_pos: Vector2, radius_px: float):
	# Legacy function - prefer submit_request for new code
	_process_circle_stamp(world_pos, radius_px)

# Helper function to consolidate clearing logic
func clear_fog_at_cell(cell: Vector2i) -> void:
	if not cleared.has(cell):
		cleared[cell] = Time.get_ticks_msec() / 1000.0
		set_cell(cell, -1)
		clear_stats.calls += 1
		_update_frontier(cell)

# ============================================================================
# REQUEST-BASED CLEARING API
# ============================================================================

# Submit a clearing request (beams call this, never mutate directly)
func submit_request(shape_type: String, data: Dictionary) -> void:
	clear_queue.append({"type": shape_type, "data": data})

# Process queued clearing requests with per-frame budget
func _process_clear_queue() -> void:
	var processed: int = 0
	while processed < max_clears_per_frame and not clear_queue.is_empty():
		var request: Dictionary = clear_queue.pop_front()
		var shape_type: String = request.get("type", "")
		var data: Dictionary = request.get("data", {})
		
		match shape_type:
			"bubble":
				_process_bubble_request(data)
			"cone":
				_process_cone_request(data)
			"laser":
				_process_laser_request(data)
		
		processed += 1

# ============================================================================
# CONSOLIDATED CLEARING LOGIC (All gameplay reasoning in Top-Down Space)
# ============================================================================

# Bubble: Elliptical check in local space
func _process_bubble_request(data: Dictionary) -> void:
	var center_world: Vector2 = data.get("center_world", Vector2.ZERO)
	var bubble_tiles: float = data.get("bubble_tiles", 6.0)
	var node_rotation: float = data.get("node_rotation", 0.0)
	
	const MIASMA_TILE_X: float = 16.0
	const MIASMA_TILE_Y: float = 8.0
	
	var center_cell: Vector2i = local_to_map(to_local(center_world))
	var r_tiles_x: int = int(bubble_tiles)
	var r_tiles_y: int = int(ceil(bubble_tiles * (MIASMA_TILE_X / MIASMA_TILE_Y)))
	var rx: float = bubble_tiles * MIASMA_TILE_X
	var ry: float = bubble_tiles * MIASMA_TILE_Y
	
	for dy in range(-r_tiles_y, r_tiles_y + 1):
		for dx in range(-r_tiles_x, r_tiles_x + 1):
			var cell: Vector2i = center_cell + Vector2i(dx, dy)
			var cell_world: Vector2 = to_global(map_to_local(cell))
			
			# Convert to node's local space (accounting for rotation)
			var cell_local: Vector2 = (cell_world - center_world).rotated(-node_rotation)
			
			# Elliptical distance check in local space
			if ((cell_local.x * cell_local.x) / (rx * rx) + (cell_local.y * cell_local.y) / (ry * ry)) <= 1.0:
				clear_fog_at_cell(cell)

# Cone: Pixel-perfect polygon testing (matches beamcone.gd visuals exactly)
func _process_cone_request(data: Dictionary) -> void:
	var origin_world: Vector2 = data.get("origin_world", Vector2.ZERO)
	var aim_angle: float = data.get("aim_angle", 0.0)
	var focus: float = data.get("focus", 0.0)
	var node_rotation: float = data.get("node_rotation", 0.0)
	
	const CONE_MIN_LENGTH_TILES: float = 6.0
	const CONE_MAX_LENGTH_TILES: float = 18.0
	const CONE_MIN_ANGLE: float = deg_to_rad(10.0)
	const CONE_MAX_ANGLE: float = deg_to_rad(60.0)
	const MIASMA_TILE_X: float = 16.0
	
	# Calculate cone geometry in top-down space (exactly matching beamcone.gd _draw())
	var t: float = clamp(focus, 0.0, 1.0)
	var length_px: float = lerp(CONE_MIN_LENGTH_TILES, CONE_MAX_LENGTH_TILES, t) * MIASMA_TILE_X
	var half_angle: float = lerp(CONE_MAX_ANGLE, CONE_MIN_ANGLE, t)
	
	var forward: Vector2 = Vector2.RIGHT.rotated(aim_angle)
	var left_td: Vector2 = forward.rotated(half_angle) * length_px
	var right_td: Vector2 = forward.rotated(-half_angle) * length_px
	
	if left_td.cross(right_td) < 0.0:
		var tmp: Vector2 = left_td
		left_td = right_td
		right_td = tmp
	
	# Body triangle: [Vector2.ZERO, left_td, right_td] in top-down space
	var body_triangle: PackedVector2Array = PackedVector2Array([Vector2.ZERO, left_td, right_td])
	
	# Cap semicircle: center and radius in top-down space
	var cap_center_td: Vector2 = (left_td + right_td) * 0.5
	var cap_radius_td: float = (right_td - left_td).length() * 0.5
	
	# Semicircle angle range (used for both bounding box and cap test)
	var angle_min: float = aim_angle - PI * 0.5
	var angle_max: float = aim_angle + PI * 0.5
	
	# Calculate bounding box in world space (encompass entire cone)
	# Project triangle vertices and cap extent to world space via isometric
	var world_points: PackedVector2Array = PackedVector2Array()
	world_points.append(origin_world + IsoMath.to_iso(Vector2.ZERO))
	world_points.append(origin_world + IsoMath.to_iso(left_td))
	world_points.append(origin_world + IsoMath.to_iso(right_td))
	
	# Add cap bounding box (semicircle extends from angle_min to angle_max)
	var cap_world: Vector2 = origin_world + IsoMath.to_iso(cap_center_td)
	# Include semicircle extremes
	world_points.append(cap_world)
	world_points.append(origin_world + IsoMath.to_iso(cap_center_td + Vector2(cos(angle_min), sin(angle_min)) * cap_radius_td))
	world_points.append(origin_world + IsoMath.to_iso(cap_center_td + Vector2(cos(angle_max), sin(angle_max)) * cap_radius_td))
	world_points.append(origin_world + IsoMath.to_iso(cap_center_td + forward * cap_radius_td))
	
	# Find bounding box
	var min_x: float = world_points[0].x
	var max_x: float = world_points[0].x
	var min_y: float = world_points[0].y
	var max_y: float = world_points[0].y
	for pt in world_points:
		min_x = min(min_x, pt.x)
		max_x = max(max_x, pt.x)
		min_y = min(min_y, pt.y)
		max_y = max(max_y, pt.y)
	
	# Expand bounding box by one tile to ensure coverage
	var tile_size: Vector2i = tile_set.tile_size
	min_x -= tile_size.x
	max_x += tile_size.x
	min_y -= tile_size.y
	max_y += tile_size.y
	
	# Convert bounding box to tile coordinates
	var min_cell: Vector2i = local_to_map(to_local(Vector2(min_x, min_y)))
	var max_cell: Vector2i = local_to_map(to_local(Vector2(max_x, max_y)))
	
	# Track clears to respect budget (check all tiles, but limit actual clears)
	var clears_this_frame: int = 0
	
	# Scan all tiles in bounding box
	for y in range(min_cell.y, max_cell.y + 1):
		for x in range(min_cell.x, max_cell.x + 1):
			# Respect per-frame budget (stop if we've cleared enough)
			if clears_this_frame >= max_clears_per_frame:
				return
			
			var cell: Vector2i = Vector2i(x, y)
			
			# Skip if already cleared (optimization)
			if cleared.has(cell):
				continue
			
			# Convert tile center to world space, then to beam's local top-down space
			var cell_world: Vector2 = to_global(map_to_local(cell))
			
			# Account for node rotation (same as draw_set_transform cancellation: -global_rotation)
			var cell_local_iso: Vector2 = (cell_world - origin_world).rotated(-node_rotation)
			
			# Convert from isometric visual space back to top-down space
			var cell_td: Vector2 = IsoMath.from_iso(cell_local_iso)
			
			# Test 1: Body triangle (in top-down space)
			var in_body: bool = Geometry2D.is_point_in_polygon(cell_td, body_triangle)
			
			# Test 2: Cap semicircle (in top-down space)
			var in_cap: bool = false
			var offset_td: Vector2 = cell_td - cap_center_td
			var dist_to_cap: float = offset_td.length()
			
			if dist_to_cap <= cap_radius_td:
				# Check if point is "forward" of cap center (semicircle constraint)
				# The semicircle spans from angle_min to angle_max (already calculated above)
				var angle_to_point: float = offset_td.angle()
				
				# Normalize angle to [angle_min, angle_max] range
				if angle_to_point < angle_min - PI:
					angle_to_point += TAU
				elif angle_to_point > angle_max + PI:
					angle_to_point -= TAU
				
				if angle_to_point >= angle_min and angle_to_point <= angle_max:
					in_cap = true
			
			# Clear if point is in either body or cap
			if in_body or in_cap:
				clear_fog_at_cell(cell)
				clears_this_frame += 1

# Laser: Path clearing
func _process_laser_request(data: Dictionary) -> void:
	var origin_world: Vector2 = data.get("origin_world", Vector2.ZERO)
	var aim_angle: float = data.get("aim_angle", 0.0)
	var focus: float = data.get("focus", 0.0)
	
	const LASER_MIN_LENGTH_TILES: float = 10.0
	const LASER_MAX_LENGTH_TILES: float = 22.0
	const LASER_MIN_HALF_WIDTH_TILES: float = 0.35
	const LASER_MAX_HALF_WIDTH_TILES: float = 0.90
	const MIASMA_TILE_X: float = 16.0
	
	var t: float = clamp(focus, 0.0, 1.0)
	var length_px: float = lerp(LASER_MIN_LENGTH_TILES, LASER_MAX_LENGTH_TILES, t) * MIASMA_TILE_X
	var half_w_px: float = lerp(LASER_MIN_HALF_WIDTH_TILES, LASER_MAX_HALF_WIDTH_TILES, t) * MIASMA_TILE_X
	
	# Calculate path in top-down space
	var dir_td: Vector2 = Vector2.RIGHT.rotated(aim_angle)
	var start_world: Vector2 = origin_world
	var end_world: Vector2 = origin_world + IsoMath.to_iso(dir_td * length_px)
	
	# Step along path
	var step_size: float = tile_set.tile_size.x * 0.5
	var dist: float = start_world.distance_to(end_world)
	var steps: int = int(dist / step_size)
	
	for i in range(steps + 1):
		var step_t: float = float(i) / float(steps) if steps > 0 else 0.0
		var stamp_pos: Vector2 = start_world.lerp(end_world, step_t)
		_process_circle_stamp(stamp_pos, half_w_px)

# Helper: Process a circular stamp (elliptical for isometric)
func _process_circle_stamp(world_pos: Vector2, radius_px: float) -> void:
	var local_pos: Vector2 = to_local(world_pos)
	var center_cell: Vector2i = local_to_map(local_pos)
	
	# Scale tile radius to match the 16:8 (2:1) isometric grid ratio
	var tile_r_x: int = int(ceil(radius_px / 16.0))
	var tile_r_y: int = int(ceil((radius_px * 0.5) / 8.0))
	
	for dy in range(-tile_r_y, tile_r_y + 1):
		for dx in range(-tile_r_x, tile_r_x + 1):
			var normalized_x: float = float(dx) / float(tile_r_x) if tile_r_x > 0 else 0.0
			var normalized_y: float = float(dy) / float(tile_r_y) if tile_r_y > 0 else 0.0
			
			# Elliptical distance check
			if (normalized_x * normalized_x) + (normalized_y * normalized_y) <= 1.0:
				var target_cell: Vector2i = center_cell + Vector2i(dx, dy)
				clear_fog_at_cell(target_cell)
