# enemigoquemira.gd
extends CharacterBody2D

# Esta variable nos permitirá definir la velocidad del enemigo.
# El sistema de rutas leerá esta variable para saber a qué velocidad moverlo.
@export var speed = 150.0

# No necesitas nada más en este script. Ni _process, ni _physics_process.
# El sistema de rutas se encargará de moverlo.
