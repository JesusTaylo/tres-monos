extends Node3D
## Puzzle de la caja fuerte: el Ciego gira la perilla hasta cada número de una
## combinación de 3 (0–20). Solo el Mudo ve el número actual de la perilla y la
## combinación (capa OBJETIVO). Cuando la perilla se queda un momento en el
## número que toca, suena un "clic" (y hay NoiseEvent); pasarse no reinicia
## nada, solo hay que regresar. Con los 3 números la caja se abre.
## El host lleva el número y el progreso, y se los manda a todos.

## Solo se emite en el host.
signal resuelto

const LARGO_COMBINACION := 3
## Diferencia mínima entre un número de la combinación y el anterior.
const DISTANCIA_MINIMA := 3
## Segundos que la perilla tiene que quedarse en el número para que haga clic.
## Así no alcanza con girar sin parar esperando oír el clic.
const ESPERA_CLIC := 0.6
const RADIO_RUIDO_CLIC := 3.0
const RADIO_RUIDO_ABRIR := 6.0
const ANGULO_PUERTA := -1.9
const DURACION_PUERTA := 1.2

@export var perilla: Perilla
## Bisagra de la puerta: gira para abrirla.
@export var bisagra: Node3D
## Lo que ve el Mudo: la combinación y cuántos números van.
@export var nota: Label3D

var _valor := 0
var _combinacion: Array[int] = []
var _progreso := 0
var _abierta := false
## Host: cuándo se movió la perilla por última vez (ms).
var _movida_en := 0
var _tween_puerta: Tween
## Si la puerta ya se ve abierta en este peer (en el host _abierta cambia antes).
var _puerta_abierta := false


func _ready() -> void:
	if not multiplayer.is_server():
		return
	perilla.girada.connect(_al_girar)
	if Lobby.en_partida:
		Lobby.todos_cargaron.connect(reiniciar)
	else:
		reiniciar.call_deferred()


func esta_resuelto() -> bool:
	return _abierta


## Solo host: combinación nueva al azar, perilla en 0 y puerta cerrada.
func reiniciar() -> void:
	_valor = 0
	_combinacion.clear()
	var anterior := _valor
	for i in LARGO_COMBINACION:
		var numero := anterior
		while _distancia(numero, anterior) < DISTANCIA_MINIMA:
			numero = randi() % Perilla.CANTIDAD_VALORES
		_combinacion.append(numero)
		anterior = numero
	_progreso = 0
	_abierta = false
	_movida_en = Time.get_ticks_msec()
	perilla.soltar()
	_enviar_estado()


func _process(_delta: float) -> void:
	if not multiplayer.is_server() or _abierta or _combinacion.is_empty():
		return
	if _valor != _combinacion[_progreso] or Time.get_ticks_msec() - _movida_en < ESPERA_CLIC * 1000:
		return
	_progreso += 1
	Ruido.emitir(perilla.global_position, RADIO_RUIDO_CLIC, 0.9)
	_sonar.rpc("clic", perilla.global_position)
	if _progreso == LARGO_COMBINACION:
		_abierta = true
		perilla.soltar()
		Ruido.emitir(bisagra.global_position, RADIO_RUIDO_ABRIR, 1.0)
		_sonar.rpc("exito", bisagra.global_position)
		resuelto.emit()
	_enviar_estado()


func _al_girar(direccion: int, _id_jugador: int) -> void:
	if _abierta:
		return
	_valor = posmod(_valor + direccion, Perilla.CANTIDAD_VALORES)
	_movida_en = Time.get_ticks_msec()
	_sonar.rpc("tic", perilla.global_position)
	_enviar_estado()


## Distancia en la perilla (da la vuelta: de 20 a 0 hay 1 paso).
static func _distancia(a: int, b: int) -> int:
	var d := absi(a - b)
	return mini(d, Perilla.CANTIDAD_VALORES - d)


func _enviar_estado() -> void:
	_recibir_estado.rpc(_valor, _combinacion, _progreso, _abierta)


@rpc("authority", "call_local", "reliable")
func _recibir_estado(valor: int, combinacion: Array, progreso: int, abierta: bool) -> void:
	var se_abre := abierta and not _puerta_abierta
	_puerta_abierta = abierta
	_valor = valor
	_combinacion.assign(combinacion)
	_progreso = progreso
	_abierta = abierta
	perilla.mostrar_valor(_valor)
	var numeros: PackedStringArray = []
	for numero in _combinacion:
		numeros.append(str(numero))
	nota.text = "Combinación\n%s\nVan %d de %d" % [" · ".join(numeros), _progreso, LARGO_COMBINACION]
	if (se_abre or not abierta) and _tween_puerta:
		_tween_puerta.kill()
	if se_abre:
		_tween_puerta = create_tween()
		_tween_puerta.tween_property(bisagra, "rotation:y", ANGULO_PUERTA, DURACION_PUERTA) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	elif not abierta:
		bisagra.rotation.y = 0.0


@rpc("authority", "call_local", "reliable")
func _sonar(nombre: String, posicion: Vector3) -> void:
	Sonidos.reproducir(self, nombre, posicion)
