extends CharacterBody3D

@export var npc_data: NPCData:
        set(value):
                _npc_data = value
                if is_node_ready():
                        _apply_npc_data()
        get:
                return _npc_data

@onready var ai_controller: EnemyAIController = $EnemyAIController
@onready var movement_component: MovementComponent = $MovementComponent
@onready var health_component: HealthComponent = $HealthComponent
@onready var animated_sprite: AnimatedSprite3D = $AnimatedSprite3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

var _npc_data: NPCData
var _active_behavior: EnemyAIBehavior


func _ready() -> void:
        if health_component:
                health_component.hurt.connect(_on_hurt)
                health_component.no_health.connect(_on_no_health)

        if ai_controller:
                ai_controller.state_changed.connect(_on_state_changed)
                ai_controller.attack_requested.connect(_on_attack_requested)

        _apply_npc_data()


func _apply_npc_data() -> void:
        if not _npc_data:
                return

        if animated_sprite and _npc_data.sprite_frames:
                animated_sprite.sprite_frames = _npc_data.sprite_frames
                var start_animation := _npc_data.get_animation_for_state(EnemyAIController.State.IDLE)
                _play_animation(start_animation)

        if movement_component:
                movement_component.SPEED = _npc_data.move_speed
                movement_component.ACCELERATION = _npc_data.acceleration
                movement_component.FRICTION = _npc_data.friction

        if health_component:
                health_component.max_health = _npc_data.max_health
                health_component.health = _npc_data.max_health

        if ai_controller:
                _active_behavior = _npc_data.instantiate_behavior()
                if _active_behavior:
                        ai_controller.set_behavior(_active_behavior)


func _on_state_changed(_previous_state: EnemyAIController.State, new_state: EnemyAIController.State) -> void:
        if not _npc_data:
                return

        var animation_name := _npc_data.get_animation_for_state(new_state)
        _play_animation(animation_name)


func _on_attack_requested() -> void:
        if _npc_data:
                print("%s attacks for %d damage." % [str(_npc_data.get_identity_key()), _npc_data.attack_damage])
                # Deal damage to the player
                if ai_controller and ai_controller.has_player():
                        var player_health = ai_controller.player.get_node_or_null("HealthComponent")
                        if player_health and player_health.has_method("take_damage"):
                                player_health.take_damage(_npc_data.attack_damage)
        else:
                print("Enemy attack triggered.")


func _on_hurt() -> void:
        if _npc_data:
                _play_animation(_npc_data.get_hurt_animation())
                print("%s was hurt." % str(_npc_data.get_identity_key()))
        else:
                print("Enemy was hurt.")


func _on_no_health() -> void:
        print("Enemy has died.")
        set_physics_process(false)

        if ai_controller:
                ai_controller.handle_death()

        if movement_component:
                movement_component.set_physics_process(false)

        if collision_shape:
                collision_shape.disabled = true

        if _npc_data:
                _play_animation(_npc_data.get_death_animation())
        else:
                _play_animation(&"death")


func _play_animation(name: StringName) -> void:
        if animated_sprite and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation(name):
                animated_sprite.play(name)


func _on_animated_sprite_3d_animation_finished() -> void:
        var death_animation := _npc_data.get_death_animation() if _npc_data else &"death"
        if animated_sprite.animation == death_animation:
                queue_free()
