class_name Roles
## Los tres roles del juego y sus textos para mostrar.

enum Rol { MUDO, SORDO, CIEGO }

const TODOS: Array[Rol] = [Rol.MUDO, Rol.SORDO, Rol.CIEGO]

const NOMBRES := {
	Rol.MUDO: "MUDO",
	Rol.SORDO: "SORDO",
	Rol.CIEGO: "CIEGO",
}

const DESCRIPCIONES := {
	Rol.MUDO: "Ves todo, incluido el objetivo. No oyes ni hablas: comunícate con gestos.",
	Rol.SORDO: "Ves a los demás, pero no el objetivo. No oyes: traduce los gestos del Mudo en voz.",
	Rol.CIEGO: "No ves casi nada, solo siluetas cuando hay ruido. Escucha al Sordo y actúa.",
}

## Recordatorio corto para el indicador del HUD.
const PISTAS := {
	Rol.MUDO: "Ves el objetivo · no oyes · solo gestos",
	Rol.SORDO: "No ves el objetivo · no oyes · habla",
	Rol.CIEGO: "Solo ves el ruido · escucha y actúa",
}


static func nombre(rol: int) -> String:
	return NOMBRES.get(rol, "?")


static func descripcion(rol: int) -> String:
	return DESCRIPCIONES.get(rol, "")


static func pista(rol: int) -> String:
	return PISTAS.get(rol, "")
