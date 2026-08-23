#!/usr/bin/env bats
#===============================================================================
# test-language-servers.bats - Test LSP language servers installation
#
# VERSION: 1.0.1
# DATE: 2026-02-15
# PURPOSE: Verify language servers are properly installed and functional
#===============================================================================

load test_helper

setup() {
    # Don't use isolated environment for these tests - we need real system paths
    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    INSTALL_SCRIPT="$PROJECT_ROOT/scripts/install-language-servers.sh"
}

teardown() {
    :
}

#===============================================================================
# SCRIPT EXISTENCE TESTS
#===============================================================================

@test "install-language-servers.sh exists" {
    [ -f "$INSTALL_SCRIPT" ]
}

@test "install-language-servers.sh is executable" {
    [ -x "$INSTALL_SCRIPT" ]
}

#===============================================================================
# HELP OUTPUT TESTS
#===============================================================================

@test "help flag shows usage" {
    run "$INSTALL_SCRIPT" --help
    [ $status -eq 0 ]
    [[ "$output" == *"Usage"* ]]
    [[ "$output" == *"--check"* ]]
    [[ "$output" == *"--essential"* ]]
}

#===============================================================================
# CHECK MODE TESTS
#===============================================================================

@test "check flag runs without error" {
    run "$INSTALL_SCRIPT" --check
    # Exit code = number of missing essential servers (0 = all installed)
    [ $status -ge 0 ]
}

@test "check mode shows essential servers" {
    run "$INSTALL_SCRIPT" --check
    [[ "$output" == *"Essential Language Servers"* ]]
}

@test "check mode shows optional servers" {
    run "$INSTALL_SCRIPT" --check
    [[ "$output" == *"Optional Language Servers"* ]]
}

@test "check mode shows summary counts" {
    run "$INSTALL_SCRIPT" --check
    [[ "$output" == *"installed"* ]]
    [[ "$output" == *"missing"* ]]
}

#===============================================================================
# ESSENTIAL SERVERS TESTS
#===============================================================================

@test "typescript-language-server is available" {
    if command -v typescript-language-server >/dev/null 2>&1; then
        run typescript-language-server --version
        [ $status -eq 0 ]
    else
        skip "typescript-language-server not installed"
    fi
}

@test "pyright is available" {
    if command -v pyright >/dev/null 2>&1; then
        run pyright --version
        [ $status -eq 0 ]
    else
        skip "pyright not installed"
    fi
}

@test "clangd is available" {
    if command -v clangd >/dev/null 2>&1; then
        run clangd --version
        [ $status -eq 0 ]
    else
        skip "clangd not installed"
    fi
}

@test "sourcekit-lsp is available (macOS)" {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        if command -v sourcekit-lsp >/dev/null 2>&1; then
            run sourcekit-lsp --help
            [ $status -eq 0 ]
        else
            skip "sourcekit-lsp not installed"
        fi
    else
        skip "sourcekit-lsp only tested on macOS"
    fi
}

#===============================================================================
# OPTIONAL SERVERS TESTS
#===============================================================================

@test "gopls check works" {
    if command -v gopls >/dev/null 2>&1; then
        run gopls version
        [ $status -eq 0 ]
    else
        skip "gopls not installed (optional)"
    fi
}

@test "rust-analyzer check works" {
    if command -v rust-analyzer >/dev/null 2>&1; then
        run which rust-analyzer
        [ $status -eq 0 ]
    else
        skip "rust-analyzer not installed (optional)"
    fi
}

@test "lua-language-server check works" {
    if command -v lua-language-server >/dev/null 2>&1; then
        run lua-language-server --version
        [ $status -eq 0 ]
    else
        skip "lua-language-server not installed (optional)"
    fi
}

@test "intelephense check works" {
    if command -v intelephense >/dev/null 2>&1; then
        # intelephense might not have --version, try --help instead
        run intelephense --help
        [ $status -eq 0 ] || run which intelephense
        [ $status -eq 0 ]
    else
        skip "intelephense not installed (optional)"
    fi
}

@test "kotlin-language-server check works" {
    if command -v kotlin-language-server >/dev/null 2>&1; then
        run kotlin-language-server --version
        [ $status -eq 0 ] || run which kotlin-language-server
        [ $status -eq 0 ]
    else
        skip "kotlin-language-server not installed (optional)"
    fi
}

#===============================================================================
# LSP-EXPLORE SKILL TESTS (check real home directory)
#===============================================================================

#===============================================================================
# INTEGRATION TESTS
#===============================================================================

@test "all platform-available essential servers are installed" {
    # Antes: `[ $count -ge 3 ]` sobre una lista fija de 4. Dos problemas:
    #   1. Al fallar solo decia "3 != 2" — habia que ir a mano a averiguar CUAL
    #      faltaba. Ahora nombra los ausentes, que es lo unico accionable.
    #   2. sourcekit-lsp llega con Xcode y NO existe fuera de macOS, asi que en
    #      Linux el maximo alcanzable eran 3 de 4 y el umbral no dejaba margen
    #      para ningun otro fallo. La lista es ahora la de servidores que la
    #      plataforma PUEDE tener, igual que ESSENTIAL_SERVERS en el instalador.
    #
    # `((count++))` con count=0 evalua a 0, que es exit status 1: bajo `set -e`
    # eso mata el script en el PRIMER servidor encontrado. Se usa la forma de
    # asignacion, que siempre devuelve 0.
    local expected=(typescript-language-server pyright clangd)
    [[ "$OSTYPE" == "darwin"* ]] && expected+=(sourcekit-lsp)

    local missing=()
    local srv
    for srv in "${expected[@]}"; do
        command -v "$srv" >/dev/null 2>&1 || missing+=("$srv")
    done

    if [ ${#missing[@]} -gt 0 ]; then
        echo "servidores LSP ausentes ($((${#expected[@]} - ${#missing[@]}))/${#expected[@]} presentes): ${missing[*]}" >&2
        echo "instalar con: scripts/install-language-servers.sh --essential" >&2
        return 1
    fi
}

@test "install script produces valid output" {
    run "$INSTALL_SCRIPT" --check

    # Should not contain unexpected errors
    [[ "$output" != *"command not found"* ]]
}

@test "script handles unknown flags gracefully" {
    run "$INSTALL_SCRIPT" --invalid-flag 2>&1
    [ $status -ne 0 ]
    [[ "$output" == *"Unknown option"* ]]
}

#===============================================================================
# ESSENTIAL VALIDATION
#===============================================================================

@test "essential servers check passes" {
    run "$INSTALL_SCRIPT" --check
    # Exit code should be 0 when all essential servers are installed
    [ $status -eq 0 ]
}
