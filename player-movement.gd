extends CharacterBody2D

const SPEED := 200

@export var focus := 0.0
@export var FOCUS_STEP := 0.05
@export var BUBBLE_MAX_FOCUS := 0.50
@export var BUBBLE_MIN_TILES := 0

@onready var beam = $BeamPivot
@onready var beam_cone = $BeamPivot/BeamCone
@onready var beam_bubble = $BeamBubble


func _unhandled_input(event):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			focus = min(1.0, focus + FOCUS_STEP)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			focus = max(0.0, focus - FOCUS_STEP)


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
	var iso_delta := mouse_pos - global_position
	var td_delta := IsoMath.from_iso(iso_delta)
	var aim := td_delta.angle()

	beam.global_position = global_position
	beam_bubble.global_position = global_position

	beam.rotation = 0.0
	beam_cone.aim_angle = aim

	if focus <= BUBBLE_MAX_FOCUS:
		beam_bubble.visible = beam_bubble.bubble_tiles > 0
		beam_cone.visible = false

		var t := 0.0
		if BUBBLE_MAX_FOCUS > 0.0:
			t = clamp(focus / BUBBLE_MAX_FOCUS, 0.0, 1.0)

		var max_tiles := int(beam_bubble.MAX_BUBBLE_TILES)
		var tiles_f: float = lerp(float(BUBBLE_MIN_TILES), float(max_tiles), t)
		beam_bubble.bubble_tiles = int(round(tiles_f))
		beam_bubble.queue_redraw()
	else:
		beam_bubble.visible = false
		beam_cone.visible = true

		var cone_t: float = clamp(
			(focus - BUBBLE_MAX_FOCUS) / (1.0 - BUBBLE_MAX_FOCUS),
			0.0,
			1.0
		)
		beam_cone.focus = cone_t
		beam_cone.queue_redraw()
