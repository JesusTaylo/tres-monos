# TwoVoIP v6.5 (fijado)

- Origen: https://github.com/goatchurchprime/two-voip-godot-4/releases/tag/v6.5
- SHA-256 del zip oficial: 811ac96d4b75314f90855e3136f9939f7a4bc4a01e51850640cff967afc20fc7
- Solo se incluyen los binarios de Windows x86_64 (debug y release). Para otras
  plataformas, copiar sus archivos de `libs/` desde el mismo zip.

**No actualizar a v6.6** hasta que se publique el arreglo del issue #107: en v6.6 el
editor de Godot 4.7 se cierra al abrir el proyecto (división por cero en
`current_chunk`, solo en x86_64). Ver https://github.com/goatchurchprime/two-voip-godot-4/issues/107

Licencias: `LICENSE` (TwoVoIP, MIT) y las de las bibliotecas compiladas dentro de la DLL:
`LICENSE.opus`, `LICENSE.rnnoise`, `LICENSE.speexdsp` (BSD).
