extends Node

# Attributes
# --------------------

# Player data
var players : Dictionary = {}

# Player data template
# PLAYER_ID:
# 	'player_name': string
# 	'team_id' : int
# 	"units": Unit Array
# 	"ack": bool flag for synchronization
#	"connected": only used in selected scenes, the player will usually be deleted on disconnected

# Ready Functions
# --------------------
func _ready():
	add_default_player()

func add_default_player():
	add_player(multiplayer.get_unique_id(), "Player", -1, [])

# Functions For External Setup
# --------------------
func add_player(player_id : int, player_name : String, team_id : int, units : Array):
	players[player_id] = {
		"player_name": player_name,
		"team_id": team_id,
		"units": units,
		"ack": false,
		"connected": true
	}

func change_id(previous_id : int, new_id : int): 
	if players.has(new_id):
		# Switch the players
		var buffer : Dictionary = players[new_id]
		players[new_id] = players[previous_id]
		players[previous_id] = buffer
	else:
		# Assign the player to new_id, delete the old one
		players[new_id] = players[previous_id]
		players.erase(previous_id)

func drop_player(player_id : int) -> bool:
	if players.has(player_id):
		players.erase(player_id)
		return true
		
	return false

func reset_all_players():
	players.clear()
	add_default_player()

func add_unit(owner_id : int, unit : Unit):
	players[owner_id]["units"].append(unit)

# Remote Procedure Calls
# --------------------
@rpc("any_peer", "call_local")
func reassign_unit(unit_path : NodePath, giver_id : int, receiver_id : int):
	var unit = get_node(unit_path)
	
	# Reassign in PlayerManager
	players[giver_id]["units"].erase(unit)
	players[receiver_id]["units"].append(unit)
	
	# Reasing in Unit
	unit.set_player_owner(receiver_id)

# Setters
# --------------------
func set_player(id : int, data : Dictionary):
	players[id] = data

func set_player_name(id : int, player_name : String):
	players[id]["player_name"] = player_name

func set_player_team(player_id : int, team_id : int):
	players[player_id]["team_id"] = team_id

func set_ack_all(value : bool):
	for player_id in players:
		players[player_id]["ack"] = value

func set_ack(player_id : int, value : bool):
	players[player_id]["ack"] = value

func set_player_connected(id : int, value : bool):
	players[id]["connected"] = value

# Getters
# --------------------
func is_ack_all() -> bool:
	for player in players:
		if !players[player]["ack"]:
			return false
			
	return true;

func get_players() -> Dictionary:
	return players

func get_player(id : int) -> Dictionary:
	return players[id]

func get_player_name(id : int) -> String:
	return players[id]["player_name"]

func get_my_data() -> Dictionary:
	return get_player(multiplayer.get_unique_id())

func get_team_id(player_id : int) -> int:
	return players[player_id]["team_id"]

func get_my_team_id() -> int:
	return get_team_id(multiplayer.get_unique_id())

func get_units(id : int) -> Array:
	return players[id]["units"]

func is_player(id : int) -> bool:
	return players.has(id)

func get_player_num() -> int:
	return players.size()

func get_player_connected(id : int) -> bool:
	return players[id]["connected"]

func get_teammates_ids(id : int) -> Array:
	var team_id = get_team_id(id)
	var teammates : Array = [] 
	
	for player_id : int in players:
		if players[player_id]["team_id"] == team_id:
			teammates.append(player_id)
			
	return teammates
