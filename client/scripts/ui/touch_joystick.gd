class_name TouchJoystick
extends Control
## Joystick virtual para toque (Android). Emite `moved(vec)` com vetor de -1 a 1.

signal moved(vec: Vector2)

const RADIUS := 90.0

var _touch_index := -1
var _vec := Vector2.ZERO
var _knob := Vector2.ZERO


func _ready() -> void:
	custom_minimum_size = Vector2(RADIUS * 2.4, RADIUS * 2.4)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _touch_index == -1:
			_touch_index = event.index
			_update(event.position)
		elif not event.pressed and event.index == _touch_index:
			_release()
	elif event is InputEventScreenDrag and event.index == _touch_index:
		_update(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_touch_index = 99
			_update(event.position)
		else:
			_release()
	elif event is InputEventMouseMotion and _touch_index == 99:
		_update(event.position)


func _update(local_pos: Vector2) -> void:
	var center := size * 0.5
	var d := (local_pos - center)
	_vec = (d / RADIUS).limit_length(1.0)
	_knob = _vec * RADIUS
	moved.emit(_vec)
	queue_redraw()


func _release() -> void:
	_touch_index = -1
	_vec = Vector2.ZERO
	_knob = Vector2.ZERO
	moved.emit(_vec)
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	draw_circle(center, RADIUS, Color(1, 1, 1, 0.12))
	draw_arc(center, RADIUS, 0.0, TAU, 48, Color(1, 1, 1, 0.35), 3.0)
	draw_circle(center + _knob, RADIUS * 0.38, Color(1, 1, 1, 0.45))
