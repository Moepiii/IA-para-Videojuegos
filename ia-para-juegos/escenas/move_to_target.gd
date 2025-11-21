# enemigoquimira.gd
extends CharacterBody2D # << SOLUCIONA los errores de Línea 18, 25, 30, etc.

# Velocidad del NPC
@export var speed = 150.0 

# Uso de @onready para obtener el NavigationAgent2D
# El nodo NavigationAgent2D DEBE ser hijo directo de este CharacterBody2D
@onready var navigation_agent = $NavigationAgent2D # << SOLUCIONA los errores de Línea 4 y 33 (Advertencia tratada como error)

# Se usará esta variable para saber cuándo moverse
var is_moving = false 

# Función que inicia el cálculo de la ruta y gestiona el movimiento
func move_to_target(target_position: Vector2):
	is_moving = true
	# 1. Establece la nueva posición objetivo para que el agente calcule la ruta.
	navigation_agent.target_position = target_position
	
	# Ya no se necesita set_process(), usamos _physics_process()
	# set_process(true) # << SOLUCIONA el error de Línea 12

func _physics_process(delta):
	# Solo se mueve si el estado lo requiere
	if not is_moving:
		return
		
	if navigation_agent.is_navigation_finished():
		# Cuando el Pathfinding termina, detiene el movimiento
		is_moving = false
		velocity = Vector2.ZERO # << 'velocity' se hereda de CharacterBody2D
		move_and_slide() # << 'move_and_slide()' se hereda de CharacterBody2D
		return

	# 1. Obtiene el siguiente punto en la ruta usando la posición actual
	var next_point = navigation_agent.get_next_path_position()
	
	# 2. Calcula la dirección y establece la velocidad
	var current_position = global_position # << 'global_position' se hereda de Node2D (padre de CharacterBody2D)
	var direction = current_position.direction_to(next_point)
	velocity = direction * speed # << 'velocity' es propiedad de CharacterBody2D
	
	# 3. Mueve el personaje
	move_and_slide()
	
	# 4. Actualiza la posición para el agente (requerido en Godot 4)
	navigation_agent.set_velocity_for_next_frame(velocity)
