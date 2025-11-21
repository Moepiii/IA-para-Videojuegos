class_name GuardiaNPC
extends CharacterBody2D

# --- AJUSTES ---
@export var speed_patrol: float = 80.0
@export var speed_chase: float = 120.0
@export var speed_return: float = 150.0
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

# [NUEVO] Añadimos SCANNING a la lista de estados
enum State { IDLE, PATROL, CHASE, SEARCH, RETURN, SCANNING }
var current_state = State.IDLE

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

	# Si cruzamos y ya estamos en casa, ir al centro
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
					# Ir a la puerta para entrar
					var conector = _buscar_conector_hacia_sala(assigned_room)
					if conector != Vector2.ZERO:
						posicion_objetivo_retorno = conector
					else:
						posicion_objetivo_retorno = _obtener_entrada_mas_cercana(assigned_room)
					_calcular_ruta_hacia(posicion_objetivo_retorno)
		
		# [NUEVO] Estado de Escaneo
		State.SCANNING:
			print("👀 Escaneando perímetro...")
			velocity = Vector2.ZERO
			ruta_manual.clear()
			# Gira durante 1.5 segundos antes de patrullar
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
		# Si estoy escaneando, NO interrumpo a menos que el jugador esté pegado
		
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

	# Movimiento
	match current_state:
		State.CHASE: _mover_persecucion_hibrida(delta)
		State.PATROL: _mover_por_ruta(delta, speed_patrol)
		State.SEARCH: _mover_por_ruta(delta, speed_chase)
		State.RETURN: _mover_por_ruta(delta, speed_return)
		
		# [NUEVO] Lógica de giro
		State.SCANNING:
			rotation += rotation_speed * delta # Girar sobre sí mismo
			move_and_slide() # Necesario para colisiones aunque esté quieto
			
		State.IDLE:
			velocity = velocity.lerp(Vector2.ZERO, acceleration * delta)
			move_and_slide()

func _mover_por_ruta(delta, velocidad_actual):
	if ruta_manual.is_empty() or indice_ruta >= ruta_manual.size():
		
		# LÓGICA DE FINALIZACIÓN
		if current_state == State.RETURN:
			# 1. Fuera de casa -> Empujar al portal
			if habitacion_actual_npc != assigned_room:
				var dir_final = (posicion_objetivo_retorno - global_position).normalized()
				velocity = velocity.lerp(dir_final * velocidad_actual, acceleration * delta)
				move_and_slide()
				_rotar_hacia_movimiento(delta)
				return
			
			# 2. En casa (Centro alcanzado) -> [CAMBIO] IR A ESCANEAR
			else:
				set_state(State.SCANNING) # <--- CAMBIO AQUÍ
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
	if not room_graph_manual or not room_graph_manual.has_method("obtener_nodo_en_posicion"): return

	var objetivo_final = Vector2.ZERO
	var id_guardia = room_graph_manual.obtener_nodo_en_posicion(global_position)
	var id_jugador = room_graph_manual.obtener_nodo_en_posicion(player.global_position)
	
	if id_guardia == -1 or id_jugador == -1:
		objetivo_final = player.global_position
	elif id_guardia == id_jugador:
		objetivo_final = player.global_position 
	else:
		var ruta = room_graph_manual.obtener_ruta(id_guardia, id_jugador)
		if ruta.size() > 1: objetivo_final = ruta[1]
		elif ruta.size() == 1: objetivo_final = ruta[0]
		else: objetivo_final = player.global_position

	var direccion = (objetivo_final - global_position).normalized()
	velocity = velocity.lerp(direccion * speed_chase, acceleration * delta)
	move_and_slide()
	_rotar_hacia_movimiento(delta)

# --- AUXILIARES ---

func _buscar_conector_hacia_sala(sala: Habitacion) -> Vector2:
	return Vector2.ZERO 

func _obtener_entrada_mas_cercana(sala: Habitacion) -> Vector2:
	if sala.has_node("Waypoints"):
		var grafo = sala.get_node("Waypoints")
		if grafo and "astar" in grafo:
			var id_cercano = grafo.astar.get_closest_point(global_position)
			if id_cercano != -1: return grafo.astar.get_point_position(id_cercano)
	return sala.global_position 

func _calcular_ruta_hacia(destino: Vector2):
	if room_graph_manual and room_graph_manual.has_method("obtener_nodo_en_posicion"):
		var id_inicio = room_graph_manual.obtener_nodo_en_posicion(global_position)
		var id_fin = room_graph_manual.obtener_nodo_en_posicion(destino)
		if id_inicio != -1 and id_fin != -1:
			ruta_manual = room_graph_manual.obtener_ruta(id_inicio, id_fin)
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
			return room_graph_manual.astar.get_point_position(ids[randi() % ids.size()])
	return global_position

func _on_idle_timer_timeout():
	if current_state == State.IDLE: 
		set_state(State.PATROL)
	
	# [NUEVO] Si termina de escanear, empieza a patrullar
	elif current_state == State.SCANNING:
		print("✅ Perímetro seguro. Patrullando.")
		set_state(State.PATROL)
