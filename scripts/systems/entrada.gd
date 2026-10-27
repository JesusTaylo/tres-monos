class_name Entrada
## Modo de entrada: mouse y teclado (PC) o pantalla táctil (teléfono).
## En PC se puede forzar el modo táctil para probar con el argumento -- --tactil.
##
## En modo táctil Godot convierte cada toque en un clic de mouse "falso"
## (emulate_mouse_from_touch): los controles de juego deben ignorar esos eventos
## de mouse para que tocar la pantalla no cuente como "agarrar" ni mueva la cámara.

const ARGUMENTO_TACTIL := "--tactil"

## Lo mantiene MenuPausa: con el menú abierto no se juega.
static var menu_abierto := false


static func es_tactil() -> bool:
	return OS.has_feature("mobile") or ARGUMENTO_TACTIL in OS.get_cmdline_user_args()


## ¿Se está jugando (y no en un menú)? En PC además el mouse tiene que estar capturado.
static func jugando() -> bool:
	if menu_abierto:
		return false
	return es_tactil() or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED


## Eventos de mouse que en modo táctil vienen de un toque y hay que ignorar.
static func es_mouse_de_toque(evento: InputEvent) -> bool:
	return es_tactil() and (evento is InputEventMouseButton or evento is InputEventMouseMotion)
