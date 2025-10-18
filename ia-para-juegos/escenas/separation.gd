extends CharacterBody2D

# ----------------------------------------------------------------------
# PROPIEDADES DINÁMICAS GENERALES
# ----------------------------------------------------------------------

@export var max_acceleration: float = 12.0   # Aceleración lineal máxima
@export var max_speed: float = 12.0          # Velocidad lineal máxima

# ----------------------------------------------------------------------
# PROPIEDADES DE WANDERING (Deambulación)
# ----------------------------------------------------------------------

@export_group("Wandering Properties")
@export var max_angular_acceleration: float = 5.0 # Aceleración angular máxima aleatoria
@export var max_rotation: float = 1.5             # Velocidad de rotación máxima

# ----------------------------------------------------------------------
# PROPIEDADES DE SEPARATION (Separación)
# ----------------------------------------------------------------------

@export_group("Separation Properties")
@export var separation_threshold: float = 60.0 # Umbral a partir del cual se aplica la repulsión
@export var decay_coefficient: float = 4000.0  # Constante 'k' para la Ley del Cuadrado Inverso

# ----------------------------------------------------------------------
# VARIABLES INTERNAS 
# ----------------------------------------------------------------------

var all_targets: Array = [] # Lista de todos los demás NPC
var current_rotation_speed: float = 0.0 
enum State { STOPPED, WANDER_SEPARATE } 
var current_state = State.STOPPED

# ----------------------------------------------------------------------
# INICIALIZACIÓN Y CONTROL DE ENTRADA
# ----------------------------------------------------------------------

func _ready():
	randomize() 
	# Obtener todos los nodos que tengan la etiqueta 'npc', excluyéndose a sí mismo.
	# ¡Recuerda añadir la etiqueta 'npc' a todos tus NPC en el editor!
	for node in get_tree().get_nodes_in_group("npc"):
		if node != self:
			all_targets.append(node)

	print("Wander + Separation: STOPPED. Presiona 8 para activar.")

func _input(event):
	# Alternar el estado con la tecla 8 (KEY_8)
	if event is InputEventKey and event.keycode == KEY_Y and event.is_pressed():
		if current_state == State.STOPPED:
			current_state = State.WANDER_SEPARATE
			print("Wander + Separation activado.")
		else:
			current_state = State.STOPPED
			print("Wander + Separation desactivado.")

# ----------------------------------------------------------------------
# FUNCIONES AUXILIARES
# ----------------------------------------------------------------------

func random_binomial() -> float:
	return randf() - randf()

# Función para limitar un vector a la aceleración máxima
func limit_linear_acceleration(accel: Vector2) -> Vector2:
	if accel.length_squared() > max_acceleration * max_acceleration:
		return accel.normalized() * max_acceleration
	return accel
	
# ----------------------------------------------------------------------
# ALGORITMO DINÁMICO: WANDER
# ----------------------------------------------------------------------

# Devuelve la aceleración que hace que el personaje avance y gire aleatoriamente.
func get_wander_steering() -> Dictionary:
	
	var linear_accel = Vector2.ZERO
	var angular_accel = 0.0
	
	# 1. Aceleración lineal: siempre adelante
	var direction_vector = Vector2.UP.rotated(rotation)
	linear_accel = direction_vector * max_acceleration
	
	# 2. Aceleración angular: rotación aleatoria suave
	angular_accel = random_binomial() * max_angular_acceleration

	return {"linear": linear_accel, "angular": angular_accel}

# ----------------------------------------------------------------------
# ALGORITMO DINÁMICO: SEPARATION (Corregido)
# ----------------------------------------------------------------------

func get_separation_steering(targets: Array) -> Vector2:
	var total_linear_accel = Vector2.ZERO
	
	for target in targets:
		if not is_instance_valid(target): continue
		
		# Obtener la dirección (del personaje al objetivo) y distancia
		var direction = target.global_position - global_position
		var distance = direction.length()
		
		if distance < separation_threshold:
			
			# Manejo del caso de Distancia CERO (Previene el error de normalización)
			if distance < 0.001: # Usamos un umbral pequeño para mayor seguridad
				# Aplicar una fuerza de repulsión ALEATORIA y máxima
				var random_dir = Vector2(randf(), randf()).normalized()
				total_linear_accel -= random_dir * max_acceleration
				continue
			
			# Aplicar la Ley del Cuadrado Inverso: strength = min(k / d², maxAcc)
			var strength = min(
				decay_coefficient / (distance * distance),
				max_acceleration
			)
			
			# Normalizar la dirección para obtener el vector de repulsión
			# Como 'direction' apunta a 'target', el repulsor debe apuntar en la dirección OPUESTA.
			direction = direction.normalized() 
			
			total_linear_accel -= strength * direction 
			
	# Limitamos la aceleración final de separación
	return limit_linear_acceleration(total_linear_accel)

# ----------------------------------------------------------------------
# PROCESAMIENTO PRINCIPAL (COMBINACIÓN DE COMPORTAMIENTOS)
# ----------------------------------------------------------------------

func _physics_process(delta: float):
	
	var final_linear_accel = Vector2.ZERO
	var final_angular_accel = 0.0
	
	if current_state == State.WANDER_SEPARATE:
		
		# 1. CALCULAR SEPARATION (Prioridad Máxima)
		var separation_accel = get_separation_steering(all_targets)
		
		# 2. DECISIÓN DE COMPORTAMIENTO
		if separation_accel.length_squared() > 0.0:
			# Si hay una fuerza de separación, USAR SOLO ESA
			final_linear_accel = separation_accel
			
			# Si estamos evitando, frenamos la rotación aleatoria de Wander 
			final_angular_accel = -current_rotation_speed / 0.1 
			
		else:
			# Si no hay nadie cerca, USAR WANDER
			var wander_steering = get_wander_steering()
			final_linear_accel = wander_steering.linear
			final_angular_accel = wander_steering.angular
			
	else:
		# STOPPED: Frenar suavemente
		final_linear_accel = velocity.normalized() * -max_acceleration
		final_angular_accel = -current_rotation_speed / 0.1 

	# --- INTEGRACIÓN DINÁMICA ---
	
	# 1. Integración de Velocidad Lineal
	final_linear_accel = limit_linear_acceleration(final_linear_accel)
	velocity += final_linear_accel * delta
	
	if velocity.length() > max_speed:
		velocity = velocity.normalized() * max_speed
	
	# 2. Integración de Rotación Angular
	current_rotation_speed += final_angular_accel * delta
	current_rotation_speed = clamp(current_rotation_speed, -max_rotation, max_rotation)

	move_and_slide()
	rotation += current_rotation_speed * delta
