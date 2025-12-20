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


func _draw():
	if not visible:
		return

	# Hard cutoff: cone turns off once laser engages
	if focus >= 0.95:
		return

	var t: float = clamp(focus, 0.0, 1.0)

	var length: float = lerp(
		float(CONE_MIN_LENGTH_TILES) * MIASMA_TILE_X,
		float(CONE_MAX_LENGTH_TILES) * MIASMA_TILE_X,
		t
	)

	var half_angle: float = lerp(
		CONE_MAX_ANGLE,
		CONE_MIN_ANGLE,
		t
	)

	draw_set_transform(Vector2.ZERO, -global_rotation, Vector2.ONE)

	var forward := Vector2.RIGHT.rotated(aim_angle)
	var left_td := forward.rotated(half_angle) * length
	var right_td := forward.rotated(-half_angle) * length

	if left_td.cross(right_td) < 0.0:
		var tmp := left_td
		left_td = right_td
		right_td = tmp

		var body := PackedVector2Array()
		body.append(to_iso(Vector2.ZERO))
		body.append(to_iso(left_td))
		body.append(to_iso(right_td))

		draw_colored_polygon(body, Color(1, 0.8, 0.2, 0.35))

		var cap_center_td := (left_td + right_td) * 0.5
		var cap_center_iso := to_iso(cap_center_td)
		var cap_radius := (right_td - left_td).length() * 0.5

		var cap_pts := PackedVector2Array()
		cap_pts.append(cap_center_iso)

		var steps := 16
		for i in range(steps + 1):
			var a: float = lerp(
				aim_angle - PI * 0.5,
				aim_angle + PI * 0.5,
				float(i) / float(steps)
			)
			var p_td := cap_center_td + Vector2(cos(a), sin(a)) * cap_radius
			cap_pts.append(to_iso(p_td))

		draw_colored_polygon(cap_pts, Color(1, 0.8, 0.2, 0.35))
		
		
func _process(_delta):
	# Mode constraint: when bubble mode hides the cone, cone clearing must be OFF.
	# Threshold lowered to 0.95 to match the laser's activation.
	if not visible or focus >= 0.95:
		if focus >= 0.95:
			queue_redraw() 
		return

	queue_redraw()
	_clear_miasma_cone()


func _clear_miasma_cone():
	var miasma = get_tree().get_first_node_in_group("miasma")
	if not miasma:
		return

	var t: float = clamp(focus, 0.0, 1.0)

	var length: float = lerp(
		float(CONE_MIN_LENGTH_TILES) * MIASMA_TILE_X,
		float(CONE_MAX_LENGTH_TILES) * MIASMA_TILE_X,
		t
	)

	var half_angle: float = lerp(
		CONE_MAX_ANGLE,
		CONE_MIN_ANGLE,
		t
	)

	# Rebuild the exact same top-down cone geometry the visual uses.
	var forward := Vector2.RIGHT.rotated(aim_angle)
	var left_td := forward.rotated(half_angle) * length
	var right_td := forward.rotated(-half_angle) * length

	if left_td.cross(right_td) < 0.0:
		var tmp := left_td
		left_td = right_td
		right_td = tmp

	var cap_center_td := (left_td + right_td) * 0.5
	var cap_radius := (right_td - left_td).length() * 0.5
	var cap_r2 := cap_radius * cap_radius

	# Pixel-for-pixel in TOP-DOWN local space:
	# 1) iterate pixels in a conservative AABB in top-down
	# 2) hit test against (triangle + semicircle cap) in top-down
	# 3) project each accepted pixel with to_iso()
	# 4) convert to world using the same ground-locked assumption as draw_set_transform(-global_rotation)
	var min_x := minf(0.0, minf(left_td.x, minf(right_td.x, cap_center_td.x - cap_radius)))
	var max_x := maxf(0.0, maxf(left_td.x, maxf(right_td.x, cap_center_td.x + cap_radius)))
	var min_y := minf(0.0, minf(left_td.y, minf(right_td.y, cap_center_td.y - cap_radius)))
	var max_y := maxf(0.0, maxf(left_td.y, maxf(right_td.y, cap_center_td.y + cap_radius)))

	var x0 := int(floor(min_x))
	var x1 := int(ceil(max_x))
	var y0 := int(floor(min_y))
	var y1 := int(ceil(max_y))

	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var p_td := Vector2(float(x), float(y))

			var in_tri := _point_in_tri(p_td, Vector2.ZERO, left_td, right_td)

			var d := p_td - cap_center_td
			var in_cap := (d.length_squared() <= cap_r2) and (d.dot(forward) >= 0.0)

			if not (in_tri or in_cap):
				continue

			var p_iso := to_iso(p_td)
			var world_pos := global_position + p_iso
			miasma.clear_fog_at_world(world_pos)
		
	
	
func _point_in_tri(p: Vector2, a: Vector2, b: Vector2, c: Vector2) -> bool:
	var v0 := c - a
	var v1 := b - a
	var v2 := p - a

	var dot00 := v0.dot(v0)
	var dot01 := v0.dot(v1)
	var dot02 := v0.dot(v2)
	var dot11 := v1.dot(v1)
	var dot12 := v1.dot(v2)

	var denom := dot00 * dot11 - dot01 * dot01
	if denom == 0.0:
		return false

	var inv := 1.0 / denom
	var u := (dot11 * dot02 - dot01 * dot12) * inv
	var v := (dot00 * dot12 - dot01 * dot02) * inv

	return (u >= 0.0) and (v >= 0.0) and (u + v <= 1.0)
	
	
	
