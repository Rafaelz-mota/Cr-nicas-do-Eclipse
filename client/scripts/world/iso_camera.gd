class_name IsoCamera
extends Camera3D
## Câmera 2.5D: perspectiva superior inclinada que segue o alvo suavemente.

@export var offset := Vector3(0.0, 13.0, 10.0)  # ~52° de inclinação
@export var follow_speed := 6.0

var target: Node3D = null


func _ready() -> void:
	fov = 40.0
	near = 0.5
	far = 150.0


func snap_to_target() -> void:
	if target != null:
		global_position = target.global_position + offset
		look_at(target.global_position + Vector3(0, 1.0, 0))


func _process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	var wanted := target.global_position + offset
	global_position = global_position.lerp(wanted, clampf(follow_speed * delta, 0.0, 1.0))
	look_at(global_position - offset + Vector3(0, 1.0, 0))
