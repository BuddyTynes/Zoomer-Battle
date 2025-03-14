extends Node3D

@onready var start: Control = $UI/Start

var peer = ENetMultiplayerPeer.new()
var level = preload("res://scenes/levels/level1.tscn")
var car = preload("res://addons/gevp/scenes/drift_car.tscn")
var level_instance: Node3D
var vehicle_rigid_body : Vehicle
var car_controller : VehicleController # assigned in add_level()

func _ready() -> void:
	# Set up multiplayer authority
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func _on_host_pressed() -> void:
	var error = peer.create_server(42069)
	if !error:
		start.hide()
		multiplayer.multiplayer_peer = peer
		var pid = multiplayer.get_unique_id()
		multiplayer.peer_connected.connect(_on_peer_connected)
		add_level()
		
		vehicle_rigid_body = get_child(1).get_child(0).get_child(0)
		vehicle_rigid_body.name = str(pid)
	else:
		print("Failed to create server: ", error)

func _on_join_pressed() -> void:
	var error = peer.create_client("99.108.174.198", 42069)
	if !error:
		multiplayer.multiplayer_peer = peer
		start.hide()
		add_level()
		vehicle_rigid_body = get_child(1).get_child(0).get_child(0)
	else:
		print("Failed to join server: ", error)

func add_level() -> void:
	level_instance = level.instantiate()
	add_child(level_instance)
	# We need our level before we can grab our car controller
	car_controller = level_instance.get_child(0)

# must always be called after add_level has been called once!
func add_player(pid: int) -> void:
	# Check if the player with the same pid already exists in the level
	if level_instance:
		for child in level_instance.get_node("VehicleController").get_children():
			if child.name == str(pid):
				print("Player with ID " + str(pid) + " already exists.")
				return
	# add the car
	var car_instance = car.instantiate()
	car_instance.name = str(pid)
	car_instance.set_multiplayer_authority(pid)
	car_controller.add_child(car_instance)
	car_instance.global_transform.origin = Vector3(0, 2, 0)
	print("Player with ID " + str(pid) + " added to the game.")

# RPC function to spawn players across all clients
@rpc("any_peer", "call_local", "reliable")
func spawn_player(pid: int) -> void:
	add_player(pid)

# Sync player transform
@rpc("any_peer", "call_local", "unreliable")
func update_player_transform(pid: int, transform: Transform3D) -> void:
	var player = car_controller.get_node(str(pid))
	if	player and pid != multiplayer.get_unique_id():
		player.global_transform = transform

func _physics_process(delta: float) -> void:
	# Only update if we're connected
	if multiplayer.multiplayer_peer and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		# Sync our car's position to other players
		if vehicle_rigid_body and vehicle_rigid_body.name == str(multiplayer.get_unique_id()):
			#print("update name: " + vehicle_rigid_body.name + "  uni_id: " + str(multiplayer.get_unique_id()))
			rpc("update_player_transform", multiplayer.get_unique_id(), vehicle_rigid_body.global_transform)

func _on_peer_connected(pid: int) -> void:
	# Tell new peer about existing players
	for existing_pid in multiplayer.get_peers():
		print("PIDS:  " + str(existing_pid))
		rpc_id(existing_pid, "spawn_player", multiplayer.get_unique_id())
	## Spawn new player for everyone
	rpc("spawn_player", pid)

func _on_connected_to_server() -> void:
	print("Connected to server!")
	var pid = multiplayer.get_unique_id()
	vehicle_rigid_body.name = str(pid)
	add_player(pid)

func _on_connection_failed() -> void:
	print("Connection failed!")
	multiplayer.multiplayer_peer = null

func _on_server_disconnected() -> void:
	print("Server disconnected!")
	multiplayer.multiplayer_peer = null
	# Clean up players
	for child in level_instance.get_children():
		if child is Vehicle:
			child.queue_free()
	start.show()
	
@rpc("any_peer", "call_local", "unreliable")
func on_hit():
	print("I'm getting hit")
