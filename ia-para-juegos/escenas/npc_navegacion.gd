class_name GuardiaNPC
extends CharacterBody2D

# --- CONFIGURACIÓN DE MOVIMIENTO ---
@export var speed_patrol: float = 80.0
@export var speed_chase: float = 160.0
@export var speed_return: float = 100.0
@export var acceleration: float = 20.0
@export var rotation_speed: float = 8.0
@export var arrival_threshold: float = 10.0 
@export var sprite_faces_up: bool = true 
@export var assigned_room_node_path: NodePath 

# --- CONFIGURACIÓN DE DISPARO ---
@export var bala_scene: PackedScene 
@export var cadencia_disparo: float = 1.0 

# --- REFERENCIAS ---
@export var player: CharacterBody2D
@export var region_graph: RegionGraph

var assigned_room: Habitacion
var room_graph_manual: Node2D 
var habitacion_actual_npc: Node = null

# --- VARIABLES ---
var ruta_manual: PackedVector2Array = []
var indice_ruta: int = 0
var idle_timer: Timer
var shoot_timer: float = 0.0 
var raycast_vision: RayCast2D 

var last_known_player_pos: Vector2 = Vector2.ZERO 
var posicion_objetivo_retorno: Vector2 = Vector2.ZERO 
var cooldown_teletransporte: bool = false 

enum State { IDLE, PATROL, CHASE, SEARCH, RETURN, SCANNING }
var current_state = State.IDLE

# --- PERFIL TÁCTICO: EL GUARDIA ---
var mis_pesos = {
	"w_cobertura": 0.8, # si hay cobertura la preferira si no hay luz alrederos
	"w_luz": -0.5,   #va a ir por estos caminos la mayoria del tiempo   
	"w_alto": 2.0,   #no pasa por aqui a menos que lo obliguen  
}

func _ready():
	idle_timer = Timer.new()
	idle_timer.one_shot = true
	idle_timer.timeout.connect(_on_idle_timer_timeout)
	add_child(idle_timer)
	
	raycast_vision = RayCast2D.new()
	raycast_vision.enabled = true
	raycast_vision.visible = false 
	raycast_vision.add_exception(self) 
	raycast_vision.collision_mask = 1 
	add_child(raycast_vision)
	
	await get_tree().process_frame
	
	if assigned_room_node_path:
		assigned_room = get_node(assigned_room_node_path)
		_actualizar_grafo_navegacion(assigned_room)
	
	set_state(State.PATROL)

func _physics_process(delta):
	if cooldown_teletransporte: 
		velocity = Vector2.ZERO
		return

	if not player or not region_graph: return
	
	if shoot_timer > 0: shoot_timer -= delta

	# 1. ACTUALIZAR SALA
	var nueva_sala = region_graph.get_region_node_from_body(self)
	if nueva_sala and nueva_sala != habitacion_actual_npc:
		_actualizar_grafo_navegacion(nueva_sala)

	var player_room = region_graph.get_region_node_from_body(player)

	# 2. LÓGICA DE PUERTAS
	if assigned_room and habitacion_actual_npc:
		if habitacion_actual_npc == assigned_room:
			if assigned_room.has_method("bloquear_salidas"): assigned_room.bloquear_salidas()
		else:
			var jugador_lejos = (player_room != habitacion_actual_npc) and (player_room != assigned_room)
			if jugador_lejos:
				habitacion_actual_npc.desbloquear_salidas()
				assigned_room.desbloquear_salidas()
			else:
				if habitacion_actual_npc.has_method("bloquear_ruta_hacia"):
					var centro = assigned_room.get_node("Marker2D").global_position
					habitacion_actual_npc.bloquear_ruta_hacia(centro)
				if assigned_room.has_method("bloquear_salidas"):
					assigned_room.bloquear_salidas()

	# 3. TRANSICIONES
	if habitacion_actual_npc == player_room:
		last_known_player_pos = player.global_position
		if current_state != State.CHASE and current_state != State.SCANNING:
			set_state(State.CHASE)
	
	if current_state == State.CHASE and habitacion_actual_npc != player_room:
		set_state(State.RETURN)

	# 4. EJECUCIÓN
	match current_state:
		State.CHASE: _comportamiento_combate(delta)
		State.PATROL: _mover_por_ruta(delta, speed_patrol)
		State.RETURN: _mover_por_ruta(delta, speed_return)
		State.SCANNING:
			rotation += rotation_speed * delta 
			velocity = Vector2.ZERO
			move_and_slide() 
		State.IDLE:
			velocity = velocity.lerp(Vector2.ZERO, 5.0 * delta)
			move_and_slide()
		
		State.SEARCH: set_state(State.RETURN)

# --- COMBATE CON POSICIONAMIENTO PERFECTO ---
func _comportamiento_combate(delta):
	# 1. VERIFICACIÓN TOPOLÓGICA (GRAFO)
	var estamos_conectados = false
	var posicion_centro_mi_nodo = global_position # Default
	
	if room_graph_manual and "astar" in room_graph_manual:
		var astar = room_graph_manual.astar
		
		var id_npc = astar.get_closest_point(global_position)
		var id_player = astar.get_closest_point(player.global_position)
		
		# Recuperamos dónde está EXACTAMENTE el centro del nodo donde estoy parado
		if id_npc != -1:
			posicion_centro_mi_nodo = astar.get_point_position(id_npc)
		
		if id_npc == id_player:
			estamos_conectados = true
		elif astar.are_points_connected(id_npc, id_player, true):
			estamos_conectados = true
	else:
		# Fallback por distancia si no hay grafo
		if global_position.distance_to(player.global_position) < 300.0:
			estamos_conectados = true

	# 2. VERIFICACIÓN VISUAL
	raycast_vision.target_position = to_local(player.global_position)
	raycast_vision.force_raycast_update()
	
	var tengo_vision_limpia = false
	if raycast_vision.is_colliding():
		var col = raycast_vision.get_collider()
		if col == player or col.is_in_group("jugador"):
			tengo_vision_limpia = true
	else:
		tengo_vision_limpia = true 

	# 3. DECISIÓN
	if estamos_conectados and tengo_vision_limpia:
		# --- FASE DE TIRO ---
		
		var distancia_al_centro = global_position.distance_to(posicion_centro_mi_nodo)
		
		if distancia_al_centro > 10.0:
			# -> Me acomodo en el nodo
			_mover_directo_a_punto(posicion_centro_mi_nodo, delta)
			# Te apunto mientras me muevo (se ve genial)
			_rotar_hacia_objetivo(player.global_position, delta)
		
		else:
			# -> Estoy en posición perfecta. FUEGO.
			velocity = Vector2.ZERO 
			_rotar_hacia_objetivo(player.global_position, delta)
			
			if shoot_timer <= 0:
				_disparar()
				shoot_timer = cadencia_disparo
	else:
		# --- FASE DE PERSECUCIÓN ---
		# No tengo tiro o no estamos conectados -> Correr hacia ti
		_mover_persecucion_hibrida(delta)

func _disparar():
	if not bala_scene: return
	var bala = bala_scene.instantiate()
	get_parent().add_child(bala)
	bala.global_position = global_position
	var dir = (player.global_position - global_position).normalized()
	bala.direccion = dir
	bala.rotation = dir.angle()

func _rotar_hacia_objetivo(objetivo: Vector2, delta):
	var ajuste = PI/2 if sprite_faces_up else 0.0
	var angle = (objetivo - global_position).angle() + ajuste
	rotation = lerp_angle(rotation, angle, 10.0 * delta)

# --- MOVIMIENTO GENERAL ---
func _mover_por_ruta(delta, velocidad):
	if ruta_manual.is_empty() or indice_ruta >= ruta_manual.size():
		if current_state == State.RETURN:
			if habitacion_actual_npc == assigned_room:
				set_state(State.SCANNING)
			else:
				if assigned_room: _calcular_ruta_hacia(_obtener_entrada_mas_cercana(assigned_room))
		elif current_state == State.PATROL:
			set_state(State.IDLE)
		return

	var objetivo = ruta_manual[indice_ruta]
	if global_position.distance_to(objetivo) < arrival_threshold:
		indice_ruta += 1
		if indice_ruta >= ruta_manual.size(): return 
		objetivo = ruta_manual[indice_ruta]

	var dir = (objetivo - global_position).normalized()
	velocity = velocity.lerp(dir * velocidad, acceleration * delta)
	move_and_slide()
	
	if velocity.length() > 5.0:
		var ajuste = PI/2 if sprite_faces_up else 0.0
		rotation = lerp_angle(rotation, velocity.angle() + ajuste, 10.0 * delta)

func _mover_persecucion_hibrida(delta):
	# Solo frena si está prácticamente encima del jugador para no atravesarlo
	if global_position.distance_to(player.global_position) < 30.0:
		velocity = Vector2.ZERO
		return

	if ruta_manual.is_empty() or indice_ruta >= ruta_manual.size():
		if room_graph_manual and room_graph_manual.has_method("obtener_ruta_tactica"):
			ruta_manual = room_graph_manual.obtener_ruta_tactica(
				global_position, player.global_position, mis_pesos, player.global_position
			)
			indice_ruta = 0
			if ruta_manual.size() > 0 and global_position.distance_to(ruta_manual[0]) < arrival_threshold:
				indice_ruta = 1
		else:
			_mover_directo_a_punto(player.global_position, delta)
			return

	if indice_ruta < ruta_manual.size():
		var objetivo = ruta_manual[indice_ruta]
		if global_position.distance_to(objetivo) < arrival_threshold:
			indice_ruta += 1
			if indice_ruta < ruta_manual.size(): objetivo = ruta_manual[indice_ruta]
			else: 
				_mover_directo_a_punto(player.global_position, delta)
				return
		_mover_directo_a_punto(objetivo, delta)

# --- AUXILIARES ---
func _mover_directo_a_punto(destino: Vector2, delta):
	var dir = (destino - global_position).normalized()
	velocity = velocity.lerp(dir * speed_chase, acceleration * delta)
	move_and_slide()
	if velocity.length() > 5.0: 
		var ajuste = PI/2 if sprite_faces_up else 0.0
		rotation = lerp_angle(rotation, velocity.angle() + ajuste, 10.0 * delta)

func recibir_teletransporte():
	velocity = Vector2.ZERO
	ruta_manual.clear()
	indice_ruta = 0 
	cooldown_teletransporte = true
	if region_graph:
		var sala = region_graph.get_region_node_from_body(self)
		if sala: _actualizar_grafo_navegacion(sala)
	if current_state == State.RETURN and habitacion_actual_npc == assigned_room:
		if assigned_room.has_method("bloquear_salidas"): assigned_room.bloquear_salidas()
		_configurar_retorno_a_centro()
	await get_tree().create_timer(0.1).timeout
	cooldown_teletransporte = false

func _calcular_ruta_hacia(destino: Vector2):
	if room_graph_manual and room_graph_manual.has_method("obtener_ruta_tactica"):
		ruta_manual = room_graph_manual.obtener_ruta_tactica(global_position, destino, mis_pesos, player.global_position)
		indice_ruta = 0
	else: ruta_manual = []

func _actualizar_grafo_navegacion(sala: Node):
	habitacion_actual_npc = sala
	if sala.has_node("Waypoints"): room_graph_manual = sala.get_node("Waypoints")

func set_state(new_state):
	current_state = new_state
	if new_state == State.PATROL:
		_calcular_ruta_hacia(_get_random_waypoint())
	elif new_state == State.IDLE:
		idle_timer.start(2.0)
	elif new_state == State.RETURN:
		if assigned_room: _configurar_retorno_a_centro()
		else: set_state(State.IDLE)
	elif new_state == State.SCANNING:
		print("👀 Centro asegurado. Escaneando...")
		idle_timer.start(3.0)

func _get_random_waypoint() -> Vector2:
	if room_graph_manual and "astar" in room_graph_manual:
		var ids = room_graph_manual.astar.get_point_ids()
		if ids.size() > 0: return room_graph_manual.astar.get_point_position(ids[randi() % ids.size()])
	return global_position

func _obtener_entrada_mas_cercana(sala: Habitacion) -> Vector2:
	if not sala: return global_position
	if sala.has_node("Waypoints"):
		var grafo = sala.get_node("Waypoints")
		if grafo and "astar" in grafo:
			var id = grafo.astar.get_closest_point(global_position)
			if id != -1: return grafo.astar.get_point_position(id)
	return sala.global_position

func _configurar_retorno_a_centro():
	if assigned_room.has_node("Marker2D"):
		posicion_objetivo_retorno = assigned_room.get_node("Marker2D").global_position
	else:
		posicion_objetivo_retorno = assigned_room.global_position 
	_calcular_ruta_hacia(posicion_objetivo_retorno)

func _on_idle_timer_timeout():
	if current_state == State.IDLE: set_state(State.PATROL)
	elif current_state == State.SCANNING: 
		print("✅ Escaneo completo.")
		set_state(State.PATROL)
