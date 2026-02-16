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


// Test file for quality validation
// Contains INTENTIONAL vulnerabilities for testing

const API_KEY = "sk-TESTONLY_000000000000";  // P0: FAKE CREDENTIAL FOR TESTING ONLY

function authenticateUser(userId, password) {
    const query = "SELECT * FROM users WHERE id=" + userId;  // P0: SQL injection
    const hash = md5(password);  // P0: Weak hashing

    // TODO: Implement proper error handling  // Stop-slop candidate
    return query;
}

// This is a very important function that is crucial for the system  // Stop-slop filler
function processData(data) {
    try {
        const result = JSON.parse(data);  // Extra try-catch
        return result;
    } catch (e) {
        return null;
    }
}
