extends Area2D

@export var velocidad: float = 75.0
var direccion: Vector2 = Vector2.RIGHT

func _ready():
	# 1. FORZAR ACTIVACIÓN
	monitoring = true 
	monitorable = true
	
	# 2. CONECTAR SEÑAL MANUALMENTE (A prueba de fallos)
	if not body_entered.is_connected(_on_impacto):
		body_entered.connect(_on_impacto)
	
	# Autodestrucción si sale de pantalla
	var notifier = get_node_or_null("VisibleOnScreenNotifier2D")
	if notifier: notifier.screen_exited.connect(queue_free)

func _physics_process(delta):
	position += direccion * velocidad * delta

func _on_impacto(body):
	# ¡SI ESTO IMPRIME ALGO, YA LO TENEMOS!
	print("🟢 COLISIÓN DETECTADA CON: ", body.name)

	if body.is_in_group("jugador"):
		print("🩸 ¡JUGADOR HERIDO!")
		queue_free()
	
	# Si no es el guardia (quien disparó), borramos la bala
	elif not body is GuardiaNPC:
		print("🧱 Pared/Obstáculo golpeado.")
		queue_free()
