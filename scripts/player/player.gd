extends VehicleBody3D

const MAX_STEER = .85
const STEERING_SPEED = 2.5
const ACCELERATION_SPEED = 1000.0
const DEAD_ZONE = 0.001
const MAX_SUCTION_FORCE = 50.0
const SUCTION_FORCE_INCREMENT = 10.0
const STABILIZE_FORCE = 200.0
const ROTATION_SPEED = 50.0

# Export vars
@export var engine: EngineResource
# On Ready
@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera_3d: Camera3D = $CameraPivot/Camera3D
@onready var reverse_camera: Camera3D = $CameraPivot/ReverseCamera
@onready var air_camera: Camera3D = $CameraPivot/AirCamera
@onready var back_left: VehicleWheel3D = $BackLeft
@onready var back_right: VehicleWheel3D = $BackRight
@onready var front_left: VehicleWheel3D = $FrontLeft
@onready var front_right: VehicleWheel3D = $FrontRight
@onready var look_at_self: Vector3 = global_position
@onready var rpm: ProgressBar = $UI/RPM
@onready var gear: RichTextLabel = $UI/GEAR

# Get the first scene master from the root


var in_air = false
var in_contact = false
var air_timer = 0
var current_gear = 1
var current_rpm = 0
var throttle = 0.0

func _ready():
	rpm.max_value = engine.max_rpm
	
func _physics_process(delta: float) -> void:
	in_air = _check_in_air() # Check if we are in the air
	if in_air: _stablize_car(delta)
	# Steering with Right Thumbstick
	_steering_inputs(delta)
	# Engine Force using Right Trigger
	_engine_power_inputs(delta)
	# Camera Follow/Reverse Code
	_camera_controls(delta)
	_check_camera_switch()
	# Clamping and Jumping forces
	if Input.is_action_pressed("jump_or_clamp"):
		# Suction Force Logic
		is_suction_active = true
		suction_force += SUCTION_FORCE_INCREMENT * delta
		if suction_force > MAX_SUCTION_FORCE:
			suction_force = MAX_SUCTION_FORCE
		apply_clamp_force()
	elif Input.is_action_just_released("jump_or_clamp") and is_suction_active:
		is_suction_active = false
		apply_jump_force()
	
func _steering_inputs(delta) -> void:
	var steer_input := (Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")) * -1
	if abs(steer_input) < DEAD_ZONE:
		steer_input = 0.0
	steering = move_toward(steering, steer_input * MAX_STEER, delta * STEERING_SPEED)
	
func _engine_power_inputs(delta) -> void:
	var trigger_input := Input.get_axis("engine_power", "reverse_power") * -1
	if abs(trigger_input) < DEAD_ZONE:
		trigger_input = 0.0
		
	var powerRPM = engine.get_power(back_right.get_rpm(), trigger_input)
	var power = powerRPM[0]
	rpm.value = powerRPM[1]
	gear.text = str(engine.current_gear)
	
	engine_force = move_toward(engine_force, power * engine.max_power, delta * 1000)
	back_left.brake = 0
	back_right.brake = 0

	if Input.is_action_pressed("reverse_power") and !Input.is_action_pressed("engine_power"):
		back_left.brake = 180
		back_right.brake = 180
		engine_force = 0

	if Input.is_action_pressed("reverse_power") and Input.is_action_pressed("engine_power"):
		back_left.brake = 0
		back_right.brake = 0
		trigger_input = Input.get_action_strength("reverse_power") * -1
		engine_force = power * (engine.max_power / 2)
	
func _check_in_air() -> bool:
	var is_in_air = false
	if !front_left.is_in_contact() and !front_right.is_in_contact() and !back_left.is_in_contact() and !back_right.is_in_contact():
		is_in_air = true # All 4 Wheels off the ground.
		gravity_scale = 1
	if front_left.is_in_contact() or front_right.is_in_contact() or back_left.is_in_contact() or back_right.is_in_contact() or in_contact:
		is_in_air = false # At least 1 wheel is touching.
		air_timer = 0
		gravity_scale = 4
	
	if is_in_air == true:
		air_timer += 1
		
	if air_timer < 10:
		axis_lock_angular_x = true
		axis_lock_angular_z = true
	else:
		axis_lock_angular_x = false
		axis_lock_angular_z = false
		
	return is_in_air
	
func apply_jump_force() -> void:
	var suction_vector = suction_force * transform.basis.y
	apply_impulse(suction_vector * 20, center_of_mass)
	suction_force = 0.0
	
func apply_clamp_force() -> void:
	var suction_vector = -suction_force * transform.basis.y
	apply_impulse(suction_vector, Vector3.ZERO)
	
func _camera_controls(delta) -> void:
	camera_pivot.global_position = camera_pivot.global_position.lerp(global_position, delta * 20.0)
	camera_pivot.transform = camera_pivot.transform.interpolate_with(transform, delta * 5.0)
	look_at_self = look_at_self.lerp(global_position + linear_velocity, delta * 5.0)
	camera_3d.look_at(look_at_self)
	reverse_camera.look_at(look_at_self)
	
func _check_camera_switch() -> void:
	if in_air:
		air_camera.current = true
	elif linear_velocity.dot(transform.basis.z) > -1:
		camera_3d.current = true
	else:
		if Input.is_action_just_pressed("engine_power"):
			camera_3d.current = true
		else:
			reverse_camera.current = true
	
func _stablize_car(delta):
	var up_dir = global_transform.basis.y.normalized()
	var gravity_dir = Vector3.UP

	# Calculate the stabilization force
	var align_dir = up_dir.cross(gravity_dir).normalized()
	var align_angle = acos(up_dir.dot(gravity_dir))

	var stabilization_torque = align_dir * align_angle * STABILIZE_FORCE
	apply_torque_impulse(stabilization_torque * delta)

	# Control rotation with right thumbstick
	var pitch_input = (Input.get_action_strength("ui_right_stick_up") - Input.get_action_strength("ui_right_stick_down")) * -1
	var roll_input = (Input.get_action_strength("ui_right_stick_left") - Input.get_action_strength("ui_right_stick_right")) * -1
	var pitch_torque = global_transform.basis.x * pitch_input * ROTATION_SPEED
	var roll_torque = global_transform.basis.z * roll_input * ROTATION_SPEED

	apply_torque_impulse(pitch_torque * delta)
	apply_torque_impulse(roll_torque * delta)
	
func _on_body_entered(_body: Node) -> void:
	in_contact = true
func _on_body_exited(_body: Node) -> void:
	in_contact = false
