extends Node3D

const MAX_THRUST_FORCE = 15000.0
const THRUST_INCREMENT = 5000.0

@onready var vehicle: Vehicle = $".."
@onready var left_jet = $"left-jet/jet"
@onready var right_jet = $"right-jet/jet"

var thrust_force: float = 0.0
var is_thrust_active: bool = false
var main

func _ready():
	main = get_tree().root.get_child(0)
	
func _process(delta: float) -> void:
	if Input.is_action_pressed("activate_jet") and str(multiplayer.get_unique_id()) == vehicle.name:
		emit_thrusters()
		main.emit_thrusters(true)
		thrust_force += THRUST_INCREMENT * delta
		if thrust_force > MAX_THRUST_FORCE:
			thrust_force = MAX_THRUST_FORCE
		apply_thrust()
	elif Input.is_action_just_released("activate_jet") and str(multiplayer.get_unique_id()) == vehicle.name:
		stop_emit_thrusters()
		main.emit_thrusters(false)
		thrust_force = 0.0

func apply_thrust() -> void:
	var left_thrust_vector = thrust_force * -left_jet.global_transform.basis.y
	var right_thrust_vector = thrust_force * -right_jet.global_transform.basis.y

	vehicle.apply_central_force(left_thrust_vector)
	vehicle.apply_central_force(right_thrust_vector)
	
func emit_thrusters():
	print("In the Emit THrusters on jet mod!!!")
	left_jet.emitting = true
	right_jet.emitting = true
	is_thrust_active = true

func stop_emit_thrusters():
	left_jet.emitting = false
	right_jet.emitting = false
	is_thrust_active = false
