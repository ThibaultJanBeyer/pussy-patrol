extends Node

const AUTO_RESTART_SECONDS := 5

# Difficulty ramps over the round so an average run ends somewhere in the
# 30-90s range: spawns start one every SPAWN_INTERVAL_START seconds and speed
# up to one every SPAWN_INTERVAL_MIN, while mob speed climbs from
# MOB_SPEED_START towards MOB_SPEED_END, both easing in quadratically over
# DIFFICULTY_RAMP_SECONDS so early game stays calm. Spawn rate stops there —
# spawning much faster starts overlapping balloons at birth — but speed has
# no such ceiling, so a run that outlasts the ramp keeps facing faster mobs
# for as long as it survives.
const SPAWN_INTERVAL_START := 0.5
const SPAWN_INTERVAL_MIN := 0.12
const MOB_SPEED_START := Vector2(150.0, 250.0) # min, max
const MOB_SPEED_END := Vector2(260.0, 420.0) # min, max at DIFFICULTY_RAMP_SECONDS, uncapped past it
const DIFFICULTY_RAMP_SECONDS := 75.0

@export var mob_scene: PackedScene
var score
var _pending_restart := false
var _round_start_msec := 0

func _ready() -> void:
	get_viewport().size_changed.connect(_update_mob_path)
	_update_mob_path()

func _update_mob_path() -> void:
	# window/stretch/aspect is "expand", so the visible screen can be any
	# size or orientation. Keep the mob spawn loop on its actual edges
	# instead of the fixed 720x1024 rectangle it shipped with.
	var size = get_viewport().get_visible_rect().size
	var curve = Curve2D.new()
	curve.add_point(Vector2(0, 0))
	curve.add_point(Vector2(size.x, 0))
	curve.add_point(size)
	curve.add_point(Vector2(0, size.y))
	curve.add_point(Vector2(0, 0))
	$MobPath.curve = curve

func _elapsed_ramp_units() -> float:
	var elapsed := (Time.get_ticks_msec() - _round_start_msec) / 1000.0
	return elapsed / DIFFICULTY_RAMP_SECONDS

func _spawn_rate_progress() -> float:
	var t := clampf(_elapsed_ramp_units(), 0.0, 1.0)
	return t * t # Ease in: gentle at first, ramps harder later; capped at 1.

func _speed_progress() -> float:
	# Same quadratic ease-in for the first DIFFICULTY_RAMP_SECONDS, but no
	# ceiling after that: 2*t-1 continues the t*t curve's slope at t=1, so
	# there's no kink where it hands off, and it keeps climbing forever.
	var t := _elapsed_ramp_units()
	return t * t if t <= 1.0 else 2.0 * t - 1.0

func game_over():
	$ScoreTimer.stop()
	$MobTimer.stop()
	$HUD.show_game_over()
	$DeathSound.play()
	_pending_restart = true
	_auto_restart()

func _auto_restart() -> void:
	for i in range(AUTO_RESTART_SECONDS, 0, -1):
		if not _pending_restart:
			return
		$HUD.show_countdown(i)
		await get_tree().create_timer(1.0).timeout
	if _pending_restart:
		_pending_restart = false
		new_game()

func new_game():
	_pending_restart = false
	score = 0
	$Player.start($StartPosition.position)
	$StartTimer.start()
	$HUD.update_score(score)
	$HUD.reset()
	$HUD.show_message("Get Ready")
	get_tree().call_group("mobs", "queue_free")


func _on_mob_timer_timeout():
	# Create a new instance of the Mob scene.
	var mob = mob_scene.instantiate()

	# Choose a random location on Path2D.
	var mob_spawn_location = $MobPath/MobSpawnLocation
	mob_spawn_location.progress_ratio = randf()

	# Set the mob's position to the random location.
	mob.position = mob_spawn_location.position

	# Set the mob's direction perpendicular to the path direction.
	var direction = mob_spawn_location.rotation + PI / 2

	# Add some randomness to the direction.
	direction += randf_range(-PI / 4, PI / 4)
	mob.rotation = direction

	# Choose the velocity for the mob, faster as the round drags on — with
	# no ceiling, so a long enough survival keeps facing faster mobs.
	var speed_min := lerpf(MOB_SPEED_START.x, MOB_SPEED_END.x, _speed_progress())
	var speed_max := lerpf(MOB_SPEED_START.y, MOB_SPEED_END.y, _speed_progress())
	var velocity = Vector2(randf_range(speed_min, speed_max), 0.0)
	mob.linear_velocity = velocity.rotated(direction)

	# Spawn the mob by adding it to the Main scene.
	add_child(mob)

	# Ramp up the spawn rate for the next mob too, capped at SPAWN_INTERVAL_MIN.
	$MobTimer.wait_time = lerpf(SPAWN_INTERVAL_START, SPAWN_INTERVAL_MIN, _spawn_rate_progress())
	print("DEBUG spawn elapsed=", (Time.get_ticks_msec() - _round_start_msec) / 1000.0, " wait_time=", $MobTimer.wait_time, " speed=[", speed_min, ",", speed_max, "]")


func _on_score_timer_timeout() -> void:
	score += 1
	$HUD.update_score(score)


func _on_start_timer_timeout() -> void:
	_round_start_msec = Time.get_ticks_msec()
	$MobTimer.wait_time = SPAWN_INTERVAL_START
	$MobTimer.start()
	$ScoreTimer.start()
