extends Node3D
class_name SoccerGoal

signal goal_scored(home_team_scored: bool)

@export var home_team_scored: bool = true
@export var plane_normal: Vector3 = Vector3.RIGHT
@export var opening_width: float = 8.0
@export var opening_height: float = 5.0
@export var ball_radius: float = 1.5
@export var ball_path: NodePath

var tracked_ball: Node3D
var previous_position: Vector3
var has_previous_position := false
var enabled := true

func _ready() -> void:
    if not ball_path.is_empty():
        tracked_ball = get_node_or_null(ball_path)
    if tracked_ball == null:
        var balls := get_tree().get_nodes_in_group("match_ball")
        if not balls.is_empty():
            tracked_ball = balls[0]
    if tracked_ball != null:
        previous_position = tracked_ball.global_position
        has_previous_position = true

func _physics_process(_delta: float) -> void:
    if not enabled or tracked_ball == null:
        return
    var current := tracked_ball.global_position
    if not has_previous_position:
        previous_position = current
        has_previous_position = true
        return

    var normal := plane_normal.normalized()
    var d0 := (previous_position - global_position).dot(normal)
    var d1 := (current - global_position).dot(normal)

    # Detect the ball center crossing the plane in the scoring direction.
    if d0 < 0.0 and d1 >= ball_radius:
        var denom := d1 - d0
        var fraction := (ball_radius - d0) / denom if absf(denom) > 0.0001 else 0.0
        var crossing := previous_position.lerp(current, clampf(fraction, 0.0, 1.0))
        var local_crossing := to_local(crossing)
        if absf(local_crossing.z) + ball_radius <= opening_width * 0.5 and local_crossing.y + ball_radius <= opening_height and local_crossing.y - ball_radius >= 0.0:
            enabled = false
            goal_scored.emit(home_team_scored)

    previous_position = current

func reset_detector() -> void:
    enabled = true
    if tracked_ball != null:
        previous_position = tracked_ball.global_position
        has_previous_position = true
