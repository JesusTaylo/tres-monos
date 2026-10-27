extends Node
## Conexión de red (autoload "Red").
## Crea el host o el cliente con ENet y reemite las señales de multiplayer
## para que la UI y el lobby no tengan que tocar la API de bajo nivel.
##
## Al conectarse, cliente y host pasan por un saludo (autenticación de
## SceneMultiplayer) donde el host acepta o rechaza con un motivo.
## Un rechazado nunca llega a estar "conectado": no recibe RPCs ni replicación.

signal servidor_creado
signal conexion_exitosa
## Se emite siempre que se cierra la conexión, por cualquier motivo
## (ver motivo_desconexion).
signal desconectado
signal jugador_conectado(id: int)
signal jugador_desconectado(id: int)
## Host: un peer que estaba en el saludo se fue o tardó demasiado.
signal saludo_fallido(id: int)

const PUERTO_POR_DEFECTO := 7777
## Jugadores totales, incluido el host.
const MAX_JUGADORES := 3
## Conexiones que acepta ENet. Hay margen sobre MAX_JUGADORES para que los que
## sobran puedan llegar al saludo y enterarse de por qué se los rechaza.
const MAX_CONEXIONES := MAX_JUGADORES + 3

## Por qué se perdió la conexión, para mostrarlo en el menú.
var motivo_desconexion := ""
## Host: decide si un peer puede entrar. Recibe el id y devuelve "" para
## aceptarlo o el motivo del rechazo. Lo asigna el Lobby.
var validar_entrada: Callable = func(_id: int) -> String: return ""

@onready var _multijugador := multiplayer as SceneMultiplayer


func _ready() -> void:
	_multijugador.auth_callback = _al_recibir_saludo
	_multijugador.peer_authenticating.connect(_al_empezar_saludo)
	_multijugador.peer_authentication_failed.connect(saludo_fallido.emit)
	multiplayer.peer_connected.connect(jugador_conectado.emit)
	multiplayer.peer_disconnected.connect(jugador_desconectado.emit)
	multiplayer.connected_to_server.connect(conexion_exitosa.emit)
	multiplayer.connection_failed.connect(_al_fallar_conexion)
	multiplayer.server_disconnected.connect(_al_desconectarse_servidor)


## Crea el servidor. El host también es jugador.
func hospedar(puerto: int = PUERTO_POR_DEFECTO) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(puerto, MAX_CONEXIONES)
	if error != OK:
		return error
	multiplayer.multiplayer_peer = peer
	motivo_desconexion = ""
	servidor_creado.emit()
	return OK


## Intenta conectarse a un host. Si falla o lo rechazan, llega desconectado.
func unirse(ip: String, puerto: int = PUERTO_POR_DEFECTO) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(ip, puerto)
	if error != OK:
		return error
	multiplayer.multiplayer_peer = peer
	motivo_desconexion = ""
	return OK


func desconectar() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	desconectado.emit()


## Convierte un nombre (por ejemplo un túnel de playit.gg) en IP sin congelar
## el juego: si no existe puede tardar varios segundos. Usar con await.
## Devuelve "" si no se encontró.
func resolver(direccion: String) -> String:
	if direccion.is_valid_ip_address():
		return direccion
	var id := IP.resolve_hostname_queue_item(direccion, IP.TYPE_IPV4)
	while IP.get_resolve_item_status(id) == IP.RESOLVER_STATUS_WAITING:
		await get_tree().process_frame
	var ip := ""
	if IP.get_resolve_item_status(id) == IP.RESOLVER_STATUS_DONE:
		ip = IP.get_resolve_item_address(id)
	IP.erase_resolve_item(id)
	return ip


## Separa "direccion" o "direccion:puerto" en [direccion, puerto].
## Devuelve [] si el texto no tiene forma de dirección o el puerto no es válido.
static func separar_direccion(texto: String) -> Array:
	var direccion := texto.strip_edges()
	var puerto := PUERTO_POR_DEFECTO
	if direccion.count(":") == 1:
		var partes := direccion.split(":")
		direccion = partes[0]
		if not partes[1].is_valid_int():
			return []
		puerto = partes[1].to_int()
		if puerto < 1 or puerto > 65535:
			return []
	if direccion.is_empty() or direccion.contains(" "):
		return []
	return [direccion, puerto]


## IPs IPv4 privadas de esta máquina, para decírselas a los demás jugadores.
func ips_locales() -> PackedStringArray:
	var resultado := PackedStringArray()
	for ip in IP.get_local_addresses():
		if ip.begins_with("192.168.") or ip.begins_with("10.") or ip.begins_with("172."):
			resultado.append(ip)
	return resultado


## El cliente abre el saludo; el host espera a que le hablen.
func _al_empezar_saludo(id: int) -> void:
	if not multiplayer.is_server():
		_multijugador.send_auth(id, var_to_bytes({}))


func _al_recibir_saludo(id: int, datos: PackedByteArray) -> void:
	if multiplayer.is_server():
		var motivo: String = validar_entrada.call(id)
		_multijugador.send_auth(id, var_to_bytes({"motivo": motivo}))
		if motivo.is_empty():
			_multijugador.complete_auth(id)
		# Si se rechaza, el cliente se desconecta solo; si no, lo corta auth_timeout.
		return
	var respuesta = bytes_to_var(datos)
	var motivo: String = respuesta.get("motivo", "Respuesta inválida del host") \
		if respuesta is Dictionary else "Respuesta inválida del host"
	if motivo.is_empty():
		_multijugador.complete_auth(id)
	else:
		motivo_desconexion = motivo
		desconectar()


func _al_fallar_conexion() -> void:
	motivo_desconexion = "No se pudo conectar (¿IP correcta?)"
	desconectar()


func _al_desconectarse_servidor() -> void:
	motivo_desconexion = "El host se desconectó"
	desconectar()
