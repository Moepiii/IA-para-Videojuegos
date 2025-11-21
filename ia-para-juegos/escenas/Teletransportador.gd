extends Area2D
class_name Teletransportador

@export var destino: Marker2D

func _ready():
	monitoring = true
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	# Si es el guardia, lo movemos YA.
	if body is GuardiaNPC:
		print("⚡ ¡Contacto! Teletransportando a ", body.name)
		_teletransportar.call_deferred(body)

func _teletransportar(cuerpo):
	if destino:
		# 1. Moverlo físicamente
		cuerpo.global_position = destino.global_position
		
		# 2. Matar la velocidad para que no salga disparado
		cuerpo.velocity = Vector2.ZERO
		
		# 3. Avisar al script del Guardia que ya cruzó
		if cuerpo.has_method("recibir_teletransporte"):
			cuerpo.recibir_teletransporte()
