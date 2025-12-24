extends TileMapLayer

# --- Config Knobs (Per Design Doc & Audit) ---
const LOGIC_TILE_SIZE = Vector2i(8, 4)
@export var buffer_tiles := 32        # Viewport padding (PAD) 
@export var forget_padding := 64      # Radius beyond which we purge memory 
@export var fog_source_id: int = 1
@export var fog_atlas: Vector2i = Vector2i(0, 0)

# Performance Budgets (DDGDD: Fixed per-frame caps)
const MAX_SETCELL_PER_FRAME := 400
const MAX_CLEAR_TILES_PER_FRAME := 500
const MAX_FRONTIER_CHECKS_PER_FRAME := 50

# State Tracking
var cleared_map := {} # Absolute Tile Coord -> Time Cleared 
var frontier := {}    # Boundary cells for regrow 
var last_center := Vector2i(999999, 999999)
var clear_queue: Array = []

# Amortization State
var frontier_iterator_index := 0
var frontier_keys_array := []  # Cached array for amortized iteration
var pending_edge_patch_work := []  # Carry-over work for edge patching

func _ready():
	add_to_group("miasma") 
	# Ensure absolute world-locking (Priority 1)
	top_level = true 
	global_position = Vector2.ZERO 

func _physics_process(_delta: float):
	var cam := get_viewport().get_camera_2d()
	if not cam: return

	# Get current Logical Center in absolute map coords
	# Use floor() to prevent sub-pixel jitter from triggering updates
	var cam_world_pos = cam.global_position
	var cam_local_pos = to_local(cam_world_pos)
	var center_tile: Vector2i = local_to_map(Vector2(floor(cam_local_pos.x), floor(cam_local_pos.y)))

	# Edge-Patching: Only update visual tiles when boundary is crossed (Priority 2)
	if center_tile != last_center:
		_edge_patch_window_incremental(last_center, center_tile)
		_forget_distant_tiles(center_tile)
		last_center = center_tile
	else:
		# Process any pending edge-patch work from previous frame
		_process_pending_edge_patch()

	_process_clear_queue()
	_process_regrow()

# --- Priority 2: Incremental Edge-Patching Algorithm (60 FPS) ---
func _edge_patch_window_incremental(old_c: Vector2i, new_c: Vector2i):
	var vp = get_viewport_rect().size
	# Account for Isometric height (squashed 2:1 ratio)
	var half_w = int(ceil(vp.x / LOGIC_TILE_SIZE.x)) + buffer_tiles
	var half_h = int(ceil(vp.y / (LOGIC_TILE_SIZE.y * 0.5))) + buffer_tiles 

	var old_rect = Rect2i(old_c.x - half_w, old_c.y - half_h, half_w * 2, half_h * 2)
	var new_rect = Rect2i(new_c.x - half_w, new_c.y - half_h, half_w * 2, half_h * 2)

	var setcell_count := 0
	
	# Calculate delta strips (only the tiles that changed)
	var delta_left = min(old_rect.position.x, new_rect.position.x)
	var delta_right = max(old_rect.end.x, new_rect.end.x)
	var delta_top = min(old_rect.position.y, new_rect.position.y)
	var delta_bottom = max(old_rect.end.y, new_rect.end.y)
	
	# 1. Clean up tiles exiting the view (Trailing Edge) - Only delta strips
	# Left edge (if old rect was further left)
	if old_rect.position.x < new_rect.position.x:
		for y in range(old_rect.position.y, old_rect.end.y):
			for x in range(old_rect.position.x, new_rect.position.x):
				if setcell_count >= MAX_SETCELL_PER_FRAME:
					pending_edge_patch_work.append({"action": "erase", "pos": Vector2i(x, y)})
					continue
				set_cell(Vector2i(x, y), -1)
				setcell_count += 1
	
	# Right edge (if old rect was further right)
	if old_rect.end.x > new_rect.end.x:
		for y in range(old_rect.position.y, old_rect.end.y):
			for x in range(new_rect.end.x, old_rect.end.x):
				if setcell_count >= MAX_SETCELL_PER_FRAME:
					pending_edge_patch_work.append({"action": "erase", "pos": Vector2i(x, y)})
					continue
				set_cell(Vector2i(x, y), -1)
				setcell_count += 1
	
	# Top edge (if old rect was further up)
	if old_rect.position.y < new_rect.position.y:
		for y in range(old_rect.position.y, new_rect.position.y):
			for x in range(old_rect.position.x, old_rect.end.x):
				if setcell_count >= MAX_SETCELL_PER_FRAME:
					pending_edge_patch_work.append({"action": "erase", "pos": Vector2i(x, y)})
					continue
				set_cell(Vector2i(x, y), -1)
				setcell_count += 1
	
	# Bottom edge (if old rect was further down)
	if old_rect.end.y > new_rect.end.y:
		for y in range(new_rect.end.y, old_rect.end.y):
			for x in range(old_rect.position.x, old_rect.end.x):
				if setcell_count >= MAX_SETCELL_PER_FRAME:
					pending_edge_patch_work.append({"action": "erase", "pos": Vector2i(x, y)})
					continue
				set_cell(Vector2i(x, y), -1)
				setcell_count += 1

	# 2. Draw tiles entering the view (Leading Edge) - Only delta strips
	# Right edge (if new rect extends further right)
	if new_rect.end.x > old_rect.end.x:
		for y in range(new_rect.position.y, new_rect.end.y):
			for x in range(old_rect.end.x, new_rect.end.x):
				if setcell_count >= MAX_SETCELL_PER_FRAME:
					pending_edge_patch_work.append({"action": "draw", "pos": Vector2i(x, y)})
					continue
				if not cleared_map.has(Vector2i(x, y)):
					set_cell(Vector2i(x, y), fog_source_id, fog_atlas)
					setcell_count += 1
	
	# Left edge (if new rect extends further left)
	if new_rect.position.x < old_rect.position.x:
		for y in range(new_rect.position.y, new_rect.end.y):
			for x in range(new_rect.position.x, old_rect.position.x):
				if setcell_count >= MAX_SETCELL_PER_FRAME:
					pending_edge_patch_work.append({"action": "draw", "pos": Vector2i(x, y)})
					continue
				if not cleared_map.has(Vector2i(x, y)):
					set_cell(Vector2i(x, y), fog_source_id, fog_atlas)
					setcell_count += 1
	
	# Bottom edge (if new rect extends further down)
	if new_rect.end.y > old_rect.end.y:
		for y in range(old_rect.end.y, new_rect.end.y):
			for x in range(new_rect.position.x, new_rect.end.x):
				if setcell_count >= MAX_SETCELL_PER_FRAME:
					pending_edge_patch_work.append({"action": "draw", "pos": Vector2i(x, y)})
					continue
				if not cleared_map.has(Vector2i(x, y)):
					set_cell(Vector2i(x, y), fog_source_id, fog_atlas)
					setcell_count += 1
	
	# Top edge (if new rect extends further up)
	if new_rect.position.y < old_rect.position.y:
		for y in range(new_rect.position.y, old_rect.position.y):
			for x in range(new_rect.position.x, new_rect.end.x):
				if setcell_count >= MAX_SETCELL_PER_FRAME:
					pending_edge_patch_work.append({"action": "draw", "pos": Vector2i(x, y)})
					continue
				if not cleared_map.has(Vector2i(x, y)):
					set_cell(Vector2i(x, y), fog_source_id, fog_atlas)
					setcell_count += 1

func _process_pending_edge_patch():
	var setcell_count := 0
	while setcell_count < MAX_SETCELL_PER_FRAME and not pending_edge_patch_work.is_empty():
		var work = pending_edge_patch_work.pop_front()
		var pos: Vector2i = work.get("pos", Vector2i.ZERO)
		var action: String = work.get("action", "")
		
		if action == "erase":
			set_cell(pos, -1)
		elif action == "draw":
			if not cleared_map.has(pos):
				set_cell(pos, fog_source_id, fog_atlas)
		setcell_count += 1

# --- Priority 3: Memory Management (Forget Logic) ---
func _forget_distant_tiles(center: Vector2i):
	var to_purge = []
	for cell in cleared_map.keys():
		# Use Manhattan distance for fast filtering 
		if abs(cell.x - center.x) > forget_padding or abs(cell.y - center.y) > forget_padding:
			to_purge.append(cell)
	for cell in to_purge:
		cleared_map.erase(cell)
		frontier.erase(cell)
	
	# Proactive frontier pruning: Remove frontier cells outside active zone
	var frontier_to_purge = []
	for cell in frontier.keys():
		if abs(cell.x - center.x) > forget_padding or abs(cell.y - center.y) > forget_padding:
			frontier_to_purge.append(cell)
	for cell in frontier_to_purge:
		frontier.erase(cell)
	
	# Update cached frontier array if it exists
	if not frontier_keys_array.is_empty():
		frontier_keys_array = frontier.keys()

# --- Priority 5: Fixed Request Processing (Budgeted) ---
func _process_clear_queue():
	var tiles_cleared_this_frame := 0
	
	while not clear_queue.is_empty() and tiles_cleared_this_frame < MAX_CLEAR_TILES_PER_FRAME:
		var req = clear_queue.pop_front()
		var type = req.get("type", "") 
		var data = req.get("data", {})
		
		match type:
			"bubble":
				var world_pos = data.get("center_world", Vector2.ZERO)
				var r_px = data.get("bubble_tiles", 6.0) * LOGIC_TILE_SIZE.x
				tiles_cleared_this_frame += _clear_circle_budgeted(world_pos, r_px, MAX_CLEAR_TILES_PER_FRAME - tiles_cleared_this_frame)
			"laser":
				var world_pos = data.get("origin_world", Vector2.ZERO)
				var aim_angle = data.get("aim_angle", 0.0)
				var focus = data.get("focus", 0.0)
				tiles_cleared_this_frame += _clear_laser_budgeted(world_pos, aim_angle, focus, MAX_CLEAR_TILES_PER_FRAME - tiles_cleared_this_frame)
			"cone":
				var world_pos = data.get("origin_world", Vector2.ZERO)
				var aim_angle = data.get("aim_angle", 0.0)
				var focus = data.get("focus", 0.0)
				var node_rotation = data.get("node_rotation", 0.0)
				tiles_cleared_this_frame += _clear_cone_budgeted(world_pos, aim_angle, focus, node_rotation, MAX_CLEAR_TILES_PER_FRAME - tiles_cleared_this_frame)
	
	# If queue still has items, they'll be processed next frame (amortization)

func _clear_circle_budgeted(world_pos: Vector2, radius: float, max_tiles: int) -> int:
	var center_tile = local_to_map(to_local(world_pos))
	var t_radius = int(ceil(radius / LOGIC_TILE_SIZE.x))
	var cleared_count := 0
	
	for dy in range(-t_radius, t_radius + 1):
		for dx in range(-t_radius, t_radius + 1):
			if cleared_count >= max_tiles:
				return cleared_count
			var tile = center_tile + Vector2i(dx, dy)
			# Circular clear logic 
			if Vector2(center_tile).distance_to(Vector2(tile)) <= t_radius:
				if not cleared_map.has(tile):
					cleared_map[tile] = Time.get_ticks_msec() / 1000.0
					set_cell(tile, -1) 
					_update_frontier(tile)
					cleared_count += 1
	return cleared_count

func _clear_laser_budgeted(world_pos: Vector2, aim_angle: float, focus: float, max_tiles: int) -> int:
	# Laser: Oriented Bounding Box (OBB) - rectangle polygon
	const LASER_MIN_LENGTH_TILES := 10.0
	const LASER_MAX_LENGTH_TILES := 22.0
	const LASER_MIN_HALF_WIDTH_TILES := 0.35
	const LASER_MAX_HALF_WIDTH_TILES := 0.90
	const MIASMA_TILE_X := 16.0
	
	var t: float = clamp(focus, 0.0, 1.0)
	var length_px: float = lerp(LASER_MIN_LENGTH_TILES, LASER_MAX_LENGTH_TILES, t) * MIASMA_TILE_X
	var half_w_px: float = lerp(LASER_MIN_HALF_WIDTH_TILES, LASER_MAX_HALF_WIDTH_TILES, t) * MIASMA_TILE_X
	
	var origin_td := world_pos
	var dir_td := Vector2.RIGHT.rotated(aim_angle)
	var perp_td := dir_td.orthogonal().normalized()
	
	var p0 := origin_td
	var p1 := origin_td + dir_td * length_px
	
	# Calculate bounding box in tile space
	var corners = [
		p0 + perp_td * half_w_px,
		p0 - perp_td * half_w_px,
		p1 - perp_td * half_w_px,
		p1 + perp_td * half_w_px
	]
	
	var min_x = corners[0].x
	var max_x = corners[0].x
	var min_y = corners[0].y
	var max_y = corners[0].y
	for corner in corners:
		min_x = min(min_x, corner.x)
		max_x = max(max_x, corner.x)
		min_y = min(min_y, corner.y)
		max_y = max(max_y, corner.y)
	
	# Convert to tile coordinates
	var min_tile = local_to_map(to_local(Vector2(min_x, min_y)))
	var max_tile = local_to_map(to_local(Vector2(max_x, max_y)))
	
	var cleared_count := 0
	
	# Iterate through bounding box and check if tile center is inside laser rectangle
	for ty in range(min_tile.y - 1, max_tile.y + 2):
		for tx in range(min_tile.x - 1, max_tile.x + 2):
			if cleared_count >= max_tiles:
				return cleared_count
			
			var tile = Vector2i(tx, ty)
			var tile_local_center = map_to_local(tile) + Vector2(LOGIC_TILE_SIZE) * 0.5
			var tile_world_center = to_global(tile_local_center)
			
			# Check if tile center is inside laser rectangle using segment-distance check
			var ab := p1 - p0
			var ap: Vector2 = tile_world_center - p0
			var ab_len_sq := ab.length_squared()
			
			if ab_len_sq > 0.0:
				var u: float = clamp(ap.dot(ab) / ab_len_sq, 0.0, 1.0)
				var closest: Vector2 = p0 + ab * u
				var dist_to_segment := tile_world_center.distance_to(closest)
				
				if dist_to_segment <= half_w_px:
					if not cleared_map.has(tile):
						cleared_map[tile] = Time.get_ticks_msec() / 1000.0
						set_cell(tile, -1)
						_update_frontier(tile)
						cleared_count += 1
	
	return cleared_count

func _clear_cone_budgeted(world_pos: Vector2, aim_angle: float, focus: float, node_rotation: float, max_tiles: int) -> int:
	# Cone: Triangle + Arc polygon
	const CONE_MIN_LENGTH_TILES := 6
	const CONE_MAX_LENGTH_TILES := 18
	const CONE_MIN_ANGLE := deg_to_rad(10.0)
	const CONE_MAX_ANGLE := deg_to_rad(60.0)
	const MIASMA_TILE_X := 16.0
	
	var t: float = clamp(focus, 0.0, 1.0)
	var length: float = lerp(float(CONE_MIN_LENGTH_TILES), float(CONE_MAX_LENGTH_TILES), t) * MIASMA_TILE_X
	var half_angle: float = lerp(CONE_MAX_ANGLE, CONE_MIN_ANGLE, t)
	
	var forward := Vector2.RIGHT.rotated(aim_angle)
	var left_td := forward.rotated(half_angle) * length
	var right_td := forward.rotated(-half_angle) * length
	
	if left_td.cross(right_td) < 0.0:
		var tmp := left_td
		left_td = right_td
		right_td = tmp
	
	var origin_td := world_pos
	var left_end := origin_td + left_td
	var right_end := origin_td + right_td
	
	# Cap center and radius for arc
	var cap_center_td := (left_end + right_end) * 0.5
	var cap_radius := (right_end - left_end).length() * 0.5
	
	# Calculate bounding box
	var corners = [origin_td, left_end, right_end]
	var min_x = corners[0].x
	var max_x = corners[0].x
	var min_y = corners[0].y
	var max_y = corners[0].y
	for corner in corners:
		min_x = min(min_x, corner.x - cap_radius)
		max_x = max(max_x, corner.x + cap_radius)
		min_y = min(min_y, corner.y - cap_radius)
		max_y = max(max_y, corner.y + cap_radius)
	
	var min_tile = local_to_map(to_local(Vector2(min_x, min_y)))
	var max_tile = local_to_map(to_local(Vector2(max_x, max_y)))
	
	var cleared_count := 0
	
	# Iterate through bounding box and check if tile is inside cone
	for ty in range(min_tile.y - 1, max_tile.y + 2):
		for tx in range(min_tile.x - 1, max_tile.x + 2):
			if cleared_count >= max_tiles:
				return cleared_count
			
			var tile = Vector2i(tx, ty)
			var tile_local_center = map_to_local(tile) + Vector2(LOGIC_TILE_SIZE) * 0.5
			var tile_world_center = to_global(tile_local_center)
			
			# Check if tile center is inside triangle (body)
			var v0 := origin_td
			var v1 := left_end
			var v2 := right_end
			var p: Vector2 = tile_world_center
			
			var d1 := (p.x - v2.x) * (v1.y - v2.y) - (v1.x - v2.x) * (p.y - v2.y)
			var d2 := (p.x - v0.x) * (v2.y - v0.y) - (v2.x - v0.x) * (p.y - v0.y)
			var d3 := (p.x - v1.x) * (v0.y - v1.y) - (v0.x - v1.x) * (p.y - v1.y)
			
			var has_neg := (d1 < 0) or (d2 < 0) or (d3 < 0)
			var has_pos := (d1 > 0) or (d2 > 0) or (d3 > 0)
			var in_triangle := not (has_neg and has_pos)
			
			# Check if tile center is inside arc (cap)
			var dist_to_cap_center := tile_world_center.distance_to(cap_center_td)
			var in_arc := dist_to_cap_center <= cap_radius
			
			if in_triangle or in_arc:
				if not cleared_map.has(tile):
					cleared_map[tile] = Time.get_ticks_msec() / 1000.0
					set_cell(tile, -1)
					_update_frontier(tile)
					cleared_count += 1
	
	return cleared_count

# --- Frontier & Regrow ---
func _update_frontier(cell: Vector2i):
	if _is_boundary(cell): 
		frontier[cell] = true
	else: 
		frontier.erase(cell)

func _is_boundary(cell: Vector2i) -> bool:
	var neighbors = [
		cell + Vector2i(1, 0), cell + Vector2i(-1, 0), 
		cell + Vector2i(0, 1), cell + Vector2i(0, -1)
	]
	for n in neighbors:
		if not cleared_map.has(n): return true
	return false

func _process_regrow():
	# Amortized frontier processing: Only check MAX_FRONTIER_CHECKS_PER_FRAME cells per frame
	if frontier_keys_array.is_empty() or frontier_iterator_index >= frontier_keys_array.size():
		# Refresh cached array and reset iterator
		frontier_keys_array = frontier.keys()
		frontier_iterator_index = 0
	
	if frontier_keys_array.is_empty():
		return
	
	var current_time = Time.get_ticks_msec() / 1000.0
	var checks_this_frame := 0
	var start_index = frontier_iterator_index
	
	# Process up to MAX_FRONTIER_CHECKS_PER_FRAME cells
	while checks_this_frame < MAX_FRONTIER_CHECKS_PER_FRAME and frontier_iterator_index < frontier_keys_array.size():
		var cell: Vector2i = frontier_keys_array[frontier_iterator_index]
		frontier_iterator_index += 1
		checks_this_frame += 1
		
		# Verify cell still exists in frontier (it might have been removed)
		if not frontier.has(cell):
			continue
		
		var t_cleared = cleared_map.get(cell, 0.0)
		if current_time - t_cleared > 1.0 and randf() < 0.6:
			cleared_map.erase(cell)
			frontier.erase(cell)
			set_cell(cell, fog_source_id, fog_atlas)
			
			# Remove from cached array if it still exists
			var idx = frontier_keys_array.find(cell)
			if idx >= 0:
				frontier_keys_array.remove_at(idx)
				if frontier_iterator_index > idx:
					frontier_iterator_index -= 1

func submit_request(shape_type: String, data: Dictionary) -> void:
	clear_queue.append({"type": shape_type, "data": data})
