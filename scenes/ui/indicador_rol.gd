extends Control
## Indicador fijo del rol propio ("Eres el CIEGO") en el HUD.
## Se actualiza solo cuando cambian los roles (rotación entre rondas).

const COLORES := {
	Roles.Rol.MUDO: Color(1, 0.82, 0.3),
	Roles.Rol.SORDO: Color(0.45, 0.75, 1),
	Roles.Rol.CIEGO: Color(0.8, 0.6, 1),
}

@onready var _nombre: Label = %nombre_rol
@onready var _pista: Label = %pista_rol


func _ready() -> void:
	Lobby.estado_cambiado.connect(_actualizar)
	_actualizar()


func _actualizar() -> void:
	var rol := Lobby.mi_rol()
	visible = rol != -1
	if rol == -1:
		return
	_nombre.text = "Eres el %s" % Roles.nombre(rol)
	_nombre.add_theme_color_override("font_color", COLORES[rol])
	_pista.text = Roles.pista(rol)
