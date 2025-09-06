extends CharacterBody3D

@export var attack_range: float = 2.0

@onready var player: CharacterBody3D = get_tree().get_first_node_in_group("Player")

# --- Components ---
@onready var movement_component: MovementComponent = $MovementComponent
@onready var chase_player_behavior: ChasePlayerBehavior = $ChasePlayerBehavior
@onready var health_component: HealthComponent = $HealthComponent

enum EnemyState {IDLE, CHASE, ATTACK, DEAD}
var current_state: EnemyState = EnemyState.IDLE

func _ready() -> void:
	# Initialize state
	_set_state(EnemyState.CHASE) # Start by chasing for now
	
	# Health component signals
	if health_component:
		health_component.hurt.connect(_on_hurt)
		health_component.no_health.connect(func(): _set_state(EnemyState.DEAD))


func _physics_process(_delta: float) -> void:
	if not player:
		return
		
	var distance_to_player = global_position.distance_to(player.global_position)
	if distance_to_player > attack_range:
		_set_state(EnemyState.CHASE)

	match current_state:
		EnemyState.CHASE:
			if distance_to_player <= attack_range:
				_set_state(EnemyState.ATTACK)
		EnemyState.ATTACK:
			# TODO: Implement attack logic here
			# For example: $AttackTimer.start()
			pass
		EnemyState.IDLE:
			pass # No specific action in idle state for now
		EnemyState.DEAD:
			pass # No action when dead


func _set_state(new_state: EnemyState) -> void:
	if current_state == new_state:
		return

	# Exit current state
	match current_state:
		EnemyState.CHASE:
			if chase_player_behavior:
				chase_player_behavior.set_process(false)
		EnemyState.ATTACK:
			# Stop attack animation/timer if any
			pass
		EnemyState.DEAD:
			pass # Already dead, no exit
		EnemyState.IDLE:
			pass

	current_state = new_state

	# Enter new state
	match current_state:
		EnemyState.CHASE:
			if chase_player_behavior:
				chase_player_behavior.set_process(true)
		EnemyState.ATTACK:
			# Start attack animation/timer
			movement_component.set_input_direction(Vector2.ZERO) # Stop moving when attacking
		EnemyState.DEAD:
			_on_death()
		EnemyState.IDLE:
			movement_component.set_input_direction(Vector2.ZERO) # Stop moving when idle


func _on_hurt() -> void:
	print("Enemy was hurt.")
	# TODO: Add hurt animation, sound, and effects.
	# For example: $AnimatedSprite3D.play("hurt")
	pass


func _on_death() -> void:
	print("Enemy has died.")
	# Stop all movement and processing
	set_physics_process(false)
	if movement_component:
		movement_component.set_process(false)
	if chase_player_behavior:
		chase_player_behavior.set_process(false)
	
	# Play death animation and disable collision
	$AnimatedSprite3D.play("death") # Assuming you have a 'death' animation
	$CollisionShape3D.disabled = true
