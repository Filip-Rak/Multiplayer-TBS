extends Node3D

class_name Tile

# Exported settings
@export var _type : Tile_Properties.tile_type = Tile_Properties.tile_type.DEFAULT
@export var _tile_label : Tile_Label_3D
@export var _point_value : int = 0
@export var _team_id : int = -1
@export var _is_a_spawn : bool = false

# Gamepplay variables
var _matrix_position : Vector3
var _units_in_tile : Array
var _support_calls : Array

# Ready Functions
func _ready():
	if _tile_label:
		_tile_label.update_info_label(_point_value, _team_id)

# Methods
# --------------------
func add_unit_to_tile(unit : Unit):
	# Update Array
	_units_in_tile.append(unit)
	
	# Update the label above tile
	if _tile_label:
		_tile_label.update_label(_units_in_tile)
		_tile_label.update_info_label(_point_value, _team_id)
	else:
		printerr ("ERROR: Tile.gd -> add_unit_to_tile(): _tile_label not set!")

func remove_unit_from_tile(unit : Unit):
	# Update Array
	_units_in_tile.erase(unit)
	
	# Update the label above tile
	if _tile_label:
		_tile_label.update_label(_units_in_tile)
		_tile_label.update_info_label(_point_value, _team_id)
	else:
		printerr ("ERROR: Tile.gd -> remove_unit_from_tile(): _tile_label not set!")
	
func has_enemy():
	for unit in _units_in_tile:
		if PlayerManager.get_team_id(unit.get_player_owner_id()) != PlayerManager.get_my_team_id():
			return true
			
	return false
	
# Setters
# --------------------
func set_matrix_position(pos : Vector3):
	_matrix_position = Vector3(pos.x, 0, pos.z)

# Getters
# --------------------
func get_type() -> Tile_Properties.tile_type:
	return _type

func get_team_id() -> int:
	return _team_id
	
func get_point_value() -> float:
	return _point_value
	
func get_is_a_spawn() -> bool:
	return _is_a_spawn
	
func get_matrix_position() -> Vector3:
	return _matrix_position

func get_units_in_tile() -> Array:
	return _units_in_tile

func get_support_calls() -> Array:
	return _support_calls
