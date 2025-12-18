extends CharacterBody2D

const SPEED := 200

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


@onready var beam = $Beam

func _process(delta):
	var mouse_pos = get_global_mouse_position()
	var dir = mouse_pos - global_position
	beam.rotation = dir.angle()
