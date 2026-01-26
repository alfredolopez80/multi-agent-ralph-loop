# LLM Provider Usage Tracking Comparison

> Analysis of usage tracking approaches across Z.AI (GLM Coding Plan), Gemini API, and OpenAI API for unified orchestration system integration.

**Date**: January 27, 2026
**Version**: 1.0.0

---

## Executive Summary

| Provider | Real-Time Tracking | Quota System | Rate Limit for Usage API | Best Refresh Rate |
|----------|-------------------|--------------|--------------------------|-------------------|
| **Z.AI** | Separate API endpoint | 5-hour rolling window | Unknown (not documented) | 5-10 minutes |
| **Gemini** | Response metadata | Monthly (Cloud Billing) | Standard API limits | Every request |
| **OpenAI** | Response headers + Separate API | Daily/TPM/RPM | Standard API limits | Every request + periodic batch |

---

## 1. Z.AI (GLM Coding Plan)

### Real-Time Tracking Method

**Method**: Separate monitoring API endpoint (undocumented/publicly exposed)

```
GET https://api.z.ai/api/monitor/usage/quota/limit
Headers: Authorization: Bearer YOUR_API_KEY
```

**Response Structure**:
```json
{
  "TOKENS_LIMIT": 1000000,
  "TIME_LIMIT": 18000,
  "remaining_tokens": 850000,
  "remaining_time": 15000,
  "reset_at": "2026-01-27T14:30:00Z"
}
```

### Quota Limits

| Plan | Prompts | Reset Cycle | Monthly MCP Quota |
|------|---------|-------------|-------------------|
| **Lite** ($3/mo) | ~120 prompts | 5 hours | 100 web searches + readers |
| **Pro** ($15/mo) | ~600 prompts | 5 hours | 1,000 web searches + readers |
| **Max** ($60/mo) | ~2,400 prompts | 5 hours | 4,000 web searches + readers |

**Key Characteristics**:
- Rolling 5-hour window for prompts (not calendar-based)
- Monthly quotas for MCP tools (vision, web search, web reader)
- No auto-consumption of account balance when quota exhausted
- All supported tools share the same quota pool

### Rate Limits

**Not publicly documented** - inferred from usage patterns:
- Recommended polling interval: 5-10 minutes
- No explicit rate limit mentioned in docs
- 1 concurrent request limit for Lite plan

### Authentication

```bash
Bearer Token: Authorization: Bearer YOUR_API_KEY
```

**Alternative**: JWT Token authentication for enhanced security
```python
import jwt, time

def generate_token(apikey: str, exp_seconds: int):
    id, secret = apikey.split(".")
    payload = {
        "api_key": id,
        "exp": int(time.time() * 1000) + exp_seconds * 1000,
        "timestamp": int(time.time() * 1000),
    }
    return jwt.encode(payload, secret, algorithm="HS256",
                      headers={"alg": "HS256", "sign_type": "SIGN"})
```

### Usage Metadata in Responses

**Not available** - Z.AI does NOT return token usage in API responses.
Must poll the monitoring endpoint separately.

---

## 2. Gemini API (Google AI)

### Real-Time Tracking Method

**Method 1**: Response metadata (every request)
```json
{
  "usage_metadata": {
    "prompt_token_count": 264,
    "candidates_token_count": 100,
    "total_token_count": 364,
    "cached_content_token_count": 0
  }
}
```

**Method 2**: Pre-count tokens API
```
POST https://generativelanguage.googleapis.com/v1beta/models/{model}:countTokens?key={API_KEY}
```

**Response**:
```json
{
  "totalTokens": 364,
  "cachedContentTokenCount": 0,
  "promptTokensDetails": [
    {"modality": "TEXT", "token_count": 264},
    {"modality": "IMAGE", "token_count": 0}
  ]
}
```

### Quota Limits

**Free Tier** (varies by model):
- 5-15 requests per minute
- 250,000 tokens per minute
- Up to 1,000 requests per day

**Paid Tier** (after enabling Cloud Billing):
- Higher rate limits (specifics in Google Cloud console)
- No hard token limit on individual requests
- Billed monthly based on consumption

**MCP Quotas** (within Coding Plan):
- Vision: Shares 5-hour prompt pool
- Web Search + Reader: Monthly quota (100-4,000 based on plan)

### Rate Limits

**Standard API rate limits apply**:
- Free tier: 5-15 RPM (model-dependent)
- Paid tier: Significantly higher (configurable in Cloud Console)
- `countTokens` API: No charge, counts against inference quota

### Authentication

```bash
API Key: ?key=$GEMINI_API_KEY
```

Or via Google Cloud OAuth for enterprise setups.

### Billing Integration

- **No separate usage/billing API** like OpenAI
- Usage tracked via Google Cloud Billing
- Costs visible in Google AI Studio Dashboard
- Invoices reconcile with Cloud Billing system

---

## 3. OpenAI API

### Real-Time Tracking Method

**Method 1**: Response headers (every request)
```
x-ratelimit-limit-requests: 60
x-ratelimit-limit-tokens: 150000
x-ratelimit-remaining-requests: 59
x-ratelimit-remaining-tokens: 149984
x-ratelimit-reset-requests: 1s
x-ratelimit-reset-tokens: 6m0s
```

**Method 2**: Usage API (historical/batch)
```
GET https://api.openai.com/v1/organization/usage/completions
  ?start_time=1730419200
  &bucket_width=1d
  &limit=7
```

**Response**:
```json
{
  "object": "page",
  "data": [{
    "object": "bucket",
    "start_time": 1730419200,
    "end_time": 1730505600,
    "results": [{
      "object": "organization.usage.completions.result",
      "input_tokens": 1000,
      "output_tokens": 500,
      "input_cached_tokens": 800,
      "num_model_requests": 5
    }]
  }],
  "has_more": true,
  "next_page": "page_AAAAAGdGxdEiJdKOAAAAAGcqsYA="
}
```

### Quota Limits

**Usage Tiers** (auto-graduated based on spend):

| Tier | Spend Required | Monthly Limit |
|------|----------------|---------------|
| **Free** | $0 | $100/month |
| **Tier 1** | $5 paid | $100/month |
| **Tier 2** | $50 + 7 days | $500/month |
| **Tier 3** | $100 + 7 days | $1,000/month |
| **Tier 4** | $250 + 14 days | $5,000/month |
| **Tier 5** | $1,000 + 30 days | $200,000/month |

**Rate Limits**:
- Measured in RPM (requests per minute) and TPM (tokens per minute)
- Limits increase automatically with usage tier
- Model-specific limits (GPT-5: ~500 RPM, ~200K TPM at Tier 1)

### Rate Limits

**Usage API Rate Limits**:
- No explicit limits documented
- Follows standard organization rate limits
- Recommended: Batch requests every 5-15 minutes
- Max buckets: 31 days (1d), 168 hours (1h), 1440 minutes (1m)

### Authentication

```bash
Bearer Token: Authorization: Bearer $OPENAI_API_KEY
```

**Admin API Key required** for `/v1/organization/usage/*` endpoints.

### Costs API (Separate)

```
GET https://api.openai.com/v1/organization/costs?start_time=1730419200
```

**Reconciles with billing invoices** (recommended for financial purposes).

---

## Unified Data Model

### Recommended Schema

```json
{
  "provider": "zai" | "gemini" | "openai",
  "timestamp": "2026-01-27T10:30:00Z",
  "quota": {
    "type": "rolling_window" | "monthly" | "daily",
    "limit": 1000000,
    "used": 150000,
    "remaining": 850000,
    "reset_at": "2026-01-27T14:30:00Z",
    "reset_in_seconds": 14400
  },
  "rate_limit": {
    "requests_per_minute": 60,
    "tokens_per_minute": 150000,
    "remaining_requests": 59,
    "remaining_tokens": 149984,
    "reset_in_seconds": 60
  },
  "usage": {
    "prompt_tokens": 1000,
    "completion_tokens": 500,
    "cached_tokens": 800,
    "total_tokens": 1500,
    "num_requests": 5
  },
  "metadata": {
    "plan": "pro" | "lite" | "max" | "free" | "paid",
    "model": "glm-4.7" | "gemini-2.0-flash" | "gpt-5",
    "organization_id": "org_abc123"
  }
}
```

---

## Standardized Statusline Format

### Recommended Display

```
🤖 75% · 96K/128K · resets in 45m
```

**Components**:
1. **Provider icon**: 🤖 (or Z🇦🇮 / G🇬🇪 / O🇺🇸 for provider-specific)
2. **Percentage**: Used quota (or context window for individual requests)
3. **Exact tokens**: Used/Total
4. **Reset time**: Human-readable countdown

### Color Thresholds

| Percentage | Color | Action |
|------------|-------|--------|
| 1-49% | Cyan | Normal operation |
| 50-74% | Green | Normal operation |
| 75-84% | Yellow | Warning - consider pausing |
| 85-100% | Red | Critical - stop new requests |

### Provider-Specific Variants

```bash
# Z.AI (rolling window)
🤖 75% · 96K/128K · resets in 45m

# Gemini (monthly quota)
🤖 23% · 230K/1M · monthly

# OpenAI (daily TPM)
🤖 60% · 90K/150K TPM · resets in 6h
```

---

## Implementation Strategy

### Refresh Frequency

| Provider | Real-Time Data | Polling Interval | Batch Frequency |
|----------|----------------|------------------|-----------------|
| **Z.AI** | No (separate API) | 5-10 minutes | N/A |
| **Gemini** | Yes (metadata) | Every request | 15 minutes (cost check) |
| **OpenAI** | Yes (headers) | Every request | 5 minutes (usage API) |

### Caching Strategy

```python
# Pseudo-code for unified cache
class UsageCache:
    def __init__(self):
        self.cache = {
            "zai": {"ttl": 300, "last_update": 0},       # 5 minutes
            "gemini": {"ttl": 60, "last_update": 0},     # 1 minute
            "openai": {"ttl": 300, "last_update": 0}     # 5 minutes
        }

    def get(self, provider: str) -> dict:
        now = time.time()
        cached = self.cache[provider]

        if now - cached["last_update"] > cached["ttl"]:
            # Fetch fresh data
            data = self._fetch_usage(provider)
            cached["data"] = data
            cached["last_update"] = now

        return cached["data"]
```

### Error Handling

```python
def fetch_with_fallback(provider: str) -> dict:
    try:
        # Try provider-specific API
        return fetch_provider_usage(provider)
    except (ConnectionError, TimeoutError) as e:
        logger.warning(f"Provider {provider} unavailable: {e}")
        # Return cached data if available
        if cache.has_stale_data(provider):
            return cache.get_stale(provider)
        # Return estimated defaults
        return get_estimated_usage(provider)
    except (AuthenticationError, RateLimitError) as e:
        logger.error(f"Auth/rate limit error for {provider}: {e}")
        # Disable provider temporarily
        disable_provider_temporarily(provider)
        raise
```

### Fallback Strategy

| Error Type | Fallback Action | User Notification |
|------------|-----------------|-------------------|
| **API unavailable** | Use cached data (5-min stale) | Yellow warning |
| **Rate limit hit** | Back off + exponential delay | Red warning |
| **Auth failure** | Disable provider, use others | Critical error |
| **Timeout** | Retry with 2x timeout | Yellow warning |
| **All providers down** | Use local estimation only | Red critical |

---

## Rate Limits Comparison

### Usage Endpoint Limits

| Provider | Endpoint | Rate Limit | Auth Required |
|----------|----------|------------|---------------|
| **Z.AI** | `/api/monitor/usage/quota/limit` | Unknown (infers 60/min) | Bearer token |
| **Gemini** | `countTokens` API | Standard API limits | API key |
| **OpenAI** | `/v1/organization/usage/*` | Standard org limits | Admin key |

### Practical Recommendations

```python
# Unified polling manager
class UsagePoller:
    INTERVALS = {
        "zai": 300,      # 5 minutes
        "gemini": 60,    # 1 minute
        "openai": 300    # 5 minutes
    }

    async def poll_all(self):
        tasks = [
            self.poll_with_backoff(p, interval)
            for p, interval in self.INTERVALS.items()
        ]
        return await asyncio.gather(*tasks)

    async def poll_with_backoff(self, provider: str, interval: int):
        for attempt in range(3):
            try:
                return await self.fetch_usage(provider)
            except RateLimitError:
                await asyncio.sleep(2 ** attempt)  # Exponential backoff
            except Exception as e:
                logger.error(f"Failed to poll {provider}: {e}")
                return None
```

---

## Quick Reference

### Authentication Headers

```bash
# Z.AI
Authorization: Bearer YOUR_ZAI_API_KEY

# Gemini (URL parameter)
?key=YOUR_GEMINI_API_KEY

# OpenAI
Authorization: Bearer YOUR_OPENAI_API_KEY
```

### Sample cURL Commands

```bash
# Z.AI - Check quota
curl https://api.z.ai/api/monitor/usage/quota/limit \
  -H "Authorization: Bearer $ZAI_API_KEY"

# Gemini - Count tokens
curl "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:countTokens?key=$GEMINI_API_KEY" \
  -H "Content-Type: application/json" \
  -X POST \
  -d '{"contents": [{"parts": [{"text": "Hello"}]}]}'

# OpenAI - Get usage (last 24 hours)
curl "https://api.openai.com/v1/organization/usage/completions?start_time=$(date -d '-1 day' +%s)&bucket_width=1h&limit=24" \
  -H "Authorization: Bearer $OPENAI_ADMIN_KEY"
```

---

## Recommendations

### For Unified Statusline Implementation

1. **Primary data source**: Response metadata (Gemini/OpenAI) or periodic polling (Z.AI)
2. **Secondary validation**: Batch API calls every 5-15 minutes
3. **Display format**: `🤖 75% · 96K/128K · resets in 45m`
4. **Color coding**: Cyan (safe) → Green → Yellow → Red (critical)

### For Cost-Effective Polling

| Provider | Optimal Strategy | Rationale |
|----------|-----------------|-----------|
| **Z.AI** | Poll every 5 min | No response metadata available |
| **Gemini** | Every request + periodic | Metadata is free, Cloud Billing for costs |
| **OpenAI** | Headers + usage API every 15 min | Headers are real-time, API for aggregation |

### Error Recovery

```python
RETRY_CONFIG = {
    "max_attempts": 3,
    "base_delay": 1.0,
    "max_delay": 60.0,
    "backoff_multiplier": 2.0
}

def fetch_with_retry(provider: str):
    for attempt in range(RETRY_CONFIG["max_attempts"]):
        try:
            return fetch_usage(provider)
        except Exception as e:
            if attempt == RETRY_CONFIG["max_attempts"] - 1:
                raise
            delay = min(
                RETRY_CONFIG["base_delay"] * (RETRY_CONFIG["backoff_multiplier"] ** attempt),
                RETRY_CONFIG["max_delay"]
            )
            time.sleep(delay)
```

---

## Sources

1. **Z.AI GLM Coding Plan FAQ**: https://docs.z.ai/devpack/faq
2. **Z.AI HTTP API Introduction**: https://docs.z.ai/guides/develop/http/introduction
3. **Gemini API Billing**: https://ai.google.dev/gemini-api/docs/billing
4. **Gemini Token Counting**: https://ai.google.dev/api/tokens
5. **OpenAI Usage API**: https://platform.openai.com/docs/api-reference/usage
6. **OpenAI Rate Limits**: https://platform.openai.com/docs/guides/rate-limits

---

**Document Version**: 1.0.0
**Last Updated**: 2026-01-27
**Maintained By**: Multi-Agent Ralph Loop Project
