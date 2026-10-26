extends Node
## Sistema de ruido (autoload "Ruido"). Cualquier peer emite un NoiseEvent
## y le llega a quien lo necesita: el Ciego, que lo convierte en siluetas.
## Va por RPC no confiable: si se pierde un paso, no importa.

signal ruido_recibido(evento: NoiseEvent)


## Emite un ruido. Lo llama quien lo produce: cada jugador sus pasos,
## el host los golpes de objetos (porque él simula la física).
func emitir(posicion: Vector3, radio: float, intensidad: float = 1.0) -> void:
	var mi_id := multiplayer.get_unique_id()
	for id in _destinos():
		if id == mi_id:
			_recibir(posicion, radio, intensidad)
		else:
			_recibir.rpc_id(id, posicion, radio, intensidad)


## Los Ciegos de la partida. Sin roles (nivel abierto suelto) solo uno mismo.
func _destinos() -> Array[int]:
	if not Lobby.roles_asignados():
		return [multiplayer.get_unique_id()]
	var ciegos: Array[int] = []
	for id in Lobby.roles:
		if Lobby.roles[id] == Roles.Rol.CIEGO:
			ciegos.append(id)
	return ciegos


@rpc("any_peer", "call_remote", "unreliable")
func _recibir(posicion: Vector3, radio: float, intensidad: float) -> void:
	ruido_recibido.emit(NoiseEvent.new(posicion, radio, intensidad))
