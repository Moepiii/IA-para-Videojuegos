@tool # <--- ¡IMPORTANTE! Esto hace que el código se ejecute en el editor
extends Area2D
class_name Teletransportador

# El punto exacto (Marker2D) donde aparecerá el NPC al otro lado
@export var destino: Marker2D

# --- AJUSTES VISUALES (Aparecerán en el Inspector) ---
@export_group("Debug Visual")
@export var mostrar_linea_debug: bool = true
@export var color_linea: Color = Color(0, 1, 0, 0.6) # Verde semi-transparente
@export var grosor_linea: float = 3.0

func _ready():
	# Solo queremos que el portal funcione de verdad en el juego, no en el editor.
	# Engine.is_editor_hint() nos dice si estamos en modo edición.
	if not Engine.is_editor_hint():
		monitoring = true
		# Usamos conexión segura por si se conecta dos veces
		if not body_entered.is_connected(_on_body_entered):
			body_entered.connect(_on_body_entered)

# --- FUNCIÓN MÁGICA DE DIBUJO ---
func _draw():
	if not destino: return 
	if not mostrar_linea_debug: return 
	
	# BUSCAMOS EL CENTRO DEL COLLISION SHAPE
	var punto_inicio = Vector2.ZERO
	var colision = get_node_or_null("CollisionShape2D")
	
	if colision:
		# Usamos la posición del hijo para empezar la línea
		punto_inicio = colision.position
	
	# Calculamos el destino relativo a mí
	var punto_fin = to_local(destino.global_position)

	draw_line(punto_inicio, punto_fin, color_linea, grosor_linea)
	draw_circle(punto_fin, grosor_linea * 1.5, color_linea)

# --- ACTUALIZACIÓN EN EL EDITOR ---
func _process(_delta):
	# Si estamos en el editor, necesitamos pedirle a Godot que redibuje la línea
	# constantemente por si movemos el Area2D o el Marker2D destino.
	if Engine.is_editor_hint():
		queue_redraw() # Esto fuerza a que se ejecute _draw() de nuevo

# ==========================================
# LA LÓGICA ORIGINAL DEL PORTAL SIGUE IGUAL
# ==========================================

func _on_body_entered(body):
	# Verificamos si es uno de tus NPCs y si tiene el método necesario
	if body.has_method("recibir_teletransporte"):
		# print("⚡ ¡ZAS! Teletransportando a ", body.name)
		# Usamos call_deferred para moverlo de forma segura
		_teletransportar.call_deferred(body)

func _teletransportar(cuerpo):
	if destino:
		# 1. Moverlo físicamente a la nueva posición
		cuerpo.global_position = destino.global_position
		# 2. FRENARLO EN SECO
		cuerpo.velocity = Vector2.ZERO
		# 3. AVISAR AL CEREBRO DEL NPC
		cuerpo.recibir_teletransporte()
	else:
		push_error("ERROR: Portal %s no tiene destino asignado" % name)
		
