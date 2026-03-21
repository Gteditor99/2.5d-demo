extends CanvasLayer

@onready var health_bar: ProgressBar = $HealthBar
@onready var health_label: Label = $HealthBar/HealthLabel
@onready var ammo_label: Label = $AmmoLabel
@onready var kills_label: Label = $KillsLabel
@onready var wave_label: Label = $WaveLabel
@onready var crosshair: TextureRect = $Crosshair
@onready var hit_indicator: ColorRect = $HitIndicator
@onready var wave_announcement: Label = $WaveAnnouncement
@onready var fire_mode_label: Label = $FireModeLabel
@onready var reload_bar: ProgressBar = $ReloadBar
@onready var interaction_prompt: Label = $InteractionPrompt
@onready var wave_complete_label: Label = $WaveCompleteLabel

var _hit_indicator_timer: float = 0.0
var _reload_active: bool = false
var _reload_elapsed: float = 0.0
var _reload_duration: float = 2.5

func _ready():
	hit_indicator.visible = false
	wave_announcement.visible = false
	reload_bar.visible = false
	interaction_prompt.visible = false
	wave_complete_label.visible = false

func _process(delta: float):
	if _hit_indicator_timer > 0.0:
		_hit_indicator_timer -= delta
		hit_indicator.modulate.a = _hit_indicator_timer / 0.3
		if _hit_indicator_timer <= 0.0:
			hit_indicator.visible = false

	if _reload_active:
		_reload_elapsed += delta
		reload_bar.value = (_reload_elapsed / _reload_duration) * 100.0
		if _reload_elapsed >= _reload_duration:
			_reload_active = false
			reload_bar.visible = false

func update_health(current: int, maximum: int):
	health_bar.max_value = maximum
	health_bar.value = current
	health_label.text = "%d" % current

	# Color the health bar based on health percentage
	var ratio = float(current) / float(maximum)
	var bar_style = health_bar.get("theme_override_styles/fill")
	if bar_style:
		if ratio > 0.6:
			bar_style.bg_color = Color(0.2, 0.75, 0.3, 0.9)
		elif ratio > 0.3:
			bar_style.bg_color = Color(0.85, 0.65, 0.1, 0.9)
		else:
			bar_style.bg_color = Color(0.85, 0.15, 0.1, 0.9)

func update_ammo(current: int, reserve: int):
	ammo_label.text = "%d | %d" % [current, reserve]

func update_kills(kills: int):
	kills_label.text = "KILLS  %d" % kills

func update_wave(wave: int):
	wave_label.text = "WAVE %d" % wave

func update_fire_mode(mode: String):
	fire_mode_label.text = mode.to_upper()

func show_reload(duration: float):
	_reload_duration = duration
	_reload_elapsed = 0.0
	_reload_active = true
	reload_bar.value = 0.0
	reload_bar.visible = true

func hide_reload():
	_reload_active = false
	reload_bar.visible = false

func show_wave_announcement(wave: int):
	wave_announcement.text = "WAVE %d" % wave
	wave_announcement.visible = true
	wave_announcement.modulate.a = 1.0
	var tween = create_tween()
	tween.tween_interval(1.5)
	tween.tween_property(wave_announcement, "modulate:a", 0.0, 1.0)
	tween.tween_callback(func(): wave_announcement.visible = false)

func show_wave_complete():
	wave_complete_label.visible = true
	wave_complete_label.modulate.a = 1.0
	var tween = create_tween()
	tween.tween_interval(1.5)
	tween.tween_property(wave_complete_label, "modulate:a", 0.0, 1.0)
	tween.tween_callback(func(): wave_complete_label.visible = false)

func show_hit_indicator():
	hit_indicator.visible = true
	_hit_indicator_timer = 0.3
	hit_indicator.modulate.a = 1.0

func show_interaction_prompt(text: String):
	interaction_prompt.text = text
	interaction_prompt.visible = true

func hide_interaction_prompt():
	interaction_prompt.visible = false
