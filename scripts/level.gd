extends Node3D

@onready var vehicle_controller = $VehicleController
@onready var gui = $GUI
@onready var camera_3d = $Camera3D
@onready var debug = $Debug
@onready var vehicle_rigid_body: Vehicle = $VehicleController/VehicleRigidBody

func replace_player_car(new_car):
	new_car = new_car.instantiate()
	new_car = new_car as Vehicle
	var vc = get_node_or_null("VehicleController")
	if vc:
		var old_car = vc.get_node_or_null("VehicleRigidBody")
		if old_car:
			old_car.queue_free()
	vc.add_child(new_car)
	vc.vehicle_node = new_car
	var gui_node = get_node_or_null("GUI")
	if gui_node:
		gui_node.vehicle = new_car
	var cam_node = get_node_or_null("Camera3D")
	if cam_node:
		cam_node.follow_this = new_car
	var debug_node = get_node_or_null("Debug")
	if debug_node:
		debug_node.vehicle = new_car
