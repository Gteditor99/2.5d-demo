@tool
class_name NPCData
extends Resource

const EnemyAIController = preload("res://scripts/components/ai/enemy_ai_controller.gd")

@export_group("Identity")
@export var npc_type: StringName = &""
@export var variant: StringName = &"default"

@export_group("Visuals")
@export var sprite_frames: SpriteFrames
@export var default_animation: StringName = &"idle"
@export var idle_animation: StringName = &"idle"
@export var chase_animation: StringName = &"walk"
@export var attack_animation: StringName = &"attack"
@export var hurt_animation: StringName = &"hurt"
@export var dead_animation: StringName = &"death"

@export_group("Stats")
@export var max_health: int = 100
@export var move_speed: float = 100.0
@export var acceleration: float = 100.0
@export var friction: float = 100.0
@export var attack_damage: int = 10
@export var experience_reward: int = 0

@export_group("Behavior")
@export var ai_behavior: EnemyAIBehavior
@export var behavior_overrides: Dictionary = {}

@export_group("Metadata")
@export var loot_table_id: StringName = &""
@export var tags: Array[StringName] = []


func get_identity_key() -> StringName:
		if npc_type == StringName():
				return variant
		return StringName("%s:%s" % [npc_type, variant])


func get_animation_for_state(state: EnemyAIController.State) -> StringName:
		match state:
				EnemyAIController.State.IDLE:
						return _resolve_animation(idle_animation)
				EnemyAIController.State.CHASE:
						return _resolve_animation(chase_animation)
				EnemyAIController.State.ATTACK:
						return _resolve_animation(attack_animation)
				EnemyAIController.State.DEAD:
						return _resolve_animation(dead_animation)
				_:
						return _resolve_animation(default_animation)


func get_hurt_animation() -> StringName:
		return _resolve_animation(hurt_animation)


func get_death_animation() -> StringName:
		return _resolve_animation(dead_animation)


func instantiate_behavior() -> EnemyAIBehavior:
		if not ai_behavior:
				return null

		var behavior_instance: EnemyAIBehavior = ai_behavior.duplicate(true)
		_apply_behavior_overrides(behavior_instance)
		return behavior_instance


func has_animation(animation_name: StringName) -> bool:
		return sprite_frames and sprite_frames.has_animation(animation_name)


func _resolve_animation(animation_name: StringName) -> StringName:
		if sprite_frames and sprite_frames.has_animation(animation_name):
				return animation_name
		if sprite_frames and sprite_frames.has_animation(default_animation):
				return default_animation
		return animation_name


func _apply_behavior_overrides(behavior_instance: EnemyAIBehavior) -> void:
		if not behavior_instance or behavior_overrides.is_empty():
				return

		for property_name in behavior_overrides.keys():
				var property_key: StringName = StringName(property_name)
				if _has_property(behavior_instance, property_key):
						behavior_instance.set(property_key, behavior_overrides[property_name])


func _has_property(target: Object, property_name: StringName) -> bool:
		for property_info in target.get_property_list():
				if property_info.name == property_name:
						return true
		return false
