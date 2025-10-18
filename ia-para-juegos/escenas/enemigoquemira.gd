extends CharacterBody2D

# ----------------------------------------------------------------------
# PROPIEDADES EXPORTADAS (Configuración del Algoritmo)
# ----------------------------------------------------------------------

@export var max_angular_acceleration: float = 5.0 
@export var max_rotation: float = 5.0 

# Parámetros del algoritmo Align
@export var target_radius: float = 0.02
@export var slow_radius: float = 0.5   
@export var time_to_target: float = 2

# ----------------------------------------------------------------------
# VARIABLES INTERNAS 
# ----------------------------------------------------------------------

var jugador: CharacterBody2D = null 
var current_rotation_speed: float = 0.0 
var is_active: bool = false # Estado de activación del algoritmo Face

# ----------------------------------------------------------------------
# INICIALIZACIÓN (Búsqueda del Jugador por Grupo)
# ----------------------------------------------------------------------

func _ready():
	
	var players = get_tree().get_nodes_in_group("player")
	
	if players.size() > 0:
		jugador = players[0]
	else:
		printerr("ERROR: Nodo Jugador no encontrado en el grupo 'player'.")

# ----------------------------------------------------------------------
# MANEJO DE INPUT (ACTIVACIÓN/DESACTIVACIÓN por KEY_1)
# ----------------------------------------------------------------------

func _input(event):
	# Tecla Q
	if event is InputEventKey and event.keycode == KEY_Q and event.is_pressed():
		
		is_active = not is_active # Cambia el estado del algoritmo (ON/OFF)
				
		if not is_active:
			current_rotation_speed = 0.0

# ----------------------------------------------------------------------
# FUNCIONES AUXILIARES
# ----------------------------------------------------------------------

# Transforma el ángulo al rango [-PI, PI] para el camino de giro más corto.
func map_to_range(angle: float) -> float:
	return fposmod(angle + PI, 2 * PI) - PI

# ----------------------------------------------------------------------
# LÓGICA DE STEERING BEHAVIOR: FACE 
# ----------------------------------------------------------------------

func get_angular_steering() -> float:
	if not is_instance_valid(jugador): return 0.0

	# 1. FACE: Cálculo de la orientación objetivo
	var direction = jugador.global_position - global_position
	if direction.length_squared() == 0.0: return 0.0

	var target_orientation = direction.angle() 
	# Compensación para la orientación del sprite
	target_orientation += PI/2

	# 2. Lógica de desaceleración y aceleración
	var rotation_difference = map_to_range(target_orientation - rotation)
	var rotation_size = abs(rotation_difference)

	if rotation_size < target_radius:
		current_rotation_speed = 0.0 
		return 0.0

	var target_rotation: float
	if rotation_size > slow_radius:
		target_rotation = max_rotation 
	else:
		target_rotation = max_rotation * rotation_size / slow_radius

	target_rotation *= rotation_difference / rotation_size
	
	var angular_acceleration = target_rotation - current_rotation_speed
	angular_acceleration /= time_to_target
	
	var angular_acceleration_size = abs(angular_acceleration)
	if angular_acceleration_size > max_angular_acceleration:
		angular_acceleration = sign(angular_acceleration) * max_angular_acceleration

	return angular_acceleration

# ----------------------------------------------------------------------
# PROCESAMIENTO PRINCIPAL CONDICIONAL
# ----------------------------------------------------------------------

func _physics_process(delta: float):
	
	if is_active: 
		# Algoritmo FACE
		var angular_acceleration = get_angular_steering()
		current_rotation_speed += angular_acceleration * delta
		current_rotation_speed = clamp(current_rotation_speed, -max_rotation, max_rotation)

	else:
		# Desaceleración suave: la nave frena su giro residual
		current_rotation_speed = move_toward(current_rotation_speed, 0.0, max_rotation * delta)

	# Aplicar el giro 
	rotation += current_rotation_speed * delta
