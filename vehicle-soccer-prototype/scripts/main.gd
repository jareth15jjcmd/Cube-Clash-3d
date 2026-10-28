extends Node3D

var ball: SoccerBall
var home_car: SoccerCar
var away_car: SoccerCar
var match_manager: SoccerMatchManager
var hud_label: Label

func _ready() -> void:
    _build_lighting()
    _build_arena()
    _build_ball()
    _build_cars()
    _build_goals()
    _build_match_manager()
    _build_hud()

func _build_lighting() -> void:
    var world := WorldEnvironment.new()
    var environment := Environment.new()
    environment.background_mode = Environment.BG_SKY
    environment.sky = Sky.new()
    environment.sky.sky_material = ProceduralSkyMaterial.new()
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color(0.55, 0.65, 0.8)
    environment.ambient_light_energy = 0.7
    world.environment = environment
    add_child(world)

    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-50.0, -30.0, 0.0)
    sun.light_energy = 1.2
    add_child(sun)

func _build_arena() -> void:
    _add_box("Ground", Vector3(0, -0.5, 0), Vector3(48, 1, 30), Color(0.08, 0.24, 0.22))
    _add_box("NorthWall", Vector3(0, 2.0, -15.5), Vector3(48, 4, 1), Color(0.12, 0.18, 0.28))
    _add_box("SouthWall", Vector3(0, 2.0, 15.5), Vector3(48, 4, 1), Color(0.12, 0.18, 0.28))
    _add_box("WestWall", Vector3(-24.5, 2.0, 0), Vector3(1, 4, 30), Color(0.12, 0.18, 0.28))
    _add_box("EastWall", Vector3(24.5, 2.0, 0), Vector3(1, 4, 30), Color(0.12, 0.18, 0.28))
    # Prototype uses flat walls. Replace corners with curved collision meshes
    # in the arena-art milestone for seamless wall/ceiling driving.

func _add_box(node_name: String, position: Vector3, size: Vector3, color: Color) -> StaticBody3D:
    var body := StaticBody3D.new()
    body.name = node_name
    body.position = position
    var shape_node := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = size
    shape_node.shape = shape
    body.add_child(shape_node)

    var mesh_node := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    mesh_node.mesh = mesh
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    mesh_node.material_override = material
    body.add_child(mesh_node)
    add_child(body)
    return body

func _build_ball() -> void:
    ball = SoccerBall.new()
    ball.name = "Ball"
    ball.position = Vector3(0, 2.0, 0)
    add_child(ball)

func _build_cars() -> void:
    home_car = SoccerCar.new()
    home_car.name = "HomeCar"
    home_car.is_local_player = true
    home_car.position = Vector3(-8, 1, 0)
    add_child(home_car)

    away_car = SoccerCar.new()
    away_car.name = "AwayCar"
    away_car.is_local_player = false
    away_car.position = Vector3(8, 1, 0)
    away_car.rotation.y = PI
    add_child(away_car)

    var camera := SoccerCamera.new()
    camera.name = "SoccerCamera"
    camera.target_car = home_car
    camera.target_ball = ball
    camera.current = true
    add_child(camera)

func _build_goals() -> void:
    var home_goal := SoccerGoal.new()
    home_goal.name = "HomeGoalLine"
    home_goal.position = Vector3(-21.5, 0, 0)
    home_goal.plane_normal = Vector3.LEFT
    home_goal.home_team_scored = false
    home_goal.tracked_ball = ball
    add_child(home_goal)

    var away_goal := SoccerGoal.new()
    away_goal.name = "AwayGoalLine"
    away_goal.position = Vector3(21.5, 0, 0)
    away_goal.plane_normal = Vector3.RIGHT
    away_goal.home_team_scored = true
    away_goal.tracked_ball = ball
    add_child(away_goal)

    # Visual goal frames/openings.
    _add_box("HomeGoalBack", Vector3(-23.0, 2.5, 0), Vector3(0.5, 5, 8), Color(0.1, 0.5, 1.0))
    _add_box("AwayGoalBack", Vector3(23.0, 2.5, 0), Vector3(0.5, 5, 8), Color(1.0, 0.25, 0.12))

func _build_match_manager() -> void:
    match_manager = SoccerMatchManager.new()
    match_manager.name = "MatchManager"
    match_manager.ball = ball
    match_manager.home_car = home_car
    match_manager.away_car = away_car
    for child in get_children():
        if child is SoccerGoal:
            if child.name == "HomeGoalLine":
                match_manager.home_goal = child
            elif child.name == "AwayGoalLine":
                match_manager.away_goal = child
    add_child(match_manager)
    match_manager.score_changed.connect(_on_score_changed)
    match_manager.timer_changed.connect(_on_timer_changed)
    match_manager.match_state_changed.connect(_on_match_state_changed)

func _build_hud() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)
    hud_label = Label.new()
    hud_label.position = Vector2(20, 18)
    hud_label.add_theme_font_size_override("font_size", 24)
    hud_label.add_theme_color_override("font_color", Color.WHITE)
    hud_label.text = "HOME 0  -  0 AWAY   |   05:00\nWASD drive • Space jump/double-jump • Shift boost • Q Ball Cam"
    layer.add_child(hud_label)

func _on_score_changed(home_score: int, away_score: int) -> void:
    _refresh_hud(home_score, away_score, ceili(match_manager.time_left))

func _on_timer_changed(seconds_left: int) -> void:
    _refresh_hud(match_manager.home_score, match_manager.away_score, seconds_left)

func _on_match_state_changed(state_name: String) -> void:
    if hud_label:
        _refresh_hud(match_manager.home_score, match_manager.away_score, ceili(match_manager.time_left), state_name)

func _refresh_hud(home_score: int, away_score: int, seconds_left: int, state_name: String = "PLAYING") -> void:
    if not hud_label:
        return
    var minutes := int(seconds_left / 60)
    var seconds := seconds_left % 60
    hud_label.text = "HOME %d  -  %d AWAY   |   %02d:%02d   |   %s\nWASD drive • Space jump/double-jump • Shift boost • Q Ball Cam" % [home_score, away_score, minutes, seconds, state_name]
