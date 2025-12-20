extends Node2D

@export var focus := 0.0
@export var CONE_MIN_LENGTH_TILES := 6
@export var CONE_MAX_LENGTH_TILES := 18
@export var CONE_MIN_ANGLE := deg_to_rad(10.0)
@export var CONE_MAX_ANGLE := deg_to_rad(60.0)

var aim_angle := 0.0

const ISO_Y_SCALE := 0.5
const MIASMA_TILE_X := 16.0


func _process(_delta):
	queue_redraw()


func to_iso(v: Vector2) -> Vector2:
	return Vector2(v.x - v.y, (v.x + v.y) * ISO_Y_SCALE)


func _draw():
	if not visible:
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
