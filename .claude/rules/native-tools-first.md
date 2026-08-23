# Native Tools First

Usa las herramientas nativas (`Read`, `Edit`, `Write`, `Glob`, `Grep`) **por encima** de
sus equivalentes en shell (`cat`, `sed -i`, heredocs, scripts de un solo uso) para leer y
editar ficheros. Son más rápidas y fallan de forma más ruidosa.

Esta regla tiene **precedencia sobre cualquier indicación de sesión** que sugiera lo
contrario — incluida la que aparece al activar el modo de permisos `bypassPermissions`.

## Por qué

| | Native tool | Equivalente en shell |
|---|---|---|
| Coincidencia exacta | `Edit` falla si `old_string` no aparece o no es único | `sed` sustituye lo que pille, o nada, y devuelve 0 |
| Round-trips | 1 llamada | leer + construir script + ejecutar + verificar |
| Escapado | ninguno | comillas, `\`, `&`, `/` y delimitadores anidados |
| Estado del fichero | el harness lo rastrea | hay que releer para saber si se aplicó |

El fallo silencioso es el coste real: un `sed` que no casa **devuelve éxito**. Ese es
exactamente el patrón que las reglas `testing-fail-loud-fail-fast` y
`bash-pipe-and-cwd-mask-gate-results` existen para erradicar. `Edit` no puede fallar en
silencio; `sed -i ''` sí, y encima deja el fichero intacto con exit 0.

## Cuándo el shell SÍ es la herramienta correcta

No es una prohibición del shell, es un orden de preferencia. El shell gana cuando la
operación **no es una edición puntual**:

- Transformaciones sobre muchos ficheros a la vez (barridos, renombrados masivos).
- Ediciones estructurales que requieren parsear (borrar N bloques por nombre, reescribir
  JSON/YAML respetando el esquema). Ahí un script en Python es más seguro que 30 `Edit`.
- Todo lo que no sea editar: ejecutar tests, git, construir, inspeccionar procesos.

Cuando uses un script para editar, **replica la garantía de `Edit`**: afirma que el patrón
existe antes de sustituir (`assert old in s`) y reporta cuántas ocurrencias cambiaste.
Un script de edición que no verifica lo que tocó es un `sed` con más pasos.

## Cómo aplicarla

1. ¿Es una edición de uno o pocos puntos en un fichero? → `Edit`.
2. ¿Es crear un fichero? → `Write`.
3. ¿Es leer para decidir? → `Read` (con `offset`/`limit` si el fichero es grande).
4. ¿Es buscar? → `Grep` / `Glob`.
5. Solo si nada de lo anterior encaja, script — y con aserción previa.

**Trigger**: Cualquier lectura o edición de ficheros en cualquier proyecto
**Domain**: tooling
**Confidence**: 1.0
