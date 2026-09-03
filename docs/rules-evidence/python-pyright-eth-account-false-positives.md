> Full text of the global rule ~/.claude/rules/proven/python-pyright-eth-account-false-positives.md, preserved 2026-09-03 when the always-loaded copy was reduced to norm + trigger. The rule file links here.

# pyright-eth-account-false-positives

Pyright emits spurious errors on the `eth_account` / `eth_utils` ecosystem. These are FALSE POSITIVES — the code is runtime-valid and ships in production. DO NOT "fix" these errors by adding casts, `# type: ignore`, import-path changes, or restructuring calls.

## Known false positives

| Pyright diagnostic | Code pattern | Why it's wrong |
|---|---|---|
| `Cannot access attribute "address" for class "Account"` | `wallet.address` after `Account.from_key(pk)` or `Account.from_mnemonic(m)` | `Account.from_key()` returns `LocalAccount`, NOT `Account`. `LocalAccount` defines `.address`, `.sign_message()`, `.sign_transaction()`. Pyright reads the declared return annotation (`Account`) from the stub instead of the actual runtime type. |
| `"to_hex" is not exported from module "eth_utils" [reportPrivateImportUsage]` | `from eth_utils import to_hex` | `to_hex` IS part of the public API of `eth_utils`. Pyright enforces `__all__` strictly; `eth_utils/__init__.py` re-exports without listing every symbol in `__all__`. The import is valid and standard across the web3 Python ecosystem. |
| `Cannot access attribute "sign_message" / "sign_transaction" for class "Account"` | `wallet.sign_message(msg)` | Same root cause: runtime type is `LocalAccount`. |

## Why the LLM keeps getting tricked

Pyright output is loud, specific, and points at a line number — it looks exactly like a real bug. Without seeing the actual runtime class (`LocalAccount` inherits from `BaseAccount`, not the static `Account` type), the instinct is to trust the tool. **The correct instinct is the opposite: if the same code pattern already ships in production or in adjacent working scripts, Pyright is wrong.**

## How to apply

Before "fixing" any Pyright diagnostic that matches the table above:

1. **Grep for the same pattern in sibling files** that are known to work:
   ```bash
   grep -rn "\.address\|from eth_utils import" scripts/ tests/ src/
   ```
   If the pattern is load-bearing elsewhere, the code is correct — ignore the diagnostic.

2. **Check whether Pyright is even in the project's CI/lint pipeline.** Most web3 Python projects use `ruff` + `black` + `mypy` (if any); Pyright is often only active via editor integration, not as a gate. If `make validate` / `make lint` / CI doesn't run Pyright, the diagnostic is editor-only noise.

3. **Do NOT apply any of these "fixes":**
   - Adding `# type: ignore[attr-defined]` or `# pyright: ignore`
   - Rewriting `from eth_utils import to_hex` to `from eth_utils.conversions import to_hex`
   - Casting via `cast(LocalAccount, wallet)` or `assert isinstance(wallet, LocalAccount)`
   - Replacing `Account.from_key(pk)` with manual construction
   - Using `getattr(wallet, "address")` as a workaround

4. **If a project genuinely adopts strict Pyright as a CI gate**, the correct long-term fix is to file an upstream issue with `eth-account` to fix the stubs, OR add a project-level `pyrightconfig.json` with `reportAttributeAccessIssue: "none"` and `reportPrivateImportUsage: "none"` — NOT per-line suppressions that pollute the code.

## Evidence

- `eth_account.Account.from_key` is annotated to return `LocalAccount` in the actual source (`eth_account/account.py`), but the public stub / type inference path resolves to `Account`. This is a long-standing stub gap, not a runtime change.
- `eth_utils` re-exports dozens of helpers (`to_hex`, `to_bytes`, `keccak`, `is_address`, etc.) via `from eth_utils.conversions import *` — Pyright's `reportPrivateImportUsage` misclassifies these as internal.

**Trigger**: Any Pyright diagnostic on `eth_account.Account`, `eth_utils` imports, or `wallet.address` / `.sign_*` access in Python scripts using the web3 stack
**Domain**: python / linting / web3
**Confidence**: 1.0
**Usage**: 1 (first documented occurrence: 2026-04-15, palmera-hypersig-api E2E script)
