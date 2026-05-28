extends Node

# Attributes
# --------------------

# Connection
var peer : ENetMultiplayerPeer
var server_port : int = 8000
var server_address = "127.0.0.1"
const COMPRESSION := ENetConnection.COMPRESS_RANGE_CODER
var has_connection : bool = false

# Ready Functions
# --------------------
func _ready():
	# Server and connected players - side signals
	multiplayer.peer_connected.connect(peer_connected)
	multiplayer.peer_disconnected.connect(peer_disconnected)
	
	# Client - side signals
	multiplayer.connected_to_server.connect(connected_to_server)
	multiplayer.connection_failed.connect(connection_failed)
	multiplayer.server_disconnected.connect(server_disconnected)
	
	# Add custom signals
	add_user_signal("player_data_updated")# Mostly legacy, dont use
	add_user_signal("synchronization_complete")
	add_user_signal("connection_lost")
	
# Multiplayer Signal Functions
func peer_connected(id):
	print("ID: %s connected" % [id])
	
func peer_disconnected(id):
	print("ID: %s disconnected" % [id])
	
	# Host ID is equal to 1
	if StateMachine.get_is_gameplay_in_progress() && id != 1:
		PlayerManager.set_player_connected(id, false)
	else: 
		# Delete disconnected player's information
		PlayerManager.drop_player(id)
	
	if id == 1: 
		print("Host disconnected, connection lost")
		has_connection = false
		emit_signal("connection_lost")
		reset_multiplayer_state()
	else:
		rpc("distribute_player_information")
		emit_signal("player_data_updated")
	
func connected_to_server():
	print("Connection to server succesfull")
	has_connection = true
	# All players have by default unique multiplayer id set to 1
	# After creating the peer move your data to correct spot
	PlayerManager.change_id(1, multiplayer.get_unique_id())
	
	# Send the data to the server
	rpc_id(1, "send_player_information", PlayerManager.get_player(multiplayer.get_unique_id()), multiplayer.get_unique_id())
	
func connection_failed():
	print("Connection to server failed")
	has_connection = false

func server_disconnected():
	print("Lost connection to the server")
	has_connection = false

# Connection Functions
# --------------------
func self_host_server(port : int):
	if port:
		server_port = port
	if setup_multiplayer_peer(true):
		print("Server is active")
		has_connection = true

func join_server(address: String, port: int):
	if port:
		server_port = port
	if address:
		server_address = address
	if !setup_multiplayer_peer(false):
		print ("Connection failure")
		
func setup_multiplayer_peer(is_server: bool):
	peer = ENetMultiplayerPeer.new()
	
	if is_server:
		var error = peer.create_server(server_port)
		if error != OK:
			print("Couldn't create a server: " + str(error))
			return false
	else:
		peer.create_client(server_address, server_port)
		
	peer.get_host().compress(COMPRESSION)
	multiplayer.set_multiplayer_peer(peer)
	return true

func reset_multiplayer_state():
	print("Resetting multiplayer state...")
	
	# How even?
	
	# Disconnect the peer
	# if peer:
		# peer.close_connection()
		
	# Reset the multiplayer peer???
	# multiplayer.multiplayer_peer = null
	
	# Reset player data
	PlayerManager.reset_all_players()

func sync_my_data_fast():
	# Get my data
	var my_data = PlayerManager.get_my_data()
	
	# Call all the players to update their entries about the caller
	rpc("update_player_data_fast", my_data, multiplayer.get_unique_id())

# Remote Procedure Calls
# --------------------
@rpc("any_peer")
func update_player_data_fast(data : Dictionary, caller_id : int):
	# Update the data
	PlayerManager.set_player(caller_id, data)

@rpc("any_peer", "reliable")
func send_ack(sender_id : int):
	PlayerManager.set_ack(sender_id, true)
	
	if PlayerManager.is_ack_all():
		rpc("emit_signal_globbaly", "synchronization_complete")
		PlayerManager.set_ack_all(false)

@rpc("any_peer", "reliable")
func send_player_information(player_data : Dictionary, id : int, last_one : bool = false):
	# Send data to server
	if !PlayerManager.is_player(id):
		PlayerManager.set_player(id, player_data)
		
		# Server sends data to all the clients
		if multiplayer.is_server():
			rpc("distribute_player_information")
	
	# Inform all the hosts that their information is up to date
	if last_one:
		emit_signal("player_data_updated")

@rpc("any_peer", "call_local", "reliable")
func distribute_player_information():
	var players = PlayerManager.get_players()
	var player_keys = players.keys()
	var last_index = player_keys.size() - 1
	
	for index in player_keys.size():
		var player_id = player_keys[index]
		var player_data = players[player_id]
		
		# If this is the last player, set the last_one flag to true
		if index == last_index:
			rpc("send_player_information", player_data, player_id, true)
		else:
			rpc("send_player_information", player_data, player_id)

@rpc("any_peer", "call_local", "reliable")
func emit_signal_globbaly(signal_name : String):
	emit_signal(signal_name)

# Getters
# --------------------
func has_connection_to_server() -> bool:
	return has_connection
