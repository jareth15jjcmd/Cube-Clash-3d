extends Node
class_name SoccerMatchManager

signal score_changed(home_score: int, away_score: int)
signal timer_changed(seconds_left: int)
signal match_state_changed(state: String)
signal match_finished

enum MatchState { KICKOFF, PLAYING, GOAL_PAUSE, FINISHED }

@export var match_length: float = 300.0
@export var kickoff_delay: float = 3.0
@export var ball: SoccerBall
@export var home_car: SoccerCar
@export var away_car: SoccerCar
@export var home_goal: SoccerGoal
@export var away_goal: SoccerGoal
@export var ball_start := Vector3.ZERO
@export var home_start := Vector3(-8.0, 1.0, 0.0)
@export var away_start := Vector3(8.0, 1.0, 0.0)

var home_score := 0
var away_score := 0
var time_left: float
var state := MatchState.KICKOFF
var kickoff_token := 0

func _ready() -> void:
    time_left = match_length
    if home_goal:
        home_goal.goal_scored.connect(_on_goal_scored)
    if away_goal:
        away_goal.goal_scored.connect(_on_goal_scored)
    start_match()

func _process(delta: float) -> void:
    if state != MatchState.PLAYING:
        return
    time_left = maxf(0.0, time_left - delta)
    timer_changed.emit(ceili(time_left))
    if time_left <= 0.0:
        state = MatchState.FINISHED
        _set_controls(false)
        match_state_changed.emit("FINISHED")
        match_finished.emit()

func start_match() -> void:
    home_score = 0
    away_score = 0
    time_left = match_length
    score_changed.emit(home_score, away_score)
    _kickoff()

func _on_goal_scored(home_team_scored: bool) -> void:
    if state != MatchState.PLAYING:
        return
    if home_team_scored:
        home_score += 1
    else:
        away_score += 1
    score_changed.emit(home_score, away_score)
    state = MatchState.GOAL_PAUSE
    match_state_changed.emit("GOAL_PAUSE")
    _kickoff()

func _kickoff() -> void:
    kickoff_token += 1
    var this_token := kickoff_token
    state = MatchState.KICKOFF
    match_state_changed.emit("KICKOFF")
    _set_controls(false)

    if ball:
        ball.freeze = true
        ball.linear_velocity = Vector3.ZERO
        ball.angular_velocity = Vector3.ZERO
        ball.global_position = ball_start
    if home_car:
        _reset_car(home_car, home_start, Vector3.ZERO)
    if away_car:
        _reset_car(away_car, away_start, Vector3(0.0, PI, 0.0))
    if home_goal:
        home_goal.reset_detector()
    if away_goal:
        away_goal.reset_detector()

    await get_tree().create_timer(kickoff_delay).timeout
    if this_token != kickoff_token or state == MatchState.FINISHED:
        return
    if ball:
        ball.freeze = false
    state = MatchState.PLAYING
    _set_controls(true)
    match_state_changed.emit("PLAYING")

func _reset_car(car: SoccerCar, position: Vector3, rotation: Vector3) -> void:
    car.global_position = position
    car.rotation = rotation
    car.velocity = Vector3.ZERO
    car.jump_count = 0
    car.boost_amount = car.boost_capacity

func _set_controls(enabled: bool) -> void:
    if home_car:
        home_car.controls_enabled = enabled
    if away_car:
        away_car.controls_enabled = enabled
