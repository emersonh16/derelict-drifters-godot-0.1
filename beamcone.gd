extends Node2D

@export var focus := 1.0
@export var MAX_BUBBLE_TILES := 8
@export var CONE_LENGTH_TILES := 12
@export var CONE_MIN_ANGLE := deg_to_rad(10)
@export var CONE_MAX_ANGLE := deg_to_rad(60)


const ISO_Y_SCALE := 0.5
const MIASMA_TILE_X := 16.0

func _process(_delta):
	queue_redraw()


func _draw():
	if focus <= 0.0:
		return

	var base_radius: float = MAX_BUBBLE_TILES * MIASMA_TILE_X
	var length: float = lerp(
		base_radius,
		CONE_LENGTH_TILES * MIASMA_TILE_X,
		focus
	)
	var half_angle: float = lerp(
		CONE_MAX_ANGLE,
		CONE_MIN_ANGLE,
		focus
	)


	var pts := PackedVector2Array()

	# left edge of flat base
	pts.append(Vector2(
		cos(half_angle) * base_radius,
		sin(half_angle) * base_radius * ISO_Y_SCALE
	))

	# cone tip
	pts.append(Vector2(length, 0))

	# right edge of flat base
	pts.append(Vector2(
		cos(-half_angle) * base_radius,
		sin(-half_angle) * base_radius * ISO_Y_SCALE
	))

	# back to player origin
	pts.append(Vector2(0, 0))

	draw_colored_polygon(pts, Color(1, 0.8, 0.2, 0.35))
