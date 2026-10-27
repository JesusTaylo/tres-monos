extends Node
## Voz del jugador (componente). En el dueño: envía lo que capta el Microfono
## según las reglas de su rol. En los demás peers: reproduce esa voz en 3D
## desde la cabeza del jugador.
##
## Reglas (se leen del Lobby en cada paquete, así que siguen a la rotación):
## - El Mudo no transmite (micrófono apagado).
## - Solo el Ciego recibe voz; el Mudo y el Sordo no oyen a nadie.
## - Sin roles (sala de pruebas) todos se oyen.

## Canal de red propio para que la voz no frene al resto del juego.
const CANAL_VOZ := 2
## Colchón antes de empezar a sonar (absorbe tirones de la red): ~60 ms.
const COLCHON_MUESTRAS := CodecVoz.MUESTRAS_POR_PAQUETE * 3
## Si se atrasa más que esto, se descartan paquetes para alcanzar (~0.4 s).
const MAXIMO_EN_COLA := CodecVoz.FRECUENCIA * 2 / 5
## Sin paquetes por este tiempo = terminó la frase; se vuelve a juntar colchón.
const FIN_DE_FRASE := 0.15
## Cada cuánto la voz genera un NoiseEvent mientras se habla.
const INTERVALO_RUIDO := 0.3
## Cuánto se abre la boca (escala vertical). Con raíz cuadrada, una voz suave
## ya se nota y una fuerte la abre mucho.
const APERTURA := 9.0
const APERTURA_TOPE := 7.0

## Replicado (on change): volumen con el que habla, para la boca y otros indicadores.
var nivel_voz := 0.0

@export var altavoz: AudioStreamPlayer3D
## Se abre según nivel_voz; la ven todos, aunque no oigan la voz.
@export var boca: Node3D

var _reproduccion: AudioStreamPlayback
var _esperando_colchon := true
var _ultimo_paquete := -INF
var _proximo_ruido := 0.0
## Debug: paquetes recibidos desde el último reporte.
var paquetes_recibidos := 0


func _ready() -> void:
	if is_multiplayer_authority():
		Microfono.paquete_listo.connect(_al_capturar)
		Lobby.estado_cambiado.connect(_actualizar_permiso)
		_actualizar_permiso()


func _exit_tree() -> void:
	if is_multiplayer_authority():
		Microfono.transmitir = false
		Microfono.soltar(&"jugador")


func puede_hablar() -> bool:
	return Lobby.mi_rol() != Roles.Rol.MUDO


func puede_oir() -> bool:
	return not Lobby.roles_asignados() or Lobby.mi_rol() == Roles.Rol.CIEGO


func _actualizar_permiso() -> void:
	Microfono.transmitir = puede_hablar()
	if puede_hablar():
		Microfono.pedir(&"jugador")
	else:
		Microfono.soltar(&"jugador")


func _process(delta: float) -> void:
	var apertura := minf(1.0 + sqrt(nivel_voz) * APERTURA, APERTURA_TOPE)
	boca.scale.y = lerpf(boca.scale.y, apertura, minf(delta * 18.0, 1.0))
	if is_multiplayer_authority():
		_actualizar_nivel_propio(delta)
	elif _reproduccion and not _esperando_colchon \
			and Time.get_ticks_msec() / 1000.0 - _ultimo_paquete > FIN_DE_FRASE:
		# Terminó la frase: al acabar lo que queda, se pausa hasta juntar colchón.
		CodecVoz.pausar_al_final(_reproduccion)
		_esperando_colchon = true


func _actualizar_nivel_propio(delta: float) -> void:
	var hablando := Microfono.hablando and Microfono.transmitir
	# Redondeado para que el sincronizador no mande cambios minúsculos cada frame.
	var nuevo := snappedf(Microfono.nivel, 0.05) if hablando else 0.0
	if nuevo != nivel_voz:
		nivel_voz = nuevo
	if not hablando:
		return
	_proximo_ruido -= delta
	if _proximo_ruido <= 0.0:
		_proximo_ruido = INTERVALO_RUIDO
		var fuerza := clampf(0.3 + Microfono.nivel * 1.5, 0.3, 1.0)
		Ruido.emitir(altavoz.global_position, 2.5 + 4.0 * fuerza, fuerza)


func _al_capturar(paquete: PackedByteArray) -> void:
	for id in _destinos():
		_recibir_voz.rpc_id(id, paquete)


func _destinos() -> Array[int]:
	var mi_id := multiplayer.get_unique_id()
	var destinos: Array[int] = []
	if not Lobby.roles_asignados():
		for id in multiplayer.get_peers():
			destinos.append(id)
		return destinos
	for id in Lobby.roles:
		if Lobby.roles[id] == Roles.Rol.CIEGO and id != mi_id:
			destinos.append(id)
	return destinos


@rpc("authority", "call_remote", "unreliable_ordered", CANAL_VOZ)
func _recibir_voz(paquete: PackedByteArray) -> void:
	if not puede_oir():
		return
	paquetes_recibidos += 1
	if _reproduccion == null:
		altavoz.stream = CodecVoz.crear_flujo()
		altavoz.play()
		_reproduccion = altavoz.get_stream_playback()
	_ultimo_paquete = Time.get_ticks_msec() / 1000.0
	if CodecVoz.en_cola(_reproduccion) > MAXIMO_EN_COLA:
		return
	CodecVoz.empujar(_reproduccion, paquete)
	if _esperando_colchon and CodecVoz.en_cola(_reproduccion) >= COLCHON_MUESTRAS:
		CodecVoz.reanudar(_reproduccion)
		_esperando_colchon = false
