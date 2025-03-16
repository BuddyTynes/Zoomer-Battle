extends Resource
class_name GameStateResource
# Dictionary to store players and their stats
var players := {}

# Add a new player to the list
func add_player(player_id: String, health: int, defense: int) -> void:
	if not players.has(player_id):
		players[player_id] = {
			"health": health,
			"defense": defense
		}
		print("Player", player_id, "added with Health:", health, "and Defense:", defense)
	else:
		print("Player", player_id, "already exists!")

# Update a player's stats
func update_player(player_id: String, health: int, defense: int) -> void:
	if players.has(player_id):
		players[player_id]["health"] = health
		players[player_id]["defense"] = defense
		print("Player: ", player_id, "updated to Health: ", health, "and Defense: ", defense)
	else:
		print("Player", player_id, "not found!")

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
