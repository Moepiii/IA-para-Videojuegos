extends Node2D
class_name Habitacion

# Referencias
@export var neighbors: Array[NodePath]
@onready var marker: Marker2D = $Marker2D

# --- NUEVO: Aquí arrastras los portales desde tu contenedor ---
@export var portales_asignados: Array[Area2D]

# Lista interna total
var mis_portales: Array[Teletransportador] = []

func _ready():
	print("--- CONFIGURANDO: ", name, " ---")
	
	# 1. Buscar portales que sean HIJOS (Método antiguo, por si acaso)
	_buscar_portales_hijos(self)
	
	# 2. Añadir portales EXTERNOS (Del contenedor)
	for portal in portales_asignados:
		if portal is Teletransportador and not mis_portales.has(portal):
			mis_portales.append(portal)
	
	print("   > Controlando ", mis_portales.size(), " portales en total.")
	
	# 3. Conectar sensor
	var sensor = get_node_or_null("RoomSensor")
	if sensor:
		if not sensor.body_entered.is_connected(_on_cuerpo_entro):
			sensor.body_entered.connect(_on_cuerpo_entro)
		if not sensor.body_exited.is_connected(_on_cuerpo_salio):
			sensor.body_exited.connect(_on_cuerpo_salio)
		
		# Verificación inicial
		var cuerpos = sensor.get_overlapping_bodies()
		for cuerpo in cuerpos:
			if cuerpo.is_in_group("jugador"): # Ojo con la minúscula
				_apagar_portales()
				return
	
	_encender_portales()

# --- EL RESTO SIGUE IGUAL ---

func _on_cuerpo_entro(body):
	if body.is_in_group("jugador"):
		_apagar_portales()

func _on_cuerpo_salio(body):
	if body.is_in_group("jugador"):
		_encender_portales()

func is_body_inside(body: Node2D) -> bool:
	var sensor = get_node_or_null("RoomSensor")
	if sensor: return sensor.overlaps_body(body)
	return false

func _encender_portales():
	for portal in mis_portales:
		portal.set_deferred("monitoring", true)

func _apagar_portales():
	for portal in mis_portales:
		portal.set_deferred("monitoring", false)

func _buscar_portales_hijos(nodo_padre):
	for hijo in nodo_padre.get_children():
		if hijo is Teletransportador:
			mis_portales.append(hijo)
		if hijo.get_child_count() > 0:
			_buscar_portales_hijos(hijo)
