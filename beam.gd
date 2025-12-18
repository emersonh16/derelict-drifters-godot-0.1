extends Node2D

@export var beam_length := 120.0
@export var beam_half_angle := deg_to_rad(30.0)
@export var circle_radius := 20.0
@export var step := 4.0
@export var width_scale := 0.2


@onready var miasma := get_tree().get_first_node_in_group("miasma")

func _physics_process(_delta):
	if not miasma:
		return

	var origin := global_position
	var forward := Vector2.RIGHT.rotated(global_rotation)

	# --- CONE ---
	var dist := 0.0
	while dist <= beam_length:
		var max_width := tan(beam_half_angle) * dist * width_scale
		var w := -max_width
		while w <= max_width:
			var p := origin + forward * dist + forward.orthogonal() * w
			miasma.clear_at_world_pos(p)
			w += step
		dist += step

	# --- CIRCLE CAP ---
	var center := origin + forward * beam_length
	var x := -circle_radius
	while x <= circle_radius:
		var y := -circle_radius
		while y <= circle_radius:
			if Vector2(x, y).length() <= circle_radius:
				miasma.clear_at_world_pos(center + Vector2(x, y))
			y += step
		x += step
