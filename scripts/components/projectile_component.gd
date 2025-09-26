class_name ProjectileComponent
extends Node

signal returned_to_pool
signal hit_something(damage)
@export var Bullet: Area3D # Bullet parent
@export var speed: float = 100.0
@export var damage: int = 10
@export var lifetime: float = 5.0 # in seconds
var direction: Vector3 = Vector3.FORWARD
var lifetime_timer = Timer.new()
var is_fired: bool 

func get_bullet_parent() -> Area3D:
#	print("Debug info for ProjectileComponent: " + str(get_parent()))
	return Bullet

func _ready():
	if not get_bullet_parent():
		push_error("ProjectileComponent must be a child of a Area3D.")
		return

	# Connect to signals for collision detection
	get_bullet_parent().body_shape_entered.connect(_on_body_shape_entered)
	get_bullet_parent().area_entered.connect(_on_area_entered)

	
	lifetime_timer.wait_time = lifetime
	lifetime_timer.one_shot = true
	lifetime_timer.timeout.connect(_on_lifetime_timer_timeout)
	add_child(lifetime_timer)

func fire():
	is_fired = true
	lifetime_timer.start()
		
func _physics_process(delta):
	if is_fired:
		get_bullet_parent().global_position += direction * speed * delta
		

func get_damage() -> int:
		return damage

func _on_area_entered(area: Area3D):
	print("Projectile entered area: %s" % area.name)
	if area.has_method("take_damage"):
		area.take_damage(damage)
	
	emit_signal("hit_something", damage)
	emit_signal("returned_to_pool", get_parent())

func _on_body_shape_entered(body_rid: RID, body: Node3D, body_shape_index: int, local_shape_index: int):
	print("Projectile collided with: %s" % body.name)

	var shape_owner = find_owner_of_shape(body, body_shape_index)
	if shape_owner is CollisionShape3D:
		print("Collided with shape: %s" % shape_owner.name)
	elif shape_owner:
		print("Collided with shape owned by: %s" % shape_owner.name)
	else:
		print("Could not determine collided shape owner.")

	var hurtbox = null
	for child in body.get_children():
		if child.is_class("HurtboxComponent"):
			hurtbox = child
			break
	
	if hurtbox and hurtbox.has_method("take_damage"):
		print("Found HurtboxComponent on %s, applying damage." % body.name)
		hurtbox.take_damage(damage)
	elif body.has_method("take_damage"):
		body.take_damage(damage)

	emit_signal("hit_something", damage)
	emit_signal("returned_to_pool", get_parent())

func find_owner_of_shape(body: CollisionObject3D, shape_index: int) -> Object:
	var current_shape_index = 0
	var owner_ids = body.get_shape_owners()
	for i in range(len(owner_ids)):
		var owner_id = owner_ids[i]
		var shape_count = body.shape_owner_get_shape_count(owner_id)
		if shape_index < current_shape_index + shape_count:
			return body.shape_owner_get_owner(owner_id)
		current_shape_index += shape_count
	return null

func _on_lifetime_timer_timeout():
	print("Projectile lifetime expired.")
	emit_signal("returned_to_pool", get_parent())
