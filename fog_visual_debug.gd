extends Node2D

@export var fog_color := Color(1, 1, 1, 0.85)

@onready var miasma := get_parent()


func _process(_delta):
	var cam := get_viewport().get_camera_2d()
	if not miasma or not cam:
		return

	var vp := get_viewport_rect().size
	var half_world := (vp * 0.5) * cam.zoom
	var top_left := cam.global_position - half_world

	# Anchor this node to the camera’s top-left in WORLD space (correct under zoom)
	global_position = top_left

	queue_redraw()


func _draw():
	if not miasma:
		return

	var cam := get_viewport().get_camera_2d()
	if not cam:
		return

	var tile_size: int = miasma.tile_size
	var vp := get_viewport_rect().size

	var half_world := (vp * 0.5) * cam.zoom
	var top_left := cam.global_position - half_world
	var bottom_right := cam.global_position + half_world

	var start_x := int(floor(top_left.x / tile_size))
	var start_y := int(floor(top_left.y / tile_size))
	var end_x := int(ceil(bottom_right.x / tile_size))
	var end_y := int(ceil(bottom_right.y / tile_size))

	for y in range(start_y, end_y):
		for x in range(start_x, end_x):
			var world_pos := Vector2(x, y) * tile_size
			if not miasma.is_fog_at_world(world_pos):
				continue

			var local_pos := world_pos - global_position
			draw_rect(
				Rect2(local_pos, Vector2(tile_size, tile_size)),
				fog_color,
				true
			)
