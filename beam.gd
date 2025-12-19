extends Node2D

enum BeamMode { CONE, LASER, BUBBLE }

# --- Beam configuration ---
@export var mode : BeamMode = BeamMode.CONE
@export var beam_length := 120.0
@export var beam_half_angle := deg_to_rad(30.0)
@export var circle_radius := 20.0
@export var laser_radius := 3.0
@export var step := 4.0
@export var width_scale := 0.2
@export var cone_fill_scale := 0.65
@export var beam_origin_offset: Vector2 = Vector2.ZERO

# --- Focus / mode control ---
var beam_focus := 0.0
@export var focus_step := 0.1
@export var focus_min := 0.0
@export var focus_max := 3.0
@export var cone_length_min := 60.0
@export var cone_length_max := 170.0

# --- Update throttling ---
var _beam_dirty := true
var _beam_cooldown := 0
@export var beam_update_interval := 2

# --- State cache ---
var _last_pos: Vector2
var _last_rot: float
var _last_focus: float

@onready var miasma := get_tree().get_first_node_in_group("miasma")


func _ready():
	set_process_input(true)


func _process(_delta):
	queue_redraw()


func _unhandled_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			beam_focus = snapped(beam_focus + focus_step, 0.1)
			_beam_dirty = true
			queue_redraw()

		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			beam_focus = max(beam_focus - focus_step, focus_min)
			_beam_dirty = true
			queue_redraw()


func _physics_process(_delta):
	var origin := global_position + beam_origin_offset.rotated(global_rotation)
	if origin != _last_pos or global_rotation != _last_rot:
		_beam_dirty = true



	apply_beam_focus()

	if not miasma:
		return

	if not _beam_dirty:
		return

	_beam_cooldown += 1
	if _beam_cooldown < beam_update_interval:
		return

	_beam_cooldown = 0



	var forward: Vector2 = Vector2.RIGHT.rotated(global_rotation)

	if mode == BeamMode.BUBBLE and circle_radius > 0.01:
		miasma.clear_circle_world(origin, circle_radius, step)

	elif mode == BeamMode.CONE:
		var end_radius: float = tan(beam_half_angle) * beam_length * cone_fill_scale
		var base_radius: float = circle_radius
		var fwd: Vector2 = forward
		var right: Vector2 = fwd.orthogonal()

		# --- CONE BODY (tip at player) ---
		var dist: float = 0.0
		while dist <= beam_length:
			var half_width := tan(beam_half_angle) * dist * cone_fill_scale

			var offset := -half_width
			while offset <= half_width:
				var p: Vector2 = origin + fwd * dist + right * offset
				miasma.clear_circle_world(p, step * 1.5, step * 1.5)
				offset += step

			dist += step

		# --- ICE CREAM HALF-CAP (matches cone width exactly) ---
		var cap_center: Vector2 = origin + fwd * beam_length
		var r := 0.0
		while r <= end_radius:
			var angle := -PI / 2.0
			while angle <= PI / 2.0:
				var dir := fwd.rotated(angle)
				var p := cap_center + dir * r
				miasma.clear_circle_world(p, step * 0.75, step)
				angle += step / max(end_radius, 1.0)
			r += step



	elif mode == BeamMode.LASER:
		var dist: float = 0.0
		while dist <= beam_length:
			var p: Vector2 = origin + forward * dist
			miasma.clear_circle_world(p, laser_radius, step)
			dist += step

	_last_pos = origin
	_last_rot = global_rotation
	_last_focus = beam_focus
	_beam_dirty = false



func apply_beam_focus():
	if beam_focus < 1.0:
		# BUBBLE (0 → 1)
		mode = BeamMode.BUBBLE
		var t := beam_focus
		circle_radius = lerp(0.0, 60.0, t)

	elif beam_focus < 2.0:
		mode = BeamMode.CONE
		var t := beam_focus - 1.0  # 0 → 1 across cone

		# Angle: wide → narrow
		beam_half_angle = lerp(
			deg_to_rad(60.0),
			deg_to_rad(8.0),
			t
		)

		# Length: short → long
		beam_length = lerp(
			cone_length_min,
			cone_length_max,
			t
		)



	else:
		# LASER (2 → 3)
		mode = BeamMode.LASER
		beam_length = 180.0


	var rays := []

	var angle_steps: int = max(6, int(beam_half_angle * 2.0 * 24.0))
	var forward: Vector2 = Vector2.RIGHT.rotated(global_rotation)

	for i in range(angle_steps + 1):
		var t: float = float(i) / float(angle_steps)
		var angle: float = lerp(-beam_half_angle, beam_half_angle, t)
		var dir: Vector2 = forward.rotated(angle)
		rays.append(dir)

	return rays


func _draw():
	var origin := Vector2.ZERO
	var forward := Vector2.RIGHT

	if mode == BeamMode.BUBBLE:
		draw_circle(origin, circle_radius, Color(0, 1, 1, 0.3))

	elif mode == BeamMode.CONE:
		var fwd := Vector2.RIGHT
		var right := Vector2.UP

			# cone body
		var dist := 0.0
		while dist <= beam_length:
			var half_width := tan(beam_half_angle) * dist * cone_fill_scale
			draw_line(
				fwd * dist + right * half_width,
				fwd * dist - right * half_width,
				Color(1, 1, 0, 0.25),
				step
			)
			dist += step

		# half-circle end cap (matches cone width)
		var end_radius := tan(beam_half_angle) * beam_length * cone_fill_scale
		var center := fwd * beam_length

		var r := 0.0
		while r <= end_radius:
			var a := -PI / 2.0
			while a <= PI / 2.0:
				var p := center + fwd.rotated(a) * r
				draw_circle(p, step * 0.5, Color(1, 1, 0, 0.25))
				a += step / max(end_radius, 1.0)
			r += step



	elif mode == BeamMode.LASER:
		draw_line(
			origin,
			origin + forward * beam_length,
			Color(1, 0, 0, 0.8),
			laser_radius * 2.0
		)
