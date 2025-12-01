extends Node2D
class_name RoomGraph

@export var navigation_region: NavigationRegion2D
@export var mostrar_debug: bool = true
@export_range(0.0, 1.0) var factor_curvatura: float = 0.25 

var astar = AStar2D.new()
var point_id_to_poly_id = {}
var rutas_reales = {} 

# Diccionario para mapear ID de AStar -> Nodo real (TacticalWaypoint)
var id_to_node = {} 

func _ready():
	await get_tree().process_frame
	await get_tree().process_frame 
	construir_grafo_poligonos()

func construir_grafo_poligonos():
	astar.clear()
	id_to_node.clear()
	rutas_reales.clear()
	
	var puntos = get_children()
	
	if not navigation_region: return
	var nav_poly = navigation_region.navigation_polygon
	var mapa_rid = get_world_2d().navigation_map
	if not nav_poly: return

	# 1. REGISTRAR PUNTOS
	for i in range(puntos.size()):
		if puntos[i] is Marker2D:
			var pos_global = puntos[i].global_position
			astar.add_point(i, pos_global)
			id_to_node[i] = puntos[i]
			
			var pos_local = navigation_region.to_local(pos_global)
			var poly_index = _get_polygon_index_at(pos_local, nav_poly)
			if poly_index != -1:
				point_id_to_poly_id[i] = poly_index

	# 2. CONECTAR
	for i in range(puntos.size()):
		for j in range(puntos.size()):
			if i == j: continue
			if point_id_to_poly_id.has(i) and point_id_to_poly_id.has(j):
				var poly_a = point_id_to_poly_id[i]
				var poly_b = point_id_to_poly_id[j]
				if poly_a == poly_b or _son_vecinos(poly_a, poly_b, nav_poly):
					if not astar.are_points_connected(i, j):
						var pos_a = astar.get_point_position(i)
						var pos_b = astar.get_point_position(j)
						var camino_recto = NavigationServer2D.map_get_path(mapa_rid, pos_a, pos_b, true)
						
						if camino_recto.size() > 0:
							astar.connect_points(i, j, true)
							
							# [CORRECCIÓN 1] Eliminada la variable 'distancia' que no se usaba.
							# Seteamos el peso base a 1.0
							astar.set_point_weight_scale(i, 1.0) 
							
							var camino_curvo = _suavizar_ruta(camino_recto)
							rutas_reales[[i, j]] = camino_curvo
	
	queue_redraw()

# --- PATHFINDING TÁCTICO ---
func obtener_ruta_tactica(inicio_pos: Vector2, fin_pos: Vector2, perfil_pesos: Dictionary, jugador_pos: Vector2) -> PackedVector2Array:
	
	var id_inicio = astar.get_closest_point(inicio_pos)
	var id_fin = astar.get_closest_point(fin_pos)
	
	# PROTECCIÓN 1: IDs inválidos
	if id_inicio == -1 or id_fin == -1:
		return PackedVector2Array() 
	
	# PROTECCIÓN 2: ¡YA ESTOY EN EL NODO DEL JUGADOR! (El arreglo del tembleque)
	# Si el nodo de inicio es el mismo que el final, no calculamos A*.
	# Devolvemos una ruta vacía para que el NPC sepa que debe usar fuerza bruta.
	if id_inicio == id_fin:
		return PackedVector2Array()
	
	# 1. ACTUALIZAR PESOS
	for id in astar.get_point_ids():
		# Protección extra por si el nodo se borró
		if not id_to_node.has(id): continue
			
		var nodo = id_to_node[id]
		var costo_tactico = 0.0
		
		# A. Cualidades Estáticas
		if nodo is TacticalWaypoint:
			if nodo.tiene_cobertura: costo_tactico += perfil_pesos.get("w_cobertura", 0.0)
			if nodo.es_iluminado:    costo_tactico += perfil_pesos.get("w_luz", 0.0)
			if nodo.es_punto_alto:   costo_tactico += perfil_pesos.get("w_alto", 0.0)
		
		# B. Cualidad Dinámica
		var dist_jugador = nodo.global_position.distance_to(jugador_pos)
		if dist_jugador < 150.0:
			costo_tactico += perfil_pesos.get("w_peligro", 0.0)
		
		var nuevo_peso = 1.0 + costo_tactico
		if nuevo_peso < 0.1: nuevo_peso = 0.1 
		
		astar.set_point_weight_scale(id, nuevo_peso)
	
	# 2. CALCULAR RUTA
	return astar.get_point_path(id_inicio, id_fin)

# --- AUXILIARES ---
func _suavizar_ruta(puntos: PackedVector2Array) -> PackedVector2Array:
	if puntos.size() < 3: return puntos 
	var curva = Curve2D.new()
	for i in range(puntos.size()):
		var dir = Vector2.ZERO
		if i > 0 and i < puntos.size() - 1:
			dir = (puntos[i+1] - puntos[i-1]).normalized()
		var fuerza = 0.0
		if i < puntos.size() - 1: fuerza = puntos[i].distance_to(puntos[i+1]) * factor_curvatura
		curva.add_point(puntos[i], -dir * fuerza, dir * fuerza)
	return curva.tessellate(5, 1)

func _calcular_longitud_ruta(puntos: PackedVector2Array) -> float:
	var l = 0.0
	for k in range(puntos.size() - 1): l += puntos[k].distance_to(puntos[k+1])
	return l

func _get_polygon_index_at(pos_local: Vector2, nav_poly: NavigationPolygon) -> int:
	for i in range(nav_poly.get_polygon_count()):
		var polygon_vertices = PackedVector2Array()
		for idx in nav_poly.get_polygon(i):
			polygon_vertices.append(nav_poly.get_vertices()[idx])
		if Geometry2D.is_point_in_polygon(pos_local, polygon_vertices): return i
	return -1

func _son_vecinos(poly_a: int, poly_b: int, nav_poly: NavigationPolygon) -> bool:
	var indices_a = nav_poly.get_polygon(poly_a)
	var indices_b = nav_poly.get_polygon(poly_b)
	var compartidos = 0
	for ia in indices_a:
		for ib in indices_b:
			if ia == ib: compartidos += 1
	return compartidos >= 2

# API estándar (por si otros scripts la llaman)
func obtener_nodo_en_posicion(pos_global: Vector2) -> int:
	return astar.get_closest_point(pos_global)
	
func obtener_ruta(id_inicio: int, id_fin: int) -> PackedVector2Array:
	# Protección también aquí
	if id_inicio == -1 or id_fin == -1: return PackedVector2Array()
	return astar.get_point_path(id_inicio, id_fin)

func _draw():
	if not mostrar_debug: return
	if astar.get_point_count() == 0: return
	for id in astar.get_point_ids():
		var pos = to_local(astar.get_point_position(id))
		draw_circle(pos, 5, Color.YELLOW)
	for key in rutas_reales.keys():
		var puntos_locales = PackedVector2Array()
		for p in rutas_reales[key]: puntos_locales.append(to_local(p))
		draw_polyline(puntos_locales, Color.GREEN, 2.0, true)
