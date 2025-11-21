extends Node2D
class_name PasilloGraph

# No necesitamos NavigationRegion aquí porque vamos a ignorar los polígonos
# y conectar por pura distancia.

var astar = AStar2D.new()

# Ajusta esto según qué tan separados pongas tus markers.
# Si hay un hueco grande entre la sala y el pasillo, sube esto.
@export var distancia_conexion_maxima: float = 300.0

func _ready():
	await get_tree().process_frame
	construir_grafo_flexible()

func construir_grafo_flexible():
	astar.clear()
	var puntos = get_children()
	
	print("PasilloGraph: Construyendo grafo flexible con ", puntos.size(), " puntos.")

	# 1. AÑADIR PUNTOS
	for i in range(puntos.size()):
		if puntos[i] is Marker2D:
			astar.add_point(i, puntos[i].global_position)

	# 2. CONECTAR POR DISTANCIA (Saltando huecos)
	var conexiones = 0
	for i in range(puntos.size()):
		for j in range(puntos.size()):
			if i == j: continue
			
			var pos_a = astar.get_point_position(i)
			var pos_b = astar.get_point_position(j)
			var distancia = pos_a.distance_to(pos_b)
			
			# REGLA 1: Estar dentro del rango
			if distancia < distancia_conexion_maxima:
				# REGLA 2: (Opcional) Raycast para no atravesar paredes reales
				# Si quieres que salte el vacío pero respete muros, mantén esto.
				if not _hay_pared_real(pos_a, pos_b):
					# Evitar duplicar conexiones
					if not astar.are_points_connected(i, j):
						astar.connect_points(i, j, true)
						conexiones += 1
	
	queue_redraw()
	print("PasilloGraph: Conexiones creadas: ", conexiones)

# Detectar paredes físicas (CollisionLayer)
func _hay_pared_real(desde: Vector2, hasta: Vector2) -> bool:
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(desde, hasta)
	# Asegúrate que la Collision Mask coincida con tus PAREDES (TileMap)
	var result = space_state.intersect_ray(query)
	return result.size() > 0

# --- API COMPATIBLE CON EL GUARDIA (Duck Typing) ---
# Estas funciones se llaman igual que en RoomGraph para que el Guardia no se rompa

func obtener_nodo_en_posicion(pos_global: Vector2) -> int:
	# Aquí está la magia para el hueco:
	# Simplemente devuelve el punto más cercano, sin importar si estás en un polígono o en el vacío.
	return astar.get_closest_point(pos_global)

func obtener_ruta(id_inicio: int, id_fin: int) -> PackedVector2Array:
	return astar.get_point_path(id_inicio, id_fin)

# --- DEBUG ---
func _draw():
	if astar.get_point_count() == 0: return
	for id in astar.get_point_ids():
		var pos = to_local(astar.get_point_position(id))
		draw_circle(pos, 6, Color.CYAN) # Color Cian para diferenciar de las habitaciones
		for id_con in astar.get_point_connections(id):
			var pos_con = to_local(astar.get_point_position(id_con))
			draw_line(pos, pos_con, Color.CYAN, 2.0)
