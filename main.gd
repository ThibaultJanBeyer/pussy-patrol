extends Node

@export var mob_scene: PackedScene
var score

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

func game_over():
	$ScoreTimer.stop()
	$MobTimer.stop()
	$HUD.show_game_over()
	$Music.stop()
	$DeathSound.play()

func new_game():
	score = 0
	$Player.start($StartPosition.position)
	$StartTimer.start()
	$HUD.update_score(score)
	$HUD.show_message("Get Ready")
	get_tree().call_group("mobs", "queue_free")
	$Music.play()


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

	# Choose the velocity for the mob.
	var velocity = Vector2(randf_range(150.0, 250.0), 0.0)
	mob.linear_velocity = velocity.rotated(direction)

	# Spawn the mob by adding it to the Main scene.
	add_child(mob)


func _on_score_timer_timeout() -> void:
	score += 1
	$HUD.update_score(score)


func _on_start_timer_timeout() -> void:
	$MobTimer.start()
	$ScoreTimer.start()
