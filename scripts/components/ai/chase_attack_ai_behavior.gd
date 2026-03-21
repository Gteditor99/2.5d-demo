class_name ChaseAttackAIBehavior
extends EnemyAIBehavior

@export var detection_range: float = 12.0
@export var disengage_range: float = 18.0
@export var attack_range: float = 2.5
@export var attack_cooldown: float = 1.25
@export var attack_windup: float = 0.3
@export var stagger_duration: float = 0.35

# Per-instance variation (applied on setup)
@export var variation_amount: float = 0.15

var _cooldown_timer: float = 0.0
var _windup_timer: float = 0.0
var _is_winding_up: bool = false
var _strafe_direction: float = 1.0
var _strafe_change_timer: float = 0.0
var _chase_lateral_offset: float = 0.0
var _chase_offset_timer: float = 0.0

func setup(controller: EnemyAIController) -> void:
	_cooldown_timer = 0.0
	_windup_timer = 0.0
	_is_winding_up = false
	controller.set_state(EnemyAIController.State.IDLE)

	# Per-instance randomization so groups don't move in lockstep
	var v := variation_amount
	detection_range *= randf_range(1.0 - v, 1.0 + v)
	disengage_range *= randf_range(1.0 - v, 1.0 + v)
	attack_cooldown *= randf_range(1.0 - v, 1.0 + v)
	attack_windup *= randf_range(1.0 - v, 1.0 + v)

	_strafe_direction = 1.0 if randf() > 0.5 else -1.0
	_strafe_change_timer = randf_range(1.5, 3.5)
	_chase_lateral_offset = randf_range(-0.3, 0.3)
	_chase_offset_timer = randf_range(2.0, 4.0)

func physics_update(controller: EnemyAIController, delta: float) -> void:
	if controller.state == EnemyAIController.State.DEAD:
		return
	if controller.state == EnemyAIController.State.STAGGER:
		return

	if not controller.has_player():
		controller.stop_movement()
		controller.ensure_state(EnemyAIController.State.IDLE)
		return

	var distance_to_player := controller.distance_to_player()

	match controller.state:
		EnemyAIController.State.IDLE:
			if distance_to_player <= detection_range:
				controller.set_state(EnemyAIController.State.CHASE)

		EnemyAIController.State.CHASE:
			if distance_to_player > disengage_range:
				controller.set_state(EnemyAIController.State.IDLE)
				controller.stop_movement()
				return

			controller.face_player()

			# Lateral offset during chase so enemies don't all converge on the same line
			_chase_offset_timer -= delta
			if _chase_offset_timer <= 0.0:
				_chase_lateral_offset = randf_range(-0.35, 0.35)
				_chase_offset_timer = randf_range(2.0, 4.0)

			if abs(_chase_lateral_offset) > 0.05:
				# Blend forward movement with slight lateral drift
				controller.move_towards_player()
				controller.strafe_around_player(_chase_lateral_offset)
			else:
				controller.move_towards_player()

			if distance_to_player <= attack_range:
				controller.set_state(EnemyAIController.State.ATTACK)
				_cooldown_timer = 0.0
				_is_winding_up = false

		EnemyAIController.State.ATTACK:
			controller.face_player()

			# Strafe around the player instead of standing still
			_strafe_change_timer -= delta
			if _strafe_change_timer <= 0.0:
				_strafe_direction *= -1.0
				_strafe_change_timer = randf_range(1.5, 3.5)
			controller.strafe_around_player(_strafe_direction * 0.5)

			# Attack with windup telegraph
			if _is_winding_up:
				_windup_timer -= delta
				if _windup_timer <= 0.0:
					controller.request_attack()
					_is_winding_up = false
					_cooldown_timer = attack_cooldown
			else:
				_cooldown_timer -= delta
				if _cooldown_timer <= 0.0:
					_is_winding_up = true
					_windup_timer = attack_windup

			if distance_to_player > attack_range * 1.3:
				controller.set_state(EnemyAIController.State.CHASE)
				_is_winding_up = false

		EnemyAIController.State.DEAD:
			controller.stop_movement()

func on_state_changed(controller: EnemyAIController, previous_state: EnemyAIController.State, new_state: EnemyAIController.State) -> void:
	if new_state == EnemyAIController.State.IDLE:
		controller.stop_movement()
		_is_winding_up = false
	elif new_state == EnemyAIController.State.CHASE and previous_state == EnemyAIController.State.ATTACK:
		_cooldown_timer = 0.0
		_is_winding_up = false
	elif new_state == EnemyAIController.State.STAGGER:
		_is_winding_up = false
