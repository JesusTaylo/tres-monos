class_name AnimadorGestos
extends Node
## Anima los gestos en el modelo del jugador (corre en todos los peers).
## Animación procedural con Tweens sobre los hombros y la cara; señalar
## orienta el brazo derecho hacia el punto replicado cada frame.
## Los brazos cuelgan a lo largo del -Z de cada hombro.

## rotation.x del hombro con el brazo colgando.
const REPOSO := -PI / 2
const VELOCIDAD_VUELTA := 10.0

@export var gestos: Gestos
@export var hombro_izquierdo: Node3D
@export var hombro_derecho: Node3D
## Se mueve para asentir y negar, sin tocar la cámara.
@export var cara: Node3D
@export var pulgar: Node3D

var _tween: Tween
var _reposo := Basis.from_euler(Vector3(REPOSO, 0.0, 0.0))


func _ready() -> void:
	gestos.gesto_hecho.connect(_reproducir)
	pulgar.visible = false


func _process(delta: float) -> void:
	if gestos.apuntando:
		_detener()
		_apuntar(gestos.punto_apuntado, delta)
	elif not _animando():
		# Vuelve suave a la pose de reposo (p. ej. después de señalar).
		var paso := minf(delta * VELOCIDAD_VUELTA, 1.0)
		hombro_derecho.basis = hombro_derecho.basis.slerp(_reposo, paso)
		hombro_izquierdo.basis = hombro_izquierdo.basis.slerp(_reposo, paso)


func _reproducir(gesto: Gestos.Gesto) -> void:
	# Señalar ocupa el brazo derecho: tiene prioridad.
	if gestos.apuntando:
		return
	_detener()
	_tween = create_tween()
	match gesto:
		Gestos.Gesto.SI:
			_oscilar(cara, "rotation:x", 0.4, -0.1, 3)
		Gestos.Gesto.NO:
			_oscilar(cara, "rotation:y", 0.5, -0.5, 3)
		Gestos.Gesto.ALTO:
			_tween.tween_property(hombro_derecho, "rotation:x", 0.05, 0.15)
			_tween.parallel().tween_property(hombro_izquierdo, "rotation:x", 0.05, 0.15)
			_tween.tween_interval(1.0)
		Gestos.Gesto.VEN:
			_tween.tween_property(hombro_derecho, "rotation:x", 0.0, 0.15)
			_oscilar(hombro_derecho, "rotation:x", 0.9, 0.1, 3)
		Gestos.Gesto.PULGAR_ARRIBA:
			_tween.tween_callback(pulgar.show)
			_tween.tween_property(hombro_derecho, "rotation:x", 0.35, 0.15)
			_tween.tween_interval(1.0)
	_tween.tween_callback(_detener)


## Va y vuelve entre dos valores; termina en 0.
func _oscilar(nodo: Node3D, propiedad: String, ida: float, vuelta: float, veces: int) -> void:
	for i in veces:
		_tween.tween_property(nodo, propiedad, ida, 0.12)
		_tween.tween_property(nodo, propiedad, vuelta, 0.12)
	_tween.tween_property(nodo, propiedad, 0.0, 0.1)


func _animando() -> bool:
	return _tween != null and _tween.is_running()


## Corta el gesto en curso y deja la cara y el pulgar en reposo.
## Los brazos vuelven solos en _process.
func _detener() -> void:
	if _tween:
		_tween.kill()
		_tween = null
	cara.rotation = Vector3.ZERO
	pulgar.visible = false


func _apuntar(punto: Vector3, delta: float) -> void:
	var direccion := punto - hombro_derecho.global_position
	if direccion.length_squared() < 0.01:
		return
	# Evita que look_at falle si se apunta justo arriba o abajo.
	var arriba := Vector3.UP if absf(direccion.normalized().y) < 0.99 else Vector3.FORWARD
	var objetivo := Basis.looking_at(direccion, arriba)
	var padre := hombro_derecho.get_parent_node_3d().global_basis.orthonormalized()
	var local := padre.inverse() * objetivo
	hombro_derecho.basis = hombro_derecho.basis.slerp(local, minf(delta * 15.0, 1.0))
