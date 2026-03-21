extends Node

const EnemyScene = preload("res://scenes/characters/enemies/enemy.tscn")

@export var spawn_points: Array[Marker3D] = []
@export var player: CharacterBody3D
@export var hud: CanvasLayer

var kills: int = 0
var current_wave: int = 0
var enemies_alive: int = 0
var wave_in_progress: bool = false
var _wave_delay_timer: float = 0.0
var _waiting_for_next_wave: bool = false

func _ready():
	if hud:
		hud.update_kills(0)
	_start_next_wave()

func _process(delta: float):
	if _waiting_for_next_wave:
		_wave_delay_timer -= delta
		if _wave_delay_timer <= 0.0:
			_waiting_for_next_wave = false
			_start_next_wave()

func _start_next_wave():
	current_wave += 1
	var enemy_count = _get_enemy_count_for_wave(current_wave)

	if hud:
		hud.update_wave(current_wave)
		hud.show_wave_announcement(current_wave)

	wave_in_progress = true
	enemies_alive = 0

	# Stagger enemy spawns
	for i in range(enemy_count):
		var timer = get_tree().create_timer(0.5 * i)
		timer.timeout.connect(_spawn_enemy)

func _get_enemy_count_for_wave(wave: int) -> int:
	return mini(3 + wave * 2, 20)

func _spawn_enemy():
	if spawn_points.is_empty():
		push_error("GameManager: No spawn points configured.")
		return

	var spawn_point = spawn_points[randi() % spawn_points.size()]
	var enemy = EnemyScene.instantiate()

	# Randomize position slightly around spawn point
	var offset = Vector3(randf_range(-2.0, 2.0), 0, randf_range(-2.0, 2.0))
	enemy.global_transform = spawn_point.global_transform
	enemy.global_position += offset

	get_tree().current_scene.add_child(enemy)
	enemies_alive += 1

	# Connect to enemy death
	var health_comp = enemy.get_node_or_null("HealthComponent") as HealthComponent
	if health_comp:
		health_comp.no_health.connect(_on_enemy_killed.bind(enemy))

func _on_enemy_killed(_enemy: Node):
	kills += 1
	enemies_alive -= 1

	if hud:
		hud.update_kills(kills)

	if enemies_alive <= 0 and wave_in_progress:
		wave_in_progress = false
		_waiting_for_next_wave = true
		_wave_delay_timer = 3.0
