class_name EnemyAIController
extends Node

signal state_changed(previous_state: State, new_state: State)
signal attack_requested

@export var behavior: EnemyAIBehavior:
        set(value):
                _behavior = value
                _apply_behavior()
        get:
                return _behavior
@export var player_group: StringName = &"Player"

var parent_body: CharacterBody3D
var movement_component: MovementComponent
var player: CharacterBody3D

enum State {IDLE, CHASE, ATTACK, STAGGER, DEAD}
var state: State = State.IDLE
var _behavior: EnemyAIBehavior
var _applied_behavior: EnemyAIBehavior
var _stagger_timer: float = 0.0

func _ready() -> void:
        parent_body = get_parent() as CharacterBody3D
        if not parent_body:
                push_error("EnemyAIController must be a child of a CharacterBody3D node.")
                set_physics_process(false)
                return

        movement_component = parent_body.get_node_or_null("MovementComponent") as MovementComponent
        _ensure_player()

        _apply_behavior()

func _physics_process(delta: float) -> void:
        if state == State.DEAD or not _behavior:
                return

        if state == State.STAGGER:
                _stagger_timer -= delta
                stop_movement()
                if _stagger_timer <= 0.0:
                        set_state(State.CHASE)
                return

        _ensure_player()
        _behavior.physics_update(self, delta)

func set_state(new_state: State) -> void:
        if state == new_state:
                return

        var previous_state: State = state
        state = new_state

        if movement_component and new_state != State.DEAD:
                movement_component.set_physics_process(true)

        state_changed.emit(previous_state, new_state)

        if _behavior:
                _behavior.on_state_changed(self, previous_state, new_state)

func handle_death() -> void:
        set_state(State.DEAD)
        stop_movement()
        set_physics_process(false)
        if movement_component:
                movement_component.set_physics_process(false)

func request_attack() -> void:
        attack_requested.emit()


func set_behavior(new_behavior: EnemyAIBehavior) -> void:
        behavior = new_behavior

func distance_to_player() -> float:
        if not has_player():
                return INF
        return parent_body.global_position.distance_to(player.global_position)

func has_player() -> bool:
        return player and is_instance_valid(player)

func move_towards_player() -> void:
        if not has_player():
                return

        var direction: Vector3 = player.global_position - parent_body.global_position
        var flat_direction := Vector2(direction.x, direction.z)
        if movement_component:
                movement_component.set_input_direction(flat_direction)
        else:
                direction = direction.normalized()
                parent_body.velocity.x = direction.x * parent_body.velocity.length()
                parent_body.velocity.z = direction.z * parent_body.velocity.length()
                parent_body.move_and_slide()

func stop_movement() -> void:
        if movement_component:
                movement_component.set_input_direction(Vector2.ZERO)
        else:
                parent_body.velocity.x = move_toward(parent_body.velocity.x, 0.0, abs(parent_body.velocity.x))
                parent_body.velocity.z = move_toward(parent_body.velocity.z, 0.0, abs(parent_body.velocity.z))

func face_player() -> void:
        if not has_player():
                return

        var target_position: Vector3 = player.global_position
        target_position.y = parent_body.global_position.y
        parent_body.look_at(target_position, Vector3.UP)

func apply_stagger(duration: float = 0.35) -> void:
        if state == State.DEAD:
                return
        _stagger_timer = duration
        set_state(State.STAGGER)
        stop_movement()

func strafe_around_player(strafe_direction: float) -> void:
        if not has_player() or not movement_component:
                return
        var to_player: Vector3 = player.global_position - parent_body.global_position
        var lateral := Vector3(-to_player.z, 0.0, to_player.x).normalized()
        var strafe_vec := lateral * strafe_direction
        var flat := Vector2(strafe_vec.x, strafe_vec.z)
        movement_component.set_input_direction(flat)

func ensure_state(target_state: State) -> void:
        if state != target_state:
                set_state(target_state)

func _ensure_player() -> void:
        if not has_player():
                player = get_tree().get_first_node_in_group(player_group) as CharacterBody3D


func _apply_behavior() -> void:
        if not is_inside_tree():
                return

        if _behavior == _applied_behavior:
                return

        _applied_behavior = _behavior

        if _applied_behavior:
                _applied_behavior.setup(self)
