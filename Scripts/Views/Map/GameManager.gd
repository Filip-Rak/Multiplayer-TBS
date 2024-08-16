extends Node

class_name Game_Manager

# Attributes
# --------------------

# Exported settings
@export var map_root : Node3D

# Other scripts
var turn_manager : Turn_Manager
var highlight_manager : Highlight_Manager
var game_ui

# Map variables
var tile_matrix = []
const tile_group_name : String = "tiles"
var positional_offset_x : int
var positional_offset_z : int
var x_size : int
var z_size : int

# Units
const unit_group_name : String = "units"

# Selections
var mouse_selection
var selected_action
var targets_and_costs : Dictionary

# Pathfinding
var reachable_tiles_and_costs : Dictionary

# Player
@onready var camera = $PlayerCamera
var player_turn : bool = false

# Ready Functions
# --------------------

func _ready():
	# This is the begining of the scene
	print ("Waiting for players")
	
	# Set up signals
	Network.connect("synchronization_complete", on_all_players_loaded)
	
	# Set up the mouse mode manager
	MouseModeManager.set_game_manager(self)
	MouseModeManager.set_camera(camera)
	MouseModeManager.set_mouse_mode(MouseModeManager.MOUSE_MODE.INSPECTION)
	
	# Set up highligt manager
	highlight_manager = Highlight_Manager.new(self)
	add_child(highlight_manager)
	
	# Load the map and get its properties
	# In the future this is where procedural generation would be added
	var map_loader = Map_Loader.new()
	map_loader.load_map(map_root, tile_group_name)
	
	tile_matrix = map_loader.get_tile_matrix()
	x_size = map_loader.get_x_size()
	z_size = map_loader.get_z_size()
	positional_offset_x = map_loader.get_pos_offset_x()
	positional_offset_z = map_loader.get_pos_offset_z()
	
	# Spawn all the action instances
	# This is required to perform PRCs on them
	for action in PlayerUnit.get_all_actions():
		if !action.is_inside_tree():
			action.set_game_manager(self)
			add_child(action)

func _process(_delta : float):
	pass

# External Interaction Functions
# --------------------

# Function for receiving game settings
func set_up(_parameters):
	# Settings for turn manager
	turn_manager = Turn_Manager.new()
	add_child(turn_manager)
	turn_manager.set_up(self)
	
	# Modify the matrix based on the settings
	
	# Acknowledge completion of loading the map
	# Host call the function manually
	if multiplayer.get_unique_id() == 1:
		Network.send_ack(1)
	else:
		Network.rpc_id(1, "send_ack", multiplayer.get_unique_id())

func select_spawnable_tiles():
	# Discard all the previous highlits
	# Order here is very important!
	highlight_manager.clear_mouse_over_highlight() 
	highlight_manager.clear_mass_highlight()
	
	# Save mouse_selection as unit
	var unit : PlayerUnit.unit_type = mouse_selection
	
	# Find all the tiles suitable for spawning
	var good_tiles = []
	for i in x_size:
		for j in z_size:
				if tile_matrix[i][j].get_is_a_spawn():
					if tile_matrix[i][j].get_team_id() == PlayerManager.get_my_team_id():
						if tile_matrix[i][j].get_accesible_to().find(unit) != -1:
							good_tiles.append(tile_matrix[i][j])
	
	# Highlight these tiles
	highlight_manager.mass_highlight_tiles(good_tiles)
	
func try_spawning_a_unit(target_tile : Node3D):
	# Only execute if turn belongs to the player
	if !player_turn: return
	
	# Make sure the selected tile is available for spawning
	if !target_tile.is_in_group(highlight_manager.get_mass_highlight_group_name()): return
	
	# Make sure a unit is selected
	if mouse_selection == null: return
	
	# Spawn the unit itself for all players
	var spawn_path : NodePath = target_tile.get_path()
	var tree : NodePath = self.get_path()
	var player_id : int = multiplayer.get_unique_id()
	
	rpc("spawn_unit", spawn_path, mouse_selection, player_id, tree) 
	
	# Clear all selections after spawning - consider not doing so for 'shift' effect
	highlight_manager.clear_mouse_over_highlight()
	highlight_manager.clear_mass_highlight()
	mouse_selection = null
		
	# Change mouse mode to inspect
	MouseModeManager.set_mouse_mode(MouseModeManager.MOUSE_MODE.INSPECTION)

func select_action(action_arg : Action):
	# Execute only if player unit is selected
	# This is a temporary measure because rn the UI is pernament
	# This should be deleted with introduction of dynamic UI
	# Since this fucntion would never be triggered without said UI element being available
	# And such a button would only be available in a situation when the unit is indeed selected
	if !(mouse_selection is PlayerUnit || mouse_selection is PlayerUnit.unit_type): return
	
	MouseModeManager.set_mouse_mode(MouseModeManager.MOUSE_MODE.ACTION)
	
	# Discard all the previous highlits
	# Order here is very important!
	highlight_manager.clear_mouse_over_highlight() 
	highlight_manager.clear_mass_highlight()
	
	# Save selected action for on click events
	selected_action = action_arg
	
	# Save targets
	targets_and_costs = action_arg.get_available_targets()
	
	# Highlighting and UI changes are handled by Action superclass
	# Through subclasses in order to make them more customizable
	
func execute_action(target):
	# Only execute if turn belongs to the player
	if !player_turn: return
	
	# Make sure mouse selection isnt null and selected target is among available ones
	if !mouse_selection: return
	if targets_and_costs["tiles"].find(target) == -1: return
	
	# Call execution on the action
	selected_action.perform_action(target)

func disable_turn():
	# Disable certain actions
	player_turn = false
	
	# Reset action points for visualization of next turn
	reset_action_points()
	
	if MouseModeManager.current_mouse_mode == MouseModeManager.MOUSE_MODE.ACTION:
		select_action(selected_action)
	
	# Recalculate highlighting on the screen for the next turn
	highlight_manager.redo_highlighting(false)
	
func enable_turn():
	# Disable certain actions
	player_turn = true
	
	if MouseModeManager.current_mouse_mode == MouseModeManager.MOUSE_MODE.ACTION:
		select_action(selected_action)
	
	# Recalculate highlighting on the screen for the next turn
	highlight_manager.redo_highlighting(player_turn)

func reset_action_points():
	var units = PlayerManager.get_units(multiplayer.get_unique_id())
	for unit in units:
		unit.reset_action_points()

# Remote Procedure Calls
# --------------------
@rpc("any_peer", "call_local")
func spawn_unit(target_tile_path : NodePath, unit_to_spawn : PlayerUnit.unit_type, spawning_player: int, parent_node_path : NodePath):
	# Get the tile to spawn in
	var target_tile = get_node(target_tile_path)
	
	# Instantiate the unit and set it's properties
	var spawned_unit = PlayerUnit.get_scene_of_type(unit_to_spawn).instantiate()
	spawned_unit.position = target_tile.position
	spawned_unit.set_player_owner(spawning_player)
	spawned_unit.set_matrix_tile_position(target_tile.get_matrix_position())
	spawned_unit.add_to_group(unit_group_name)
	
	# Update the tile properties
	target_tile.units_in_tile.append(spawned_unit)
	
	# Add the unit to the tree
	var tree = get_node(parent_node_path)
	tree.add_child(spawned_unit)
	
	# Add the unit to list of units of a player
	PlayerManager.add_unit(spawning_player, spawned_unit)
	
	# Recalculate the highlighting for other players
	if !player_turn: highlight_manager.redo_highlighting(player_turn)

# Link Functions
# --------------------
func select_unit_for_spawn(type : PlayerUnit.unit_type):
	mouse_selection = type
	select_spawnable_tiles()
	MouseModeManager.set_mouse_mode(MouseModeManager.MOUSE_MODE.SPAWN)

func on_all_players_loaded():
	print ("All players loaded")
	
	# Start the first turn
	turn_manager.begin_game()

# Setters
# --------------------
func set_mouse_selection(selection):
	mouse_selection = selection

func set_game_ui(reference):
	game_ui = reference

	
# Getters
# --------------------
func get_tile_group_name() -> String:
	return tile_group_name

func get_unit_group_name() -> String:
	return unit_group_name
	
func get_tile_matrix() -> Array:
	return tile_matrix

func get_mouse_selection():
	return mouse_selection
