extends Camera3D

@export var follow_distance = 5
@export var follow_height = 2
@export var speed := 20.0
@export var follow_this : Node3D

var start_rotation : Vector3
var start_position : Vector3

var rotating = false
var previous_mouse_position : Vector2

func _ready():
	start_rotation = rotation
	start_position = position

func _physics_process(delta : float):
	if Input.is_action_pressed("ui_right_click"):
		if not rotating:
			rotating = true
			previous_mouse_position = get_viewport().get_mouse_position()
		update_camera_rotation()
	else:
		rotating = false
		follow_target()

	look_at(follow_this.global_transform.origin, Vector3.UP)

func follow_target():
	var delta_v := global_transform.origin - follow_this.global_transform.origin
	delta_v.y = 0.0
	if delta_v.length() > follow_distance:
		delta_v = delta_v.normalized() * follow_distance
		delta_v.y = follow_height
		global_position = follow_this.global_transform.origin + delta_v

func update_camera_rotation():
	print("Updating roation")
	var mouse_delta = Input.get_last_mouse_velocity()
	var rotation_speed = 2  # Adjust rotation speed as needed

	var yaw = -mouse_delta.x * rotation_speed
	var pitch = -mouse_delta.y * rotation_speed

	rotate_object_local(Vector3.UP, yaw)
	rotate_object_local(Vector3.RIGHT, pitch)
