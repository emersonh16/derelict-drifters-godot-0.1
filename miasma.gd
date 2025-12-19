extends Node2D

# --- Grid config ---
@export var tile_size := 8            # world pixels per fog tile
@export var margin_tiles := 8          # extra tiles beyond viewport

# --- Runtime ---
var _grid_w := 0
var _grid_h := 0
var _fog := {}  # Dictionary<Vector2i, bool>   true = fog, false = clear
var _origin_cell := Vector2i.ZERO      # top-left cell in world-space tiles

@onready var _player := get_tree().get_first_node_in_group("player")


func _ready():
	_build_grid()


func _process(_delta):
	_follow_player()


# -------------------------
# Public API (used later)
# -------------------------

func is_fog_at_world(world_pos: Vector2) -> bool:
	var cell := Vector2i(
		floor(world_pos.x / tile_size),
		floor(world_pos.y / tile_size)
	)
	return _fog.get(cell, true)

func clear_at_world(world_pos: Vector2):
	var cell := Vector2i(
		floor(world_pos.x / tile_size),
		floor(world_pos.y / tile_size)
	)
	_fog[cell] = false

# -------------------------
# Internal
# -------------------------

func _build_grid():
	pass


func _follow_player():
	var cam := get_viewport().get_camera_2d()
	if not cam:
		return

	var vp := get_viewport_rect().size
	var top_left_world := cam.global_position - vp * 0.5

	_origin_cell = Vector2i(
		floor(top_left_world.x / tile_size),
		floor(top_left_world.y / tile_size)
	)




func _world_to_cell(world_pos: Vector2) -> Vector2i:
	var local := world_pos - Vector2(_origin_cell) * tile_size
	return Vector2i(
		floor(local.x / tile_size),
		floor(local.y / tile_size)
	)


func _idx(c: Vector2i) -> int:
	return c.y * _grid_w + c.x
	
func clear_circle_world(world_pos: Vector2, radius_px: float):
	if radius_px <= 0.0:
		return

	var center := Vector2i(
		floor(world_pos.x / tile_size),
		floor(world_pos.y / tile_size)
	)

	var r_tiles := int(ceil(radius_px / float(tile_size)))

	for dy in range(-r_tiles, r_tiles + 1):
		for dx in range(-r_tiles, r_tiles + 1):
			var cell := center + Vector2i(dx, dy)
			var p := Vector2(dx, dy) * float(tile_size)
			if p.length() > radius_px:
				continue

			_fog[cell] = false
