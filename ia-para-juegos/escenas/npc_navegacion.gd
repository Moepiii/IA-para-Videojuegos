class_name GuardiaNPC
extends CharacterBody2D

# --- AJUSTES ---
@export var speed_patrol: float = 80.0
@export var speed_chase: float = 160.0
@export var speed_return: float = 100.0
@export var acceleration: float = 20.0
@export var rotation_speed: float = 8.0
@export var sprite_faces_up: bool = true
@export var arrival_threshold: float = 10.0 

# --- REFERENCIAS ---
@export var player: CharacterBody2D
@export var region_graph: RegionGraph
@export var assigned_room_node_path: NodePath

var assigned_room: Habitacion
var room_graph_manual: Node2D 

# --- VARIABLES ---
var ruta_manual: PackedVector2Array = []
var indice_ruta: int = 0
var idle_timer: Timer
var last_known_player_pos: Vector2 = Vector2.ZERO 
var posicion_objetivo_retorno: Vector2 = Vector2.ZERO 

var habitacion_actual_npc: Node = null
var forzando_cruce: bool = false 
var cooldown_teletransporte: bool = false 

enum State { IDLE, PATROL, CHASE, SEARCH, RETURN, SCANNING }
var current_state = State.IDLE

# --- [NUEVO] PERFIL TÁCTICO: EL GUARDIA ---
var mis_pesos = {
	"w_cobertura": 0.0,  # Indiferente
	"w_luz": -0.5,       # Prefiere zonas iluminadas (Pequeño Negativo)
	"w_alto": 2.0,       # Evita zonas altas (Medio Positivo)
	"w_peligro": 0.0     # Valiente (Ignora el peligro)
}

func _ready():
	idle_timer = Timer.new()
	idle_timer.one_shot = true
	idle_timer.timeout.connect(_on_idle_timer_timeout)
	add_child(idle_timer)
	
	await get_tree().process_frame
	
	if get_node_or_null(assigned_room_node_path) is Habitacion:
		assigned_room = get_node(assigned_room_node_path)
		_actualizar_grafo_navegacion(assigned_room)
	
	set_state(State.PATROL)

# --- 🌀 AL CRUZAR EL PORTAL ---
func recibir_teletransporte():
	print("👮 Guardia cruzó. Evaluando...")
	velocity = Vector2.ZERO
	ruta_manual.clear()
	forzando_cruce = false
	cooldown_teletransporte = true
	
	if region_graph:
		var nueva_sala = region_graph.get_region_node_from_body(self)
		if nueva_sala: _actualizar_grafo_navegacion(nueva_sala)

	if current_state == State.RETURN and habitacion_actual_npc == assigned_room:
		print("🏡 En casa. Yendo al centro...")
		_configurar_retorno_a_centro()
	
	await get_tree().create_timer(0.2).timeout
	cooldown_teletransporte = false

func _configurar_retorno_a_centro():
	if assigned_room.has_node("Marker2D"):
		posicion_objetivo_retorno = assigned_room.get_node("Marker2D").global_position
	else:
		posicion_objetivo_retorno = assigned_room.global_position 
	
	_calcular_ruta_hacia(posicion_objetivo_retorno)

func _actualizar_grafo_navegacion(sala_nueva: Node):
	if sala_nueva == habitacion_actual_npc: return 
	habitacion_actual_npc = sala_nueva
	
	if sala_nueva.has_node("Waypoints"):
		room_graph_manual = sala_nueva.get_node("Waypoints")
		forzando_cruce = false 

func set_state(new_state):
	current_state = new_state
	if not idle_timer: return
	
	match new_state:
		State.IDLE:
			idle_timer.wait_time = 2.0
			idle_timer.start()
			ruta_manual.clear()
			
		State.PATROL:
			idle_timer.stop()
			var destino = _get_random_waypoint()
			_calcular_ruta_hacia(destino)
			
		State.CHASE:
			idle_timer.stop()
			
		State.SEARCH:
			idle_timer.stop()
			_calcular_ruta_hacia(last_known_player_pos)
			
		State.RETURN:
			idle_timer.stop()
			if assigned_room:
				if habitacion_actual_npc == assigned_room:
					_configurar_retorno_a_centro()
				else:
					var conector = _buscar_conector_hacia_sala(assigned_room)
					if conector != Vector2.ZERO:
						posicion_objetivo_retorno = conector
					else:
						posicion_objetivo_retorno = _obtener_entrada_mas_cercana(assigned_room)
					_calcular_ruta_hacia(posicion_objetivo_retorno)
		
		State.SCANNING:
			print("👀 Escaneando perímetro...")
			velocity = Vector2.ZERO
			ruta_manual.clear()
			idle_timer.wait_time = 1.5 
			idle_timer.start()

func _physics_process(delta):
	if cooldown_teletransporte: return
	if not player or not region_graph: return

	var nueva_sala = region_graph.get_region_node_from_body(self)
	if nueva_sala and nueva_sala != habitacion_actual_npc:
		_actualizar_grafo_navegacion(nueva_sala)

	var player_room = region_graph.get_region_node_from_body(player)
	
	if not forzando_cruce and current_state != State.SCANNING: 
		
		if player_room == habitacion_actual_npc:
			if current_state != State.CHASE: set_state(State.CHASE)
			last_known_player_pos = player.global_position
		else:
			if current_state == State.CHASE:
				set_state(State.SEARCH)
			elif current_state == State.SEARCH and ruta_manual.is_empty():
				set_state(State.RETURN)
			elif habitacion_actual_npc != assigned_room and player_room != habitacion_actual_npc:
				if current_state != State.RETURN: set_state(State.RETURN)

	match current_state:
		State.CHASE: _mover_persecucion_hibrida(delta)
		State.PATROL: _mover_por_ruta(delta, speed_patrol)
		State.SEARCH: _mover_por_ruta(delta, speed_chase)
		State.RETURN: _mover_por_ruta(delta, speed_return)
		
		State.SCANNING:
			rotation += rotation_speed * delta 
			move_and_slide() 
			
		State.IDLE:
			velocity = velocity.lerp(Vector2.ZERO, acceleration * delta)
			move_and_slide()

func _mover_por_ruta(delta, velocidad_actual):
	if ruta_manual.is_empty() or indice_ruta >= ruta_manual.size():
		
		if current_state == State.RETURN:
			if habitacion_actual_npc != assigned_room:
				var dir_final = (posicion_objetivo_retorno - global_position).normalized()
				velocity = velocity.lerp(dir_final * velocidad_actual, acceleration * delta)
				move_and_slide()
				_rotar_hacia_movimiento(delta)
				return
			else:
				set_state(State.SCANNING) 
				return

		if current_state == State.SEARCH: set_state(State.RETURN)
		elif current_state == State.PATROL: set_state(State.IDLE)
		
		velocity = velocity.lerp(Vector2.ZERO, acceleration * delta)
		move_and_slide()
		return

	var objetivo = ruta_manual[indice_ruta]
	if global_position.distance_to(objetivo) < arrival_threshold:
		indice_ruta += 1
		return

	var direccion = (objetivo - global_position).normalized()
	velocity = velocity.lerp(direccion * velocidad_actual, acceleration * delta)
	move_and_slide()
	_rotar_hacia_movimiento(delta)

func _mover_persecucion_hibrida(delta):
	# REGLA 1: ATAQUE DIRECTO DE CORTO ALCANCE
	# Si estoy muy cerca, ignoro los nodos para no temblar. ¡A por él!
	var distancia_real = global_position.distance_to(player.global_position)
	if distancia_real < 60.0:
		_mover_directo_a_punto(player.global_position, delta)
		return

	if not room_graph_manual: 
		_mover_directo_a_punto(player.global_position, delta)
		return

	# REGLA 2: RECALCULAR RUTA TÁCTICA
	# Solo si no tengo ruta o ya la terminé
	if ruta_manual.is_empty() or indice_ruta >= ruta_manual.size():
		if room_graph_manual.has_method("obtener_ruta_tactica"):
			ruta_manual = room_graph_manual.obtener_ruta_tactica(
				global_position, 
				player.global_position, 
				mis_pesos, 
				player.global_position
			)
			
			# TRUCO ANTITEMBLEQUE:
			# Si la ruta generada es muy corta (ej. estoy en el mismo nodo),
			# la limpiamos para forzar el ataque directo en el siguiente frame.
			if ruta_manual.size() <= 1:
				ruta_manual = []
				_mover_directo_a_punto(player.global_position, delta)
				return
				
			# Si el primer punto es donde estoy parado, lo saltamos
			indice_ruta = 0
			if global_position.distance_to(ruta_manual[0]) < arrival_threshold:
				indice_ruta = 1
		else:
			# Fallback simple
			_mover_directo_a_punto(player.global_position, delta)
			return

	# REGLA 3: SEGUIR LA RUTA
	if indice_ruta < ruta_manual.size():
		var objetivo = ruta_manual[indice_ruta]
		
		# Si llegamos al punto, pasamos al siguiente
		if global_position.distance_to(objetivo) < arrival_threshold:
			indice_ruta += 1
			if indice_ruta >= ruta_manual.size():
				# Fin de la ruta: correr hacia el jugador lo que falte
				_mover_directo_a_punto(player.global_position, delta)
				return
			objetivo = ruta_manual[indice_ruta]

		_mover_directo_a_punto(objetivo, delta)

# Asegúrate de tener esta función auxiliar en el script (si no la tienes, pégala):
func _mover_directo_a_punto(destino: Vector2, delta):
	var dir = (destino - global_position).normalized()
	velocity = velocity.lerp(dir * speed_chase, acceleration * delta)
	move_and_slide()
	_rotar_hacia_movimiento(delta)

# --- AUXILIARES TÁCTICOS ---

func _buscar_conector_hacia_sala(_sala: Habitacion) -> Vector2:
	return Vector2.ZERO 

func _obtener_entrada_mas_cercana(sala: Habitacion) -> Vector2:
	if sala.has_node("Waypoints"):
		var grafo = sala.get_node("Waypoints")
		if grafo and "astar" in grafo:
			var id_cercano = grafo.astar.get_closest_point(global_position)
			if id_cercano != -1: return grafo.astar.get_point_position(id_cercano)
	return sala.global_position 

func _calcular_ruta_hacia(destino: Vector2):
	if room_graph_manual and room_graph_manual.has_method("obtener_ruta_tactica"):
		# [CAMBIO] Usar ruta táctica con mis pesos
		ruta_manual = room_graph_manual.obtener_ruta_tactica(
			global_position, 
			destino, 
			mis_pesos, 
			player.global_position
		)
		indice_ruta = 0
	else:
		ruta_manual = []

func _rotar_hacia_movimiento(delta):
	if velocity.length() > 10.0:
		var angle = velocity.angle() 
		if sprite_faces_up: angle += PI/2 
		rotation = lerp_angle(rotation, angle, rotation_speed * delta)

func _get_random_waypoint() -> Vector2:
	if room_graph_manual and "astar" in room_graph_manual:
		var ids = room_graph_manual.astar.get_point_ids()
		if ids.size() > 0:
			var idx = randi() % ids.size()
			var id = ids[idx]
			return room_graph_manual.astar.get_point_position(id)
	return global_position

func _on_idle_timer_timeout():
	if current_state == State.IDLE: 
		set_state(State.PATROL)
	elif current_state == State.SCANNING:
		print("✅ Perímetro seguro. Patrullando.")
		set_state(State.PATROL)
