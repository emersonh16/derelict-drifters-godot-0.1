extends Node2D

@onready var tiles := $MiasmaTiles

func clear_at_world_pos(world_pos: Vector2):
	print("CLEAR CALLED")
	var local_pos = tiles.to_local(world_pos)
	var cell = tiles.local_to_map(local_pos)
	tiles.erase_cell(cell)
