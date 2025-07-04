extends CharacterBody3D

@export var move_speed: float = 2.0
@export var attack_range: float = 2.0

@onready var player: CharacterBody3D = get_tree().get_first_node_in_group("Player")
var dead: bool = false


func _physics_process(delta: float) -> void:
	if dead:
		return
	if player == null:
		return
		
	var direction: Vector3 = (player.global_transform.origin - global_transform.origin).normalized()
	var distance_to_player: float = global_transform.origin.distance_to(player.global_transform.origin)

	if distance_to_player > attack_range:
		velocity = direction * move_speed
		move_and_slide()
	else:
		# Attack the player
		velocity = Vector3.ZERO
		move_and_slide()

func kill() -> void:
	dead = true
	velocity = Vector3.ZERO
	# Optionally, you can add a death animation or effect here.
	$AnimatedSprite3D.sprite_frames.set_animation_loop("idle", false) # Stop looping the animation.
	$AnimatedSprite3D.play("idle") # Play a death animation if you have one.
	$CollisionShape3D.disabled = true # Disable collision to prevent further interactions.
	# queue_free() # Remove the enemy from the scene after death.
	# You might want to notify the game manager or player about the enemy's death.
	print("Enemy shot!")

func _animation_finished() -> void:
	# queue_free()
	queue_free()
	print("Animation finished, enemy removed.")
	pass # Replace with function body.
