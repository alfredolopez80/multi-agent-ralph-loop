# GitHub Actions CI/CD

Este directorio contiene los workflows de GitHub Actions para el proyecto **Multi-Agent Ralph Loop**.

## Workflows Disponibles

### `ci.yml` - Continuous Integration

Este workflow se ejecuta automáticamente en:
- **Push** a las ramas `main` y `develop`
- **Pull requests** dirigidas a `main` y `develop`

## Jobs

### 1. `validate` - Validación de Scripts

Valida la estructura y sintaxis de todos los scripts del proyecto:

| Paso | Descripción |
|------|-------------|
| `Install dependencies` | Instala `shellcheck`, `jq` y `curl` |
| `Validate shell syntax` | Verifica sintaxis de `scripts/ralph`, `scripts/ralph-doctor.sh` e `install.sh` |
| `Run shellcheck` | Analiza scripts bash en busca de problemas (severity=warning) |
| `Check executable permissions` | Asegura que hooks y scripts sean ejecutables |
| `Validate hooks structure` | Verifica que todos los hooks tengan extensión `.sh` |
| `Validate skills structure` | Confirma que cada skill tenga su archivo `SKILL.md` |

### 2. `test` - Ejecución de Tests

Ejecuta el suite de tests Python:

| Paso | Descripción |
|------|-------------|
| `Set up Python` | Configura Python 3.12 |
| `Install test dependencies` | Instala `pytest` y `pytest-cov` |
| `Run pytest` | Ejecuta todos los tests en el directorio `tests/` |

### 3. `health-check` - Verificación de Salud

Ejecuta el diagnóstico rápido del sistema:

| Paso | Descripción |
|------|-------------|
| `Run ralph-doctor` | Ejecuta `scripts/ralph-doctor.sh --quick` |

## Uso Manual

Para ejecutar el workflow manualmente desde la CLI de GitHub:

```bash
# Ver estado de los workflows
gh run list

# Ver logs de un run específico
gh run view <run-id>

# Re-ejecutar un workflow fallido
gh run rerun <run-id>
```

## Badges de Estado

Agrega este badge a tu README principal:

```markdown
![CI](https://github.com/USERNAME/multi-agent-ralph-loop/actions/workflows/ci.yml/badge.svg)
```

## Notas

- El workflow usa `|| true` en ciertos pasos para que los errores no bloqueen el CI completo
- `shellcheck` se ejecuta con `--severity=warning` para filtrar solo advertencias y errores
- Los tests Python son opcionales (solo se ejecutan si existe el directorio `tests/`)
