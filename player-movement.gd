extends CharacterBody2D

const SPEED := 200

@onready var beam = $Beam
@onready var miasma = get_tree().get_first_node_in_group("miasma")

func _physics_process(delta):
	var dir := Vector2.ZERO
	if Input.is_action_pressed("ui_right"):
		dir.x += 1
	if Input.is_action_pressed("ui_left"):
		dir.x -= 1
	if Input.is_action_pressed("ui_down"):
		dir.y += 1
	if Input.is_action_pressed("ui_up"):
		dir.y -= 1

	velocity = dir.normalized() * SPEED
	move_and_slide()

func _process(delta):
	var mouse_pos = get_global_mouse_position()
	var dir = mouse_pos - global_position
	beam.rotation = dir.angle()

	if miasma:
		var start = beam.global_position
		var dir_norm = dir.normalized()
		var length = 120        # beam reach
		var step = 3            # tile size (match your 8x8 diamonds)

		var dist = 0
		while dist <= length:
			miasma.clear_at_world_pos(start + dir_norm * dist)
			dist += step
