extends Node3D

@onready var vehicle_controller = $VehicleController
@onready var gui = $GUI
@onready var camera_3d = $Camera3D
@onready var debug = $Debug
@onready var vehicle_rigid_body: Vehicle = $VehicleController/VehicleRigidBody

func replace_player_car(new_car):
	new_car = new_car.instantiate()
	if get_child(0):
		print("vehicle controler found.")
		get_child(0).add_child(new_car)
		get_child(0).vehicle_node = new_car
		get_child(1).vehicle = new_car
		get_child(2).follow_this = new_car
		get_child(4).vehicle = new_car
		get_child(0).get_child(0).queue_free()
