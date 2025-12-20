extends CharacterBody2D

const SPEED := 200

@onready var beam = $BeamPivot
@onready var beam_cone = $BeamPivot/BeamCone
@onready var miasma = get_tree().get_first_node_in_group("miasma")
@onready var beam_bubble = $BeamBubble


func _physics_process(_delta):
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


func _process(_delta):
	var mouse_pos := get_global_mouse_position()
	var aim := (mouse_pos - global_position).angle()

	beam.global_position = global_position
	beam_bubble.global_position = global_position

	# Do NOT rotate the pivot; the cone is rotated in top-down math, then projected to iso.
	beam.rotation = 0.0
	beam_cone.aim_angle = aim
