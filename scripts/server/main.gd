extends Node3D

@onready var start: Control = get_node_or_null("UI/Start")
@onready var game_state = preload("res://scripts/resources/game-state.tres")
@onready var port_input: LineEdit = get_node_or_null("UI/Start/VBoxContainer/Port")
@onready var ip_input: LineEdit = get_node_or_null("UI/Start/VBoxContainer/IP")
@onready var lobby: Control = get_node_or_null("UI/Lobby")
@onready var end_game: Control = get_node_or_null("UI/EndGame")
@onready var end_game_winner: Label = get_node_or_null("UI/EndGame/Panel/VBox/Winner")
@onready var end_game_scores: ItemList = get_node_or_null("UI/EndGame/Panel/VBox/Scores")
@onready var end_game_continue: Button = get_node_or_null("UI/EndGame/Panel/VBox/Continue")
@onready var pause_menu: Control = get_node_or_null("UI/PauseMenu")
@onready var pause_resume: Button = get_node_or_null("UI/PauseMenu/Panel/VBox/Resume")
@onready var pause_back: Button = get_node_or_null("UI/PauseMenu/Panel/VBox/BackToLobby")
@onready var rooms_list_widget: ItemList = get_node_or_null("UI/Lobby/Root/RoomsPanel/RoomsVBox/RoomsList")
@onready var refresh_rooms_button: Button = get_node_or_null("UI/Lobby/Root/RoomsPanel/RoomsVBox/RoomsButtons/RefreshRooms")
@onready var join_room_button: Button = get_node_or_null("UI/Lobby/Root/RoomsPanel/RoomsVBox/RoomsButtons/JoinRoom")
@onready var room_name_input: LineEdit = get_node_or_null("UI/Lobby/Root/CreatePanel/CreateVBox/RoomName")
@onready var max_players_input: SpinBox = get_node_or_null("UI/Lobby/Root/CreatePanel/CreateVBox/MaxPlayers")
@onready var kill_limit_input: SpinBox = get_node_or_null("UI/Lobby/Root/CreatePanel/CreateVBox/KillLimit")
@onready var create_room_button: Button = get_node_or_null("UI/Lobby/Root/CreatePanel/CreateVBox/CreateRoom")
@onready var room_title_label: Label = get_node_or_null("UI/Lobby/Root/RoomPanel/RoomVBox/RoomTitle")
@onready var room_info_label: Label = get_node_or_null("UI/Lobby/Root/RoomPanel/RoomVBox/RoomInfo")
@onready var room_players_list: ItemList = get_node_or_null("UI/Lobby/Root/RoomPanel/RoomVBox/PlayersList")
@onready var start_match_button: Button = get_node_or_null("UI/Lobby/Root/RoomPanel/RoomVBox/RoomButtons/StartMatch")
@onready var leave_room_button: Button = get_node_or_null("UI/Lobby/Root/RoomPanel/RoomVBox/RoomButtons/LeaveRoom")
@onready var lobby_status_label: Label = get_node_or_null("UI/Lobby/Status")

var peer = ENetMultiplayerPeer.new()
var level = preload("res://scenes/levels/level1.tscn")
var car = preload("res://addons/gevp/scenes/drift_car.tscn")
var level_instance: Node3D
var vehicle_rigid_body : Vehicle
var car_controller : VehicleController # assigned in add_level()
var car_scene
const RESPAWN_TIME := 3
const MAX_HEALTH := 100
const HIT_DAMAGE := 30
const MAX_SHIELD := 100
const SHIELD_PICKUP_AMOUNT := 40
const SHIELD_RESPAWN_TIME := 30.0
const SPAWN_INPUT_LOCK_MS := 1200
const SPAWN_FREEZE_TIME := 1.2
const SPAWN_BONUS_CLEARANCE := 2.0
const GUARD_LOCK_TIME_MS := 2200
const GUARD_SETTLE_TIME := 1.2
const GUARD_POSITION_LOCK := true
const OOB_Y_THRESHOLD := -50.0
const OOB_DIST_THRESHOLD := 600.0
const OOB_RESPAWN_COOLDOWN_MS := 3000
const OOB_GUARD_MS := 2000
const SPAWN_MIN_SEPARATION := 16.0
const SPAWN_RETRY_COUNT := 5
const RAY_ENABLE_DELAY := 2.0
const RESPAWN_CLEARANCE := 3.0
const RESPAWN_RAY_HEIGHT := 10.0
const RESPAWN_RAY_DEPTH := 50.0
const RESPAWN_FREEZE_TIME := 0.8
const RESPAWN_UNFREEZE_DELAY := 0.2
const RESPAWN_BONUS_CLEARANCE := 2.0
const RESPAWN_GUARD_MS := 600
const MAX_VERTICAL_SPEED := 50.0
const DEFAULT_PORT := 42069
const DEFAULT_MAX_PLAYERS := 9
const DEFAULT_HOST := "178.128.75.89"

var rooms := {}
var player_room := {}
var _next_room_id := 1
var current_room_id: String = ""
var current_room: Dictionary = {}
var in_match := false

var _cmd_dedicated := false
var _cmd_port := DEFAULT_PORT
var _cmd_max_players := DEFAULT_MAX_PLAYERS
var _cmd_host := DEFAULT_HOST

func _ready() -> void:
	# Set up multiplayer authority
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	if multiplayer.peer_disconnected.is_connected(_on_peer_disconnected) == false:
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	if refresh_rooms_button:
		refresh_rooms_button.pressed.connect(_on_refresh_rooms_pressed)
	if join_room_button:
		join_room_button.pressed.connect(_on_join_room_pressed)
	if create_room_button:
		create_room_button.pressed.connect(_on_create_room_pressed)
	if leave_room_button:
		leave_room_button.pressed.connect(_on_leave_room_pressed)
	if start_match_button:
		start_match_button.pressed.connect(_on_start_match_pressed)
	if end_game_continue:
		end_game_continue.pressed.connect(_on_end_game_continue_pressed)
	if pause_resume:
		pause_resume.pressed.connect(_on_pause_resume_pressed)
	if pause_back:
		pause_back.pressed.connect(_on_pause_back_pressed)
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
		_show_lobby(true)
		
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
	print("Peer Connectred ... ID: " + str(pid))
	if multiplayer.is_server():
		_ensure_player_state(pid, car_scene_path, [])
		_send_scores_to(pid)
		
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
	# Remove placeholder car
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
		var spawn_parents = level_instance.find_children("SpawnPoints", "Node3D", true, false)
		for sp in spawn_parents:
			for c in sp.get_children():
				if c is Node3D:
					_spawn_points.append(c)
		var grouped = level_instance.get_tree().get_nodes_in_group("SpawnPoint")
		for node in grouped:
			if node is Node3D and not _spawn_points.has(node):
				_spawn_points.append(node)
	if _spawn_points.size() > 1:
		_spawn_points.shuffle()

func _get_next_spawn_position() -> Vector3:
	if _spawn_points.size() == 0:
		return Vector3(0, 2, 0)
	var n: Node3D = _spawn_points[_next_spawn_index % _spawn_points.size()]
	_next_spawn_index += 1
	return n.global_transform.origin

func _choose_spawn_position(exclude_pid: String = "") -> Vector3:
	if _spawn_points.size() == 0:
		return Vector3(0, 2, 0)
	var best_pos = _spawn_points[0].global_transform.origin
	var best_score := -INF
	for sp in _spawn_points:
		var pos = sp.global_transform.origin
		var min_dist := INF
		if car_controller:
			for child in car_controller.get_children():
				if exclude_pid != "" and child.name == exclude_pid:
					continue
				if child is Node3D:
					var d = pos.distance_to(child.global_transform.origin)
					min_dist = min(min_dist, d)
		if min_dist == INF:
			min_dist = SPAWN_MIN_SEPARATION
		var score = min_dist
		if score > best_score:
			best_score = score
			best_pos = pos
	return best_pos

func _choose_spawn_position_reserved(exclude_pid: String, reserved_positions: Array) -> Vector3:
	if _spawn_points.size() == 0:
		return Vector3(0, 2, 0)
	var best_pos = _spawn_points[0].global_transform.origin
	var best_score := -INF
	for sp in _spawn_points:
		var pos = sp.global_transform.origin
		var min_dist := INF
		for reserved in reserved_positions:
			if reserved is Vector3:
				min_dist = min(min_dist, pos.distance_to(reserved))
		if car_controller:
			for child in car_controller.get_children():
				if exclude_pid != "" and child.name == exclude_pid:
					continue
				if child is Node3D:
					var d = pos.distance_to(child.global_transform.origin)
					min_dist = min(min_dist, d)
		if min_dist == INF:
			min_dist = SPAWN_MIN_SEPARATION
		var score = min_dist
		if score > best_score:
			best_score = score
			best_pos = pos
	return best_pos

func _choose_unique_spawn(reserved_positions: Array) -> Vector3:
	if _spawn_points.size() == 0:
		return Vector3(0, 2, 0)
	var candidates: Array = []
	for sp in _spawn_points:
		candidates.append(sp)
	# Prefer positions not already reserved
	for sp in candidates:
		var pos = sp.global_transform.origin
		var clash := false
		for reserved in reserved_positions:
			if reserved is Vector3 and pos.distance_to(reserved) < 0.1:
				clash = true
				break
		if not clash:
			return pos
	# Fallback to farthest from reserved
	return _choose_spawn_position_reserved("", reserved_positions)

func _min_distance_to_other_cars(pos: Vector3, exclude_pid: String = "") -> float:
	var min_dist := INF
	if car_controller:
		for child in car_controller.get_children():
			if exclude_pid != "" and child.name == exclude_pid:
				continue
			if child is Node3D:
				min_dist = min(min_dist, pos.distance_to(child.global_transform.origin))
	if min_dist == INF:
		min_dist = SPAWN_MIN_SEPARATION
	return min_dist

func _resolve_spawn_overlap(car_node: Node, exclude_pid: String = "") -> void:
	if car_node == null:
		return
	var clearance = _get_car_clearance(car_node) + SPAWN_BONUS_CLEARANCE
	for _i in range(SPAWN_RETRY_COUNT):
		var candidate = _choose_spawn_position(exclude_pid)
		var safe = _adjust_spawn_position(candidate, [car_node], clearance)
		if _min_distance_to_other_cars(safe, exclude_pid) >= SPAWN_MIN_SEPARATION:
			car_node.global_transform = Transform3D(Basis.IDENTITY, safe)
			return
	# Fallback to farthest even if too close
	var fallback = _adjust_spawn_position(_choose_spawn_position(exclude_pid), [car_node], clearance)
	car_node.global_transform = Transform3D(Basis.IDENTITY, fallback)


func _adjust_spawn_position(spawn_pos: Vector3, exclude: Array = [], clearance: float = RESPAWN_CLEARANCE) -> Vector3:
	if not _vec_ok(spawn_pos):
		return Vector3(0, 2, 0)
	var world = get_world_3d()
	if world == null:
		return spawn_pos + Vector3.UP * clearance
	var space_state = world.direct_space_state
	var from = spawn_pos + Vector3.UP * RESPAWN_RAY_HEIGHT
	var to = spawn_pos - Vector3.UP * RESPAWN_RAY_DEPTH
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = exclude
	query.collide_with_areas = false
	var hit = space_state.intersect_ray(query)
	if hit and hit.has("position"):
		var pos = hit["position"] + Vector3.UP * clearance
		return pos if _vec_ok(pos) else spawn_pos + Vector3.UP * clearance
	var fallback = spawn_pos + Vector3.UP * clearance
	return fallback if _vec_ok(fallback) else Vector3(0, 2, 0)

func _get_car_clearance(car_node: Node) -> float:
	var clearance := RESPAWN_CLEARANCE
	if car_node:
		var shapes = car_node.find_children("", "CollisionShape3D", true, false)
		var max_extent := 0.0
		for s in shapes:
			if s is CollisionShape3D and s.shape:
				var shape = s.shape
				var extent := 0.0
				if shape is BoxShape3D:
					extent = shape.size.y * 0.5
				elif shape is CapsuleShape3D:
					extent = shape.height * 0.5 + shape.radius
				elif shape is SphereShape3D:
					extent = shape.radius
				elif shape is CylinderShape3D:
					extent = shape.height * 0.5 + shape.radius
				max_extent = max(max_extent, extent)
		if max_extent > 0.0:
			clearance = max(clearance, max_extent + 0.75)
	return clearance


@rpc("any_peer", "reliable")
func spawn_player(pid: int, car_scene_path, mods, spawn_pos: Vector3 = Vector3(INF, INF, INF)) -> void:
	if level_instance == null:
		add_level()
	if car_controller == null and level_instance:
		car_controller = level_instance.get_node_or_null("VehicleController")
	add_player(pid, car_scene_path, mods, spawn_pos)
# must always be called after add_level has been called once!
func add_player(pid: int, car_scene_path, mods, spawn_pos: Vector3 = Vector3(INF, INF, INF)) -> void:
	# Check if the player with the same pid already exists in the level
	if level_instance:
		for child in level_instance.get_node("VehicleController").get_children():
			if child.name == str(pid):
				print("Player with ID " + str(pid) + " already exists.")
				return
	if multiplayer.is_server():
		_ensure_player_state(pid, car_scene_path, mods)
		# Broadcast initial score for this player
		var score = game_state.get_score(str(pid))
		for peer_id in multiplayer.get_peers():
			rpc_id(peer_id, "sync_score", str(pid), score["kills"], score["deaths"])
		_send_stats_to(str(pid))
		_send_stats_to(str(pid))
	# add the car
	var car_res = load(car_scene_path) # load resource without clobbering global 'car'
	var car_instance = car_res.instantiate()
	car_instance.set_multiplayer_authority(pid)
	car_instance.name = str(pid)
	# Cache default collision layers for respawn restores
	car_instance.set_meta("_orig_layer", car_instance.collision_layer)
	car_instance.set_meta("_orig_mask", car_instance.collision_mask)
	# Spawn safely to avoid impulse on load
	car_instance.collision_layer = 0
	car_instance.collision_mask = 0
	car_instance.freeze = true
	if car_instance.has_method("set_sleeping"):
		car_instance.set_sleeping(true)
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
		car_instance.set_meta("_input_lock_until", Time.get_ticks_msec() + SPAWN_INPUT_LOCK_MS)
		car_instance.set_meta("_oob_guard_until", Time.get_ticks_msec() + OOB_GUARD_MS)
	_apply_respawn_guard(car_instance)
			
	var clearance = _get_car_clearance(car_instance) + SPAWN_BONUS_CLEARANCE
	var spawn = spawn_pos
	if not spawn.is_finite():
		spawn = _choose_spawn_position(str(pid))
	spawn = _adjust_spawn_position(spawn, [car_instance], clearance)
	car_instance.global_transform = Transform3D(Basis.IDENTITY, spawn)
	car_instance.linear_velocity = Vector3.ZERO
	car_instance.angular_velocity = Vector3.ZERO
	_defer_spawn_enable(car_instance)
	print("Player with ID " + str(pid) + " added to the game.")

func _ensure_player_state(pid: int, car_scene_path, mods) -> void:
	var pid_str := str(pid)
	if not game_state.players.has(pid_str):
		game_state.add_player(pid_str, MAX_HEALTH, 100, car_scene_path)
	else:
		game_state.players[pid_str]["scene"] = car_scene_path
	if not game_state.players[pid_str].has("shield"):
		game_state.players[pid_str]["shield"] = 0
	if typeof(mods) == TYPE_ARRAY:
		for m in mods:
			if not game_state.players[pid_str]["mods"].has(m):
				game_state.add_mod(pid_str, m)
	elif typeof(mods) == TYPE_STRING and mods != "":
		if not game_state.players[pid_str]["mods"].has(mods):
			game_state.add_mod(pid_str, mods)

# RPC function to spawn players across all clients



# Sync player transform
@rpc("any_peer", "unreliable")
func update_player_transform(pid: int, new_transform: Transform3D) -> void:
	var player = car_controller.get_node_or_null(str(pid))
	if player and pid != multiplayer.get_unique_id():
		if player.has_meta("_guard_lock_until"):
			var lock_until = int(player.get_meta("_guard_lock_until"))
			if Time.get_ticks_msec() < lock_until:
				return
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
			if vehicle_rigid_body.has_meta("_guard_lock_until"):
				var lock_until = int(vehicle_rigid_body.get_meta("_guard_lock_until"))
				if Time.get_ticks_msec() < lock_until:
					vehicle_rigid_body.linear_velocity = Vector3.ZERO
					vehicle_rigid_body.angular_velocity = Vector3.ZERO
					if GUARD_POSITION_LOCK and vehicle_rigid_body.has_meta("_guard_transform"):
						var lock_xform = vehicle_rigid_body.get_meta("_guard_transform")
						if lock_xform is Transform3D:
							vehicle_rigid_body.global_transform = lock_xform
					return
			# Apply respawn guard to prevent launch/NaNs
			if vehicle_rigid_body.has_meta("_respawn_guard_until"):
				var until = int(vehicle_rigid_body.get_meta("_respawn_guard_until"))
				if Time.get_ticks_msec() < until:
					vehicle_rigid_body.linear_velocity = Vector3.ZERO
					vehicle_rigid_body.angular_velocity = Vector3.ZERO
					if GUARD_POSITION_LOCK and vehicle_rigid_body.has_meta("_guard_transform"):
						var guard_xform = vehicle_rigid_body.get_meta("_guard_transform")
						if guard_xform is Transform3D:
							vehicle_rigid_body.global_transform = guard_xform
					return
				else:
					vehicle_rigid_body.set_meta("_respawn_guard_until", null)
					if vehicle_rigid_body.has_meta("_orig_gravity_scale"):
						vehicle_rigid_body.gravity_scale = float(vehicle_rigid_body.get_meta("_orig_gravity_scale"))
						vehicle_rigid_body.set_meta("_orig_gravity_scale", null)
					if vehicle_rigid_body.has_meta("_orig_linear_damp"):
						vehicle_rigid_body.linear_damp = float(vehicle_rigid_body.get_meta("_orig_linear_damp"))
						vehicle_rigid_body.set_meta("_orig_linear_damp", null)
					if vehicle_rigid_body.has_meta("_orig_angular_damp"):
						vehicle_rigid_body.angular_damp = float(vehicle_rigid_body.get_meta("_orig_angular_damp"))
						vehicle_rigid_body.set_meta("_orig_angular_damp", null)
			if vehicle_rigid_body.freeze:
				return
			if vehicle_rigid_body.has_meta("_oob_guard_until"):
				var oob_until = int(vehicle_rigid_body.get_meta("_oob_guard_until"))
				if Time.get_ticks_msec() < oob_until:
					return
				else:
					vehicle_rigid_body.set_meta("_oob_guard_until", null)
			# Out-of-bounds soft respawn
			if _is_out_of_bounds(vehicle_rigid_body.global_transform.origin):
				_request_soft_respawn()
				return
			# Clamp extreme vertical velocity
			if absf(vehicle_rigid_body.linear_velocity.y) > MAX_VERTICAL_SPEED:
				var lv = vehicle_rigid_body.linear_velocity
				lv.y = clampf(lv.y, -MAX_VERTICAL_SPEED, MAX_VERTICAL_SPEED)
				vehicle_rigid_body.linear_velocity = lv
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

func add_shield_pickup(amount: int, pickup_path := NodePath()) -> void:
	if multiplayer.is_server():
		_apply_shield(multiplayer.get_unique_id(), amount, pickup_path)
	else:
		rpc_id(1, "request_shield", amount, pickup_path)

@rpc("any_peer", "reliable")
func request_shield(amount: int, pickup_path := NodePath()) -> void:
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	_apply_shield(sender_id, amount, pickup_path)

func _apply_shield(pid: int, amount: int, pickup_path := NodePath()) -> void:
	var pid_str := str(pid)
	var st = game_state.get_player(pid_str)
	if typeof(st) != TYPE_DICTIONARY:
		return
	var shield = int(st.get("shield", 0))
	shield = clampi(shield + amount, 0, MAX_SHIELD)
	game_state.update_player_stats(pid_str, int(st.get("health", MAX_HEALTH)), int(st.get("defense", 100)), shield)
	_send_stats_to(pid_str)
	# Remove pickup across all peers if a path was provided
	if String(pickup_path) != "":
		var node := get_node_or_null(pickup_path)
		var scene_path := ""
		var parent_path := NodePath()
		var xform := Transform3D()
		if node:
			scene_path = node.scene_file_path
			if node.get_parent():
				parent_path = node.get_parent().get_path()
			xform = node.global_transform
		rpc("remove_pickup", pickup_path)
		if node:
			node.queue_free()
		if scene_path != "" and String(parent_path) != "":
			_schedule_pickup_respawn(scene_path, parent_path, xform)

func _schedule_pickup_respawn(scene_path: String, parent_path: NodePath, xform: Transform3D) -> void:
	await get_tree().create_timer(SHIELD_RESPAWN_TIME).timeout
	_respawn_pickup(scene_path, parent_path, xform)

func _respawn_pickup(scene_path: String, parent_path: NodePath, xform: Transform3D) -> void:
	_spawn_pickup_local(scene_path, parent_path, xform)
	for peer_id in multiplayer.get_peers():
		rpc_id(peer_id, "spawn_pickup", scene_path, parent_path, xform)

func _spawn_pickup_local(scene_path: String, parent_path: NodePath, xform: Transform3D) -> void:
	var parent = get_node_or_null(parent_path)
	if parent == null:
		return
	var scene = load(scene_path)
	if scene == null:
		return
	var inst = scene.instantiate()
	parent.add_child(inst)
	inst.global_transform = xform

@rpc("any_peer", "reliable")
func spawn_pickup(scene_path: String, parent_path: NodePath, xform: Transform3D) -> void:
	_spawn_pickup_local(scene_path, parent_path, xform)
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
		if not car_node.has_meta("_orig_layer"):
			car_node.set_meta("_orig_layer", car_node.collision_layer)
		if not car_node.has_meta("_orig_mask"):
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
			game_state.update_player_stats(player_name, MAX_HEALTH, int(st["defense"]), 0)
			if game_state.players.has(player_name):
				game_state.players[player_name]["shield"] = 0
			_send_stats_to(player_name)
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
	_do_respawn(pid, car_scene_path, spawn_pos, true)

@rpc("any_peer", "reliable")
func soft_respawn_player(pid: String, car_scene_path: String, spawn_pos: Vector3) -> void:
	_do_respawn(pid, car_scene_path, spawn_pos, false)

func _do_respawn(pid: String, car_scene_path: String, spawn_pos: Vector3, reset_stats: bool) -> void:
	# Prefer reusing existing node to avoid queue_free/name races
	var car_node: Node = null
	if car_controller:
		car_node = car_controller.get_node_or_null(pid)
	if car_node == null:
		var scene = load(car_scene_path)
		if scene:
			car_node = scene.instantiate()
			car_node.name = pid
			# Cache default collision layers for respawn restores
			car_node.set_meta("_orig_layer", car_node.collision_layer)
			car_node.set_meta("_orig_mask", car_node.collision_mask)
			car_controller.add_child(car_node)
	if car_node:
		var pid_int = int(pid)
		if car_node.has_method("set_multiplayer_authority"):
			car_node.set_multiplayer_authority(pid_int)
		# Temporarily disable collisions and freeze while repositioning
		car_node.collision_layer = 0
		car_node.collision_mask = 0
		car_node.freeze = true
		if car_node.has_method("set_sleeping"):
			car_node.set_sleeping(true)
		var clearance = _get_car_clearance(car_node) + RESPAWN_BONUS_CLEARANCE
		var safe_spawn = _adjust_spawn_position(spawn_pos, [car_node], clearance)
		car_node.global_transform = Transform3D(Basis.IDENTITY, safe_spawn)
		# Clear KO state and motion
		car_node.set_meta("dead", false)
		car_node.linear_velocity = Vector3.ZERO
		car_node.angular_velocity = Vector3.ZERO
		_apply_respawn_guard(car_node)
		car_node.show()
		_defer_respawn_enable(car_node)
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
			car_node.set_meta("_input_lock_until", Time.get_ticks_msec() + SPAWN_INPUT_LOCK_MS)
			car_node.set_meta("_oob_guard_until", Time.get_ticks_msec() + OOB_GUARD_MS)
	# Server authoritative state reset for respawn_player path
	if multiplayer.is_server() and reset_stats:
		var st = game_state.get_player(pid)
		if typeof(st) == TYPE_DICTIONARY:
			game_state.update_player_stats(pid, MAX_HEALTH, int(st.get("defense", 100)), 0)
			if game_state.players.has(pid):
				game_state.players[pid]["shield"] = 0
			_send_stats_to(pid)
	
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
	if typeof(player) != TYPE_DICTIONARY or not player.has("health"):
		return
	var shield = int(player.get("shield", 0))
	var remaining_damage = HIT_DAMAGE
	if shield > 0:
		var absorbed = min(shield, HIT_DAMAGE)
		shield -= absorbed
		remaining_damage -= absorbed
	player.health = int(player.health) - remaining_damage
	# Update the victim, not the shooter
	game_state.update_player_stats(hit_body_name, int(player.health), int(player.defense), shield)
	_send_stats_to(hit_body_name)
	if int(player.health) <= 0:
		# Update scores on server
		if multiplayer.is_server():
			game_state.add_death(hit_body_name)
			if pid != null:
				game_state.add_kill(str(pid))
			var victim_score = game_state.get_score(hit_body_name)
			for peer_id in multiplayer.get_peers():
				rpc_id(peer_id, "sync_score", hit_body_name, victim_score["kills"], victim_score["deaths"])
			if pid != null:
				var killer_score = game_state.get_score(str(pid))
				for peer_id in multiplayer.get_peers():
					rpc_id(peer_id, "sync_score", str(pid), killer_score["kills"], killer_score["deaths"])
			var room_id = _get_room_id_for_player(hit_body_name)
			var room = _get_room(room_id)
			var kill_limit = int(room.get("kill_limit", 0))
			if room_id != "" and room.get("status", "lobby") == "in_game" and pid != null and kill_limit > 0:
				var ks = game_state.get_score(str(pid))
				if int(ks["kills"]) >= kill_limit:
					_end_match(room_id, str(pid))
					return
		# Run on server immediately, then notify clients only
		player_dead(pid, hit_body_name)
		for peer_id in multiplayer.get_peers():
			rpc_id(peer_id, "player_dead", pid, hit_body_name)
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
			var room_id = _get_room_id_for_player(hit_body_name)
			var room = _get_room(room_id)
			if room_id == "" or room.get("status", "lobby") != "in_game":
				return
			# Notify everyone to enter respawn state and show countdown for owner
			rpc("start_respawn", hit_body_name, RESPAWN_TIME)
			# Tell the owning peer to show their countdown UI
			var owner_id := int(str(hit_body_name))
			rpc_id(owner_id, "show_respawn", RESPAWN_TIME)
			# Also apply on the server
			start_respawn(hit_body_name, RESPAWN_TIME)
			await get_tree().create_timer(RESPAWN_TIME).timeout
			var spawn := _choose_spawn_position(hit_body_name)
			var st = game_state.get_player(hit_body_name)
			var scene_path = st["scene"] if typeof(st) == TYPE_DICTIONARY and st.has("scene") else car.resource_path
			# Ask the owner to hide UI; send fresh car to all peers
			rpc_id(owner_id, "hide_respawn_ui")
			rpc("respawn_player", hit_body_name, scene_path, spawn)
			respawn_player(hit_body_name, scene_path, spawn)
	
func set_car_scene(scene):
	car_scene = scene
	car = load(scene)
	
func _on_connected_to_server() -> void:
	print("Connected to server!")
	if start:
		start.hide()
	_show_lobby(true)
	# Inform server about our selected car and receive state
	if car_scene == null or car_scene == "":
		car_scene = car.resource_path
	rpc_id(1, "set_peer_data", multiplayer.get_unique_id(), car_scene)
	rpc_id(1, "list_rooms")

func _on_connection_failed() -> void:
	print("Connection failed!")
	multiplayer.multiplayer_peer = null
	if start:
		start.show()
	_show_lobby(false)

func _on_server_disconnected() -> void:
	print("Server disconnected!")
	multiplayer.multiplayer_peer = null
	if start:
		start.show()
	_show_lobby(false)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if in_match:
			_show_pause_menu(not (pause_menu and pause_menu.visible))
			get_viewport().set_input_as_handled()

func _on_peer_disconnected(peer_id: int) -> void:
	if multiplayer.is_server():
		_remove_from_room(peer_id, true)
		_despawn_player(str(peer_id))
		player_room.erase(str(peer_id))
		if game_state.players.has(str(peer_id)):
			game_state.remove_player(str(peer_id))

func _show_lobby(visible: bool) -> void:
	if lobby:
		lobby.visible = visible
	if end_game and visible:
		end_game.visible = false
	if pause_menu and visible:
		pause_menu.visible = false
	if visible:
		_set_lobby_status("Connected")
	else:
		_set_lobby_status("")

func _show_end_game(visible: bool) -> void:
	if end_game:
		end_game.visible = visible
	if visible:
		_show_lobby(false)

func _show_pause_menu(visible: bool) -> void:
	if pause_menu:
		pause_menu.visible = visible
	if visible:
		_show_lobby(false)
		if end_game:
			end_game.visible = false

func _reset_level() -> void:
	if level_instance:
		level_instance.queue_free()
	level_instance = null
	car_controller = null
	vehicle_rigid_body = null
	_spawn_points.clear()
	_next_spawn_index = 0


func _set_lobby_status(text: String) -> void:
	if lobby_status_label:
		lobby_status_label.text = text

func _ensure_level_loaded() -> void:
	if level_instance == null:
		add_level()

func _despawn_player(pid: String) -> void:
	if car_controller:
		var car_node = car_controller.get_node_or_null(pid)
		if car_node:
			car_node.queue_free()
	if str(multiplayer.get_unique_id()) == pid:
		vehicle_rigid_body = null
		if level_instance:
			if level_instance.has_node("VehicleController"):
				var vc = level_instance.get_node("VehicleController")
				vc.vehicle_node = null
			if level_instance.has_node("GUI"):
				var gui_node = level_instance.get_node("GUI")
				gui_node.vehicle = null
			if level_instance.has_node("Camera3D"):
				var cam = level_instance.get_node("Camera3D")
				cam.follow_this = null

func _get_room_id_for_player(pid: String) -> String:
	if player_room.has(pid):
		return str(player_room[pid])
	return ""

func _get_room(room_id: String) -> Dictionary:
	if rooms.has(room_id):
		return rooms[room_id]
	return {}

func _build_room_summary(room: Dictionary) -> Dictionary:
	return {
		"id": room.get("id", ""),
		"name": room.get("name", "Room"),
		"players": room.get("players", []).size(),
		"max_players": room.get("max_players", 0),
		"status": room.get("status", "lobby"),
		"kill_limit": room.get("kill_limit", 0)
	}

func _broadcast_rooms_list() -> void:
	if not multiplayer.is_server():
		return
	var list: Array = []
	for room_id in rooms.keys():
		var room = rooms[room_id]
		if room.get("status", "lobby") == "lobby":
			list.append(_build_room_summary(room))
	for peer_id in multiplayer.get_peers():
		rpc_id(peer_id, "rooms_list", list)

func _update_room_ui(room_data: Dictionary) -> void:
	if room_title_label:
		room_title_label.text = room_data.get("name", "Room")
	if room_info_label:
		room_info_label.text = "Players: %s/%s  Kill Limit: %s  Status: %s" % [
			str(room_data.get("players", []).size()),
			str(room_data.get("max_players", 0)),
			str(room_data.get("kill_limit", 0)),
			str(room_data.get("status", "lobby"))
		]
	if room_players_list:
		room_players_list.clear()
		for p in room_data.get("players", []):
			room_players_list.add_item(str(p))
	if start_match_button:
		var is_leader = str(room_data.get("leader", "")) == str(multiplayer.get_unique_id())
		var in_lobby = str(room_data.get("status", "lobby")) == "lobby"
		start_match_button.disabled = not (is_leader and in_lobby)

func _remove_from_room(peer_id: int, notify_peer: bool) -> void:
	var pid = str(peer_id)
	if not player_room.has(pid):
		return
	var room_id = str(player_room[pid])
	player_room.erase(pid)
	if not rooms.has(room_id):
		return
	var room = rooms[room_id]
	room["players"].erase(pid)
	if room.get("status", "lobby") == "in_game":
		_cleanup_room(room_id, "", "player_left")
		return
	if room["players"].is_empty():
		rooms.erase(room_id)
		_broadcast_rooms_list()
		return
	# Reassign leader if needed
	if str(room.get("leader", "")) == pid:
		room["leader"] = room["players"][0]
	rooms[room_id] = room
	_broadcast_rooms_list()
	for member_id in room["players"]:
		rpc_id(int(member_id), "room_updated", room)
	if notify_peer:
		rpc_id(int(pid), "room_left")

func _start_match(room_id: String) -> void:
	if not rooms.has(room_id):
		return
	var room = rooms[room_id]
	if room.get("status", "lobby") != "lobby":
		return
	_ensure_level_loaded()
	room["status"] = "in_game"
	rooms[room_id] = room
	var reserved_spawns: Array = []
	var spawn_map := {}
	for pid in room["players"]:
		var spawn = _choose_unique_spawn(reserved_spawns)
		reserved_spawns.append(spawn)
		spawn_map[pid] = spawn
	room["spawn_map"] = spawn_map
	rooms[room_id] = room
	for pid in room["players"]:
		if game_state.players.has(pid):
			game_state.players[pid]["kills"] = 0
			game_state.players[pid]["deaths"] = 0
			game_state.players[pid]["shield"] = 0
			game_state.update_player_stats(pid, MAX_HEALTH, int(game_state.players[pid]["defense"]), 0)
			var score = game_state.get_score(pid)
			for member_id in room["players"]:
				rpc_id(int(member_id), "sync_score", pid, score["kills"], score["deaths"])
			_send_stats_to(pid)
	for member_id in room["players"]:
		rpc_id(int(member_id), "match_started", room_id, int(room.get("kill_limit", 0)))
	for pid in room["players"]:
		var st = game_state.get_player(pid)
		var scene_path = st["scene"] if typeof(st) == TYPE_DICTIONARY and st.has("scene") else car.resource_path
		var mods = st["mods"] if typeof(st) == TYPE_DICTIONARY and st.has("mods") else []
		var spawn = spawn_map.get(pid, _choose_spawn_position(pid))
		# Spawn on server
		_despawn_player(pid)
		add_player(int(pid), scene_path, mods, spawn)
		# Spawn on clients
		for member_id in room["players"]:
			rpc_id(int(member_id), "spawn_player", int(pid), scene_path, mods, spawn)
	for member_id in room["players"]:
		rpc_id(int(member_id), "room_updated", room)
	_broadcast_rooms_list()

func _end_match(room_id: String, winner_id: String) -> void:
	_cleanup_room(room_id, winner_id, "match_ended")

func _cleanup_room(room_id: String, winner_id: String, reason: String) -> void:
	if not rooms.has(room_id):
		return
	var room = rooms[room_id]
	var players: Array = room.get("players", []).duplicate()
	if players.is_empty():
		rooms.erase(room_id)
		_broadcast_rooms_list()
		return
	room["status"] = "lobby"
	room.erase("spawn_map")
	rooms[room_id] = room
	var scores := []
	for pid in players:
		var score = game_state.get_score(pid)
		scores.append({
			"id": pid,
			"kills": int(score.get("kills", 0)),
			"deaths": int(score.get("deaths", 0))
		})
	for pid in players:
		_despawn_player(pid)
		if game_state.players.has(pid):
			game_state.players[pid]["kills"] = 0
			game_state.players[pid]["deaths"] = 0
			game_state.players[pid]["shield"] = 0
		for member_id in players:
			rpc_id(int(member_id), "despawn_player", pid)
	for member_id in players:
		rpc_id(int(member_id), "match_ended", room_id, winner_id, scores)
		rpc_id(int(member_id), "room_updated", room)
	_broadcast_rooms_list()

func _on_refresh_rooms_pressed() -> void:
	if multiplayer.multiplayer_peer:
		rpc_id(1, "list_rooms")

func _on_create_room_pressed() -> void:
	if not multiplayer.multiplayer_peer:
		return
	var name := "Room %s" % str(_next_room_id)
	if room_name_input and room_name_input.text.strip_edges() != "":
		name = room_name_input.text.strip_edges()
	var max_players := int(max_players_input.value) if max_players_input else 8
	var kill_limit := int(kill_limit_input.value) if kill_limit_input else 10
	rpc_id(1, "create_room", name, max_players, kill_limit)

func _on_join_room_pressed() -> void:
	if not multiplayer.multiplayer_peer or not rooms_list_widget:
		return
	var idx = rooms_list_widget.get_selected_items()
	if idx.is_empty():
		_set_lobby_status("Select a room to join")
		return
	var room_id = str(rooms_list_widget.get_item_metadata(idx[0]))
	if room_id == "":
		return
	rpc_id(1, "join_room", room_id)

func _on_leave_room_pressed() -> void:
	if multiplayer.multiplayer_peer:
		rpc_id(1, "leave_room")

func _on_start_match_pressed() -> void:
	if multiplayer.multiplayer_peer and current_room_id != "":
		rpc_id(1, "start_match", current_room_id)

@rpc("any_peer", "reliable")
func list_rooms() -> void:
	if not multiplayer.is_server():
		return
	var list: Array = []
	for room_id in rooms.keys():
		var room = rooms[room_id]
		if room.get("status", "lobby") == "lobby":
			list.append(_build_room_summary(room))
	rpc_id(multiplayer.get_remote_sender_id(), "rooms_list", list)

@rpc("any_peer", "reliable")
func create_room(name: String, max_players: int, kill_limit: int) -> void:
	if not multiplayer.is_server():
		return
	var pid = str(multiplayer.get_remote_sender_id())
	if player_room.has(pid):
		rpc_id(int(pid), "room_error", "Leave your current room first")
		return
	var room_id := str(_next_room_id)
	_next_room_id += 1
	var room = {
		"id": room_id,
		"name": name,
		"max_players": max_players,
		"players": [pid],
		"leader": pid,
		"status": "lobby",
		"kill_limit": kill_limit
	}
	rooms[room_id] = room
	player_room[pid] = room_id
	_broadcast_rooms_list()
	rpc_id(int(pid), "room_joined", room_id, room)

@rpc("any_peer", "reliable")
func join_room(room_id: String) -> void:
	if not multiplayer.is_server():
		return
	var pid = str(multiplayer.get_remote_sender_id())
	if not rooms.has(room_id):
		rpc_id(int(pid), "room_error", "Room not found")
		return
	if player_room.has(pid):
		rpc_id(int(pid), "room_error", "Leave your current room first")
		return
	var room = rooms[room_id]
	if room.get("status", "lobby") != "lobby":
		rpc_id(int(pid), "room_error", "Match already started")
		return
	if room["players"].size() >= int(room.get("max_players", 0)):
		rpc_id(int(pid), "room_error", "Room is full")
		return
	room["players"].append(pid)
	rooms[room_id] = room
	player_room[pid] = room_id
	_broadcast_rooms_list()
	for member_id in room["players"]:
		rpc_id(int(member_id), "room_updated", room)
	rpc_id(int(pid), "room_joined", room_id, room)

@rpc("any_peer", "reliable")
func leave_room() -> void:
	if not multiplayer.is_server():
		return
	var pid = str(multiplayer.get_remote_sender_id())
	_remove_from_room(int(pid), true)

@rpc("any_peer", "reliable")
func start_match(room_id: String) -> void:
	if not multiplayer.is_server():
		return
	var pid = str(multiplayer.get_remote_sender_id())
	if not rooms.has(room_id):
		return
	var room = rooms[room_id]
	if str(room.get("leader", "")) != pid:
		rpc_id(int(pid), "room_error", "Only the leader can start")
		return
	_start_match(room_id)

@rpc("any_peer", "reliable")
func rooms_list(rooms_array: Array) -> void:
	if not rooms_list_widget:
		return
	rooms_list_widget.clear()
	for room in rooms_array:
		var label = "%s (%s/%s) - %s kills" % [
			str(room.get("name", "Room")),
			str(room.get("players", 0)),
			str(room.get("max_players", 0)),
			str(room.get("kill_limit", 0))
		]
		var idx = rooms_list_widget.add_item(label)
		rooms_list_widget.set_item_metadata(idx, room.get("id", ""))

@rpc("any_peer", "reliable")
func room_joined(room_id: String, room_data: Dictionary) -> void:
	current_room_id = room_id
	current_room = room_data
	_update_room_ui(room_data)
	_set_lobby_status("Joined room")

@rpc("any_peer", "reliable")
func room_left() -> void:
	current_room_id = ""
	current_room = {}
	if room_players_list:
		room_players_list.clear()
	if room_title_label:
		room_title_label.text = "Room"
	if room_info_label:
		room_info_label.text = "Waiting..."
	_set_lobby_status("Left room")

@rpc("any_peer", "reliable")
func room_updated(room_data: Dictionary) -> void:
	if current_room_id != str(room_data.get("id", "")):
		return
	current_room = room_data
	_update_room_ui(room_data)

@rpc("any_peer", "reliable")
func room_error(message: String) -> void:
	_set_lobby_status(message)

@rpc("any_peer", "reliable")
func match_started(room_id: String, _kill_limit: int) -> void:
	if current_room_id != room_id:
		return
	in_match = true
	_show_lobby(false)
	_ensure_level_loaded()

@rpc("any_peer", "reliable")
func match_ended(room_id: String, winner_id: String, scores: Array) -> void:
	if current_room_id != room_id:
		return
	in_match = false
	_show_end_game(true)
	if end_game_winner:
		end_game_winner.text = "Winner: %s" % winner_id
	if end_game_scores:
		end_game_scores.clear()
		var sorted_scores = scores.duplicate()
		sorted_scores.sort_custom(func(a, b):
			return int(a.get("kills", 0)) > int(b.get("kills", 0))
		)
		for s in sorted_scores:
			var line = "%s  K:%s  D:%s" % [str(s.get("id", "")), str(s.get("kills", 0)), str(s.get("deaths", 0))]
			end_game_scores.add_item(line)
	_set_lobby_status("Match ended. Winner: %s" % winner_id)

func _on_end_game_continue_pressed() -> void:
	_show_end_game(false)
	_show_lobby(true)
	if multiplayer.multiplayer_peer:
		rpc_id(1, "list_rooms")

func _on_pause_resume_pressed() -> void:
	_show_pause_menu(false)

func _on_pause_back_pressed() -> void:
	_show_pause_menu(false)
	if multiplayer.multiplayer_peer:
		rpc_id(1, "leave_room")
	_show_lobby(true)
	if multiplayer.multiplayer_peer:
		rpc_id(1, "list_rooms")

@rpc("any_peer", "reliable")
func despawn_player(pid: String) -> void:
	_despawn_player(pid)

@rpc("any_peer", "reliable")
func sync_score(player_id: String, kills: int, deaths: int) -> void:
	if level_instance and level_instance.has_node("GUI"):
		if str(multiplayer.get_unique_id()) == str(player_id):
			var gui_node = level_instance.get_node("GUI")
			if gui_node.has_method("set_score"):
				gui_node.set_score(kills, deaths)

@rpc("any_peer", "reliable")
func sync_stats(health: int, max_health: int, shield: int, max_shield: int) -> void:
	if level_instance and level_instance.has_node("GUI"):
		var gui_node = level_instance.get_node("GUI")
		if gui_node.has_method("set_health_shield"):
			gui_node.set_health_shield(health, max_health, shield, max_shield)

func _send_scores_to(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	for player_id in game_state.players.keys():
		var score = game_state.get_score(player_id)
		rpc_id(peer_id, "sync_score", player_id, score["kills"], score["deaths"])

func _send_stats_to(player_id: String) -> void:
	if not multiplayer.is_server():
		return
	var st = game_state.get_player(player_id)
	if typeof(st) != TYPE_DICTIONARY:
		return
	var health = int(st.get("health", MAX_HEALTH))
	var shield = int(st.get("shield", 0))
	rpc_id(int(player_id), "sync_stats", health, MAX_HEALTH, shield, MAX_SHIELD)

func _get_player_scene_path(pid: String) -> String:
	var st = game_state.get_player(pid)
	if typeof(st) == TYPE_DICTIONARY and st.has("scene"):
		return st["scene"]
	return car.resource_path

func _is_out_of_bounds(pos: Vector3) -> bool:
	return pos.y < OOB_Y_THRESHOLD or Vector2(pos.x, pos.z).length() > OOB_DIST_THRESHOLD

func _request_soft_respawn() -> void:
	if not multiplayer.multiplayer_peer:
		return
	if vehicle_rigid_body and vehicle_rigid_body.has_meta("_oob_respawn_until"):
		var until = int(vehicle_rigid_body.get_meta("_oob_respawn_until"))
		if Time.get_ticks_msec() < until:
			return
	if vehicle_rigid_body:
		vehicle_rigid_body.set_meta("_oob_respawn_until", Time.get_ticks_msec() + OOB_RESPAWN_COOLDOWN_MS)
		vehicle_rigid_body.set_meta("_oob_guard_until", Time.get_ticks_msec() + OOB_GUARD_MS)
	rpc_id(1, "request_soft_respawn")

@rpc("any_peer", "reliable")
func request_soft_respawn() -> void:
	if not multiplayer.is_server():
		return
	var pid = str(multiplayer.get_remote_sender_id())
	var room_id = _get_room_id_for_player(pid)
	var room = _get_room(room_id)
	if room_id == "" or room.get("status", "lobby") != "in_game":
		return
	if not room.has("players") or not room["players"].has(pid):
		return
	var spawn := _choose_spawn_position(pid)
	var scene_path = _get_player_scene_path(pid)
	# Respawn on server
	_do_respawn(pid, scene_path, spawn, false)
	# Respawn on clients in the room
	for member_id in room["players"]:
		rpc_id(int(member_id), "soft_respawn_player", pid, scene_path, spawn)

func _restore_collisions(car_node: Node) -> void:
	if car_node.has_meta("_orig_layer"):
		car_node.collision_layer = int(car_node.get_meta("_orig_layer"))
	else:
		car_node.collision_layer = 1
	if car_node.has_meta("_orig_mask"):
		car_node.collision_mask = int(car_node.get_meta("_orig_mask"))
	else:
		car_node.collision_mask = 1

func _defer_respawn_enable(car_node: Node) -> void:
	await get_tree().create_timer(RESPAWN_FREEZE_TIME).timeout
	if is_instance_valid(car_node):
		_restore_collisions(car_node)
		await get_tree().create_timer(GUARD_SETTLE_TIME).timeout
		if is_instance_valid(car_node):
			car_node.freeze = false
			car_node.linear_velocity = Vector3.ZERO
			car_node.angular_velocity = Vector3.ZERO
			if car_node.has_meta("_orig_gravity_scale"):
				car_node.gravity_scale = float(car_node.get_meta("_orig_gravity_scale"))
				car_node.set_meta("_orig_gravity_scale", null)
			if car_node.has_meta("_orig_linear_damp"):
				car_node.linear_damp = float(car_node.get_meta("_orig_linear_damp"))
				car_node.set_meta("_orig_linear_damp", null)
			if car_node.has_meta("_orig_angular_damp"):
				car_node.angular_damp = float(car_node.get_meta("_orig_angular_damp"))
				car_node.set_meta("_orig_angular_damp", null)
			if car_node.has_meta("_orig_custom_integrator"):
				# restore after rays are re-enabled
				car_node.set_meta("_restore_custom_integrator", bool(car_node.get_meta("_orig_custom_integrator")))
				car_node.set_meta("_orig_custom_integrator", null)
			car_node.set_meta("_respawn_guard_until", null)
			car_node.set_meta("_guard_transform", null)
			car_node.set_meta("_guard_lock_until", null)
			_reset_vehicle_inputs(car_node)
			_set_vehicle_processing(car_node, true)
			_set_wheel_rays(car_node, false)
			_defer_enable_rays(car_node)
			if car_node.has_method("set_sleeping"):
				car_node.set_sleeping(false)

func _defer_spawn_enable(car_node: Node) -> void:
	await get_tree().create_timer(SPAWN_FREEZE_TIME).timeout
	if is_instance_valid(car_node):
		_restore_collisions(car_node)
		await get_tree().create_timer(GUARD_SETTLE_TIME).timeout
		if is_instance_valid(car_node):
			car_node.freeze = false
			car_node.linear_velocity = Vector3.ZERO
			car_node.angular_velocity = Vector3.ZERO
			if car_node.has_meta("_orig_gravity_scale"):
				car_node.gravity_scale = float(car_node.get_meta("_orig_gravity_scale"))
				car_node.set_meta("_orig_gravity_scale", null)
			if car_node.has_meta("_orig_linear_damp"):
				car_node.linear_damp = float(car_node.get_meta("_orig_linear_damp"))
				car_node.set_meta("_orig_linear_damp", null)
			if car_node.has_meta("_orig_angular_damp"):
				car_node.angular_damp = float(car_node.get_meta("_orig_angular_damp"))
				car_node.set_meta("_orig_angular_damp", null)
			if car_node.has_meta("_orig_custom_integrator"):
				# restore after rays are re-enabled
				car_node.set_meta("_restore_custom_integrator", bool(car_node.get_meta("_orig_custom_integrator")))
				car_node.set_meta("_orig_custom_integrator", null)
			car_node.set_meta("_respawn_guard_until", null)
			car_node.set_meta("_guard_transform", null)
			car_node.set_meta("_guard_lock_until", null)
			_reset_vehicle_inputs(car_node)
			_set_vehicle_processing(car_node, true)
			_set_wheel_rays(car_node, false)
			_defer_enable_rays(car_node)
			if car_node.has_method("set_sleeping"):
				car_node.set_sleeping(false)

func _apply_respawn_guard(car_node: Node) -> void:
	if car_node and car_node.has_method("get"):
		car_node.set_meta("_orig_gravity_scale", car_node.gravity_scale)
		car_node.gravity_scale = 0.0
		car_node.set_meta("_orig_linear_damp", car_node.linear_damp)
		car_node.set_meta("_orig_angular_damp", car_node.angular_damp)
		car_node.linear_damp = 6.0
		car_node.angular_damp = 6.0
		car_node.set_meta("_orig_custom_integrator", car_node.custom_integrator)
		car_node.custom_integrator = true
		_reset_vehicle_inputs(car_node)
		_set_vehicle_processing(car_node, false)
		car_node.set_meta("_guard_transform", car_node.global_transform)
		car_node.set_meta("_respawn_guard_until", Time.get_ticks_msec() + RESPAWN_GUARD_MS)
		car_node.set_meta("_guard_lock_until", Time.get_ticks_msec() + GUARD_LOCK_TIME_MS)

func _reset_vehicle_inputs(car_node: Node) -> void:
	if car_node and car_node.has_method("set"):
		car_node.set("brake_input", 0.0)
		car_node.set("steering_input", 0.0)
		car_node.set("throttle_input", 0.0)
		car_node.set("handbrake_input", 0.0)
		car_node.set("clutch_input", 0.0)
		car_node.set("current_gear", 0)
		car_node.set("requested_gear", 0)
		if car_node.has_method("reset_state"):
			car_node.reset_state()

func _set_vehicle_processing(car_node: Node, enabled: bool) -> void:
	if not car_node:
		return
	car_node.set_physics_process(enabled)
	var nodes = car_node.find_children("", "Node", true, false)
	for n in nodes:
		n.set_physics_process(enabled)
	_set_wheel_rays(car_node, enabled)

func _set_wheel_rays(car_node: Node, enabled: bool) -> void:
	var rays = car_node.find_children("", "RayCast3D", true, false)
	for r in rays:
		if r is RayCast3D:
			r.enabled = enabled

func _defer_enable_rays(car_node: Node) -> void:
	await get_tree().create_timer(RAY_ENABLE_DELAY).timeout
	if is_instance_valid(car_node):
		_set_wheel_rays(car_node, true)
		if car_node.has_meta("_restore_custom_integrator"):
			car_node.custom_integrator = bool(car_node.get_meta("_restore_custom_integrator"))
			car_node.set_meta("_restore_custom_integrator", null)

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
