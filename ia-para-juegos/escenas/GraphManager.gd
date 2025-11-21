extends Node

# --- ¡¡IMPORTANTE!! ---
# El "corazón" del grafo. Debes definir manualmente
# qué habitaciones se conectan con qué otras.
# Usa los NOMBRES de tus nodos de Habitación (ej. "Habitacion_01").
var connections = {
	"Habitacion_01": ["Habitacion_02"],
	"Habitacion_02": ["Habitacion_01","Habitacion_03","Habitacion_07"],
	"Habitacion_03": ["Habitacion_02", "Habitacion_04"],
	"Habitacion_04": ["Habitacion_03", "Habitacion_05", "Habitacion_06"],
	"Habitacion_05": ["Habitacion_04"],
	"Habitacion_06": ["Habitacion_04", "Habitacion_10", "Habitacion_09"],
	"Habitacion_07": ["Habitacion_02", "Habitacion_08", "Habitacion_09"],
	"Habitacion_08": ["Habitacion_07"],
	"Habitacion_09": ["Habitacion_07","Habitacion_06","Habitacion_10"],
	"Habitacion_10": ["Habitacion_06","Habitacion_09"],
	# ... (¡Debes rellenar esto para tus 10 habitaciones!)
}

# --- Variables Internas ---
# El objeto A* que hará la magia
var astar_graph = AStar2D.new()
# Diccionario para guardar referencias a los nodos Marker2D
var room_nodes = {}
# Referencia a tu nodo de Regiones
var region_node: Node2D


func _ready():
	# Espera a que el árbol de escenas esté listo
	await get_tree().root.ready
	
	# Busca el nodo RegionRepresentation
	region_node = get_tree().root.get_node("Principal/RegionRepresentation")
	if not region_node:
		print_debug("ERROR (GraphManager): No se encontró 'Principal/RegionRepresentation'")
		return
		
	_build_graph()


# 1. Construye el grafo A*
func _build_graph():
	var point_id = 0
	
	# --- Paso 1: Añadir todos los 'Marker2D' como puntos ---
	for room_child in region_node.get_children():
		var room_name = room_child.name
		var marker = room_child.get_node_or_null("Marker2D")
		
		if marker:
			# Guarda la referencia al nodo
			room_nodes[room_name] = marker
			
			# Añade el punto al grafo A*
			astar_graph.add_point(point_id, marker.global_position)
			
			# Asocia el ID del punto con el nombre de la habitación
			astar_graph.set_point_meta(point_id, room_name)
			
			point_id += 1

	# --- Paso 2: Conectar los puntos según tu diccionario 'connections' ---
	for room_name in connections:
		var room_id = _get_id_from_name(room_name)
		if room_id == -1: continue # No se encontró el nodo

		for neighbor_name in connections[room_name]:
			var neighbor_id = _get_id_from_name(neighbor_name)
			if neighbor_id == -1: continue
			
			# Conecta los dos puntos en el grafo A*
			astar_graph.connect_points(room_id, neighbor_id, false) # false = bidireccional

	print("Grafo de alto nivel (HPF) construido con ", astar_graph.get_point_count(), " nodos.")

# 2. La función pública que usarán los NPCs
func find_high_level_path(start_pos: Vector2, end_pos: Vector2) -> Array:
	# Encuentra el nodo (Marker2D) más cercano a la posición inicial y final
	var start_id = astar_graph.get_closest_point(start_pos)
	var end_id = astar_graph.get_closest_point(end_pos)
	
	if start_id == end_id:
		return [] # Ya estamos en la región correcta
	
	# Calcula la ruta de IDs (ej. [0, 2, 5])
	var id_path = astar_graph.get_id_path(start_id, end_id)
	
	# Convierte la ruta de IDs en una ruta de posiciones (ej. [Vector2(..), Vector2(..)])
	var pos_path = []
	for id in id_path:
		pos_path.append(astar_graph.get_point_position(id))
	
	# Quita el primer punto (porque ya estamos ahí)
	if not pos_path.is_empty():
		pos_path.pop_front()
		
	return pos_path


# --- Funciones auxiliares ---
func _get_id_from_name(room_name: String) -> int:
	for id in astar_graph.get_point_ids():
		if astar_graph.get_point_meta(id) == room_name:
			return id
	return -1
