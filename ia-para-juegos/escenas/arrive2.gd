extends CharacterBody2D

# ----------------------------------------------------------------------
# PROPIEDADES DINÁMICAS Y ARRIVE (EXPORTADAS) 
# ----------------------------------------------------------------------

@export var max_acceleration: float = 100.0
@export var max_speed: float = 200.0          
@export var arrive_slow_radius: float = 100.0 # Frenar
@export var target_radius: float = 280.0      # Radio de detención total
@export var time_to_reach_target_speed: float = 0.5 

# Parámetros de LOOK WHERE YOU'RE GOING 
@export var max_angular_acceleration: float = 5.0
@export var max_rotation: float = 3.0
@export var lwgyg_target_radius: float = 0.005 
@export var lwgyg_slow_radius: float = 0.5
@export var time_to_target: float = 0.1

# ----------------------------------------------------------------------
# VARIABLES INTERNAS 
# ----------------------------------------------------------------------

var jugador: CharacterBody2D = null
var current_rotation_speed: float = 0.0
enum State { STOPPED, ARRIVING }
var current_state = State.STOPPED

# ----------------------------------------------------------------------
# INICIALIZACIÓN Y CONTROL DE ENTRADA
# ----------------------------------------------------------------------

func _ready():
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		jugador = players[0]
	print("Dynamic Arrive: STOPPED. Presiona 5 para activar.")

func _input(event):
	if event is InputEventKey and event.keycode == KEY_5 and event.is_pressed():
		if current_state == State.STOPPED:
			current_state = State.ARRIVING
			print("Dynamic Arrive activado.")
		else:
			current_state = State.STOPPED
			print("Dynamic Arrive desactivado.")

# ----------------------------------------------------------------------
# LÓGICA LINEAL: DYNAMIC ARRIVE
# ----------------------------------------------------------------------

func get_arrive_steering(target_position: Vector2) -> Vector2:
	var direction = target_position - global_position
	var distance = direction.length()
	
	# 1. Chequeo de Detención Total
	if distance < target_radius:
		return -velocity / time_to_reach_target_speed
		
	# 2. Cálculo de Velocidad Objetivo (Target Velocity)
	var target_speed: float
	if distance > arrive_slow_radius:
		target_speed = max_speed
	else:
		# Desaceleración suave y proporcional a la distancia
		target_speed = max_speed * distance / arrive_slow_radius
		
	var target_velocity = direction.normalized() * target_speed
	
	# 3. Cálculo de Aceleración Dinámica
	var linear_acceleration = (target_velocity - velocity) / time_to_reach_target_speed
	
	return linear_acceleration

# ----------------------------------------------------------------------
# LÓGICA ANGULAR: LOOK WHERE YOU'RE GOING
# ----------------------------------------------------------------------

func map_to_range(angle: float) -> float:
	return fposmod(angle + PI, 2 * PI) - PI

func get_look_where_youre_going_steering() -> float:
	var current_velocity = velocity
	if current_velocity.length_squared() == 0.0: return 0.0

	var target_orientation_raw = current_velocity.angle()
	var target_orientation_compensated = target_orientation_raw + PI/2
	
	var rotation_difference = map_to_range(target_orientation_compensated - rotation)
	
	if abs(rotation_difference) < lwgyg_target_radius:
		current_rotation_speed = 0.0
		return 0.0

	var target_rotation: float
	if abs(rotation_difference) > lwgyg_slow_radius:
		target_rotation = max_rotation
	else:
		target_rotation = max_rotation * abs(rotation_difference) / lwgyg_slow_radius

	target_rotation *= rotation_difference / abs(rotation_difference)
	
	var angular_acceleration = target_rotation - current_rotation_speed
	angular_acceleration /= time_to_target
	
	if abs(angular_acceleration) > max_angular_acceleration:
		angular_acceleration = sign(angular_acceleration) * max_angular_acceleration

	return angular_acceleration

# ----------------------------------------------------------------------
# PROCESAMIENTO PRINCIPAL (INTEGRACIÓN DINÁMICA)
# ----------------------------------------------------------------------

func _physics_process(delta: float):
	if not is_instance_valid(jugador):
		velocity = Vector2.ZERO
		return

	var linear_acceleration = Vector2.ZERO

	if current_state == State.ARRIVING:
		linear_acceleration = get_arrive_steering(jugador.global_position)
	else:
		# Frenar al detenerse
		linear_acceleration = velocity.normalized() * -max_acceleration
		
	# 1. Limitación e Integración de Velocidad Lineal
	if linear_acceleration.length_squared() > max_acceleration * max_acceleration:
		linear_acceleration = linear_acceleration.normalized() * max_acceleration
	
	velocity += linear_acceleration * delta
	
	if velocity.length() > max_speed:
		velocity = velocity.normalized() * max_speed
	
	# 2. Integración de Rotación 
	var angular_acceleration = get_look_where_youre_going_steering()
	current_rotation_speed += angular_acceleration * delta
	current_rotation_speed = clamp(current_rotation_speed, -max_rotation, max_rotation)

	move_and_slide()
	rotation += current_rotation_speed * delta
