---
# VERSION: 1.0.0
name: ethereum-rpc
description: "Ethereum/EVM JSON-RPC call builder and validator - use when interacting with blockchain nodes via RPC"
allowed-tools: Bash,Read,Write,WebFetch,WebSearch
---

**ultrathink** - Blockchain interactions require precision. One wrong hex, one missing zero, and the call fails silently.

## The Vision
Make RPC calls foolproof. Validate formats, build correct payloads, and handle responses properly.

## Quick Reference

### Invoke this skill when:
- Building `eth_getLogs`, `eth_call`, `eth_getBalance` or any JSON-RPC call
- Converting between decimal and hexadecimal for blocks/values
- Padding addresses for topics arrays
- Debugging RPC errors (code -32000, -32020, etc.)
- Working with Hedera, Ethereum, Polygon, or any EVM chain

---

## Core Concepts

### Hexadecimal Encoding Rules

| Type | Format | Example |
|------|--------|---------|
| Block number | `0x` + hex (no leading zeros) | `0x560B8CF` (90,177,743) |
| Address | `0x` + 40 hex chars | `0xdAC17F958D2ee523a2206206994597C13D831ec7` |
| Address (in topics) | `0x` + 24 zeros + 40 hex | `0x000000000000000000000000dAC17F958D2ee523a2206206994597C13D831ec7` |
| Hash (32 bytes) | `0x` + 64 hex chars | `0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef` |
| Value (wei) | `0x` + hex | `0xde0b6b3a7640000` (1 ETH) |

### Block Tags

| Tag | Description |
|-----|-------------|
| `latest` | Most recent mined block |
| `pending` | Pending state/transactions |
| `earliest` | Genesis block |
| `safe` | Latest safe head block |
| `finalized` | Latest finalized block |

---

## Common RPC Methods

### 1. eth_blockNumber
```json
{
  "jsonrpc": "2.0",
  "method": "eth_blockNumber",
  "params": [],
  "id": 1
}
```
**Returns:** Current block number in hex

### 2. eth_getBalance
```json
{
  "jsonrpc": "2.0",
  "method": "eth_getBalance",
  "params": ["0xADDRESS", "latest"],
  "id": 1
}
```
**Returns:** Balance in wei (hex)

### 3. eth_call (Read contract)
```json
{
  "jsonrpc": "2.0",
  "method": "eth_call",
  "params": [{
    "to": "0xCONTRACT_ADDRESS",
    "data": "0xMETHOD_SIGNATURE_AND_PARAMS"
  }, "latest"],
  "id": 1
}
```
**Returns:** Encoded return value

### 4. eth_getTransactionReceipt
```json
{
  "jsonrpc": "2.0",
  "method": "eth_getTransactionReceipt",
  "params": ["0xTRANSACTION_HASH"],
  "id": 1
}
```
**Returns:** Receipt with status, logs, gasUsed

### 5. eth_getLogs ⭐ (Most Complex)
```json
{
  "jsonrpc": "2.0",
  "method": "eth_getLogs",
  "params": [{
    "fromBlock": "0xHEX_BLOCK",
    "toBlock": "0xHEX_BLOCK",
    "address": "0xCONTRACT_ADDRESS",
    "topics": [
      "0xEVENT_SIGNATURE",
      "0xTOPIC1_OR_NULL",
      "0xTOPIC2_OR_NULL",
      "0xTOPIC3_OR_NULL"
    ]
  }],
  "id": 1
}
```

---

## eth_getLogs Deep Dive

### Topics Structure

For `Transfer(address indexed from, address indexed to, uint256 value)`:

| Index | Content | Description |
|-------|---------|-------------|
| `topics[0]` | `0xddf252ad...` | Event signature hash |
| `topics[1]` | Padded address | `from` (sender) |
| `topics[2]` | Padded address | `to` (recipient) |

### Topics Logic

| Syntax | Meaning |
|--------|---------|
| `"0xABC..."` | Match exact value |
| `null` | Match ANY value |
| `["0xA...", "0xB..."]` | Match A **OR** B |

### Common Event Signatures

| Event | Signature Hash |
|-------|---------------|
| `Transfer(address,address,uint256)` | `0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef` |
| `Approval(address,address,uint256)` | `0x8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925` |
| `Swap(...)` Uniswap V2 | `0xd78ad95fa46c994b6551d0da85fc275fe613ce37657fb8d5e3d130840159d822` |
| `Sync(uint112,uint112)` | `0x1c411e9a96e071241c2f21f7726b17ae89e3cab4c78be50e062b03a9fffbbad1` |

### Address Padding Function

```bash
# Convert address to 32-byte topic format
pad_address() {
  local addr="${1#0x}"  # Remove 0x prefix
  echo "0x000000000000000000000000${addr}"
}

# Example:
# pad_address "0xdAC17F958D2ee523a2206206994597C13D831ec7"
# Output: 0x000000000000000000000000dAC17F958D2ee523a2206206994597C13D831ec7
```

### Block Conversion Functions

```bash
# Decimal to Hex (for blocks)
dec_to_hex() {
  printf "0x%X" "$1"
}

# Hex to Decimal
hex_to_dec() {
  printf "%d" "$1"
}

# Examples:
# dec_to_hex 90177743  → 0x560B8CF
# hex_to_dec 0x560B8CF → 90177743
```

---

## Provider-Specific Limits

### eth_getLogs Limits

| Provider | Block Range | Topics Array | Rate Limit |
|----------|-------------|--------------|------------|
| **QuickNode Free** | 5 blocks | Unknown | Low |
| **QuickNode Paid** | 10,000 blocks | 20 elements | Higher |
| **Alchemy Free** | 2,000 blocks | Unknown | 330 req/sec |
| **Infura Free** | 10,000 blocks | Unknown | 10 req/sec |
| **Hedera Mirror** | Varies | **20 elements max** | Varies |

### Hedera-Specific Notes

⚠️ **CRITICAL:** Hedera Mirror Node has a **hard limit of 20 elements** in topics arrays.

```json
// ✅ WORKS (20 addresses)
"topics": [
  "0xddf252ad...",
  null,
  ["addr1", "addr2", ... "addr20"]  // Max 20
]

// ❌ FAILS (21+ addresses) - Error -32020
"topics": [
  "0xddf252ad...",
  null,
  ["addr1", "addr2", ... "addr21"]  // Error 500
]
```

**Workaround:** Batch requests in groups of 20:
```python
BATCH_SIZE = 20
for i in range(0, len(addresses), BATCH_SIZE):
    batch = addresses[i:i+BATCH_SIZE]
    # Make RPC call with this batch
```

---

## Error Codes Reference

| Code | Message | Cause | Solution |
|------|---------|-------|----------|
| `-32700` | Parse error | Invalid JSON | Check JSON syntax |
| `-32600` | Invalid request | Missing required field | Add `jsonrpc`, `method`, `id` |
| `-32601` | Method not found | Typo in method name | Verify method spelling |
| `-32602` | Invalid params | Wrong parameter format | Check hex encoding |
| `-32603` | Internal error | Node error | Retry or change node |
| `-32000` | Server error | Generic | Check block range, params |
| `-32020` | Mirror node failure | Hedera-specific | Reduce topics array size |

---

## Templates

### Template: Query Transfers to Multiple Addresses

```json
{
  "jsonrpc": "2.0",
  "method": "eth_getLogs",
  "params": [{
    "fromBlock": "0xFROM_BLOCK_HEX",
    "toBlock": "0xTO_BLOCK_HEX",
    "topics": [
      "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef",
      null,
      [
        "0x000000000000000000000000ADDRESS1",
        "0x000000000000000000000000ADDRESS2"
      ]
    ]
  }],
  "id": 1
}
```

### Template: Query Transfers FROM Specific Address

```json
{
  "jsonrpc": "2.0",
  "method": "eth_getLogs",
  "params": [{
    "fromBlock": "0xFROM_BLOCK_HEX",
    "toBlock": "0xTO_BLOCK_HEX",
    "topics": [
      "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef",
      "0x000000000000000000000000FROM_ADDRESS",
      null
    ]
  }],
  "id": 1
}
```

### Template: Query Specific Token Transfers

```json
{
  "jsonrpc": "2.0",
  "method": "eth_getLogs",
  "params": [{
    "fromBlock": "0xFROM_BLOCK_HEX",
    "toBlock": "0xTO_BLOCK_HEX",
    "address": "0xTOKEN_CONTRACT_ADDRESS",
    "topics": [
      "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"
    ]
  }],
  "id": 1
}
```

### Template: cURL Request

```bash
curl -s -X POST 'RPC_URL' \
  -H 'Content-Type: application/json' \
  -d @payload.json | jq .
```

---

## Validation Checklist

Before executing an RPC call, verify:

- [ ] `jsonrpc` is `"2.0"`
- [ ] `method` is spelled correctly
- [ ] `id` is present (integer)
- [ ] Block numbers are hex with `0x` prefix
- [ ] Addresses are 42 chars (`0x` + 40 hex)
- [ ] Topics addresses are 66 chars (`0x` + 64 hex, padded)
- [ ] Topics array ≤ 20 elements (Hedera)
- [ ] Block range ≤ provider limit
- [ ] No trailing commas in JSON

---

## Quick Conversion Tool

When you need conversions, use:

```bash
# Block decimal to hex
echo "Block $(printf '0x%X' 90177743)"

# Block hex to decimal
echo "Block $((0x560B8CF))"

# Pad address for topics
addr="0xdAC17F958D2ee523a2206206994597C13D831ec7"
echo "0x000000000000000000000000${addr#0x}"
```

---

## References

- [Ethereum JSON-RPC Spec](https://ethereum.org/developers/docs/apis/json-rpc/)
- [QuickNode Docs](https://www.quicknode.com/docs/ethereum/)
- [Alchemy Docs](https://www.alchemy.com/docs/ethereum-basics)
- [eth_getLogs Deep Dive](https://www.alchemy.com/docs/deep-dive-into-eth_getlogs)
