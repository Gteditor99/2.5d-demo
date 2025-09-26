extends PanelContainer

const PROPERTY_GROUPS := [
	{
		"name": "Recoil",
		"properties": [
			{"name": "randomness", "label": "Randomness", "min": 0.0, "max": 1.0, "step": 0.01, "tooltip": "Random horizontal/vertical variance applied to each shot."},
			{"name": "recovery_speed", "label": "Recovery Speed", "min": 0.1, "max": 40.0, "step": 0.1, "tooltip": "How quickly the gun returns to neutral after recoil."}
		]
	},
	{
		"name": "Spring",
		"properties": [
			{"name": "positional_stiffness", "label": "Positional Stiffness", "min": 0.0, "max": 500.0, "step": 1.0},
			{"name": "positional_damping", "label": "Positional Damping", "min": 0.0, "max": 100.0, "step": 0.5},
			{"name": "rotational_stiffness", "label": "Rotational Stiffness", "min": 0.0, "max": 500.0, "step": 1.0},
			{"name": "rotational_damping", "label": "Rotational Damping", "min": 0.0, "max": 100.0, "step": 0.5}
		]
	},
	{
		"name": "Kick",
		"properties": [
			{"name": "positional_kick_up", "label": "Kick Up (Pos)", "min": - 5.0, "max": 10.0, "step": 0.05},
			{"name": "positional_kick_back", "label": "Kick Back (Pos)", "min": - 10.0, "max": 10.0, "step": 0.05},
			{"name": "positional_kick_horizontal", "label": "Kick Horizontal (Pos)", "min": - 5.0, "max": 5.0, "step": 0.05},
			{"name": "rotational_kick_up", "label": "Kick Up (Rot)", "min": - 10.0, "max": 10.0, "step": 0.05},
			{"name": "rotational_kick_back", "label": "Kick Back (Rot)", "min": - 10.0, "max": 10.0, "step": 0.05},
			{"name": "rotational_kick_horizontal", "label": "Kick Horizontal (Rot)", "min": - 10.0, "max": 10.0, "step": 0.05}
		]
	},
	{
		"name": "ADS",
		"properties": [
			{"name": "ads_positional_multiplier", "label": "ADS Pos Mult", "min": 0.0, "max": 1.0, "step": 0.01, "tooltip": "Multiplier applied to positional recoil while aiming."},
			{"name": "ads_rotational_multiplier", "label": "ADS Rot Mult", "min": 0.0, "max": 1.0, "step": 0.01, "tooltip": "Multiplier applied to rotational recoil while aiming."}
		]
	}
]

# Dragging functionality
var dragging = false
var drag_start_position = Vector2()

# UI references
@onready var graph_container: GridContainer = $HBoxContainer/GraphContainer
@onready var property_list: VBoxContainer = $HBoxContainer/DataContainer/ScrollContainer/PropertyList
@onready var reset_button: Button = $HBoxContainer/DataContainer/ActionBar/ResetButton
@onready var copy_button: Button = $HBoxContainer/DataContainer/ActionBar/CopyButton

# Data and state
var _recoil_data: RecoilData
var recoil_data: RecoilData:
	set(value):
		if _recoil_data == value:
			return
		_recoil_data = value
		if is_node_ready():
			_capture_baseline_values()
			_refresh_property_values()
			_queue_redraw_all_canvases()
	get:
		return _recoil_data

var _progress: float = 0.0
var _connected_view_model: ViewModelComponent = null
var _positional_recoil_history: Array = []
var _rotational_recoil_history: Array = []

var _property_controls: Dictionary = {}
var _property_config_by_name: Dictionary = {}
var _baseline_values: Dictionary = {}

# Fallback animation variables
var _fallback_animation_enabled: bool = false
var _fallback_animation_time: float = 0.0
var _fallback_animation_duration: float = 2.0 # 2 seconds for full animation

var _connection_timer: Timer

func _ready():
	Debug.log("RecoilDebugMenu: _ready() called")
	_create_graph_canvases()
	_build_property_controls()
	reset_button.pressed.connect(_on_reset_pressed)
	copy_button.pressed.connect(_on_copy_pressed)
	if _recoil_data:
		Debug.log("RecoilDebugMenu: recoil_data exists")
		_capture_baseline_values()
		graph_container.queue_redraw()
		_refresh_property_values()
	else:
		Debug.log("RecoilDebugMenu: no recoil_data set")
	visibility_changed.connect(_on_visibility_changed)
	
	# Timer for connection retries
	_connection_timer = Timer.new()
	_connection_timer.wait_time = 0.1
	_connection_timer.one_shot = false
	_connection_timer.timeout.connect(_try_connect_to_view_model)
	add_child(_connection_timer)
	
	# Initial connection attempt
	_try_connect_to_view_model()
	_connection_timer.start()

func _process(delta):
	# Handle fallback animation when no weapon system is connected
	if _fallback_animation_enabled and not _connected_view_model:
		_fallback_animation_time += delta
		if _fallback_animation_time >= _fallback_animation_duration:
			_fallback_animation_time = 0.0 # Loop the animation
		
		var new_progress = _fallback_animation_time / _fallback_animation_duration
		if new_progress != _progress:
			_progress = new_progress
			Debug.log("RecoilDebugMenu: Fallback animation progress: %.2f" % _progress)
			_queue_redraw_all_canvases()

func _on_visibility_changed():
	if visible:
		_progress = 0.0
		_try_connect_to_view_model()
		
		if not _connected_view_model:
			Debug.log("RecoilDebugMenu: Starting fallback animation")
			_start_fallback_animation()
		else:
			Debug.log("RecoilDebugMenu: Connected to view model: " + str(_connected_view_model))
		
		_queue_redraw_all_canvases()

func _try_connect_to_view_model():
	# Disconnect from previous view model if exists
	if _connected_view_model:
		if _connected_view_model.recoil_started.is_connected(_on_recoil_started):
			_connected_view_model.recoil_started.disconnect(_on_recoil_started)
		if _connected_view_model.recoil_progress_updated.is_connected(_on_recoil_progress_updated):
			_connected_view_model.recoil_progress_updated.disconnect(_on_recoil_progress_updated)
		if _connected_view_model.recoil_history_updated.is_connected(_on_recoil_history_updated):
			_connected_view_model.recoil_history_updated.disconnect(_on_recoil_history_updated)
		_connected_view_model = null
	
	# Find view model component in the scene
	var view_models = get_tree().get_nodes_in_group("view_model")
	if view_models.size() > 0:
		_connected_view_model = view_models[0] as ViewModelComponent
	else:
		# Try to find it by searching for ViewModelComponent nodes
		var all_nodes = get_tree().get_nodes_in_group("player") # Assuming it's part of player
		for node in all_nodes:
			var view_model = _find_view_model_component(node)
			if view_model:
				_connected_view_model = view_model
				break
	
	# Connect to signals if view model found
	if _connected_view_model:
		if _connection_timer.is_stopped() == false:
			_connection_timer.stop()
		_connected_view_model.recoil_started.connect(_on_recoil_started)
		_connected_view_model.recoil_progress_updated.connect(_on_recoil_progress_updated)
		_connected_view_model.recoil_history_updated.connect(_on_recoil_history_updated)
		if _connected_view_model._weapon_data and _connected_view_model._weapon_data.recoil_data:
			recoil_data = _connected_view_model._weapon_data.recoil_data
		else:
			recoil_data = null
		_fallback_animation_enabled = false
		Debug.log("RecoilDebugMenu: Connected to ViewModelComponent")
	else:
		if not _connection_timer.is_stopped():
			Debug.log("RecoilDebugMenu: No ViewModelComponent found, retrying...")
		else:
			Debug.log("RecoilDebugMenu: No ViewModelComponent found, using fallback animation")

func _find_view_model_component(node: Node) -> ViewModelComponent:
	if node is ViewModelComponent:
		return node
	
	for child in node.get_children():
		var result = _find_view_model_component(child)
		if result:
			return result
	
	return null

func _start_fallback_animation():
	_fallback_animation_enabled = true
	_fallback_animation_time = 0.0
	_progress = 0.0
	Debug.log("RecoilDebugMenu: Fallback animation started - enabled: " + str(_fallback_animation_enabled))

func _queue_redraw_all_canvases():
	if graph_container:
		for i in range(graph_container.get_child_count()):
			var canvas = graph_container.get_child(i)
			if canvas:
				canvas.queue_redraw()

func _build_property_controls():
	_property_controls.clear()
	_property_config_by_name.clear()
	for child in property_list.get_children():
		child.queue_free()

	for group in PROPERTY_GROUPS:
		var header = Label.new()
		header.text = str(group.get("name", ""))
		header.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
		header.add_theme_font_size_override("font_size", 16)
		property_list.add_child(header)

		var separator = HSeparator.new()
		separator.modulate = Color(0.6, 0.6, 0.6, 0.6)
		property_list.add_child(separator)

		for property_config in group.get("properties", []):
			var property_name = property_config.get("name", "")
			_property_config_by_name[property_name] = property_config
			var row = HBoxContainer.new()
			row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_theme_constant_override("separation", 6)

			var label = Label.new()
			label.text = property_config.get("label", property_name)
			label.tooltip_text = property_config.get("tooltip", "")
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(label)

			var spin_box = SpinBox.new()
			spin_box.size_flags_horizontal = Control.SIZE_FILL
			spin_box.min_value = property_config.get("min", -INF)
			spin_box.max_value = property_config.get("max", INF)
			spin_box.step = property_config.get("step", 0.1)
			spin_box.allow_lesser = true
			spin_box.allow_greater = true
			spin_box.tooltip_text = property_config.get("tooltip", "")
			spin_box.custom_minimum_size = Vector2(120, 24)
			spin_box.value_changed.connect(func(value, prop_name = property_name): _on_property_value_changed(prop_name, value))

			row.add_child(spin_box)
			property_list.add_child(row)
			_property_controls[property_name] = spin_box

	property_list.add_child(Control.new()) # Spacer to keep scroll padding
	_refresh_property_values()

func _refresh_property_values():
	var has_data = _recoil_data != null
	for property_name in _property_controls.keys():
		var control = _property_controls[property_name]
		if not control:
			continue
		control.editable = has_data
		if has_data:
			var target_value = _recoil_data.get(property_name)
			if target_value == null:
				target_value = 0.0
			control.set_block_signals(true)
			control.value = target_value
			control.set_block_signals(false)

func _on_property_value_changed(property_name: String, value: float):
	if not _recoil_data:
		return
	var current_value = _recoil_data.get(property_name)
	if typeof(current_value) == TYPE_NIL:
		return
	if typeof(current_value) in [TYPE_FLOAT, TYPE_INT] and is_equal_approx(float(current_value), value):
		return
	_recoil_data.set(property_name, value)
	_recoil_data.emit_changed()
	_queue_redraw_all_canvases()

func _capture_baseline_values():
	_baseline_values.clear()
	if not _recoil_data:
		return
	for group in PROPERTY_GROUPS:
		for property_config in group.get("properties", []):
			var property_name = property_config.get("name", "")
			if _recoil_data.get(property_name) != null:
				_baseline_values[property_name] = _recoil_data.get(property_name)

func _on_reset_pressed():
	if not _recoil_data:
		return
	for property_name in _baseline_values.keys():
		var baseline_value = _baseline_values[property_name]
		_recoil_data.set(property_name, baseline_value)
	_recoil_data.emit_changed()
	_refresh_property_values()
	_queue_redraw_all_canvases()

func _on_copy_pressed():
	if not _recoil_data:
		return
	var payload := {}
	for property_name in _property_controls.keys():
		payload[property_name] = _recoil_data.get(property_name)
	var json = JSON.stringify(payload, "\t")
	DisplayServer.clipboard_set(json)
	Debug.log("RecoilDebugMenu: Copied recoil settings to clipboard")

func _on_recoil_started():
	_progress = 0.0
	_fallback_animation_enabled = false
	Debug.log("RecoilDebugMenu: Recoil started signal received")
	_queue_redraw_all_canvases()

func _on_recoil_progress_updated(progress: float):
	_progress = progress
	_fallback_animation_enabled = false
	Debug.log("RecoilDebugMenu: Progress updated to: %.2f" % progress)
	_queue_redraw_all_canvases()

func _on_recoil_history_updated(positional_history: Array, rotational_history: Array):
	_positional_recoil_history = positional_history
	_rotational_recoil_history = rotational_history
	Debug.log("RecoilDebugMenu: History updated - pos entries: %d, rot entries: %d" % [positional_history.size(), rotational_history.size()])
	_queue_redraw_all_canvases()

func _create_graph_canvases():
	Debug.log("RecoilDebugMenu: Creating graph canvases")
	for i in range(6):
		var canvas = Control.new()
		canvas.clip_contents = true
		canvas.custom_minimum_size = Vector2(100, 100)
		canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
		graph_container.add_child(canvas)
		
		# Create a lambda that captures the index correctly
		var draw_func = func(idx = i): _on_single_curve_draw(idx)
		canvas.draw.connect(draw_func)
		
		# Force an initial draw
		canvas.queue_redraw()
	Debug.log("RecoilDebugMenu: Created 6 graph canvases")


func _on_single_curve_draw(index: int):
	var canvas: Control = graph_container.get_child(index)
	if not canvas:
		Debug.log("RecoilDebugMenu: Canvas %d is null" % index)
		return
	if not recoil_data:
		Debug.log("RecoilDebugMenu: No recoil_data for canvas %d" % index)
		return
	
	Debug.log("RecoilDebugMenu: Drawing curve %d with progress: %.2f" % [index, _progress])

	var curve: Curve
	var color: Color
	var label: String

	match index:
		0:
			curve = recoil_data.positional_recoil_curve_x
			color = Color.RED
			label = "Pos X"
		1:
			curve = recoil_data.positional_recoil_curve_y
			color = Color.GREEN
			label = "Pos Y"
		2:
			curve = recoil_data.positional_recoil_curve_z
			color = Color.BLUE
			label = "Pos Z"
		3:
			curve = recoil_data.rotational_recoil_curve_x
			color = Color(0.86, 0.08, 0.23)
			label = "Rot X"
		4:
			curve = recoil_data.rotational_recoil_curve_y
			color = Color.LIME
			label = "Rot Y"
		5:
			curve = recoil_data.rotational_recoil_curve_z
			color = Color(0.25, 0.41, 0.88)
			label = "Rot Z"

	_draw_single_curve(canvas, curve, color, label, true)
	_draw_single_curve(canvas, curve, color, "", false)
	_draw_progress_indicator(canvas)

func _draw_progress_indicator(canvas: Control):
	if not canvas:
		Debug.log("RecoilDebugMenu: Canvas is null in _draw_progress_indicator")
		return
		
	var canvas_size = canvas.size
	Debug.log("RecoilDebugMenu: Drawing progress indicator - progress: %.2f, canvas_size: %v" % [_progress, canvas_size])
	
	# Draw progress line
	var progress_x = _progress * (canvas_size.x - 40) + 20
	canvas.draw_line(
		Vector2(progress_x, 0),
		Vector2(progress_x, canvas_size.y),
		Color.YELLOW,
		2.0
	)
	
	# Draw progress text
	var font = ThemeDB.fallback_font
	var font_size = 12
	var progress_text = "%.1f%%" % (_progress * 100)
	var text_pos = Vector2(progress_x + 5, 15)
	
	# Ensure text doesn't go off screen
	if text_pos.x + 30 > canvas_size.x:
		text_pos.x = progress_x - 35
	
	canvas.draw_string(font, text_pos, progress_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.YELLOW)

func _draw_single_curve(canvas: Control, curve: Curve, color: Color, label: String = "", draw_full: bool = false):
	if not canvas or not curve:
		return

	var canvas_size = canvas.size
	var origin = canvas_size / 2
	var graph_scale = Vector2(canvas_size.x - 40, 40)
	
	# Define the number of samples for drawing the curve
	var num_samples = 100
	
	if curve.get_point_count() < 1:
		return

	# Draw the full curve with a dimmer color
	if draw_full:
		var full_curve_points = PackedVector2Array()
		for i in range(num_samples + 1):
			var t = float(i) / num_samples
			var val = curve.sample(t)
			var view_point = Vector2(t * graph_scale.x, -val * graph_scale.y)
			full_curve_points.append(origin + view_point)
		
		if full_curve_points.size() > 1:
			canvas.draw_polyline(full_curve_points, color * 0.5, 1.0, false)

	# Draw the curve up to the current progress
	var progress_points = PackedVector2Array()
	var num_progress_samples = int(num_samples * _progress)

	for i in range(num_progress_samples + 1):
		var t = float(i) / num_samples
		var val = curve.sample(t)
		var view_point = Vector2(t * graph_scale.x, -val * graph_scale.y)
		progress_points.append(origin + view_point)

	if progress_points.size() > 1:
		canvas.draw_polyline(progress_points, color, 2.0, false)

	# Draw a circle at the current progress point
	if _progress > 0:
		var current_val = curve.sample(_progress)
		var current_pos = origin + Vector2(_progress * graph_scale.x, -current_val * graph_scale.y)
		canvas.draw_circle(current_pos, 4.0, color)

	# Draw label if provided
	if not label.is_empty():
		var font = ThemeDB.fallback_font
		var font_size = 10
		var label_pos = Vector2(5, 5)
		canvas.draw_string(font, label_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.is_pressed():
				dragging = true
				drag_start_position = get_global_mouse_position() - position
			else:
				dragging = false
	
	if event is InputEventMouseMotion and dragging:
		position = get_global_mouse_position() - drag_start_position
