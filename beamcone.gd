extends Node2D

@export var focus := 1.0
@export var CONE_LENGTH_TILES := 12
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
	# Keep the cone "ground-locked" even if parents rotate.
	draw_set_transform(Vector2.ZERO, -global_rotation, Vector2.ONE)

	var half_angle: float = lerp(CONE_MIN_ANGLE, CONE_MAX_ANGLE, clamp(focus, 0.0, 1.0))
	var length: float = float(CONE_LENGTH_TILES) * MIASMA_TILE_X

	# Build in TOP-DOWN space (pure math)
	var forward := Vector2.RIGHT.rotated(aim_angle)
	var left_td := forward.rotated(half_angle) * length
	var right_td := forward.rotated(-half_angle) * length

	# Enforce stable winding so the triangle never "flips"
	if left_td.cross(right_td) < 0.0:
		var tmp := left_td
		left_td = right_td
		right_td = tmp

	# Project vertices into ISO space
	var pts := PackedVector2Array()
	pts.append(to_iso(Vector2.ZERO)) # tip at player
	pts.append(to_iso(left_td))
	pts.append(to_iso(right_td))

	draw_colored_polygon(pts, Color(1, 0.8, 0.2, 0.35))
