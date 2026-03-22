extends CharacterBody3D

@export var npc_data: NPCData:
        set(value):
                _npc_data = value
                if is_node_ready():
                        _apply_npc_data()
        get:
                return _npc_data

@export_group("Hit Feedback")
@export var hit_flash_duration: float = 0.08
@export var hit_flash_color: Color = Color(10.0, 10.0, 10.0, 1.0)
@export var hit_knockback_force: float = 3.0
@export var hit_scale_punch: float = 1.15

@onready var ai_controller: EnemyAIController = $EnemyAIController
@onready var movement_component: MovementComponent = $MovementComponent
@onready var health_component: HealthComponent = $HealthComponent
@onready var animated_sprite: AnimatedSprite3D = $AnimatedSprite3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

var _npc_data: NPCData
var _active_behavior: EnemyAIBehavior
var _hit_flash_timer: float = 0.0
var _original_modulate: Color = Color.WHITE
var _knockback_velocity: Vector3 = Vector3.ZERO
var _scale_punch_timer: float = 0.0
var _original_sprite_scale: Vector3
var _detection_sound: AudioStreamPlayer3D
var _hurt_sound: AudioStreamPlayer3D
var _has_detected_player: bool = false


func _ready() -> void:
        if health_component:
                health_component.hurt.connect(_on_hurt)
                health_component.no_health.connect(_on_no_health)

        if ai_controller:
                ai_controller.state_changed.connect(_on_state_changed)
                ai_controller.attack_requested.connect(_on_attack_requested)

        if animated_sprite:
                _original_sprite_scale = animated_sprite.scale
                _original_modulate = animated_sprite.modulate

        _setup_audio()
        _apply_npc_data()


func _process(delta: float) -> void:
        # Hit flash effect
        if _hit_flash_timer > 0.0:
                _hit_flash_timer -= delta
                if _hit_flash_timer <= 0.0 and animated_sprite:
                        animated_sprite.modulate = _original_modulate

        # Scale punch recovery
        if _scale_punch_timer > 0.0:
                _scale_punch_timer -= delta
                if animated_sprite:
                        var t := clamp(_scale_punch_timer / hit_flash_duration, 0.0, 1.0)
                        animated_sprite.scale = _original_sprite_scale * lerpf(1.0, hit_scale_punch, t)


func _physics_process(delta: float) -> void:
        # Apply knockback
        if _knockback_velocity.length_squared() > 0.01:
                _knockback_velocity = _knockback_velocity.lerp(Vector3.ZERO, 8.0 * delta)
                velocity = _knockback_velocity
                move_and_slide()


func _setup_audio() -> void:
        var detection_stream = load("res://resources/1.mp3")
        var hurt_stream = load("res://resources/2.mp3")

        if detection_stream:
                _detection_sound = AudioStreamPlayer3D.new()
                _detection_sound.stream = detection_stream
                _detection_sound.max_distance = 20.0
                add_child(_detection_sound)

        if hurt_stream:
                _hurt_sound = AudioStreamPlayer3D.new()
                _hurt_sound.stream = hurt_stream
                _hurt_sound.max_distance = 20.0
                add_child(_hurt_sound)


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

        # Play detection sound on first chase
        if new_state == EnemyAIController.State.CHASE and not _has_detected_player:
                _has_detected_player = true
                if _detection_sound:
                        _detection_sound.play()

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
        _apply_hit_feedback()

        if _hurt_sound:
                _hurt_sound.play()

        if _npc_data:
                _play_animation(_npc_data.get_hurt_animation())

        # Stagger the enemy on hit so they visibly react to damage
        if ai_controller and ai_controller.state != EnemyAIController.State.DEAD:
                var stagger_time := 0.35
                if _active_behavior and "stagger_duration" in _active_behavior:
                        stagger_time = _active_behavior.stagger_duration
                ai_controller.apply_stagger(stagger_time)


func _apply_hit_feedback() -> void:
        # White flash
        if animated_sprite:
                animated_sprite.modulate = hit_flash_color
                _hit_flash_timer = hit_flash_duration

        # Scale punch
        if animated_sprite:
                _scale_punch_timer = hit_flash_duration

        # Knockback away from player
        var player := get_tree().get_first_node_in_group("Player")
        if player and player is Node3D:
                var knockback_dir: Vector3 = (global_position - player.global_position).normalized()
                knockback_dir.y = 0.0
                _knockback_velocity = knockback_dir * hit_knockback_force


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


func _play_animation(anim_name: StringName) -> void:
        if animated_sprite and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation(anim_name):
                animated_sprite.play(anim_name)


func _on_animated_sprite_3d_animation_finished() -> void:
        var death_animation := _npc_data.get_death_animation() if _npc_data else &"death"
        if animated_sprite.animation == death_animation:
                queue_free()
