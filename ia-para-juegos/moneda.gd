extends Area2D

func _ready():
	# Conectar señal de choque
	body_entered.connect(_on_body_entered)
	
	# (Opcional) Animación de flotar
	var tween = create_tween().set_loops()
	tween.tween_property($Sprite2D, "position:y", -5.0, 1.0).as_relative().set_trans(Tween.TRANS_SINE)
	tween.tween_property($Sprite2D, "position:y", 5.0, 1.0).as_relative().set_trans(Tween.TRANS_SINE)

func _on_body_entered(body):
	if body.is_in_group("jugador"):
		# 1. Sumar al contador global
		GameManager.sumar_moneda()
		
		# 2. Desaparecer
		queue_free()
