extends CharacterBody2D

# ----------------------------------------------------------------------
# PROPIEDADES EXPORTADAS para KinematicSeek
# ----------------------------------------------------------------------

# NOTE: En Godot, la velocidad y la aceleración se gestionan internamente, pero
#       simularemos la lógica cinemática pura.
@export var max_speed: float = 200.0  # Velocidad lineal máxima (maxSpeed)

# Parámetros para la función update (time/delta)
@export var time_to_target: float = 0.1 # Usado para controlar el frenado al detenerse (no parte de Seek)

# ----------------------------------------------------------------------
# VARIABLES INTERNAS (Según la clase Kinematic simplificada)
# ----------------------------------------------------------------------

var jugador: CharacterBody2D = null 
# Kinematic data:
# position: global_position (interno de CharacterBody2D)
# velocity: velocity (interno de CharacterBody2D)
# orientation: rotation (interno de CharacterBody2D)
# rotation: No se usa directamente en este Seek cinemático.

enum State { STOPPED, SEEKING } 
var current_state = State.STOPPED # Comienza detenido

# ----------------------------------------------------------------------
# INICIALIZACIÓN Y CONTROL DE ENTRADA
# ----------------------------------------------------------------------

func _ready():
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		jugador = players[0]
	print("Cinematic Seek: STOPPED. Presiona 1 para alternar el estado.")

func _input(event):
	# Alternar el estado con la tecla 1 (KEY_1)
	if event is InputEventKey and event.keycode == KEY_1 and event.is_pressed():
		if current_state == State.STOPPED:
			current_state = State.SEEKING
			print("Cinematic Seek activado: SEEKING")
		else:
			current_state = State.STOPPED
			print("Cinematic Seek desactivado: STOPPED")

# ----------------------------------------------------------------------
# LÓGICA CINEMÁTICA AUXILIAR
# ----------------------------------------------------------------------

# Función newOrientation: Establece la orientación para mirar en la dirección de la velocidad.
# La función atan2 de Godot (Vector2.angle()) asume el eje X positivo como 0.
# Mi caso es (+PI/2), usaremos compensación.
func new_orientation(current_orientation: float, new_velocity: Vector2) -> float:
	if new_velocity.length_squared() > 0:
		# Calculamos el ángulo de la velocidad (dirección del movimiento)
		var target_angle = new_velocity.angle()
		
		return target_angle + PI/2
	else:
		return current_orientation

# ----------------------------------------------------------------------
# ALGORITMO CINEMATIC SEEK
# ----------------------------------------------------------------------

# Simula la función getSteering() de KinematicSeek y actualiza la cinemática.
func get_cinematic_seek_output(target_position: Vector2):
	var result_velocity = Vector2.ZERO
	
	# Get the direction to the target.
	result_velocity = target_position - global_position
	
	# The velocity is along this direction, at full speed.
	# Solo si hay distancia
	if result_velocity.length_squared() > 0:
		result_velocity = result_velocity.normalized()
		result_velocity *= max_speed
		
	# modifica directamente la orientación del Kinematic.
	rotation = new_orientation(rotation, result_velocity)
	
	# Establecer la velocidad.
	velocity = result_velocity

# ----------------------------------------------------------------------
# PROCESAMIENTO PRINCIPAL (Simulación del update cinemático simplificado)
# ----------------------------------------------------------------------

func _physics_process(delta: float):
	if not is_instance_valid(jugador): 
		velocity = Vector2.ZERO
		return

	if current_state == State.SEEKING:
		# 1. Calcular el resultado cinemático (actualiza velocity y rotation directamente)
		get_cinematic_seek_output(jugador.global_position)
		
	else:
		# STOPPED: Frenar suavemente hasta detenerse (simulando que velocity->0)
		velocity = velocity.move_toward(Vector2.ZERO, max_speed / time_to_target * delta)
		
	# Aplicar el movimiento cinemático (Godot lo hace con move_and_slide())
	# Esto simula: position += velocity * time
	move_and_slide()
