extends CanvasLayer

@onready var health_bar: ProgressBar = $HealthBar
@onready var health_label: Label = $HealthBar/HealthLabel
@onready var ammo_label: Label = $AmmoLabel
@onready var kills_label: Label = $KillsLabel
@onready var wave_label: Label = $WaveLabel
@onready var crosshair: TextureRect = $Crosshair
@onready var hit_indicator: ColorRect = $HitIndicator
@onready var wave_announcement: Label = $WaveAnnouncement

var _hit_indicator_timer: float = 0.0

func _ready():
	hit_indicator.visible = false
	wave_announcement.visible = false

func _process(delta: float):
	if _hit_indicator_timer > 0.0:
		_hit_indicator_timer -= delta
		hit_indicator.modulate.a = _hit_indicator_timer / 0.3
		if _hit_indicator_timer <= 0.0:
			hit_indicator.visible = false

func update_health(current: int, maximum: int):
	health_bar.max_value = maximum
	health_bar.value = current
	health_label.text = "%d / %d" % [current, maximum]

func update_ammo(current: int, reserve: int):
	ammo_label.text = "%d / %d" % [current, reserve]

func update_kills(kills: int):
	kills_label.text = "Kills: %d" % kills

func update_wave(wave: int):
	wave_label.text = "Wave %d" % wave

func show_wave_announcement(wave: int):
	wave_announcement.text = "WAVE %d" % wave
	wave_announcement.visible = true
	wave_announcement.modulate.a = 1.0
	var tween = create_tween()
	tween.tween_interval(1.5)
	tween.tween_property(wave_announcement, "modulate:a", 0.0, 1.0)
	tween.tween_callback(func(): wave_announcement.visible = false)

func show_hit_indicator():
	hit_indicator.visible = true
	_hit_indicator_timer = 0.3
	hit_indicator.modulate.a = 1.0
