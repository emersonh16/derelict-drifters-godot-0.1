extends Node2D

@export var bubble_radius := 96.0
@export var radius_step := 16.0
const ISO_Y_SCALE := 0.5

func _ready():
	queue_redraw()

func _unhandled_input(event):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			bubble_radius += radius_step
			queue_redraw()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			bubble_radius = max(radius_step, bubble_radius - radius_step)
			queue_redraw()

func _draw():
	# CRITICAL: cancel node rotation so shape is ground-locked
	draw_set_transform(
		Vector2.ZERO,
		-global_rotation,
		Vector2.ONE
	)

	var rx := bubble_radius
	var ry := bubble_radius * ISO_Y_SCALE
	var steps := 48
	var pts := PackedVector2Array()

	for i in range(steps):
		var a := TAU * float(i) / float(steps)
		pts.append(Vector2(cos(a) * rx, sin(a) * ry))

	draw_colored_polygon(pts, Color(1, 1, 0, 0.25))
