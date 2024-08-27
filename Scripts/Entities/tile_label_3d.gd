extends Sprite3D

class_name Tile_Label_3D

# Attributes
# --------------------
@export var _vbox : VBoxContainer
@export var _shared_label : PanelContainer
@export var _viewport : SubViewport
@export var _display_limit : int = 3

# Ready Function
# --------------------
func _ready():
	_vbox.visible = false
	_shared_label.visible = false

# Public Methods
# --------------------
func update_label(units : Array):
	if units.size() > _display_limit:
		_shared_label.visible = true
		_viewport.size = _shared_label.size
		_set_vbox(units)
		_vbox.visible = false
	elif units.size() > 1:
		_set_vbox(units)
		_vbox.visible = true
		_shared_label.visible = false
		_viewport.size = _vbox.size
	else:
		_clear_vbox() 
		_shared_label.visible = false
		_vbox.visible = false
		
	# Make sure to redraw vbox for size updates to take place
	_vbox.queue_redraw()

# Private Methods
# --------------------
func _clear_vbox():
	# Clear the vbox from labels
	# And activate their parents labels
	for label : Unit_Label_Content in _vbox.get_children():
		_vbox.remove_child(label)
		label.owner = null
		label.get_unit().enable_visual_elements(true)

# Not most efficient but simplest 
# with higher chances of working under less predicitable cicumstances
func _set_vbox(units : Array):
	# Clear vbox of labels
	_clear_vbox()
	
	# For every unit
	for unit : Unit in units:
		# Get it's label and ensure it exists
		var label : Unit_Label_Content = unit.get_label_conent()
		if label != null:
			# Disable parent's 3D label
			unit.enable_visual_elements(false)
			
			# Add label to vbox
			label.owner = null
			label.set_sprite_3D(self)
			_vbox.add_child(label)

# Input
func _unhandled_input(_event):
	if Input.is_action_just_pressed("main_interaction"):
		var local_pos = _viewport.get_mouse_position()
		if local_pos != Vector2.ZERO:
			print ("INPUT: %s" % [local_pos])
		
		# Check which node in the VBox was clicked
		var clicked_node = find_node_under_click(local_pos)
		
		if clicked_node:
			print ("CLICKED ON %s" % [clicked_node])

func find_node_under_click(local_pos: Vector2) -> Control:
	# Iterate over all children of VBox to see which one was clicked
	for child in _vbox.get_children():
		if child is Control:
			var rect = child.get_rect()
			if rect.has_point(local_pos):
				return child
	return null

