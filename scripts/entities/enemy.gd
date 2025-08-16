extends CharacterBody3D

@export var attack_range: float = 2.0

@onready var player: CharacterBody3D = get_tree().get_first_node_in_group("Player")

# --- Components ---
@onready var movement_component: MovementComponent = $MovementComponent
@onready var health_component: HealthComponent = $HealthComponent
@onready var chase_player_behavior: ChasePlayerBehavior = $ChasePlayerBehavior

enum EnemyState {IDLE, CHASE, ATTACK, DEAD}
var current_state: EnemyState = EnemyState.IDLE


func take_damage(amount: int) -> void:
	health_component.take_damage(amount)


func _ready() -> void:
	# Connect to the health component's died signal
	health_component.died.connect(_on_death)
	health_component.health_changed.connect(_on_health_changed)
	
	# Initialize state
	_set_state(EnemyState.CHASE) # Start by chasing for now


func _physics_process(_delta: float) -> void:
	if not player or health_component.current_health <= 0:
		_set_state(EnemyState.DEAD)
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
			chase_player_behavior.set_process(true)
		EnemyState.ATTACK:
			# Start attack animation/timer
			movement_component.set_input_direction(Vector2.ZERO) # Stop moving when attacking
		EnemyState.DEAD:
			_on_death()
		EnemyState.IDLE:
			movement_component.set_input_direction(Vector2.ZERO) # Stop moving when idle


func _on_death() -> void:
	print("Enemy has died.")
	# Stop all movement and processing
	set_physics_process(false)
	movement_component.set_process(false)
	chase_player_behavior.set_process(false)
	
	# Play death animation and disable collision
	$AnimatedSprite3D.play("death") # Assuming you have a 'death' animation
	$CollisionShape3D.disabled = true

func _on_health_changed(new_health: int, max_health: int) -> void:
	# This function can be used to trigger a "hurt" animation or effect
	# when the enemy takes damage but is not yet dead.
	if new_health > 0:
		# Assuming you have a "hurt" animation.
		# If you want to show a single frame of an animation, you can do this:
		# $AnimatedSprite3D.animation = "hurt"
		# $AnimatedSprite3D.frame = 0 
		# $AnimatedSprite3D.stop() # Stop it from playing the full animation
		# If you want to advance the current animation by one frame:
		$AnimatedSprite3D.frame += 1
