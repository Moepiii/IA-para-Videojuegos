extends CharacterBody2D

# ----------------------------------------------------------------------
# PROPIEDADES EXPORTADAS (Cinematic Arrive)
# ----------------------------------------------------------------------

@export var max_speed: float = 200.0          # Velocidad lineal máxima
@export var arrive_slow_radius: float = 350.0 # Radio para empezar a frenar 
@export var target_radius: float = 135.0        # Radio para detenerse por completo

# Parámetros para la función update 
@export var time_to_target: float = 10 

# ----------------------------------------------------------------------
# VARIABLES INTERNAS 
# ----------------------------------------------------------------------

var jugador: CharacterBody2D = null 
enum State { STOPPED, ARRIVING } 
var current_state = State.STOPPED # Comienza detenido

# ----------------------------------------------------------------------
# INICIALIZACIÓN Y CONTROL DE ENTRADA
# ----------------------------------------------------------------------

func _ready():
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		jugador = players[0]
		print("✅ Jugador encontrado: ", jugador.name)
	else:
		print("❌ ERROR: Jugador no encontrado. Asegúrate de que tiene la etiqueta 'player'.")
		
	print("Cinematic Arrive: STOPPED. Presiona 2 para alternar el estado.")

func _input(event):
	#  la tecla 2
	if event is InputEventKey and event.keycode == KEY_2 and event.is_pressed():
		if current_state == State.STOPPED:
			current_state = State.ARRIVING
			print("Cinematic Arrive activado: ARRIVING")
		else:
			current_state = State.STOPPED
			print("Cinematic Arrive desactivado: STOPPED")

# ----------------------------------------------------------------------
# LÓGICA CINEMÁTICA AUXILIAR (Corregida)
# ----------------------------------------------------------------------

# Función newOrientation: Establece la orientación para mirar en la dirección de la velocidad.
func new_orientation(current_orientation: float, new_velocity: Vector2) -> float:
	if new_velocity.length_squared() > 0:
		var target_angle = new_velocity.angle()
		# esto es para que mire a donde debe por 5tavez :(
		return target_angle + PI/2
	else:
		return current_orientation

# ----------------------------------------------------------------------
# ALGORITMO CINEMATIC ARRIVE
# ----------------------------------------------------------------------

# Simula la función getSteering() cinemática.
func get_cinematic_arrive_output(target_position: Vector2):
	var result_velocity = Vector2.ZERO
	
	# 1. Obtener la dirección y distancia al objetivo.
	var direction = target_position - global_position
	var distance = direction.length()
	
	# 2. Comprobación principal: si está dentro del radio de detención.
	if distance < target_radius:
		velocity = Vector2.ZERO # Detención inmediata
		return # Detenemos la ejecución del algoritmo

	# 3. Calcular la velocidad objetivo (target_speed).
	var target_speed: float
	
	if distance > arrive_slow_radius:
		# Fuera del radio de frenado: ir a máxima velocidad.
		target_speed = max_speed
	else:
		# Dentro del radio de frenado: la velocidad es proporcional a la distancia.
		target_speed = max_speed * distance / arrive_slow_radius

	# 4. Establecer la velocidad.
	result_velocity = direction.normalized() * target_speed
		
	# 5. Face in the direction we want to move.

	rotation = new_orientation(rotation, result_velocity) 
	
	# 6. Asignar la velocidad final.
	velocity = result_velocity

# ----------------------------------------------------------------------
# PROCESAMIENTO PRINCIPAL
# ----------------------------------------------------------------------

func _physics_process(delta: float):
	if not is_instance_valid(jugador): 
		velocity = Vector2.ZERO
		return

	if current_state == State.ARRIVING:
		# Calcular el resultado cinemático (actualiza velocity y rotation directamente)
		get_cinematic_arrive_output(jugador.global_position)
		
	else:
		# STOPPED: Frenar suavemente hasta detenerse 
		var deceleration_rate = max_speed / time_to_target 
		velocity = velocity.move_toward(Vector2.ZERO, deceleration_rate * delta)
		
	# Aplicar el movimiento cinemático
	move_and_slide()
