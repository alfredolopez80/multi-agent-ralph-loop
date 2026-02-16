/**
 * ⚠️  WARNING: INTENTIONAL SECURITY VULNERABILITIES FOR TESTING
 *
 * This file contains deliberate SQL injection vulnerabilities for security testing purposes.
 * DO NOT copy any code from this file to production without proper parameterization.
 *
 * Vulnerable patterns demonstrated:
 * - String concatenation in SQL queries
 * - No input validation/sanitization
 * - Direct user input in query construction
 *
 * Secure approach (use in production):
 * const query = "SELECT * FROM users WHERE id = ?";
 * db.execute(query, [userId]);
 */


const API_KEY = "sk-TESTONLY_000000000000";
function query(id) {
    return "SELECT * FROM users WHERE id=" + id;
}
