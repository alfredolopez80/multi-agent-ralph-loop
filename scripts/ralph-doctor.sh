#!/bin/bash
#
# ralph-doctor.sh - Diagnóstico y verificación del sistema Ralph
# Versión: 1.0.0
#

set -euo pipefail

#==============================================================================
# CONFIGURACIÓN GLOBAL
#==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
RALPH_DIR="${HOME}/.ralph"
VERSION="1.0.0"

# Contadores globales
ERRORS=0
WARNINGS=0
CHECKS_PASSED=0

#==============================================================================
# FUNCIONES DE UTILIDAD
#==============================================================================

log_section() {
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "  $1"
    echo "═══════════════════════════════════════════════════════════════"
}

log_success() {
    echo "  ✅ $1"
}

log_error() {
    echo "  ❌ $1"
}

log_warn() {
    echo "  ⚠️  $1"
}

log_info() {
    echo "  ℹ️  $1"
}

#==============================================================================
# FUNCIÓN: check_dependencies()
# Verifica las dependencias requeridas y opcionales del sistema
#==============================================================================

check_dependencies() {
    log_section "Verificando Dependencias"
    
    local deps=("jq" "curl")
    local optional_deps=("claude" "codex" "gemini" "gh" "npx" "pyright" "ruff" "ast-grep")
    
    # Required dependencies
    for dep in "${deps[@]}"; do
        if command -v "$dep" &>/dev/null; then
            log_success "$dep instalado ($(command -v $dep))"
            ((CHECKS_PASSED++))
        else
            log_error "$dep NO encontrado (REQUERIDO)"
            ((ERRORS++))
        fi
    done
    
    # Optional dependencies
    for dep in "${optional_deps[@]}"; do
        if command -v "$dep" &>/dev/null; then
            log_success "$dep instalado (opcional)"
            ((CHECKS_PASSED++))
        else
            log_warn "$dep no instalado (opcional)"
            ((WARNINGS++))
        fi
    done
    
    # Check API keys (if config exists)
    if [ -f "${RALPH_DIR}/config/glm.json" ]; then
        if jq -e '.api_key' "${RALPH_DIR}/config/glm.json" &>/dev/null; then
            log_success "API Key de GLM-4.7 configurada"
            ((CHECKS_PASSED++))
        else
            log_warn "API Key de GLM-4.7 no configurada"
            ((WARNINGS++))
        fi
    fi
}

#==============================================================================
# FUNCIÓN: check_skills()
# Verifica la integridad de los skills en el repositorio
#==============================================================================

check_skills() {
    log_section "Verificando Skills"
    
    local skills_dir="${REPO_DIR}/.claude/skills"
    local broken_symlinks=0
    local missing_skillmd=0
    local total_skills=0
    
    # Check if skills directory exists
    if [ ! -d "$skills_dir" ]; then
        log_error "Directorio de skills no encontrado: $skills_dir"
        ((ERRORS++))
        return 1
    fi
    
    # Iterate through skills
    for skill_path in "$skills_dir"/*; do
        [ -e "$skill_path" ] || continue
        ((total_skills++))
        
        local skill_name=$(basename "$skill_path")
        
        # Check if it's a broken symlink
        if [ -L "$skill_path" ] && [ ! -e "$skill_path" ]; then
            log_error "Skill '$skill_name': SYMLINK ROTO → $skill_path"
            ((broken_symlinks++))
            ((ERRORS++))
            continue
        fi
        
        # Check if SKILL.md exists
        if [ ! -f "$skill_path/SKILL.md" ]; then
            log_warn "Skill '$skill_name': falta SKILL.md"
            ((missing_skillmd++))
            ((WARNINGS++))
        else
            log_success "Skill '$skill_name': OK"
            ((CHECKS_PASSED++))
        fi
    done
    
    log_info "Total skills verificados: $total_skills"
    
    if [ $broken_symlinks -eq 0 ] && [ $missing_skillmd -eq 0 ]; then
        log_success "Todos los skills están correctamente configurados"
    fi
}

#==============================================================================
# FUNCIÓN: check_tests()
# Verifica y ejecuta los tests del repositorio
#==============================================================================

check_tests() {
    log_section "Verificando Tests"
    
    local tests_dir="${REPO_DIR}/tests"
    
    # Check if test directory exists
    if [ ! -d "$tests_dir" ]; then
        log_warn "Directorio de tests no encontrado: $tests_dir"
        ((WARNINGS++))
        return 0
    fi
    
    # Run hooks tests if available
    if [ -f "${tests_dir}/test_hooks_comprehensive.py" ]; then
        log_info "Ejecutando tests de hooks..."
        if python -m pytest "${tests_dir}/test_hooks_comprehensive.py" -v --tb=short &>/dev/null; then
            log_success "Tests de hooks: PASARON"
            ((CHECKS_PASSED++))
        else
            log_warn "Tests de hooks: ALGUNOS FALLARON (ver logs)"
            ((WARNINGS++))
        fi
    else
        log_info "Tests de hooks no encontrados (opcional)"
    fi
    
    # Check command router tests
    if [ -f "${tests_dir}/test-command-router.sh" ]; then
        log_info "Ejecutando tests de command router..."
        if bash "${tests_dir}/test-command-router.sh" &>/dev/null; then
            log_success "Tests de command router: PASARON"
            ((CHECKS_PASSED++))
        else
            log_warn "Tests de command router: ALGUNOS FALLARON"
            ((WARNINGS++))
        fi
    fi
}

#==============================================================================
# FUNCIÓN: apply_fixes()
# Aplica correcciones automáticas al sistema
#==============================================================================

apply_fixes() {
    log_section "Aplicando Correcciones Automáticas"
    
    local hooks_dir="${REPO_DIR}/.claude/hooks"
    local fixes_applied=0
    
    # Fix permissions on hooks
    log_info "Corrigiendo permisos de hooks..."
    while IFS= read -r hook_file; do
        [ -n "$hook_file" ] || continue
        if [ ! -x "$hook_file" ]; then
            chmod +x "$hook_file"
            log_success "Permisos corregidos: $(basename "$hook_file")"
            ((fixes_applied++))
        fi
    done < <(find "$hooks_dir" -name "*.sh" -type f)
    
    # Create missing directories
    local required_dirs=(
        "${RALPH_DIR}/logs"
        "${RALPH_DIR}/memory"
    )
    
    for dir in "${required_dirs[@]}"; do
        if [ ! -d "$dir" ]; then
            mkdir -p "$dir"
            chmod 700 "$dir"
            log_success "Directorio creado: $dir"
            ((fixes_applied++))
        fi
    done
    
    if [ $fixes_applied -eq 0 ]; then
        log_info "No se encontraron issues para corregir"
    else
        log_success "Total correcciones aplicadas: $fixes_applied"
    fi
}

#==============================================================================
# FUNCIÓN: generate_report()
# Genera reportes en formato JSON y Markdown
#==============================================================================

generate_report() {
    log_section "Generando Reporte"
    
    local report_dir="${RALPH_DIR}/logs"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local report_file="${report_dir}/doctor-report-${timestamp}.json"
    
    mkdir -p "$report_dir"
    
    # Generate JSON report
    cat > "$report_file" << EOF
{
    "version": "${VERSION}",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "summary": {
        "checks_passed": ${CHECKS_PASSED},
        "warnings": ${WARNINGS},
        "errors": ${ERRORS},
        "status": "$([ $ERRORS -eq 0 ] && echo "HEALTHY" || echo "UNHEALTHY")"
    },
    "system": {
        "hostname": "$(hostname)",
        "user": "$(whoami)",
        "ralph_dir": "${RALPH_DIR}",
        "repo_dir": "${REPO_DIR}"
    }
}
EOF
    
    log_success "Reporte generado: $report_file"
    
    # Also generate markdown report
    local md_report="${report_dir}/doctor-report-${timestamp}.md"
    cat > "$md_report" << EOF
# Ralph Doctor Report

**Generated:** $(date -u +%Y-%m-%dT%H:%M:%SZ)  
**Version:** ${VERSION}

## Summary

| Metric | Value |
|--------|-------|
| Status | $([ $ERRORS -eq 0 ] && echo "✅ HEALTHY" || echo "❌ UNHEALTHY") |
| Checks Passed | ${CHECKS_PASSED} |
| Warnings | ${WARNINGS} |
| Errors | ${ERRORS} |

## System Info

- **Hostname:** $(hostname)
- **User:** $(whoami)
- **Ralph Directory:** ${RALPH_DIR}
- **Repo Directory:** ${REPO_DIR}

---

*Report generated by ralph doctor v${VERSION}*
EOF
    
    log_success "Reporte Markdown: $md_report"
}

#==============================================================================
# FUNCIÓN: check_hooks()
# Verifica los hooks de Claude Code
#==============================================================================

check_hooks() {
    log_section "Verificando Hooks"
    
    local hooks_dir="${REPO_DIR}/.claude/hooks"
    local not_executable=0
    local syntax_errors=0
    local total_hooks=0
    
    # Check if hooks directory exists
    if [ ! -d "$hooks_dir" ]; then
        log_error "Directorio de hooks no encontrado: $hooks_dir"
        ((ERRORS++))
        return 1
    fi
    
    # Count total hooks
    total_hooks=$(find "$hooks_dir" -name "*.sh" -type f | wc -l)
    log_info "Total hooks encontrados: $total_hooks"
    
    # Check each hook
    while IFS= read -r hook_file; do
        [ -n "$hook_file" ] || continue
        
        local hook_name=$(basename "$hook_file")
        local has_error=false
        
        # Check if executable
        if [ ! -x "$hook_file" ]; then
            log_warn "Hook '$hook_name': no es ejecutable"
            ((not_executable++))
            ((WARNINGS++))
            has_error=true
        fi
        
        # Check bash syntax
        if ! bash -n "$hook_file" 2>/dev/null; then
            log_error "Hook '$hook_name': error de sintaxis bash"
            ((syntax_errors++))
            ((ERRORS++))
            has_error=true
        fi
        
        if [ "$has_error" = false ]; then
            ((CHECKS_PASSED++))
        fi
        
    done < <(find "$hooks_dir" -name "*.sh" -type f)
    
    # Summary
    if [ $not_executable -gt 0 ]; then
        log_warn "$not_executable hooks no son ejecutables (usar: chmod +x)"
    fi
    
    if [ $syntax_errors -gt 0 ]; then
        log_error "$syntax_errors hooks tienen errores de sintaxis"
    fi
    
    if [ $not_executable -eq 0 ] && [ $syntax_errors -eq 0 ]; then
        log_success "Todos los hooks ($total_hooks) son válidos"
    fi
}

#==============================================================================
# FUNCIÓN: check_configuration()
# Verifica la configuración del sistema Ralph
#==============================================================================

check_configuration() {
    log_section "Verificando Configuración"
    
    # Check ~/.ralph directory structure
    local required_dirs=(
        "${RALPH_DIR}"
        "${RALPH_DIR}/config"
        "${RALPH_DIR}/logs"
        "${RALPH_DIR}/memory"
    )
    
    for dir in "${required_dirs[@]}"; do
        if [ -d "$dir" ]; then
            log_success "Directorio existe: $(basename "$dir")"
            ((CHECKS_PASSED++))
        else
            log_warn "Directorio no existe: $dir (se creará si es necesario)"
            ((WARNINGS++))
        fi
    done
    
    # Check config files
    if [ -f "${RALPH_DIR}/config/models.json" ]; then
        if jq empty "${RALPH_DIR}/config/models.json" 2>/dev/null; then
            log_success "config/models.json: válido"
            ((CHECKS_PASSED++))
        else
            log_error "config/models.json: JSON inválido"
            ((ERRORS++))
        fi
    else
        log_warn "config/models.json: no existe"
        ((WARNINGS++))
    fi
    
    # Check settings.json.example exists in repo
    if [ -f "${REPO_DIR}/.claude/settings.json.example" ]; then
        log_success "settings.json.example: existe"
        ((CHECKS_PASSED++))
    else
        log_warn "settings.json.example: no existe"
        ((WARNINGS++))
    fi
    
    # Check if Claude Code is configured
    if [ -f "${CLAUDE_DIR}/settings.json" ]; then
        log_success "Claude Code settings.json: configurado"
        ((CHECKS_PASSED++))
    else
        log_warn "Claude Code settings.json: no configurado (ejecutar install.sh)"
        ((WARNINGS++))
    fi
}

#==============================================================================
# FUNCIÓN PRINCIPAL
#=============

main() {
    echo ""
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║                    🔧 RALPH DOCTOR v1.0.0                     ║"
    echo "║            Diagnóstico del sistema Multi-Agent Ralph           ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo ""
    
    # Ejecutar verificaciones
    check_dependencies
    check_skills
    check_hooks
    check_configuration
    check_tests
    
    # Aplicar correcciones automáticas
    apply_fixes
    
    # Generar reportes
    generate_report
    
    # Resumen final
    log_section "Resumen del Diagnóstico"
    log_info "Checks pasados: $CHECKS_PASSED"
    log_info "Advertencias: $WARNINGS"
    log_info "Errores: $ERRORS"
    echo ""
    
    if [ $ERRORS -eq 0 ]; then
        echo "  ✅ Sistema saludable"
        exit 0
    else
        echo "  ❌ Se encontraron problemas. Revisa los errores arriba."
        exit 1
    fi
}

# Ejecutar si se llama directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
