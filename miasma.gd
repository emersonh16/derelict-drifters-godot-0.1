extends Node2D

@onready var tiles := $MiasmaTiles

func clear_at_world_pos(world_pos: Vector2):
	var local_pos = tiles.to_local(world_pos)
	var cell = tiles.local_to_map(local_pos)
	tiles.erase_cell(cell)

func clear_circle_world(pos: Vector2, radius: float, step := 4):
	var y := -radius
	while y <= radius:
		var x := -radius
		while x <= radius:
			if Vector2(x, y).length() <= radius:
				clear_at_world_pos(pos + Vector2(x, y))
			x += step
		y += step
