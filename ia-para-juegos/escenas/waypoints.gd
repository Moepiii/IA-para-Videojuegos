extends Node2D
class_name RoomGraph

# --- ARRASTRA TU NavigationRegion2D AQUÍ ---
@export var navigation_region: NavigationRegion2D

var astar = AStar2D.new()
# Diccionario para saber en qué polígono está cada punto
var point_id_to_poly_id = {}

func _ready():
	await get_tree().process_frame
	await get_tree().process_frame # Doble espera para asegurar que el NavMesh cargó
	construir_grafo_poligonos()

func construir_grafo_poligonos():
	astar.clear()
	point_id_to_poly_id.clear()
	
	var puntos = get_children()
	
	# 1. VALIDACIÓN
	if not navigation_region:
		print("🛑 RoomGraph: ¡Falta asignar NavigationRegion2D en el Inspector!")
		return
		
	var nav_poly = navigation_region.navigation_polygon
	if not nav_poly:
		return

	# 2. REGISTRAR PUNTOS Y ASIGNARLOS A POLÍGONOS
	for i in range(puntos.size()):
		if puntos[i] is Marker2D:
			var pos_global = puntos[i].global_position
			astar.add_point(i, pos_global)
			
			# Convertimos a local para chequear contra el polígono
			var pos_local = navigation_region.to_local(pos_global)
			var poly_index = _get_polygon_index_at(pos_local, nav_poly)
			
			if poly_index != -1:
				point_id_to_poly_id[i] = poly_index
			else:
				# Si el punto está en lo negro, lo registramos pero sin polígono (quedará aislado)
				# print("⚠️ Marker ", puntos[i].name, " está fuera de la malla azul.")
				pass

	# 3. CONECTAR PUNTOS (Lógica de Vecinos)
	var conexiones = 0
	for i in range(puntos.size()):
		for j in range(puntos.size()):
			if i == j: continue
			
			# Solo intentamos conectar si AMBOS tienen un polígono válido asociado
			if point_id_to_poly_id.has(i) and point_id_to_poly_id.has(j):
				var poly_a = point_id_to_poly_id[i]
				var poly_b = point_id_to_poly_id[j]
				
				# REGLA DE ORO: Conectar si es el MISMO polígono o son VECINOS (comparten borde)
				if poly_a == poly_b or _son_vecinos(poly_a, poly_b, nav_poly):
					if not astar.are_points_connected(i, j):
						astar.connect_points(i, j, true)
						conexiones += 1
	
	queue_redraw()
	print("RoomGraph: Grafo estricto construido con ", conexiones, " conexiones.")

# --- MATEMÁTICAS DE POLÍGONOS ---

func _get_polygon_index_at(pos_local: Vector2, nav_poly: NavigationPolygon) -> int:
	for i in range(nav_poly.get_polygon_count()):
		var polygon_indices = nav_poly.get_polygon(i)
		var polygon_vertices = PackedVector2Array()
		for idx in polygon_indices:
			polygon_vertices.append(nav_poly.get_vertices()[idx])
		
		if Geometry2D.is_point_in_polygon(pos_local, polygon_vertices):
			return i
	return -1

func _son_vecinos(poly_a: int, poly_b: int, nav_poly: NavigationPolygon) -> bool:
	var indices_a = nav_poly.get_polygon(poly_a)
	var indices_b = nav_poly.get_polygon(poly_b)
	var compartidos = 0
	
	for ia in indices_a:
		for ib in indices_b:
			if ia == ib: compartidos += 1
			
	# Dos polígonos son vecinos si comparten al menos 2 vértices (una arista)
	return compartidos >= 2

# --- API PARA EL GUARDIA ---

func obtener_nodo_en_posicion(pos_global: Vector2) -> int:
	# Busca el punto más cercano (aunque esté desconectado, para empezar la ruta)
	return astar.get_closest_point(pos_global)

func obtener_ruta(id_inicio: int, id_fin: int) -> PackedVector2Array:
	return astar.get_point_path(id_inicio, id_fin)

func _draw():
	if astar.get_point_count() == 0: return
	for id in astar.get_point_ids():
		var pos = to_local(astar.get_point_position(id))
		draw_circle(pos, 5, Color.YELLOW)
		for id_con in astar.get_point_connections(id):
			var pos_con = to_local(astar.get_point_position(id_con))
			draw_line(pos, pos_con, Color.GREEN, 2.0)
