extends Node2D

@export var bubble_tiles := 6
@export var MAX_BUBBLE_TILES := 8

const MIASMA_TILE_X := 16.0
const MIASMA_TILE_Y := 8.0

@onready var miasma = get_tree().get_first_node_in_group("miasma")

func _draw():
	# LAW #7: Cancel node rotation so shape is ground-locked (visual only)
	draw_set_transform(
		Vector2.ZERO,
		-global_rotation,
		Vector2.ONE
	)

	var rx := bubble_tiles * MIASMA_TILE_X
	var ry := bubble_tiles * MIASMA_TILE_Y

	var steps := 32 # Reduced from 48 for minor optimization
	var pts := PackedVector2Array()

	for i in range(steps):
		var a := TAU * float(i) / float(steps)
		pts.append(Vector2(cos(a) * rx, sin(a) * ry))

	draw_colored_polygon(pts, Color(1, 1, 0, 0.25))

func _process(_delta):
	if not visible or not miasma:
		return
	
	# LAW #5: Submit clearing request (Intent → Truth → Projection flow)
	miasma.submit_request("bubble", {
		"center_world": global_position,
		"bubble_tiles": float(bubble_tiles),
		"node_rotation": global_rotation
	})
