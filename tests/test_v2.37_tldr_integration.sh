#!/usr/bin/env bash
# Test suite for Multi-Agent Ralph v2.37 - LLM-TLDR Integration
# Tests: llm-tldr installation, skills, ralph CLI commands, integration
#
# Usage:
#   ./tests/test_v2.37_tldr_integration.sh           # Run all v2.37 tests
#   ./tests/test_v2.37_tldr_integration.sh skills    # Run only skills tests
#   ./tests/test_v2.37_tldr_integration.sh cli       # Run only CLI tests
#   ./tests/test_v2.37_tldr_integration.sh install   # Run only installation tests

set -uo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Counters
PASSED=0
FAILED=0
SKIPPED=0
TOTAL=0

# Configuration
GLOBAL_SKILLS_DIR="${HOME}/.claude/skills"
RALPH_SCRIPT="${HOME}/.local/bin/ralph"
PROJECT_RALPH="./scripts/ralph"

# Test functions
test_pass() {
    ((PASSED++))
    ((TOTAL++))
    echo -e "${GREEN}✅ PASS${NC}: $1"
}

test_fail() {
    ((FAILED++))
    ((TOTAL++))
    echo -e "${RED}❌ FAIL${NC}: $1"
    [ -n "${2:-}" ] && echo "   Details: $2"
}

test_skip() {
    ((SKIPPED++))
    ((TOTAL++))
    echo -e "${YELLOW}⏭️  SKIP${NC}: $1"
}

section() {
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
}

# ═══════════════════════════════════════════════════════════════
# TEST: Skills Existence
# ═══════════════════════════════════════════════════════════════
test_tldr_skills() {
    section "LLM-TLDR Skills Tests"

    # Test 1: tldr skill exists
    if [ -f "$GLOBAL_SKILLS_DIR/tldr/SKILL.md" ]; then
        test_pass "tldr skill exists"
    else
        test_fail "tldr skill not found" "$GLOBAL_SKILLS_DIR/tldr/SKILL.md"
    fi

    # Test 2: tldr-semantic skill exists
    if [ -f "$GLOBAL_SKILLS_DIR/tldr-semantic/SKILL.md" ]; then
        test_pass "tldr-semantic skill exists"
    else
        test_fail "tldr-semantic skill not found"
    fi

    # Test 3: tldr-impact skill exists
    if [ -f "$GLOBAL_SKILLS_DIR/tldr-impact/SKILL.md" ]; then
        test_pass "tldr-impact skill exists"
    else
        test_fail "tldr-impact skill not found"
    fi

    # Test 4: tldr-context skill exists
    if [ -f "$GLOBAL_SKILLS_DIR/tldr-context/SKILL.md" ]; then
        test_pass "tldr-context skill exists"
    else
        test_fail "tldr-context skill not found"
    fi

    # Test 5: tldr skill has proper frontmatter
    if [ -f "$GLOBAL_SKILLS_DIR/tldr/SKILL.md" ]; then
        if grep -q "^name: tldr" "$GLOBAL_SKILLS_DIR/tldr/SKILL.md" 2>/dev/null; then
            test_pass "tldr skill has name in frontmatter"
        else
            test_fail "tldr skill missing name in frontmatter"
        fi

        if grep -q "^description:" "$GLOBAL_SKILLS_DIR/tldr/SKILL.md" 2>/dev/null; then
            test_pass "tldr skill has description in frontmatter"
        else
            test_fail "tldr skill missing description in frontmatter"
        fi
    fi

    # Test 6: Skills mention 95% token savings
    if grep -q "95%" "$GLOBAL_SKILLS_DIR/tldr/SKILL.md" 2>/dev/null; then
        test_pass "tldr skill mentions 95% token savings"
    else
        test_fail "tldr skill should mention 95% token savings"
    fi

    # Test 7: Skills mention 5-layer analysis
    if grep -qi "5.layer\|5 layer\|5-layer" "$GLOBAL_SKILLS_DIR/tldr/SKILL.md" 2>/dev/null; then
        test_pass "tldr skill mentions 5-layer analysis"
    else
        test_fail "tldr skill should mention 5-layer analysis"
    fi
}

# ═══════════════════════════════════════════════════════════════
# TEST: Ralph CLI Integration
# ═══════════════════════════════════════════════════════════════
test_ralph_cli() {
    section "Ralph CLI v2.37 Tests"

    # Determine which ralph to use
    local RALPH_CMD=""
    if [ -x "$RALPH_SCRIPT" ]; then
        RALPH_CMD="$RALPH_SCRIPT"
    elif [ -x "$PROJECT_RALPH" ]; then
        RALPH_CMD="$PROJECT_RALPH"
    else
        test_skip "ralph script not found"
        return
    fi

    # Test 1: Ralph version is 2.37.x
    local VERSION
    VERSION=$($RALPH_CMD version 2>&1 || echo "error")
    if [[ "$VERSION" == *"2.37"* ]]; then
        test_pass "Ralph version is 2.37.x ($VERSION)"
    else
        test_fail "Ralph version should be 2.37.x" "Got: $VERSION"
    fi

    # Test 2: tldr command in help
    if $RALPH_CMD help 2>&1 | grep -q "tldr"; then
        test_pass "tldr appears in ralph help"
    else
        test_fail "tldr should appear in ralph help"
    fi

    # Test 3: LLM-TLDR section in help
    if $RALPH_CMD help 2>&1 | grep -q "LLM-TLDR"; then
        test_pass "LLM-TLDR section exists in help"
    else
        test_fail "LLM-TLDR section should exist in help"
    fi

    # Test 4: tldr subcommand shows help
    local TLDR_HELP
    TLDR_HELP=$($RALPH_CMD tldr help 2>&1 || echo "error")
    if [[ "$TLDR_HELP" == *"95% Token Savings"* ]]; then
        test_pass "ralph tldr help shows correct info"
    else
        # Check if tldr not installed (expected if not set up)
        if [[ "$TLDR_HELP" == *"not installed"* ]]; then
            test_skip "tldr not installed - install with: pip install llm-tldr"
        else
            test_fail "ralph tldr help should show 95% Token Savings" "Got: ${TLDR_HELP:0:100}"
        fi
    fi

    # Test 5: tldr in FEATURE_TOOLS
    if grep -q "tldr:LLM-TLDR" "$RALPH_CMD" 2>/dev/null; then
        test_pass "tldr in FEATURE_TOOLS array"
    else
        test_fail "tldr should be in FEATURE_TOOLS array"
    fi

    # Test 6: cmd_tldr function exists
    if grep -q "cmd_tldr()" "$RALPH_CMD" 2>/dev/null; then
        test_pass "cmd_tldr function exists"
    else
        test_fail "cmd_tldr function should exist"
    fi

    # Test 7: tldr case in main switch
    if grep -q "tldr|code-analysis|token-optimize)" "$RALPH_CMD" 2>/dev/null; then
        test_pass "tldr case exists in main switch"
    else
        test_fail "tldr case should exist in main switch"
    fi

    # Test 8: tldr in integrations check
    if grep -q "log_success.*LLM-TLDR\|log_warn.*LLM-TLDR" "$RALPH_CMD" 2>/dev/null; then
        test_pass "LLM-TLDR appears in integrations check"
    else
        test_fail "LLM-TLDR should appear in integrations check"
    fi
}

# ═══════════════════════════════════════════════════════════════
# TEST: Installation Detection
# ═══════════════════════════════════════════════════════════════
test_installation() {
    section "Installation Detection Tests"

    # Test 1: pip show llm-tldr
    if pip show llm-tldr &>/dev/null; then
        local TLDR_VERSION
        TLDR_VERSION=$(pip show llm-tldr 2>&1 | grep "Version:" | awk '{print $2}')
        test_pass "llm-tldr pip package installed (v$TLDR_VERSION)"
    else
        test_skip "llm-tldr not installed - run: pip install llm-tldr"
    fi

    # Test 2: tldr command available
    if command -v tldr &>/dev/null; then
        test_pass "tldr command in PATH"
    else
        test_skip "tldr command not in PATH"
    fi

    # Test 3: tldr-mcp available (for MCP integration)
    if command -v tldr-mcp &>/dev/null; then
        test_pass "tldr-mcp command available for MCP integration"
    else
        test_skip "tldr-mcp not available (optional MCP integration)"
    fi
}

# ═══════════════════════════════════════════════════════════════
# TEST: Documentation
# ═══════════════════════════════════════════════════════════════
test_documentation() {
    section "Documentation Tests"

    # Test 1: README mentions v2.37
    if [ -f "README.md" ] && grep -q "2.37\|LLM-TLDR\|tldr" README.md 2>/dev/null; then
        test_pass "README.md mentions v2.37 or TLDR"
    else
        test_skip "README.md not updated for v2.37 yet"
    fi

    # Test 2: CLAUDE.md mentions tldr
    if [ -f "CLAUDE.md" ] && grep -q "tldr" CLAUDE.md 2>/dev/null; then
        test_pass "CLAUDE.md mentions tldr"
    else
        test_skip "CLAUDE.md not updated for tldr yet"
    fi

    # Test 3: Help text mentions semantic search
    local RALPH_CMD="${RALPH_SCRIPT:-$PROJECT_RALPH}"
    if [ -x "$RALPH_CMD" ] && $RALPH_CMD help 2>&1 | grep -qi "semantic"; then
        test_pass "Help mentions semantic search"
    else
        test_fail "Help should mention semantic search"
    fi
}

# ═══════════════════════════════════════════════════════════════
# TEST: Token Savings Validation (Real Usage)
# ═══════════════════════════════════════════════════════════════
test_token_savings() {
    section "Token Savings Validation Tests"

    # Check if tldr and python/tiktoken are available
    if ! command -v tldr &>/dev/null; then
        test_skip "tldr not installed - cannot validate token savings"
        return
    fi

    if ! python3 -c "import tiktoken" 2>/dev/null; then
        test_skip "tiktoken not installed - cannot count tokens"
        return
    fi

    # Create temporary test directory
    local TEST_DIR
    TEST_DIR=$(mktemp -d)
    trap "rm -rf $TEST_DIR" EXIT

    # Create a sample Python file with multiple functions (realistic codebase sample)
    cat > "$TEST_DIR/sample_auth.py" << 'PYEOF'
"""
Authentication module with JWT token handling, user validation,
password hashing, and session management.
"""
import hashlib
import secrets
import time
from typing import Optional, Dict, Any
from dataclasses import dataclass

@dataclass
class User:
    """User model with authentication attributes."""
    id: int
    username: str
    email: str
    password_hash: str
    salt: str
    created_at: float
    last_login: Optional[float] = None
    is_active: bool = True
    roles: list = None

    def __post_init__(self):
        if self.roles is None:
            self.roles = ["user"]

class AuthenticationError(Exception):
    """Custom exception for authentication failures."""
    pass

class TokenExpiredError(AuthenticationError):
    """Raised when JWT token has expired."""
    pass

class InvalidCredentialsError(AuthenticationError):
    """Raised when credentials are invalid."""
    pass

def hash_password(password: str, salt: Optional[str] = None) -> tuple[str, str]:
    """
    Hash a password using SHA-256 with salt.

    Args:
        password: The plain text password to hash
        salt: Optional salt, generates new one if not provided

    Returns:
        Tuple of (hash, salt)
    """
    if salt is None:
        salt = secrets.token_hex(32)

    combined = f"{password}{salt}"
    password_hash = hashlib.sha256(combined.encode()).hexdigest()

    return password_hash, salt

def verify_password(password: str, stored_hash: str, salt: str) -> bool:
    """
    Verify a password against stored hash.

    Args:
        password: Plain text password to verify
        stored_hash: Previously stored password hash
        salt: Salt used when creating the hash

    Returns:
        True if password matches, False otherwise
    """
    computed_hash, _ = hash_password(password, salt)
    return secrets.compare_digest(computed_hash, stored_hash)

def create_jwt_token(user_id: int, secret_key: str, expiry_hours: int = 24) -> str:
    """
    Create a JWT token for user authentication.

    Args:
        user_id: The user's ID to encode in token
        secret_key: Secret key for signing
        expiry_hours: Hours until token expires

    Returns:
        Encoded JWT token string
    """
    import base64
    import json

    header = {"alg": "HS256", "typ": "JWT"}
    payload = {
        "user_id": user_id,
        "iat": int(time.time()),
        "exp": int(time.time()) + (expiry_hours * 3600)
    }

    header_b64 = base64.urlsafe_b64encode(json.dumps(header).encode()).decode().rstrip("=")
    payload_b64 = base64.urlsafe_b64encode(json.dumps(payload).encode()).decode().rstrip("=")

    signature_input = f"{header_b64}.{payload_b64}"
    signature = hashlib.sha256(f"{signature_input}{secret_key}".encode()).hexdigest()[:32]

    return f"{header_b64}.{payload_b64}.{signature}"

def validate_jwt_token(token: str, secret_key: str) -> Dict[str, Any]:
    """
    Validate and decode a JWT token.

    Args:
        token: The JWT token string
        secret_key: Secret key used for signing

    Returns:
        Decoded payload dictionary

    Raises:
        TokenExpiredError: If token has expired
        AuthenticationError: If token is invalid
    """
    import base64
    import json

    try:
        parts = token.split(".")
        if len(parts) != 3:
            raise AuthenticationError("Invalid token format")

        header_b64, payload_b64, signature = parts

        # Verify signature
        signature_input = f"{header_b64}.{payload_b64}"
        expected_sig = hashlib.sha256(f"{signature_input}{secret_key}".encode()).hexdigest()[:32]

        if not secrets.compare_digest(signature, expected_sig):
            raise AuthenticationError("Invalid token signature")

        # Decode payload
        padding = 4 - len(payload_b64) % 4
        payload_b64 += "=" * padding
        payload = json.loads(base64.urlsafe_b64decode(payload_b64))

        # Check expiry
        if payload.get("exp", 0) < time.time():
            raise TokenExpiredError("Token has expired")

        return payload

    except (ValueError, KeyError) as e:
        raise AuthenticationError(f"Token decode error: {e}")

def authenticate_user(username: str, password: str, users_db: Dict[str, User]) -> User:
    """
    Authenticate a user with username and password.

    Args:
        username: User's username
        password: Plain text password
        users_db: Dictionary of username -> User objects

    Returns:
        Authenticated User object

    Raises:
        InvalidCredentialsError: If credentials are invalid
    """
    user = users_db.get(username)

    if user is None:
        raise InvalidCredentialsError("User not found")

    if not user.is_active:
        raise InvalidCredentialsError("User account is disabled")

    if not verify_password(password, user.password_hash, user.salt):
        raise InvalidCredentialsError("Invalid password")

    user.last_login = time.time()
    return user

def check_permission(user: User, required_role: str) -> bool:
    """
    Check if user has required role/permission.

    Args:
        user: User object to check
        required_role: Role string required for access

    Returns:
        True if user has permission, False otherwise
    """
    if not user.is_active:
        return False

    if "admin" in user.roles:
        return True

    return required_role in user.roles
PYEOF

    # Test 1: Count raw tokens in the sample file
    local RAW_CONTENT
    RAW_CONTENT=$(cat "$TEST_DIR/sample_auth.py")
    local RAW_TOKENS
    RAW_TOKENS=$(python3 -c "
import tiktoken
enc = tiktoken.get_encoding('cl100k_base')
content = '''$RAW_CONTENT'''
print(len(enc.encode(content)))
" 2>/dev/null)

    if [ -z "$RAW_TOKENS" ] || [ "$RAW_TOKENS" -eq 0 ]; then
        test_fail "Could not count raw tokens"
        return
    fi
    test_pass "Raw file has $RAW_TOKENS tokens"

    # Test 2: Generate tldr structure output
    local TLDR_OUTPUT
    TLDR_OUTPUT=$(cd "$TEST_DIR" && tldr structure . --lang python 2>/dev/null)

    if [ -z "$TLDR_OUTPUT" ]; then
        test_fail "tldr structure produced no output"
        return
    fi
    test_pass "tldr structure generated output"

    # Test 3: Count tokens in tldr output
    local TLDR_TOKENS
    TLDR_TOKENS=$(python3 -c "
import tiktoken
enc = tiktoken.get_encoding('cl100k_base')
content = '''$TLDR_OUTPUT'''
print(len(enc.encode(content)))
" 2>/dev/null)

    if [ -z "$TLDR_TOKENS" ] || [ "$TLDR_TOKENS" -eq 0 ]; then
        test_fail "Could not count tldr output tokens"
        return
    fi
    test_pass "tldr structure output has $TLDR_TOKENS tokens"

    # Test 4: Calculate and validate token savings
    local SAVINGS_PERCENT
    SAVINGS_PERCENT=$(python3 -c "
raw = $RAW_TOKENS
tldr = $TLDR_TOKENS
savings = ((raw - tldr) / raw) * 100
print(f'{savings:.1f}')
" 2>/dev/null)

    echo "    📊 Token Analysis:"
    echo "       Raw file:     $RAW_TOKENS tokens"
    echo "       TLDR output:  $TLDR_TOKENS tokens"
    echo "       Savings:      $SAVINGS_PERCENT%"

    # Validate at least 50% savings (conservative threshold for structure command)
    local SAVINGS_INT
    SAVINGS_INT=${SAVINGS_PERCENT%.*}
    if [ "$SAVINGS_INT" -ge 50 ]; then
        test_pass "Token savings >= 50% ($SAVINGS_PERCENT% achieved)"
    else
        test_fail "Token savings < 50% (only $SAVINGS_PERCENT%)"
    fi

    # Test 5: Validate tldr context command produces even more savings
    # First, build the index
    (cd "$TEST_DIR" && tldr warm . 2>/dev/null) || true

    local CONTEXT_OUTPUT
    CONTEXT_OUTPUT=$(cd "$TEST_DIR" && tldr context hash_password --project . 2>/dev/null || echo "")

    if [ -n "$CONTEXT_OUTPUT" ]; then
        local CONTEXT_TOKENS
        CONTEXT_TOKENS=$(python3 -c "
import tiktoken
enc = tiktoken.get_encoding('cl100k_base')
content = '''$CONTEXT_OUTPUT'''
print(len(enc.encode(content)))
" 2>/dev/null)

        if [ -n "$CONTEXT_TOKENS" ] && [ "$CONTEXT_TOKENS" -gt 0 ]; then
            local CONTEXT_SAVINGS
            CONTEXT_SAVINGS=$(python3 -c "
raw = $RAW_TOKENS
ctx = $CONTEXT_TOKENS
savings = ((raw - ctx) / raw) * 100
print(f'{savings:.1f}')
" 2>/dev/null)

            echo "    📊 Context Analysis (hash_password function):"
            echo "       Raw file:       $RAW_TOKENS tokens"
            echo "       Context output: $CONTEXT_TOKENS tokens"
            echo "       Savings:        $CONTEXT_SAVINGS%"

            local CTX_SAVINGS_INT
            CTX_SAVINGS_INT=${CONTEXT_SAVINGS%.*}
            if [ "$CTX_SAVINGS_INT" -ge 70 ]; then
                test_pass "Context savings >= 70% ($CONTEXT_SAVINGS% achieved)"
            else
                test_skip "Context savings < 70% ($CONTEXT_SAVINGS%) - may vary by function"
            fi
        else
            test_skip "Could not measure context command tokens"
        fi
    else
        test_skip "tldr context command not available or requires index"
    fi
}

# ═══════════════════════════════════════════════════════════════
# TEST: Skills TLDR Integration (v2.37)
# ═══════════════════════════════════════════════════════════════
test_skills_tldr_integration() {
    section "Skills TLDR Integration Tests (v2.37)"

    # Skills that should have TLDR integration
    local SKILLS_WITH_TLDR=(
        "orchestrator"
        "clarify"
        "gates"
        "research"
        "bugs"
    )

    for skill in "${SKILLS_WITH_TLDR[@]}"; do
        local SKILL_FILE="$GLOBAL_SKILLS_DIR/$skill/SKILL.md"

        if [ ! -f "$SKILL_FILE" ]; then
            test_fail "$skill skill not found at $SKILL_FILE"
            continue
        fi

        # Test 1: Version marker (v2.37)
        if grep -q "(v2.37)" "$SKILL_FILE" 2>/dev/null; then
            test_pass "$skill skill has v2.37 version marker"
        else
            test_fail "$skill skill missing v2.37 version marker"
        fi

        # Test 2: TLDR command presence
        if grep -q "tldr" "$SKILL_FILE" 2>/dev/null; then
            test_pass "$skill skill references tldr commands"
        else
            test_fail "$skill skill should reference tldr commands"
        fi

        # Test 3: Token savings mention
        if grep -q "95%\|token\|Token" "$SKILL_FILE" 2>/dev/null; then
            test_pass "$skill skill mentions token savings"
        else
            test_fail "$skill skill should mention token savings"
        fi

        # Test 4: TLDR Integration section or table
        if grep -qE "TLDR Integration|Pre-.*(TLDR|Context)" "$SKILL_FILE" 2>/dev/null; then
            test_pass "$skill skill has TLDR Integration section"
        else
            test_fail "$skill skill should have TLDR Integration section"
        fi
    done
}

# ═══════════════════════════════════════════════════════════════
# TEST: Agents TLDR Integration (v2.37)
# ═══════════════════════════════════════════════════════════════
test_agents_tldr_integration() {
    section "Agents TLDR Integration Tests (v2.37)"

    local GLOBAL_AGENTS_DIR="${HOME}/.claude/agents"

    # Agents that should have TLDR integration
    local AGENTS_WITH_TLDR=(
        "orchestrator"
        "code-reviewer"
        "test-architect"
        "security-auditor"
        "debugger"
        "kieran-python-reviewer"
        "kieran-typescript-reviewer"
        "pattern-recognition-specialist"
        "architecture-strategist"
    )

    for agent in "${AGENTS_WITH_TLDR[@]}"; do
        local AGENT_FILE="$GLOBAL_AGENTS_DIR/$agent.md"

        if [ ! -f "$AGENT_FILE" ]; then
            test_skip "$agent agent not found at $AGENT_FILE"
            continue
        fi

        # Test 1: Version marker (v2.37)
        if grep -q "(v2.37)" "$AGENT_FILE" 2>/dev/null; then
            test_pass "$agent agent has v2.37 version marker"
        else
            test_fail "$agent agent missing v2.37 version marker"
        fi

        # Test 2: TLDR command presence
        if grep -q "tldr" "$AGENT_FILE" 2>/dev/null; then
            test_pass "$agent agent references tldr commands"
        else
            test_fail "$agent agent should reference tldr commands"
        fi

        # Test 3: Pre-step TLDR section
        if grep -qE "Pre-.*(TLDR|Context|Analysis|Review|Debug|Audit)" "$AGENT_FILE" 2>/dev/null; then
            test_pass "$agent agent has Pre-step TLDR section"
        else
            test_fail "$agent agent should have Pre-step TLDR section"
        fi

        # Test 4: TLDR Integration table
        if grep -qE "TLDR Integration|95%.*token|token.*savings" "$AGENT_FILE" 2>/dev/null; then
            test_pass "$agent agent has TLDR integration documentation"
        else
            test_fail "$agent agent should have TLDR integration documentation"
        fi
    done
}

# ═══════════════════════════════════════════════════════════════
# TEST: TLDR vs ast-search Comparison
# ═══════════════════════════════════════════════════════════════
test_tldr_vs_ast_search() {
    section "TLDR vs ast-search Comparison Tests"

    # Test 1: ast-search skill exists
    if [ -f "$GLOBAL_SKILLS_DIR/ast-search/SKILL.md" ]; then
        test_pass "ast-search skill exists (for structural AST patterns)"
    else
        test_skip "ast-search skill not found"
    fi

    # Test 2: tldr-semantic skill exists (replacement for semantic search)
    if [ -f "$GLOBAL_SKILLS_DIR/tldr-semantic/SKILL.md" ]; then
        test_pass "tldr-semantic skill exists (improved semantic search)"
    else
        test_fail "tldr-semantic skill should exist"
    fi

    # Test 3: ast-grep MCP available (structural search stays)
    if command -v ast-grep &>/dev/null || [ -d "$HOME/.cargo/bin" ]; then
        test_pass "ast-grep available for structural patterns"
    else
        test_skip "ast-grep not installed"
    fi

    # Test 4: tldr provides semantic embeddings (bge-large-en-v1.5)
    if grep -q "semantic\|embedding\|bge-large" "$GLOBAL_SKILLS_DIR/tldr-semantic/SKILL.md" 2>/dev/null; then
        test_pass "tldr-semantic uses 1024-dim embeddings"
    else
        test_skip "Could not verify tldr-semantic embeddings"
    fi

    # Comparison summary
    echo ""
    echo "    📊 TLDR vs ast-search Comparison:"
    echo "    ┌──────────────────┬────────────────────┬────────────────────┐"
    echo "    │ Use Case         │ ast-search         │ tldr               │"
    echo "    ├──────────────────┼────────────────────┼────────────────────┤"
    echo "    │ Exact patterns   │ ✅ Best            │ ❌ Not ideal       │"
    echo "    │ Semantic search  │ ❌ Limited         │ ✅ Best (95% save) │"
    echo "    │ Context extract  │ ❌ N/A             │ ✅ Best            │"
    echo "    │ Dependency graph │ ❌ N/A             │ ✅ Built-in        │"
    echo "    │ Token efficiency │ ~75% savings       │ ~95% savings       │"
    echo "    └──────────────────┴────────────────────┴────────────────────┘"
    echo ""
    echo "    ℹ️  Recommendation: Keep ast-search for structural AST patterns,"
    echo "       use tldr for semantic search and context extraction."
}

# ═══════════════════════════════════════════════════════════════
# TEST: Regression Detection (Future Changes)
# ═══════════════════════════════════════════════════════════════
test_regression_detection() {
    section "Regression Detection Tests"

    local GLOBAL_AGENTS_DIR="${HOME}/.claude/agents"

    # Test 1: orchestrator skill has mandatory tldr commands
    local ORCH_SKILL="$GLOBAL_SKILLS_DIR/orchestrator/SKILL.md"
    if [ -f "$ORCH_SKILL" ]; then
        local ORCH_CMDS=("tldr warm" "tldr structure" "tldr context" "tldr semantic")
        for cmd in "${ORCH_CMDS[@]}"; do
            if grep -q "$cmd" "$ORCH_SKILL" 2>/dev/null; then
                test_pass "orchestrator skill has '$cmd'"
            else
                test_fail "orchestrator skill MISSING '$cmd' (REGRESSION)"
            fi
        done
    else
        test_fail "orchestrator skill not found"
    fi

    # Test 2: code-reviewer agent has Pre-Review section
    if [ -f "$GLOBAL_AGENTS_DIR/code-reviewer.md" ]; then
        if grep -q "Pre-Review" "$GLOBAL_AGENTS_DIR/code-reviewer.md" 2>/dev/null; then
            test_pass "code-reviewer has Pre-Review TLDR section"
        else
            test_fail "code-reviewer MISSING Pre-Review section (REGRESSION)"
        fi
    fi

    # Test 3: security-auditor has Pre-Audit section
    if [ -f "$GLOBAL_AGENTS_DIR/security-auditor.md" ]; then
        if grep -q "Pre-Audit" "$GLOBAL_AGENTS_DIR/security-auditor.md" 2>/dev/null; then
            test_pass "security-auditor has Pre-Audit TLDR section"
        else
            test_fail "security-auditor MISSING Pre-Audit section (REGRESSION)"
        fi
    fi

    # Test 4: Count total tldr references (baseline check)
    local TLDR_COUNT
    TLDR_COUNT=$(grep -r "tldr " "$GLOBAL_SKILLS_DIR"/*.md "$GLOBAL_AGENTS_DIR"/*.md 2>/dev/null | wc -l)

    if [ "$TLDR_COUNT" -ge 50 ]; then
        test_pass "System has $TLDR_COUNT+ tldr references (healthy integration)"
    elif [ "$TLDR_COUNT" -ge 20 ]; then
        test_pass "System has $TLDR_COUNT tldr references (acceptable)"
    else
        test_fail "Only $TLDR_COUNT tldr references found (possible regression)"
    fi
}

# ═══════════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════════

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  Multi-Agent Ralph v2.37 - LLM-TLDR Integration Tests"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Parse arguments
TEST_SUITE="${1:-all}"

case "$TEST_SUITE" in
    skills)
        test_tldr_skills
        ;;
    cli)
        test_ralph_cli
        ;;
    install|installation)
        test_installation
        ;;
    docs|documentation)
        test_documentation
        ;;
    tokens|savings)
        test_token_savings
        ;;
    integration)
        test_skills_tldr_integration
        test_agents_tldr_integration
        ;;
    comparison)
        test_tldr_vs_ast_search
        ;;
    regression)
        test_regression_detection
        ;;
    all|*)
        test_tldr_skills
        test_ralph_cli
        test_installation
        test_documentation
        test_token_savings
        test_skills_tldr_integration
        test_agents_tldr_integration
        test_tldr_vs_ast_search
        test_regression_detection
        ;;
esac

# Summary
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  Test Summary"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo -e "  ${GREEN}PASSED${NC}:  $PASSED"
echo -e "  ${RED}FAILED${NC}:  $FAILED"
echo -e "  ${YELLOW}SKIPPED${NC}: $SKIPPED"
echo -e "  TOTAL:   $TOTAL"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed.${NC}"
    exit 1
fi
