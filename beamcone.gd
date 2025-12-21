extends Node2D

@export var focus := 0.0
@export var CONE_MIN_LENGTH_TILES := 6
@export var CONE_MAX_LENGTH_TILES := 18
@export var CONE_MIN_ANGLE := deg_to_rad(10.0)
@export var CONE_MAX_ANGLE := deg_to_rad(60.0)

var aim_angle := 0.0

const ISO_Y_SCALE := 0.5
const MIASMA_TILE_X := 16.0

func to_iso(v: Vector2) -> Vector2:
	return Vector2(v.x - v.y, (v.x + v.y) * ISO_Y_SCALE)

func from_iso(iso: Vector2) -> Vector2:
	# Inverse of to_iso: iso = (td.x - td.y, (td.x + td.y) * 0.5)
	# Solving: td.x = iso.x + 2*iso.y, td.y = 2*iso.y - iso.x
	return Vector2(iso.x + 2.0 * iso.y, 2.0 * iso.y - iso.x)

func _draw():
	if not visible or focus >= 0.95:
		return

	var t: float = clamp(focus, 0.0, 1.0)
	var length: float = lerp(float(CONE_MIN_LENGTH_TILES), float(CONE_MAX_LENGTH_TILES), t) * MIASMA_TILE_X
	var half_angle: float = lerp(CONE_MAX_ANGLE, CONE_MIN_ANGLE, t)

	draw_set_transform(Vector2.ZERO, -global_rotation, Vector2.ONE)

	var forward: Vector2 = Vector2.RIGHT.rotated(aim_angle)
	var left_td: Vector2 = forward.rotated(half_angle) * length
	var right_td: Vector2 = forward.rotated(-half_angle) * length

	if left_td.cross(right_td) < 0.0:
		var tmp: Vector2 = left_td
		left_td = right_td
		right_td = tmp

	# Draw Body
	var body: PackedVector2Array = PackedVector2Array()
	body.append(to_iso(Vector2.ZERO))
	body.append(to_iso(left_td))
	body.append(to_iso(right_td))
	draw_colored_polygon(body, Color(1, 0.8, 0.2, 0.35))

	# Draw Cap - This midpoint must be mirrored in clearing
	var cap_center_td: Vector2 = (left_td + right_td) * 0.5
	var cap_radius: float = (right_td - left_td).length() * 0.5
	var cap_pts: PackedVector2Array = PackedVector2Array()
	cap_pts.append(to_iso(cap_center_td))

	var steps: int = 16
	for i in range(steps + 1):
		var a: float = lerp(aim_angle - PI * 0.5, aim_angle + PI * 0.5, float(i) / float(steps))
		var p_td: Vector2 = cap_center_td + Vector2(cos(a), sin(a)) * cap_radius
		cap_pts.append(to_iso(p_td))
	draw_colored_polygon(cap_pts, Color(1, 0.8, 0.2, 0.35))

func _process(_delta):
	if not visible or focus >= 0.95:
		if focus >= 0.95: queue_redraw() 
		return
	queue_redraw()
	_clear_miasma_cone()

func _clear_miasma_cone():
	var miasma: Node = get_tree().get_first_node_in_group("miasma")
	if not miasma or not visible:
		return

	var t: float = clamp(focus, 0.0, 1.0)
	var length: float = lerp(float(CONE_MIN_LENGTH_TILES), float(CONE_MAX_LENGTH_TILES), t) * MIASMA_TILE_X
	var half_angle: float = lerp(CONE_MAX_ANGLE, CONE_MIN_ANGLE, t)

	var forward: Vector2 = Vector2.RIGHT.rotated(aim_angle)
	var left_td: Vector2 = forward.rotated(half_angle) * length
	var right_td: Vector2 = forward.rotated(-half_angle) * length

	if left_td.cross(right_td) < 0.0:
		var tmp: Vector2 = left_td
		left_td = right_td
		right_td = tmp

	# 1. BODY CLEARING: Sweep along center line and edges to cover entire triangle
	var cap_center_td: Vector2 = (left_td + right_td) * 0.5
	var body_length: float = cap_center_td.length()
	var steps: int = max(16, int(ceil(body_length / (MIASMA_TILE_X * 0.4))))
	
	# Sweep along center line
	for i in range(steps + 1):
		var step_t: float = float(i) / float(steps)
		var dist: float = step_t * body_length
		# Width at this distance: 2 * dist * tan(half_angle), so radius is dist * tan(half_angle)
		var current_radius: float = dist * tan(half_angle)
		# Add padding to ensure full coverage
		current_radius += MIASMA_TILE_X * 0.3
		if current_radius > 0.0:
			var sweep_pos_td: Vector2 = forward * dist
			miasma.clear_circle(global_position + to_iso(sweep_pos_td), current_radius)
	
	# Also sweep along left and right edges to ensure edge coverage
	var edge_steps: int = max(8, int(ceil(length / (MIASMA_TILE_X * 0.6))))
	for i in range(edge_steps + 1):
		var edge_t: float = float(i) / float(edge_steps)
		var left_pos_td: Vector2 = left_td * edge_t
		var right_pos_td: Vector2 = right_td * edge_t
		miasma.clear_circle(global_position + to_iso(left_pos_td), MIASMA_TILE_X * 0.4)
		miasma.clear_circle(global_position + to_iso(right_pos_td), MIASMA_TILE_X * 0.4)

	# 2. CAP CLEARING: Cell-based check for perfect semicircle coverage
	var cap_radius: float = (right_td - left_td).length() * 0.5
	var cap_world_pos: Vector2 = global_position + to_iso(cap_center_td)
	var cap_cell: Vector2i = miasma.local_to_map(miasma.to_local(cap_world_pos))
	
	# Calculate bounding box in tiles (accounting for isometric scaling)
	var radius_tiles_x: int = int(ceil(cap_radius / MIASMA_TILE_X)) + 1
	var radius_tiles_y: int = int(ceil(cap_radius / (MIASMA_TILE_X * ISO_Y_SCALE))) + 1
	
	# Check each cell in bounding box
	for dy in range(-radius_tiles_y, radius_tiles_y + 1):
		for dx in range(-radius_tiles_x, radius_tiles_x + 1):
			var cell: Vector2i = cap_cell + Vector2i(dx, dy)
			var cell_world: Vector2 = miasma.to_global(miasma.map_to_local(cell))
			
			# Convert cell world position to beamcone's local space
			# Account for node rotation (same as draw_set_transform cancellation)
			var cell_local_iso: Vector2 = (cell_world - global_position).rotated(global_rotation)
			# Convert from isometric visual space back to top-down space
			var cell_td: Vector2 = from_iso(cell_local_iso)
			
			# Check if within semicircle: distance and angle
			var offset_td: Vector2 = cell_td - cap_center_td
			var dist: float = offset_td.length()
			
			if dist > cap_radius:
				continue
			
			# Check angle: must be between aim_angle - PI/2 and aim_angle + PI/2
			# This matches the draw function's lerp(aim_angle - PI * 0.5, aim_angle + PI * 0.5, ...)
			var angle: float = offset_td.angle()
			var angle_min: float = aim_angle - PI * 0.5
			var angle_max: float = aim_angle + PI * 0.5
			
			# Normalize angle to [angle_min, angle_max] range
			# If angle is outside, wrap it
			if angle < angle_min - PI:
				angle += TAU
			elif angle > angle_max + PI:
				angle -= TAU
			
			# Check if within semicircle range
			if angle >= angle_min and angle <= angle_max:
				miasma.clear_fog_at_cell(cell)
