extends Node3D

@onready var start: Control = $UI/Start
@onready var game_state = preload("res://scripts/resources/game-state.tres")
@onready var port = $UI/Start/VBoxContainer/Port
@onready var ip = $UI/Start/VBoxContainer/IP

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
	port = int(port.text) if port.text != "" else 42069
	var error = peer.create_server(port, 9)
	if !error:
		start.hide()
		multiplayer.multiplayer_peer = peer
		var pid = multiplayer.get_unique_id()
		multiplayer.peer_connected.connect(_on_peer_connected)
		add_level()
		# remove the car instance and activate host cam.
		level_instance.get_node("HostCam").current = true
		level_instance.get_node("Debug").queue_free()
		level_instance.get_node("GUI").queue_free()
		level_instance.get_node("Camera3D").queue_free()
		level_instance.get_node("VehicleController").set_script(null)
		level_instance.get_node("VehicleController").get_child(0).queue_free()
		print("Server started ...")
	else:
		print("Failed to create server: ", error)
		
func _on_join_pressed() -> void:
	port = int(port.text) if port.text != "" else 42069
	ip = ip.text if ip.text != "" else "localhost"
	var error = peer.create_client(ip, port)
	if !error:
		multiplayer.multiplayer_peer = peer
		start.hide()
		add_level()
	else:
		print("Failed to join server: ", error)

#  SSS   EEEE  RRRR   V   V  EEEE  RRRR 
# S      E     R   R  V   V  E     R   R
#  SSS   EEEE  RRRR   V   V  EEEE  RRRR 
#     S  E     R  R    V V   E     R  R
#  SSS   EEEE  R   R    V    EEEE  R   R
@rpc("any_peer")
func _on_peer_connected(pid: int) -> void:
	# Tell new peer about existing players
	print("Peer Connectred ... ID: " + str(pid))
	if multiplayer.is_server():
		for existing_pid in multiplayer.get_peers():
			if existing_pid != pid:
				rpc_id(existing_pid, "spawn_player", pid)
				rpc_id(pid, "spawn_player", existing_pid)
				
		add_player(pid)
#  SSS   EEEE  RRRR   V   V  EEEE  RRRR 
# S      E     R   R  V   V  E     R   R
#  SSS   EEEE  RRRR   V   V  EEEE  RRRR 
#     S  E     R  R    V V   E     R  R
#  SSS   EEEE  R   R    V    EEEE  R   R


func add_level() -> void:
	level_instance = level.instantiate()
	level_instance.replace_player_car(car)
	add_child(level_instance)
	# We need our level before we can grab our car controller
	car_controller = level_instance.get_child(0)
	vehicle_rigid_body = car_controller.get_child(0)
	vehicle_rigid_body.name = str(multiplayer.get_unique_id())


@rpc("any_peer", "reliable")
func spawn_player(pid: int) -> void:
	add_player(pid)
# must always be called after add_level has been called once!
func add_player(pid: int) -> void:
	# Check if the player with the same pid already exists in the level
	if level_instance:
		for child in level_instance.get_node("VehicleController").get_children():
			if child.name == str(pid):
				print("Player with ID " + str(pid) + " already exists.")
				return
	if multiplayer.is_server():
		game_state.add_player(str(pid), 500, 100)
	# add the car
	var car_instance = car.instantiate()
	car_instance.set_multiplayer_authority(pid)
	car_instance.name = str(pid)
	car_controller.add_child(car_instance)
	car_instance.global_transform.origin = Vector3(0, 2, 0)
	print("Player with ID " + str(pid) + " added to the game.")

# RPC function to spawn players across all clients



# Sync player transform
@rpc("any_peer", "unreliable")
func update_player_transform(pid: int, transform: Transform3D) -> void:
	var player = car_controller.get_node(str(pid))
	if	player and pid != multiplayer.get_unique_id():
		player.global_transform = transform
func _physics_process(delta: float) -> void:
	# Only update if we're connected
	if multiplayer.multiplayer_peer and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		# Sync our car's position to other players
		if !multiplayer.is_server():
			rpc("update_player_transform", multiplayer.get_unique_id(), vehicle_rigid_body.global_transform)


	
# add mods to client cars
# This should happen on the server. same logic, but on server.
func add_mod(mod_name):
	for existing_pid in multiplayer.get_peers():
		if multiplayer.get_unique_id() != existing_pid:
			rpc_id(existing_pid, "sync_mod", multiplayer.get_unique_id(), mod_name)
@rpc("any_peer", "unreliable")
func sync_mod(pid, mod_name):
	# create list of mods and their file paths
	if car_controller.has_node(str(pid)) and !car_controller.get_node(str(pid)).has_node(mod_name):
		var mod_path = "res://scenes/player/modules/" + mod_name + ".tscn"
		var mod = load(mod_path)
		mod = mod.instantiate()
		car_controller.get_node(str(pid)).add_child(mod)
	
	
	
# from the gun mod reach out 
# here we spawn_bullet
# spawn bullet calls back to the gun mod, we will have to get it manually?
# then each clients cars/gun mod will shoot?? 
func spawn_bullet():
	for existing_pid in multiplayer.get_peers():
		if multiplayer.get_unique_id() != existing_pid:
			rpc_id(existing_pid, "sync_bullet", multiplayer.get_unique_id())
@rpc("any_peer", "unreliable")
func sync_bullet(pid):
	if get_child(1).get_child(0).has_node(str(pid)):
		var gun_mod = get_child(1).get_child(0).get_node(str(pid)).get_node("gun-mod")
		gun_mod.shoot_guns()
		


func emit_thrusters(emit):
	for existing_pid in multiplayer.get_peers():
		if multiplayer.get_unique_id() != existing_pid:
			rpc_id(existing_pid, "sync_thrusters", multiplayer.get_unique_id(), emit)
@rpc("any_peer", "unreliable")
func sync_thrusters(pid, emit):
	if get_child(1).get_child(0).has_node(str(pid)):
		var jet_mod = get_child(1).get_child(0).get_node(str(pid)).get_node("JetMod")
		if emit:
			jet_mod.emit_thrusters()
		else:
			jet_mod.stop_emit_thrusters()




func hit_body(hit_body_name, pid):
	var player = game_state.get_player(hit_body_name)
	player.health = player.health - 30
	game_state.update_player(str(pid), player.health, player.defense)
	if player.health <= 0:
		rpc("player_dead", pid, hit_body_name)
@rpc("any_peer", "unreliable")
func player_dead(pid, hit_body_name):
	var player = car_controller.get_node(str(hit_body_name))
	if player:
		var player_pos = player.global_position
		player.hide()
		var explosion = preload("res://scenes/player/death/death.tscn")
		explosion = explosion.instantiate()
		explosion.global_position = player_pos
		get_tree().get_root().add_child(explosion)
		await get_tree().create_timer(2).timeout
		if explosion: explosion.queue_free()
		if player: player.hide()
		# detach player
		# wait then re-spawn
	
func set_car_scene(scene):
	car = load(scene)
	
func _on_connected_to_server() -> void:
	print("Connected to server!")

func _on_connection_failed() -> void:
	print("Connection failed!")
	multiplayer.multiplayer_peer = null

func _on_server_disconnected() -> void:
	print("Server disconnected!")
	multiplayer.multiplayer_peer = null
	start.show()
