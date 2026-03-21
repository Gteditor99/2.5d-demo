extends Node

const EnemyScene = preload("res://scenes/characters/enemies/enemy.tscn")

@export var spawn_points: Array[Marker3D] = []
@export var player: CharacterBody3D
@export var hud: CanvasLayer

var kills: int = 0
var current_wave: int = 0
var enemies_alive: int = 0
var enemies_to_spawn: int = 0
var wave_in_progress: bool = false
var _wave_delay_timer: float = 0.0
var _waiting_for_next_wave: bool = false
var _spawn_queue: Array = []
var _spawn_timer: float = 0.0

# Elite enemy resource paths
var _elite_npc_data: Resource

var _tutorial_active: bool = false

func _ready():
	_elite_npc_data = load("res://resources/npcs/enemies/jy_elite.tres")

	if hud:
		hud.update_kills(0)

	# Give player reserve ammo
	_give_player_reserve_ammo(90)

	# Connect weapon system signals for fire mode display
	if player:
		var weapon_sys = player.get_node_or_null("WeaponSystemComponent")
		if weapon_sys:
			weapon_sys.weapon_fired.connect(_on_weapon_fired)
			weapon_sys.weapon_reload_started.connect(_on_weapon_reload_started)
			weapon_sys.weapon_reloaded.connect(_on_weapon_reloaded)
			# Set initial fire mode display
			if hud and weapon_sys.weapon_data:
				hud.update_fire_mode(weapon_sys.current_fire_mode)

	# Check if there's a tutorial - wait for it to complete before starting waves
	var tutorial = get_parent().get_node_or_null("Tutorial")
	if tutorial:
		_tutorial_active = true
		tutorial.tutorial_completed.connect(_on_tutorial_completed)
	else:
		_start_next_wave()

func _on_tutorial_completed():
	_tutorial_active = false
	_start_next_wave()

func _process(delta: float):
	if _waiting_for_next_wave:
		_wave_delay_timer -= delta
		if _wave_delay_timer <= 0.0:
			_waiting_for_next_wave = false
			_start_next_wave()

	# Staggered spawn processing
	if not _spawn_queue.is_empty():
		_spawn_timer -= delta
		if _spawn_timer <= 0.0:
			var is_elite = _spawn_queue.pop_front()
			_do_spawn_enemy(is_elite)
			_spawn_timer = 0.4

func _start_next_wave():
	current_wave += 1
	var enemy_count = _get_enemy_count_for_wave(current_wave)
	var elite_count = _get_elite_count_for_wave(current_wave)

	if hud:
		hud.update_wave(current_wave)
		hud.show_wave_announcement(current_wave)

	wave_in_progress = true
	enemies_alive = 0
	enemies_to_spawn = enemy_count

	# Build spawn queue (elites mixed in)
	_spawn_queue.clear()
	for i in range(enemy_count):
		_spawn_queue.append(i < elite_count)
	_spawn_queue.shuffle()
	_spawn_timer = 1.5  # Initial delay after wave announcement

	# Give ammo between waves
	if current_wave > 1:
		_give_player_reserve_ammo(30 + current_wave * 5)

func _get_enemy_count_for_wave(wave: int) -> int:
	return mini(3 + wave * 2, 24)

func _get_elite_count_for_wave(wave: int) -> int:
	if wave < 3:
		return 0
	return mini(wave - 2, 8)

func _give_player_reserve_ammo(amount: int):
	if player:
		var weapon_sys = player.get_node_or_null("WeaponSystemComponent") as WeaponSystemComponent
		if weapon_sys:
			weapon_sys.reserve_ammo += amount
			weapon_sys.emit_signal("ammo_updated", weapon_sys.current_ammo, weapon_sys.reserve_ammo)

func _do_spawn_enemy(is_elite: bool):
	if spawn_points.is_empty():
		return

	var spawn_point = spawn_points[randi() % spawn_points.size()]
	var enemy = EnemyScene.instantiate()

	# Set elite data if applicable
	if is_elite and _elite_npc_data:
		enemy.npc_data = _elite_npc_data

	var offset = Vector3(randf_range(-3.0, 3.0), 0, randf_range(-3.0, 3.0))

	get_tree().current_scene.add_child(enemy)
	enemy.global_transform = spawn_point.global_transform
	enemy.global_position += offset

	enemies_alive += 1

	var health_comp = enemy.get_node_or_null("HealthComponent") as HealthComponent
	if health_comp:
		health_comp.no_health.connect(_on_enemy_killed.bind(enemy))

func _on_enemy_killed(_enemy: Node):
	kills += 1
	enemies_alive -= 1

	if hud:
		hud.update_kills(kills)

	if enemies_alive <= 0 and _spawn_queue.is_empty() and wave_in_progress:
		wave_in_progress = false
		_waiting_for_next_wave = true
		_wave_delay_timer = 4.0
		if hud:
			hud.show_wave_complete()

func _on_weapon_fired():
	# Update fire mode display after each shot (in case mode was switched)
	if player and hud:
		var weapon_sys = player.get_node_or_null("WeaponSystemComponent") as WeaponSystemComponent
		if weapon_sys:
			hud.update_fire_mode(weapon_sys.current_fire_mode)

func _on_weapon_reload_started():
	if player and hud:
		var weapon_sys = player.get_node_or_null("WeaponSystemComponent") as WeaponSystemComponent
		if weapon_sys and weapon_sys.weapon_data:
			hud.show_reload(weapon_sys.weapon_data.reload_time)

func _on_weapon_reloaded():
	if hud:
		hud.hide_reload()
