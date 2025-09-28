class_name ProjectileComponent
extends Node

signal returned_to_pool
signal hit_something(damage)

@export var Bullet: Area3D # Bullet parent
@export var speed: float = 100.0
@export var damage: int = 10
@export var lifetime: float = 5.0 # in seconds

var direction: Vector3 = Vector3.FORWARD
var lifetime_timer := Timer.new()
var is_fired: bool = false
var owner_to_ignore: CollisionObject3D
var last_global_position: Vector3 = Vector3.ZERO

func get_bullet_parent() -> Area3D:
	return Bullet

func _ready():
	var bullet := get_bullet_parent()
	if not bullet:
		push_error("ProjectileComponent must be a child of a Area3D.")
		return

	bullet.body_shape_entered.connect(_on_body_shape_entered)
	bullet.area_entered.connect(_on_area_entered)

	lifetime_timer.wait_time = lifetime
	lifetime_timer.one_shot = true
	lifetime_timer.timeout.connect(_on_lifetime_timer_timeout)
	add_child(lifetime_timer)

	set_physics_process(false)
	last_global_position = bullet.global_position
	bullet.set_deferred("monitoring", false)
	bullet.monitorable = true

func set_owner_to_ignore(ignore_owner: CollisionObject3D) -> void:
	owner_to_ignore = ignore_owner

func fire():
	var bullet := get_bullet_parent()
	if not bullet:
		return

	_restart_lifetime_timer()

	direction = direction.normalized()
	if direction.length_squared() == 0.0:
		direction = Vector3.FORWARD

	is_fired = true
	last_global_position = bullet.global_position
	set_physics_process(true)
	bullet.monitoring = true

func _physics_process(delta: float) -> void:
	if not is_fired:
		return

	var bullet := get_bullet_parent()
	if not bullet or not bullet.is_inside_tree():
		return

	var normalized_direction := direction if direction.length_squared() != 0.0 else Vector3.FORWARD
	normalized_direction = normalized_direction.normalized()
	var motion_vector := normalized_direction * speed * delta
	if motion_vector.length_squared() == 0.0:
		return

	var from_position := last_global_position
	var to_position := from_position + motion_vector

	var world := bullet.get_world_3d()
	var space_state := world.direct_space_state if world else null
	if space_state:
		var query := PhysicsRayQueryParameters3D.create(from_position, to_position)
		query.collision_mask = bullet.collision_mask
		query.collide_with_areas = true
		query.collide_with_bodies = true
		query.hit_from_inside = true
		query.exclude = _build_exclude_list(bullet)

		var result := space_state.intersect_ray(query)
		if result:
			_handle_ray_hit(result)
			return

	bullet.global_position = to_position
	last_global_position = to_position

func get_damage() -> int:
	return damage

func _on_area_entered(area: Area3D) -> void:
	_register_hit(area)

func _on_body_shape_entered(_body_rid: RID, body: Node3D, _body_shape_index: int, _local_shape_index: int) -> void:
	_register_hit(body)

func _handle_ray_hit(result: Dictionary) -> void:
	var bullet := get_bullet_parent()
	if bullet and result.has("position"):
		bullet.global_position = result["position"]
	last_global_position = bullet.global_position if bullet else last_global_position
	_register_hit(result.get("collider"))

func _build_exclude_list(bullet: Area3D) -> Array:
	var excludes: Array = []
	if bullet:
		excludes.append(bullet.get_rid())
	if owner_to_ignore and owner_to_ignore.is_inside_tree():
		excludes.append(owner_to_ignore.get_rid())
	return excludes

func _register_hit(target: Object) -> void:
	if not is_fired:
		return
	var target_name := "<unknown>"
	if target is Node:
		target_name = (target as Node).name
	elif target:
		target_name = str(target)
	Debug.log("Projectile hit target: %s" % target_name)
	_apply_damage(target)
	hit_something.emit(damage)
	_return_to_pool()

func _apply_damage(target: Object) -> void:
	if not is_instance_valid(target):
		return

	var receiver := _resolve_damage_receiver(target)
	if receiver:
		receiver.call("take_damage", damage)
	else:
		var target_name: String = target.name if target is Node else str(target)
		Debug.log("Projectile hit target without damage receiver: %s" % target_name)

func _resolve_damage_receiver(target: Object) -> Object:
	if not target:
		return null
	if target == owner_to_ignore:
		return null

	if target.has_method("take_damage"):
		return target

	if target is Node:
		var child_receiver := _find_damage_receiver_in_children(target)
		if child_receiver:
			return child_receiver

		var parent: Node = target.get_parent()
		while parent:
			if parent == owner_to_ignore:
				return null
			if parent.has_method("take_damage"):
				return parent
			var parent_child_receiver := _find_damage_receiver_in_children(parent)
			if parent_child_receiver:
				return parent_child_receiver
			parent = parent.get_parent()

	return null

func _find_damage_receiver_in_children(node: Node) -> Object:
	var stack: Array = []
	for child in node.get_children():
		if child is Node:
			stack.append(child)

	while not stack.is_empty():
		var candidate: Node = stack.pop_back()
		if candidate == owner_to_ignore:
			continue
		if owner_to_ignore and owner_to_ignore.is_ancestor_of(candidate):
			continue
		if candidate.has_method("take_damage"):
			return candidate
		for grandchild in candidate.get_children():
			if grandchild is Node:
				stack.append(grandchild)

	return null

func _return_to_pool() -> void:
	var bullet := get_bullet_parent()
	is_fired = false
	lifetime_timer.stop()
	set_physics_process(false)
	owner_to_ignore = null
	if bullet:
		last_global_position = bullet.global_position
		bullet.monitoring = false
	Debug.log("Projectile returned to pool.")
	returned_to_pool.emit(get_parent())

func _restart_lifetime_timer() -> void:
	lifetime_timer.stop()
	lifetime_timer.wait_time = lifetime
	lifetime_timer.start()

func _on_lifetime_timer_timeout() -> void:
	_return_to_pool()
