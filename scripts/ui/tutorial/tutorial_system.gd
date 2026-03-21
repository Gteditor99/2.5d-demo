extends CanvasLayer

signal tutorial_completed

@onready var prompt_label: Label = $TutorialPanel/VBox/PromptLabel
@onready var hint_label: Label = $TutorialPanel/VBox/HintLabel
@onready var progress_label: Label = $TutorialPanel/VBox/ProgressLabel
@onready var panel: PanelContainer = $TutorialPanel
@onready var skip_label: Label = $SkipLabel

enum Step {
	WELCOME,
	MOVE,
	LOOK,
	SPRINT,
	CROUCH,
	JUMP,
	SHOOT,
	AIM,
	RELOAD,
	SWITCH_WEAPON,
	PEEK,
	SWITCH_FIRE_MODE,
	COMPLETE
}

var current_step: Step = Step.WELCOME
var _step_timer: float = 0.0
var _step_validated: bool = false
var _completed: bool = false
var _mouse_moved: float = 0.0
var _move_accumulated: float = 0.0

const STEP_DATA = {
	Step.WELCOME: {
		"prompt": "Welcome, Operative",
		"hint": "Let's get you combat-ready. Follow the instructions.",
		"auto_advance": 3.0
	},
	Step.MOVE: {
		"prompt": "MOVE",
		"hint": "Use W A S D to move around",
		"action": "movement"
	},
	Step.LOOK: {
		"prompt": "LOOK AROUND",
		"hint": "Move the mouse to look around",
		"action": "mouse_look"
	},
	Step.SPRINT: {
		"prompt": "SPRINT",
		"hint": "Hold SHIFT while moving to sprint",
		"action": "sprint"
	},
	Step.CROUCH: {
		"prompt": "CROUCH",
		"hint": "Press CTRL to toggle crouch",
		"action": "crouch"
	},
	Step.JUMP: {
		"prompt": "JUMP",
		"hint": "Press SPACE to jump",
		"action": "jump"
	},
	Step.SHOOT: {
		"prompt": "SHOOT",
		"hint": "Press LEFT MOUSE BUTTON to fire your weapon",
		"action": "shoot"
	},
	Step.AIM: {
		"prompt": "AIM DOWN SIGHTS",
		"hint": "Hold RIGHT MOUSE BUTTON to aim",
		"action": "aim"
	},
	Step.RELOAD: {
		"prompt": "RELOAD",
		"hint": "Press R to reload your weapon",
		"action": "reload"
	},
	Step.SWITCH_WEAPON: {
		"prompt": "SWITCH WEAPON",
		"hint": "Press 1 or 2, or use SCROLL WHEEL to switch weapons",
		"action": "switch_weapon"
	},
	Step.PEEK: {
		"prompt": "PEEK",
		"hint": "Hold Q or E to peek left or right around corners",
		"action": "peek"
	},
	Step.SWITCH_FIRE_MODE: {
		"prompt": "FIRE MODE",
		"hint": "Press V to switch between fire modes",
		"action": "switch_fire_mode"
	},
	Step.COMPLETE: {
		"prompt": "Training Complete!",
		"hint": "Enemies incoming. Good luck, Operative.",
		"auto_advance": 3.0
	}
}

func _ready():
	_show_step(Step.WELCOME)

func _input(event: InputEvent):
	if _completed:
		return

	# Skip tutorial
	if event is InputEventKey and event.pressed and event.keycode == KEY_TAB:
		_complete_tutorial()
		return

	if event is InputEventMouseMotion and current_step == Step.LOOK:
		_mouse_moved += event.relative.length()
		if _mouse_moved > 300.0:
			_advance_step()

func _process(delta: float):
	if _completed:
		return

	var data = STEP_DATA.get(current_step, {})

	# Auto-advance steps
	if data.has("auto_advance"):
		_step_timer += delta
		if _step_timer >= data.get("auto_advance"):
			_advance_step()
		return

	# Check action-based steps
	var action = data.get("action", "")
	match action:
		"movement":
			var input = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
			if input.length() > 0.1:
				_move_accumulated += delta
			if _move_accumulated > 1.5:
				_advance_step()
		"sprint":
			if Input.is_action_pressed("sprint"):
				var input = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
				if input.length() > 0.1:
					_move_accumulated += delta
				if _move_accumulated > 1.0:
					_advance_step()
		"crouch":
			if Input.is_action_just_pressed("crouch"):
				_advance_step()
		"jump":
			if Input.is_action_just_pressed("jump"):
				_advance_step()
		"shoot":
			if Input.is_action_just_pressed("shoot"):
				_advance_step()
		"aim":
			if Input.is_action_pressed("aim"):
				_move_accumulated += delta
			if _move_accumulated > 1.0:
				_advance_step()
		"reload":
			if Input.is_action_just_pressed("reload"):
				_advance_step()
		"switch_weapon":
			if Input.is_action_just_pressed("hotbar_1") or Input.is_action_just_pressed("hotbar_2") \
				or Input.is_action_just_pressed("hotbar_next") or Input.is_action_just_pressed("hotbar_prev"):
				_advance_step()
		"peek":
			if Input.is_action_pressed("peek_left") or Input.is_action_pressed("peek_right"):
				_move_accumulated += delta
			if _move_accumulated > 0.5:
				_advance_step()
		"switch_fire_mode":
			if Input.is_action_just_pressed("switch_fire_mode"):
				_advance_step()

func _show_step(step: Step):
	current_step = step
	_step_timer = 0.0
	_step_validated = false
	_move_accumulated = 0.0
	_mouse_moved = 0.0

	var data = STEP_DATA.get(step, {})
	prompt_label.text = data.get("prompt", "")
	hint_label.text = data.get("hint", "")

	var step_index = Step.values().find(step)
	var total = Step.values().size() - 1  # Exclude COMPLETE
	progress_label.text = "%d / %d" % [mini(step_index, total), total]

	# Animate in
	panel.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.3)

func _advance_step():
	var step_values = Step.values()
	var current_index = step_values.find(current_step)

	if current_step == Step.COMPLETE:
		_complete_tutorial()
		return

	if current_index + 1 < step_values.size():
		# Fade out current, then show next
		var tween = create_tween()
		tween.tween_property(panel, "modulate:a", 0.0, 0.2)
		tween.tween_callback(func(): _show_step(step_values[current_index + 1]))

func _complete_tutorial():
	_completed = true
	var tween = create_tween()
	tween.tween_property(panel, "modulate:a", 0.0, 0.5)
	tween.parallel().tween_property(skip_label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func():
		tutorial_completed.emit()
		queue_free()
	)
