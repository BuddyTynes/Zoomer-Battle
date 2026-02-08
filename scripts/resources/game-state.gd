extends Resource
class_name GameStateResource
# Dictionary to store players and their stats
var players := {}

# Add a new player to the list
func add_player(player_id: String, health: int, defense: int, car_scene: String) -> void:
	# add more data to gamestate here.
	if not players.has(player_id):
		players[player_id] = {
			"health": health,
			"defense": defense,
			"scene": car_scene,
			"mods": [],
			"shield": 0,
			"kills": 0,
			"deaths": 0
		}
	else:
		print("Player", player_id, "already exists!")

# Update a player's stats
func update_player(player_id: String, health: int, defense: int) -> void:
	if players.has(player_id):
		players[player_id]["health"] = health
		players[player_id]["defense"] = defense
	else:
		print("Player", player_id, "not found!")

func update_player_stats(player_id: String, health: int, defense: int, shield: int) -> void:
	if players.has(player_id):
		players[player_id]["health"] = health
		players[player_id]["defense"] = defense
		players[player_id]["shield"] = shield
	else:
		print("Player", player_id, "not found!")
		

# Add a mod to a player
func add_mod(player_id: String, mod) -> void:
	if players.has(player_id):
		players[player_id]["mods"].append(mod)
	else:
		print("Player", player_id, "not found!")

func add_kill(player_id: String) -> void:
	if players.has(player_id):
		players[player_id]["kills"] += 1
	else:
		print("Player", player_id, "not found!")

func add_death(player_id: String) -> void:
	if players.has(player_id):
		players[player_id]["deaths"] += 1
	else:
		print("Player", player_id, "not found!")

func get_score(player_id: String) -> Dictionary:
	if players.has(player_id):
		return {
			"kills": players[player_id].get("kills", 0),
			"deaths": players[player_id].get("deaths", 0)
		}
	return {
		"kills": 0,
		"deaths": 0
	}

# Remove a player
func remove_player(player_id: String) -> void:
	if players.has(player_id):
		players.erase(player_id)
		print("Player", player_id, "removed.")
	else:
		print("Player", player_id, "not found!")

# Get a player's stats
func get_player(player_id: String) -> Dictionary:
	if players.has(player_id):
		return players[player_id]
	else:
		print("Player", player_id, "not found!")
		return {}

# Reset all players
func reset_players() -> void:
	players.clear()
	print("All players have been reset!")
