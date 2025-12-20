extends Node2D

@export var visible_in_editor := true

@export var LASER_MIN_LENGTH_TILES := 10.0
@export var LASER_MAX_LENGTH_TILES := 22.0

@export var LASER_MIN_HALF_WIDTH_TILES := 0.35
@export var LASER_MAX_HALF_WIDTH_TILES := 0.90

@export var CORE_WIDTH_SCALE := 0.35

const ISO_Y_SCALE := 0.5
const MIASMA_TILE_X := 16.0

func to_iso(v: Vector2) -> Vector2:
	return Vector2(v.x - v.y, (v.x + v.y) * ISO_Y_SCALE)

func _process(_delta):
	if not visible_in_editor and Engine.is_editor_hint():
		visible = false
	queue_redraw()


func _draw():
	var cone := _get_cone()
	if not cone:
		return

	# Laser only activates once cone is fully focused
	if cone.focus < 1.0:
		return

	var aim_angle: float = cone.aim_angle
	var focus: float = clamp(cone.focus, 0.0, 1.0)

	var length_px: float = lerp(
		LASER_MIN_LENGTH_TILES * MIASMA_TILE_X,
		LASER_MAX_LENGTH_TILES * MIASMA_TILE_X,
		focus
	)

	var half_w_px: float = lerp(
		LASER_MIN_HALF_WIDTH_TILES * MIASMA_TILE_X,
		LASER_MAX_HALF_WIDTH_TILES * MIASMA_TILE_X,
		focus
	)

	var origin_td := Vector2.ZERO
	var dir_td := Vector2.RIGHT.rotated(aim_angle)
	var perp_td := dir_td.orthogonal().normalized()

	var p0 := origin_td
	var p1 := origin_td + dir_td * length_px

	var a := to_iso(p0 + perp_td * half_w_px)
	var b := to_iso(p0 - perp_td * half_w_px)
	var c := to_iso(p1 - perp_td * half_w_px)
	var d := to_iso(p1 + perp_td * half_w_px)

	draw_colored_polygon([a, b, c, d], Color(1, 0.8, 0.2, 0.35))

	var core_half_w := half_w_px * CORE_WIDTH_SCALE
	var a2 := to_iso(p0 + perp_td * core_half_w)
	var b2 := to_iso(p0 - perp_td * core_half_w)
	var c2 := to_iso(p1 - perp_td * core_half_w)
	var d2 := to_iso(p1 + perp_td * core_half_w)

	draw_colored_polygon([a2, b2, c2, d2], Color(1.0, 0.8, 0.2, 1.0))

func _get_cone() -> Node:
	if not get_parent():
		return null
	return get_parent().get_node_or_null("BeamCone")
