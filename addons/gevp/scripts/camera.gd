extends Camera3D

@export var follow_distance = 5
@export var follow_height = 2
@export var speed := 20.0
@export var follow_this : Node3D

var start_rotation : Vector3
var start_position : Vector3
var rotating = false
var previous_mouse_position : Vector2
var current_yaw = 0.0
var current_pitch = 0.0
var last_mouse_position = Vector2()

func _ready():
	start_rotation = rotation
	start_position = position

func _physics_process(delta : float):
	follow_target()
	if Input.is_action_pressed("ui_right_click"):
		rotating = true
		previous_mouse_position = get_viewport().get_mouse_position()
		update_camera_rotation()
	else:
		rotating = false
		
	look_at(follow_this.global_transform.origin, Vector3.UP)

func follow_target():
	var delta_v := global_transform.origin - follow_this.global_transform.origin
	delta_v.y = 0.0
	if delta_v.length() > follow_distance:
		delta_v = delta_v.normalized() * follow_distance
		delta_v.y = follow_height
		global_position = follow_this.global_transform.origin + delta_v



func update_camera_rotation():
	var mouse_position = get_viewport().get_mouse_position()
	var mouse_delta = mouse_position - last_mouse_position
	last_mouse_position = mouse_position
	var rotation_speed = 0.01  # Adjust rotation speed as needed

	if mouse_delta.x != 0 or mouse_delta.y != 0:
		current_yaw += mouse_delta.x * rotation_speed
		current_pitch = clamp(current_pitch + mouse_delta.y * rotation_speed, -PI / 4, PI / 4)  # Prevent flipping

		var offset = Vector3(
			follow_distance * cos(current_yaw) * cos(current_pitch),
			follow_height + follow_distance * sin(current_pitch),
			follow_distance * sin(current_yaw) * cos(current_pitch)
		)
		
		global_transform.origin = follow_this.global_transform.origin + offset

		look_at(follow_this.global_transform.origin, Vector3.UP)
		
