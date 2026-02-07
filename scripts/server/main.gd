extends Node3D

@onready var start: Control = get_node_or_null("UI/Start")
@onready var game_state = preload("res://scripts/resources/game-state.tres")
@onready var port_input: LineEdit = get_node_or_null("UI/Start/VBoxContainer/Port")
@onready var ip_input: LineEdit = get_node_or_null("UI/Start/VBoxContainer/IP")

var peer = ENetMultiplayerPeer.new()
var level = preload("res://scenes/levels/level1.tscn")
var car = preload("res://addons/gevp/scenes/drift_car.tscn")
var level_instance: Node3D
var vehicle_rigid_body : Vehicle
var car_controller : VehicleController # assigned in add_level()
var car_scene
const RESPAWN_TIME := 3
const DEFAULT_PORT := 42069
const DEFAULT_MAX_PLAYERS := 9
const DEFAULT_HOST := "178.128.75.89"

var _cmd_dedicated := false
var _cmd_port := DEFAULT_PORT
var _cmd_max_players := DEFAULT_MAX_PLAYERS
var _cmd_host := DEFAULT_HOST

func _ready() -> void:
	# Set up multiplayer authority
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	if car_scene == null or car_scene == "":
		car_scene = car.resource_path
	_parse_cmdline()
	if _is_dedicated():
		_start_server(_cmd_port, _cmd_max_players)
		_cleanup_host_view()
		return
				
func _on_host_pressed() -> void:
	var ui_port := DEFAULT_PORT
	if port_input and port_input.text != "":
		ui_port = int(port_input.text)
	if _start_server(ui_port, DEFAULT_MAX_PLAYERS):
		_cleanup_host_view()
		
func _on_join_pressed() -> void:
	var ui_port := DEFAULT_PORT
	var ui_ip := DEFAULT_HOST
	if port_input and port_input.text.strip_edges() != "":
		ui_port = int(port_input.text.strip_edges())
	if ip_input and ip_input.text.strip_edges() != "":
		ui_ip = ip_input.text.strip_edges()
		if ":" in ui_ip:
			var parts = ui_ip.split(":", false, 2)
			if parts.size() > 0 and parts[0] != "":
				ui_ip = parts[0]
			if parts.size() > 1 and parts[1] != "":
				ui_port = int(parts[1])
	var error = peer.create_client(ui_ip, ui_port)
	if !error:
		multiplayer.multiplayer_peer = peer
		# The connection is asynchronous. Defer level init and RPCs
		# to the connected_to_server callback to ensure we are connected.
	else:
		print("Failed to join server: ", error)

#  SSS   EEEE  RRRR   V   V  EEEE  RRRR 
# S      E     R   R  V   V  E     R   R
#  SSS   EEEE  RRRR   V   V  EEEE  RRRR 
#     S  E     R  R    V V   E     R  R
#  SSS   EEEE  R   R    V    EEEE  R   R
@rpc("any_peer")
func _on_peer_connected(_pid: int) -> void:
	pass
@rpc("any_peer")
func set_peer_data(pid: int, car_scene_path) -> void:
	# Tell new peer about existing players
	print("Peer Connectred ... ID: " + str(pid))
	if multiplayer.is_server():
		var player_state = game_state.get_player(str(pid))
		var joiner_mods: Array = []
		if typeof(player_state) == TYPE_DICTIONARY and player_state.has("mods"):
			joiner_mods = player_state["mods"]
		# Ensure the joining peer spawns themselves
		rpc_id(pid, "spawn_player", pid, car_scene_path, joiner_mods)
		for existing_pid in multiplayer.get_peers():
			var other_player = game_state.get_player(str(existing_pid))
			if existing_pid != pid:
				# Tell existing peers to spawn the joiner
				rpc_id(existing_pid, "spawn_player", pid, car_scene_path, joiner_mods)
				print("player mods")
				print(joiner_mods)
				print("Other Player")
				var other_mods = other_player["mods"] if typeof(other_player) == TYPE_DICTIONARY and other_player.has("mods") else []
				print(other_mods)
				# need to spawn others, with their mods
				var existing = game_state.get_player(str(existing_pid)) # get the correct scene for existing player.
				if typeof(existing) == TYPE_DICTIONARY and existing.has("scene"):
					rpc_id(pid, "spawn_player", existing_pid, existing["scene"], other_mods)
		# Add on server scene and record state
		add_player(pid, car_scene_path, joiner_mods)
		
#  SSS   EEEE  RRRR   V   V  EEEE  RRRR
# S      E     R   R  V   V  E     R   R
#  SSS   EEEE  RRRR   V   V  EEEE  RRRR
#     S  E     R  R    V V   E     R  R
#  SSS   EEEE  R   R    V    EEEE  R   R


func add_level() -> void:
	level_instance = level.instantiate()
	add_child(level_instance)
	if start and start.get_child_count() > 1:
		start.get_child(1).queue_free()
	# We need our level before we can grab our car controller
	car_controller = level_instance.get_node_or_null("VehicleController")
	if multiplayer.is_server():
		level_instance.replace_player_car(car)
		vehicle_rigid_body = level_instance.get_node_or_null("VehicleController/VehicleRigidBody")
		if vehicle_rigid_body:
			vehicle_rigid_body.name = str(multiplayer.get_unique_id())
	else:
		# Remove placeholder car on clients
		var placeholder = level_instance.get_node_or_null("VehicleController/VehicleRigidBody")
		if placeholder:
			placeholder.queue_free()
	if not multiplayer.is_server() and level_instance.has_node("Camera3D"):
		level_instance.get_node("Camera3D").current = true
	_cache_spawn_points()

var _spawn_points: Array = []
var _next_spawn_index: int = 0

func _cache_spawn_points() -> void:
	_spawn_points.clear()
	if level_instance:
		if level_instance.has_node("SpawnPoints"):
			var sp = level_instance.get_node("SpawnPoints")
			for c in sp.get_children():
				if c is Node3D:
					_spawn_points.append(c)

func _get_next_spawn_position() -> Vector3:
	if _spawn_points.size() == 0:
		return Vector3(0, 2, 0)
	var n: Node3D = _spawn_points[_next_spawn_index % _spawn_points.size()]
	_next_spawn_index += 1
	return n.global_transform.origin


@rpc("any_peer", "reliable")
func spawn_player(pid: int, car_scene_path, mods) -> void:
	add_player(pid, car_scene_path, mods)
# must always be called after add_level has been called once!
func add_player(pid: int, car_scene_path, mods) -> void:
	# Check if the player with the same pid already exists in the level
	if level_instance:
		for child in level_instance.get_node("VehicleController").get_children():
			if child.name == str(pid):
				print("Player with ID " + str(pid) + " already exists.")
				return
	if multiplayer.is_server():
		# Adding our players initial data.
		game_state.add_player(str(pid), 500, 100, car_scene_path)
		# Persist any provided mods
		if typeof(mods) == TYPE_ARRAY:
			for m in mods:
				game_state.add_mod(str(pid), m)
		elif typeof(mods) == TYPE_STRING and mods != "":
			game_state.add_mod(str(pid), mods)
	# add the car
	var car_res = load(car_scene_path) # load resource without clobbering global 'car'
	var car_instance = car_res.instantiate()
	car_instance.set_multiplayer_authority(pid)
	car_instance.name = str(pid)
	car_controller.add_child(car_instance)
	if typeof(mods) == TYPE_ARRAY and not mods.is_empty():
		for mod in mods: # load mods and add child to this player's car
			var mod_path = "res://scenes/player/modules/" + mod + ".tscn"
			var mod_scene = load(mod_path)
			if mod_scene:
				var mod_instance = mod_scene.instantiate()
				car_instance.add_child(mod_instance)

	if str(multiplayer.get_unique_id()) == str(pid):
		vehicle_rigid_body = car_instance
		if level_instance:
			if level_instance.has_node("VehicleController"):
				var vc = level_instance.get_node("VehicleController")
				vc.vehicle_node = car_instance
			if level_instance.has_node("GUI"):
				var gui_node = level_instance.get_node("GUI")
				gui_node.vehicle = car_instance
			if level_instance.has_node("Camera3D"):
				var cam = level_instance.get_node("Camera3D")
				cam.follow_this = car_instance
			
	car_instance.global_transform.origin = Vector3(0, 2, 0)
	print("Player with ID " + str(pid) + " added to the game.")

# RPC function to spawn players across all clients



# Sync player transform
@rpc("any_peer", "unreliable")
func update_player_transform(pid: int, new_transform: Transform3D) -> void:
	var player = car_controller.get_node_or_null(str(pid))
	if player and pid != multiplayer.get_unique_id():
		# Validate incoming transform to avoid NaNs/huge values propagating
		if _is_transform_valid(new_transform):
			player.global_transform = new_transform.orthonormalized()
		else:
			return
func _physics_process(_delta: float) -> void:
	# Only update if we're connected
	if multiplayer.multiplayer_peer and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		# Sync our car's position to other players
		if !multiplayer.is_server():
			if not is_instance_valid(vehicle_rigid_body):
				return
			# Do not send transforms while our local car is KO'd or missing
			if vehicle_rigid_body and not (vehicle_rigid_body.has_meta("dead") and vehicle_rigid_body.get_meta("dead") == true) and _is_transform_valid(vehicle_rigid_body.global_transform):
				rpc("update_player_transform", multiplayer.get_unique_id(), vehicle_rigid_body.global_transform.orthonormalized())

# Basic sanity checks for transforms coming over the network
const _MAX_POS := 100000.0
const _MIN_BASIS_LEN := 0.0001
const _MAX_BASIS_LEN := 1000.0
func _vec_ok(v: Vector3) -> bool:
	return not is_nan(v.x) and not is_nan(v.y) and not is_nan(v.z) and absf(v.x) < _MAX_POS and absf(v.y) < _MAX_POS and absf(v.z) < _MAX_POS

func _basis_ok(v: Vector3) -> bool:
	return _vec_ok(v) and v.length() > _MIN_BASIS_LEN and v.length() < _MAX_BASIS_LEN

func _is_transform_valid(t: Transform3D) -> bool:
	return _vec_ok(t.origin) and _basis_ok(t.basis.x) and _basis_ok(t.basis.y) and _basis_ok(t.basis.z)


# add mods to client cars
# This should happen on the server. same logic, but on server.
func add_mod(mod_name, pickup_path := NodePath()):
	var my_id = multiplayer.get_unique_id()
	if multiplayer.is_server():
		# Server is authority: broadcast to all peers (including equipper)
		rpc("sync_mod", my_id, mod_name)
		# Remove pickup across all peers if a path was provided
		if String(pickup_path) != "":
			rpc("remove_pickup", pickup_path)
			var node := get_node_or_null(pickup_path)
			if node:
				node.queue_free()
	else:
		# Client informs server; server will broadcast to everyone
		rpc_id(1, "sync_mod", my_id, mod_name)
		if String(pickup_path) != "":
			rpc_id(1, "remove_pickup", pickup_path)
@rpc("any_peer", "reliable")
func sync_mod(pid, mod_name):
	# Entry point for mod sync. If called on server (from a client),
	# apply locally, persist, and broadcast to all clients.
	if multiplayer.is_server():
		# Persist on server
		game_state.add_mod(str(pid), mod_name)
		# Apply on server scene
		_apply_mod_to_node(pid, mod_name)
		# Broadcast to all clients
		for peer_id in multiplayer.get_peers():
			rpc_id(peer_id, "apply_mod", pid, mod_name)
	else:
		# If received on a client directly (server broadcast), just apply
		_apply_mod_to_node(pid, mod_name)

@rpc("any_peer", "reliable")
func apply_mod(pid, mod_name):
	_apply_mod_to_node(pid, mod_name)

func _apply_mod_to_node(pid, mod_name):
	# create list of mods and their file paths
	if car_controller and car_controller.has_node(str(pid)):
		var player_node = car_controller.get_node(str(pid))
		var expected_node_name = mod_name
		if mod_name == "gun_mod":
			expected_node_name = "gun-mod"
		elif mod_name == "jet_mod":
			expected_node_name = "JetMod"
		if !player_node.has_node(expected_node_name):
			var mod_path = "res://scenes/player/modules/" + mod_name + ".tscn"
			var mod_scene = load(mod_path)
			if mod_scene:
				var mod_instance = mod_scene.instantiate()
				player_node.add_child(mod_instance)

@rpc("any_peer", "reliable")
func remove_pickup(pickup_path: NodePath) -> void:
	var node := get_node_or_null(pickup_path)
	if node:
		node.queue_free()

# --- Respawn flow ---
# Called by server when a player reaches 0 health
@rpc("any_peer", "reliable")
func start_respawn(player_name: String, _seconds: int) -> void:
	# Called on all peers to put the car into a safe, non-interactive state and show countdown for owner
	if car_controller and car_controller.has_node(player_name):
		var car_node: Node = car_controller.get_node(player_name)
		# Save current collision masks so we can restore later
		car_node.set_meta("_orig_layer", car_node.collision_layer)
		car_node.set_meta("_orig_mask", car_node.collision_mask)
		car_node.collision_layer = 0
		car_node.collision_mask = 0
		car_node.linear_velocity = Vector3.ZERO
		car_node.angular_velocity = Vector3.ZERO
		car_node.freeze = true
		car_node.hide()
		car_node.set_meta("dead", true)
		# Owner will be asked to show countdown via direct RPC from server

@rpc("any_peer", "reliable")
func finish_respawn(player_name: String, spawn_pos: Vector3) -> void:
	# Called on all peers to restore a car to play
	if car_controller and car_controller.has_node(player_name):
		var car_node: Node = car_controller.get_node(player_name)
		# Restore collisions
		if car_node.has_meta("_orig_layer"):
			car_node.collision_layer = int(car_node.get_meta("_orig_layer"))
		else:
			car_node.collision_layer = 1
		if car_node.has_meta("_orig_mask"):
			car_node.collision_mask = int(car_node.get_meta("_orig_mask"))
		else:
			car_node.collision_mask = 1
		# Reset physics state
		car_node.freeze = false
		car_node.linear_velocity = Vector3.ZERO
		car_node.angular_velocity = Vector3.ZERO
		var xform: Transform3D = car_node.global_transform
		xform.origin = spawn_pos
		car_node.global_transform = xform
		# Remove any mod visuals
		for child in car_node.get_children():
			if child is Node and (child.name == "gun-mod" or child.name == "JetMod"):
				child.queue_free()
		car_node.set_meta("dead", false)
		car_node.show()
		# Wake up
		if car_node.has_method("set_sleeping"):
			car_node.set_sleeping(false)
		# Owner will be asked to hide countdown via direct RPC from server
	# Server authoritative state reset
	if multiplayer.is_server():
		var st = game_state.get_player(player_name)
		if typeof(st) == TYPE_DICTIONARY:
			game_state.update_player(player_name, 100, st["defense"])
			if game_state.players.has(player_name) and game_state.players[player_name].has("mods"):
				game_state.players[player_name]["mods"].clear()

@rpc("any_peer", "reliable")
func show_respawn(seconds: int) -> void:
	# Runs only on the owning client
	if level_instance and level_instance.has_node("GUI"):
		var gui = level_instance.get_node("GUI")
		if gui.has_method("start_respawn_countdown"):
			gui.start_respawn_countdown(seconds)

@rpc("any_peer", "reliable")
func hide_respawn_ui() -> void:
	if level_instance and level_instance.has_node("GUI"):
		var gui = level_instance.get_node("GUI")
		if gui.has_method("hide_respawn"):
			gui.hide_respawn()

@rpc("any_peer", "reliable")
func respawn_player(pid: String, car_scene_path: String, spawn_pos: Vector3) -> void:
	# Prefer reusing existing node to avoid queue_free/name races
	var car_node: Node = null
	if car_controller:
		car_node = car_controller.get_node_or_null(pid)
	if car_node == null:
		var scene = load(car_scene_path)
		if scene:
			car_node = scene.instantiate()
			car_node.name = pid
			car_controller.add_child(car_node)
	if car_node:
		var pid_int = int(pid)
		if car_node.has_method("set_multiplayer_authority"):
			car_node.set_multiplayer_authority(pid_int)
		var t = car_node.global_transform
		t.origin = spawn_pos
		car_node.global_transform = t
		# Restore collisions
		if car_node.has_meta("_orig_layer"):
			car_node.collision_layer = int(car_node.get_meta("_orig_layer"))
		else:
			car_node.collision_layer = 1
		if car_node.has_meta("_orig_mask"):
			car_node.collision_mask = int(car_node.get_meta("_orig_mask"))
		else:
			car_node.collision_mask = 1
		# Clear KO state and motion
		car_node.set_meta("dead", false)
		car_node.freeze = false
		car_node.linear_velocity = Vector3.ZERO
		car_node.angular_velocity = Vector3.ZERO
		car_node.show()
		if car_node.has_method("set_sleeping"):
			car_node.set_sleeping(false)
		# If this is my local player, retarget controller, GUI and camera
		if str(multiplayer.get_unique_id()) == pid and level_instance:
			if level_instance.has_node("VehicleController"):
				var vc = level_instance.get_node("VehicleController")
				vc.vehicle_node = car_node
			if level_instance.has_node("GUI"):
				var gui_node = level_instance.get_node("GUI")
				gui_node.vehicle = car_node
			if level_instance.has_node("Camera3D"):
				var cam = level_instance.get_node("Camera3D")
				cam.follow_this = car_node
			# Also update our local reference used for transform syncing
			vehicle_rigid_body = car_node
	
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
	# Update the victim, not the shooter
	game_state.update_player(hit_body_name, player.health, player.defense)
	if player.health <= 0:
		rpc("player_dead", pid, hit_body_name)
@rpc("any_peer", "reliable")
func player_dead(_pid, hit_body_name):
	var player = car_controller.get_node_or_null(str(hit_body_name))
	if player and player is Node3D:
		# prevent duplicate KO handling
		if player.has_meta("dead") and player.get_meta("dead") == true:
			return
		var player_pos = Vector3.ZERO
		if player.is_inside_tree():
			player_pos = player.global_position
		# Mark dead and disable interactions
		player.set_meta("dead", true)
		player.set_meta("_orig_layer", player.collision_layer)
		player.set_meta("_orig_mask", player.collision_mask)
		player.collision_layer = 0
		player.collision_mask = 0
		player.freeze = true
		player.hide()
		var explosion = preload("res://scenes/player/death/death.tscn")
		explosion = explosion.instantiate()
		get_tree().get_root().add_child(explosion)
		# Set position after adding to tree to avoid transform warnings
		explosion.global_position = player_pos
		await get_tree().create_timer(2).timeout
		if explosion: explosion.queue_free()
		if player: player.hide()
		# detach player
		# wait then re-spawn
		# Server orchestrates start/finish for all peers
		if multiplayer.is_server():
			# Notify everyone to enter respawn state and show countdown for owner
			rpc("start_respawn", hit_body_name, RESPAWN_TIME)
			# Tell the owning peer to show their countdown UI
			rpc_id(int(hit_body_name), "show_respawn", RESPAWN_TIME)
			# Also apply on the server
			start_respawn(hit_body_name, RESPAWN_TIME)
			await get_tree().create_timer(RESPAWN_TIME).timeout
			var spawn := _get_next_spawn_position()
			var st = game_state.get_player(hit_body_name)
			var scene_path = st["scene"] if typeof(st) == TYPE_DICTIONARY and st.has("scene") else car.resource_path
			# Ask the owner to hide UI; send fresh car to all peers
			rpc_id(int(hit_body_name), "hide_respawn_ui")
			rpc("respawn_player", hit_body_name, scene_path, spawn)
			respawn_player(hit_body_name, scene_path, spawn)
	
func set_car_scene(scene):
	car_scene = scene
	car = load(scene)
	
func _on_connected_to_server() -> void:
	print("Connected to server!")
	if start:
		start.hide()
	# Safe point to create level and inform server
	if level_instance == null:
		add_level()
	# Inform server about our selected car and receive state
	if car_scene == null or car_scene == "":
		car_scene = car.resource_path
	rpc_id(1, "set_peer_data", multiplayer.get_unique_id(), car_scene)

func _on_connection_failed() -> void:
	print("Connection failed!")
	multiplayer.multiplayer_peer = null
	if start:
		start.show()

func _on_server_disconnected() -> void:
	print("Server disconnected!")
	multiplayer.multiplayer_peer = null
	if start:
		start.show()

func _start_server(server_port: int, max_players: int) -> bool:
	var error = peer.create_server(server_port, max_players)
	if !error:
		if start:
			start.hide()
		multiplayer.multiplayer_peer = peer
		multiplayer.peer_connected.connect(_on_peer_connected)
		add_level()
		print("Server started on port %s ..." % str(server_port))
		return true
	else:
		print("Failed to create server: ", error)
		return false

func _cleanup_host_view() -> void:
	if not level_instance:
		return
	if level_instance.has_node("HostCam"):
		level_instance.get_node("HostCam").current = true
	if level_instance.has_node("Debug"):
		level_instance.get_node("Debug").queue_free()
	if level_instance.has_node("GUI"):
		level_instance.get_node("GUI").queue_free()
	if level_instance.has_node("Camera3D"):
		level_instance.get_node("Camera3D").queue_free()
	if level_instance.has_node("VehicleController"):
		var vc = level_instance.get_node("VehicleController")
		vc.set_script(null)
		if vc.get_child_count() > 0:
			vc.get_child(0).queue_free()
		for child in vc.get_children():
			child.queue_free()

func _parse_cmdline() -> void:
	var args = OS.get_cmdline_args()
	for i in range(args.size()):
		var arg = args[i]
		if arg == "--dedicated":
			_cmd_dedicated = true
		elif arg == "--port" and i + 1 < args.size():
			_cmd_port = int(args[i + 1])
		elif arg == "--max-players" and i + 1 < args.size():
			_cmd_max_players = int(args[i + 1])
		elif arg == "--host" and i + 1 < args.size():
			_cmd_host = args[i + 1]

func _is_dedicated() -> bool:
	return _cmd_dedicated or OS.has_feature("server") or DisplayServer.get_name() == "headless"
