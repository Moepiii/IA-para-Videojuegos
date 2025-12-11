extends Node2D
class_name Habitacion

# --- REFERENCIAS ---
@export var neighbors: Array[NodePath]
@onready var marker: Marker2D = $Marker2D

# Referencias a portales que no sean hijos directos
@export var portales_asignados: Array[Area2D]

# Lista interna total
var mis_portales: Array[Teletransportador] = []

func _ready():
	# 1. Recopilar portales
	_buscar_portales_hijos(self)
	for portal in portales_asignados:
		if portal is Teletransportador and not mis_portales.has(portal):
			mis_portales.append(portal)
	
	# Estado inicial: ABIERTO
	desbloquear_salidas()

# --- FUNCIONES DE MANDO ---

# Cierra TODO
func bloquear_salidas():
	for portal in mis_portales:
		portal.set_deferred("monitoring", false)

# Abre TODO
func desbloquear_salidas():
	for portal in mis_portales:
		portal.set_deferred("monitoring", true)

# Cierra todos MENOS el que lleva a 'punto_objetivo'
# (Usado por el Guardia cuando quiere volver a casa sin dejar pasar a nadie más)
func bloquear_todo_menos_ruta_a(punto_objetivo: Vector2):
	for portal in mis_portales:
		if portal.destino:
			var dist = portal.destino.global_position.distance_to(punto_objetivo)
			if dist < 600.0:
				portal.set_deferred("monitoring", true) # ESTE SE QUEDA ABIERTO
			else:
				portal.set_deferred("monitoring", false) # LOS DEMÁS SE CIERRAN
		else:
			portal.set_deferred("monitoring", false)

# --- UTILS ---
func is_body_inside(body: Node2D) -> bool:
	var sensor = get_node_or_null("RoomSensor")
	if sensor: return sensor.overlaps_body(body)
	return false

func _buscar_portales_hijos(nodo_padre):
	for hijo in nodo_padre.get_children():
		if hijo is Teletransportador:
			mis_portales.append(hijo)
		if hijo.get_child_count() > 0:
			_buscar_portales_hijos(hijo)
