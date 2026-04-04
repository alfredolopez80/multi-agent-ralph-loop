# Testing Patterns Reference

## Unit Tests
1. Test one behavior per test function
2. Name tests: `test_<behavior>_when_<condition>_then_<expected>`
3. Arrange-Act-Assert pattern
4. Mock external dependencies, not internal logic
5. Test edge cases: empty, null, boundary values, overflow

## Integration Tests
6. Test API endpoints end-to-end
7. Use real database (not mocks) for data layer tests
8. Test authentication/authorization flows
9. Test error responses (4xx, 5xx)
10. Test rate limiting behavior

## Frontend Tests
11. Test component rendering in all 8 states
12. Test keyboard navigation (Tab, Enter, Escape)
13. Test responsive behavior at 3 breakpoints
14. Test with screen reader (aria labels)
15. Test form validation (client + server)

## General
16. No flaky tests — if it fails intermittently, fix or remove
17. Tests must be deterministic (no time-dependent assertions)
18. Test data should be self-contained (no shared state)
19. CI must run full test suite (no skipped tests in CI)
20. Coverage target: 80% lines, 100% critical paths
