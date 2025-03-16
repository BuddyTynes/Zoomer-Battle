extends Node3D

const STABILIZE_FORCE = 200.0
const ROTATION_SPEED = 5550.0

@onready var vehicle: Vehicle = $".."
@onready var ground_distance = $"RayCast3D"

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if get_distance_from_ground() == -1: 
		vehicle.gravity_scale = .25
		stablize_car(delta) # car in air controll
	else:
		vehicle.gravity_scale = 1
	
func get_distance_from_ground() -> float:
	if ground_distance.is_colliding():
		return ground_distance.get_collision_point().distance_to(ground_distance.global_transform.origin)
	return -1  # Return -1 if not colliding (indicates not detecting ground)

# needs to be it's own gyro_mod
func stablize_car(delta):
	var up_dir = global_transform.basis.y.normalized()
	var gravity_dir = Vector3.UP

	# Calculate the stabilization force
	var align_dir = up_dir.cross(gravity_dir).normalized()
	var align_angle = acos(up_dir.dot(gravity_dir))

	var stabilization_torque = align_dir * align_angle * STABILIZE_FORCE
	vehicle.apply_torque_impulse(stabilization_torque * delta)

	# Control rotation with right thumbstick
	var pitch_input = (Input.get_action_strength("ui_left_stick_up") - Input.get_action_strength("ui_left_stick_down")) * -1
	var roll_input = Input.get_action_strength("ui_left_stick_left") - Input.get_action_strength("ui_left_stick_right")
	var pitch_torque = global_transform.basis.x * pitch_input * ROTATION_SPEED
	var roll_torque = global_transform.basis.y * roll_input * ROTATION_SPEED
	
	vehicle.axis_lock_angular_x = false
	vehicle.axis_lock_angular_z = false
	vehicle.apply_torque_impulse(pitch_torque * delta)
	vehicle.apply_torque_impulse(roll_torque * delta)
