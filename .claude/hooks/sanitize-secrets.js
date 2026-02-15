#!/usr/bin/env node
/**
 * Hook de Sanitización de Secretos para Claude-Mem
 *
 * Este hook intercepta datos antes de ser guardados y redacta
 * cualquier información sensible detectada.
 *
 * Patrones detectados:
 * - GitHub PAT (ghp_*, github_pat_*)
 * - OpenAI API Keys (sk-*)
 * - AWS Keys (AKIA*, aws_secret_*)
 * - Ethereum Private Keys (0x + 64 hex chars)
 * - Generic API Keys y Tokens
 * - JWT Tokens
 * - Passwords en config
 */

const SECRET_PATTERNS = [
  // GitHub Personal Access Tokens
  {
    pattern: /ghp_[a-zA-Z0-9]{36,}/g,
    replacement: '[REDACTED:GITHUB_PAT]',
    name: 'GitHub PAT'
  },
  {
    pattern: /github_pat_[a-zA-Z0-9_]{22,}/g,
    replacement: '[REDACTED:GITHUB_PAT_FINE]',
    name: 'GitHub Fine-grained PAT'
  },

  // OpenAI API Keys
  {
    pattern: /sk-[a-zA-Z0-9]{32,}/g,
    replacement: '[REDACTED:OPENAI_KEY]',
    name: 'OpenAI API Key'
  },
  {
    pattern: /sk-proj-[a-zA-Z0-9\-_]{40,}/g,
    replacement: '[REDACTED:OPENAI_PROJECT_KEY]',
    name: 'OpenAI Project Key'
  },

  // AWS Credentials
  {
    pattern: /AKIA[0-9A-Z]{16}/g,
    replacement: '[REDACTED:AWS_ACCESS_KEY]',
    name: 'AWS Access Key'
  },
  {
    pattern: /aws_secret_access_key\s*[=:]\s*["']?[A-Za-z0-9/+=]{40}["']?/gi,
    replacement: 'aws_secret_access_key=[REDACTED:AWS_SECRET]',
    name: 'AWS Secret Key'
  },

  // Ethereum/Crypto Private Keys (64 hex chars after 0x)
  {
    pattern: /(?:private[_-]?key|priv[_-]?key|secret[_-]?key)\s*[=:]\s*["']?0x[a-fA-F0-9]{64}["']?/gi,
    replacement: '[REDACTED:ETH_PRIVATE_KEY]',
    name: 'Ethereum Private Key (labeled)'
  },
  {
    pattern: /["']0x[a-fA-F0-9]{64}["']/g,
    replacement: '"[REDACTED:POSSIBLE_PRIVATE_KEY]"',
    name: 'Possible Private Key (quoted)'
  },

  // Mnemonic/Seed Phrases (12 or 24 words)
  {
    pattern: /(?:mnemonic|seed|recovery)\s*[=:]\s*["'][a-z\s]{20,}["']/gi,
    replacement: '[REDACTED:SEED_PHRASE]',
    name: 'Seed Phrase'
  },

  // Anthropic API Keys
  {
    pattern: /sk-ant-[a-zA-Z0-9\-]{40,}/g,
    replacement: '[REDACTED:ANTHROPIC_KEY]',
    name: 'Anthropic API Key'
  },

  // Generic API Keys and Tokens
  {
    pattern: /(?:api[_-]?key|apikey|api[_-]?token|auth[_-]?token|access[_-]?token|bearer)\s*[=:]\s*["']?[a-zA-Z0-9\-_\.]{20,}["']?/gi,
    replacement: '[REDACTED:API_KEY]',
    name: 'Generic API Key'
  },

  // JWT Tokens
  {
    pattern: /eyJ[a-zA-Z0-9\-_]+\.eyJ[a-zA-Z0-9\-_]+\.[a-zA-Z0-9\-_]+/g,
    replacement: '[REDACTED:JWT_TOKEN]',
    name: 'JWT Token'
  },

  // Password patterns in config
  {
    pattern: /(?:password|passwd|pwd|secret)\s*[=:]\s*["'][^"'\n]{8,}["']/gi,
    replacement: '[REDACTED:PASSWORD]',
    name: 'Password'
  },

  // Database connection strings with credentials
  {
    pattern: /(?:mongodb|postgres|mysql|redis):\/\/[^:]+:[^@]+@[^\s"']+/gi,
    replacement: '[REDACTED:DB_CONNECTION_STRING]',
    name: 'Database Connection String'
  },

  // Slack tokens
  {
    pattern: /xox[baprs]-[a-zA-Z0-9\-]{10,}/g,
    replacement: '[REDACTED:SLACK_TOKEN]',
    name: 'Slack Token'
  },

  // Discord tokens
  {
    pattern: /[MN][A-Za-z\d]{23,}\.[\w-]{6}\.[\w-]{27}/g,
    replacement: '[REDACTED:DISCORD_TOKEN]',
    name: 'Discord Token'
  },

  // Stripe keys
  {
    pattern: /sk_(?:live|test)_[a-zA-Z0-9]{24,}/g,
    replacement: '[REDACTED:STRIPE_KEY]',
    name: 'Stripe Secret Key'
  },
  {
    pattern: /pk_(?:live|test)_[a-zA-Z0-9]{24,}/g,
    replacement: '[REDACTED:STRIPE_PUBLISHABLE]',
    name: 'Stripe Publishable Key'
  },

  // Twilio
  {
    pattern: /SK[a-f0-9]{32}/g,
    replacement: '[REDACTED:TWILIO_KEY]',
    name: 'Twilio API Key'
  },

  // SendGrid
  {
    pattern: /SG\.[a-zA-Z0-9\-_]{22,}\.[a-zA-Z0-9\-_]{22,}/g,
    replacement: '[REDACTED:SENDGRID_KEY]',
    name: 'SendGrid API Key'
  },

  // Infura/Alchemy API Keys
  {
    pattern: /(?:infura|alchemy)[_-]?(?:api[_-]?)?key\s*[=:]\s*["']?[a-zA-Z0-9]{20,}["']?/gi,
    replacement: '[REDACTED:WEB3_PROVIDER_KEY]',
    name: 'Web3 Provider Key'
  },

  // SSH Private Keys
  {
    pattern: /-----BEGIN (?:RSA |EC |DSA |OPENSSH )?PRIVATE KEY-----[\s\S]*?-----END (?:RSA |EC |DSA |OPENSSH )?PRIVATE KEY-----/g,
    replacement: '[REDACTED:SSH_PRIVATE_KEY]',
    name: 'SSH Private Key'
  },

  // Base64 encoded secrets (likely tokens) longer than 40 chars
  {
    pattern: /(?:token|secret|key|credential)\s*[=:]\s*["']?[A-Za-z0-9+/=]{40,}["']?/gi,
    replacement: '[REDACTED:BASE64_SECRET]',
    name: 'Base64 Encoded Secret'
  }
];

// Statistics for logging
let stats = {
  totalRedactions: 0,
  byType: {}
};

/**
 * Sanitize text by replacing all detected secrets
 */
function sanitizeText(text) {
  if (!text || typeof text !== 'string') return text;

  let sanitized = text;

  for (const { pattern, replacement, name } of SECRET_PATTERNS) {
    const matches = sanitized.match(pattern);
    if (matches) {
      stats.totalRedactions += matches.length;
      stats.byType[name] = (stats.byType[name] || 0) + matches.length;
      sanitized = sanitized.replace(pattern, replacement);
    }
  }

  return sanitized;
}

/**
 * Recursively sanitize an object
 */
function sanitizeObject(obj) {
  if (obj === null || obj === undefined) return obj;

  if (typeof obj === 'string') {
    return sanitizeText(obj);
  }

  if (Array.isArray(obj)) {
    return obj.map(item => sanitizeObject(item));
  }

  if (typeof obj === 'object') {
    const sanitized = {};
    for (const [key, value] of Object.entries(obj)) {
      sanitized[key] = sanitizeObject(value);
    }
    return sanitized;
  }

  return obj;
}

/**
 * Main hook handler
 */
async function main() {
  let input = '';

  // Read from stdin
  process.stdin.setEncoding('utf8');

  for await (const chunk of process.stdin) {
    input += chunk;
  }

  if (!input.trim()) {
    // No input, just pass through
    console.log(JSON.stringify({ continue: true }));
    return;
  }

  try {
    const data = JSON.parse(input);

    // Sanitize the entire input
    const sanitizedData = sanitizeObject(data);

    // Log redactions if any occurred
    if (stats.totalRedactions > 0) {
      console.error(`[sanitize-secrets] Redacted ${stats.totalRedactions} secret(s):`);
      for (const [type, count] of Object.entries(stats.byType)) {
        console.error(`  - ${type}: ${count}`);
      }
    }

    // Output sanitized data
    console.log(JSON.stringify(sanitizedData));

  } catch (error) {
    // SEC: Log parse failure for anomaly detection, then fail-open with text sanitization
    const fs = require('fs');
    const logDir = `${process.env.HOME}/.ralph/logs`;
    try { fs.mkdirSync(logDir, { recursive: true }); } catch (_) {}
    fs.appendFileSync(`${logDir}/sanitize-secrets.log`,
      `[${new Date().toISOString()}] WARN: JSON parse failed, falling back to text sanitization: ${error.message}\n`);
    const sanitized = sanitizeText(input);
    console.log(sanitized);
  }
}

main().catch(err => {
  console.error('[sanitize-secrets] Error:', err.message);
  process.exit(1);
});
