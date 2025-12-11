extends Area2D

# Tiempo antes de desaparecer (puedes cambiarlo en el inspector)
@export var tiempo_vida: float = 2.0 

func _ready():
	# 1. Conectar la señal de choque (Si el jugador la pisa)
	body_entered.connect(_on_body_entered)
	
	# 2. Iniciar la cuenta regresiva para desaparecer sola
	_iniciar_autodestruccion()

func _on_body_entered(body):
	if body.is_in_group("jugador"):
		print("💥 ¡PUM! Pisaste una caja trampa.")
		# Aquí le harías daño al jugador: body.recibir_dano(10)
		queue_free() # Se borra inmediatamente al explotar

func _iniciar_autodestruccion():
	# Crea un temporizador invisible que espera 2 segundos
	await get_tree().create_timer(tiempo_vida).timeout
	
	# Cuando el tiempo se acaba:
	# Verificamos si la caja aún existe (por si el jugador la pisó justo antes)
	if is_instance_valid(self):
		# print("💨 La trampa expiró y desapareció.")
		queue_free() # Se borra sola por vieja
