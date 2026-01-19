#!/usr/bin/env python3
"""
Test Suite for Repository Learner Components (v1.0)

Tests for github-repo-loader, pattern-extractor, best-practices-analyzer,
and procedural-enricher components.

VERSION: 1.0.0
"""

import json
import sys
import tempfile
import unittest
from pathlib import Path

# Load modules from ~/.claude/scripts
SCRIPTS_DIR = Path.home() / '.claude' / 'scripts'

def load_module(script_name: str):
    """Load a module from scripts directory."""
    path = SCRIPTS_DIR / script_name
    if not path.exists():
        return None
    module_name = script_name.replace('-', '_').replace('.py', '')
    with open(path) as f:
        code = f.read()
    module = type(sys)(module_name)
    exec(code, module.__dict__)
    sys.modules[module_name] = module
    return module

# Load all modules
github_repo_loader = load_module('github-repo-loader.py')
pattern_extractor = load_module('pattern-extractor.py')
best_practices_analyzer = load_module('best-practices-analyzer.py')
procedural_enricher = load_module('procedural-enricher.py')

# Import classes from loaded modules
GitHubRepoLoader = github_repo_loader.GitHubRepoLoader
FileContent = github_repo_loader.FileContent
PatternExtractor = pattern_extractor.PatternExtractor
Pattern = pattern_extractor.Pattern
PythonPatternExtractor = pattern_extractor.PythonPatternExtractor
TypeScriptPatternExtractor = pattern_extractor.TypeScriptPatternExtractor
RustPatternExtractor = pattern_extractor.RustPatternExtractor
GoPatternExtractor = pattern_extractor.GoPatternExtractor
BestPracticesAnalyzer = best_practices_analyzer.BestPracticesAnalyzer
AnalyzedPattern = best_practices_analyzer.AnalyzedPattern
ProceduralEnricher = procedural_enricher.ProceduralEnricher


class TestGitHubRepoLoader(unittest.TestCase):
    """Tests for GitHub Repository Loader."""

    def test_parse_github_url(self):
        """Test GitHub URL parsing."""
        loader = GitHubRepoLoader()

        # Standard URL
        owner, repo = loader.parse_github_url(
            'https://github.com/python/cpython'
        )
        self.assertEqual(owner, 'python')
        self.assertEqual(repo, 'cpython')

        # URL with .git suffix
        owner, repo = loader.parse_github_url(
            'https://github.com/facebook/react.git'
        )
        self.assertEqual(owner, 'facebook')
        self.assertEqual(repo, 'react')

        # Invalid URL
        with self.assertRaises(ValueError):
            loader.parse_github_url('https://gitlab.com/org/repo')

    def test_should_exclude(self):
        """Test file exclusion patterns."""
        loader = GitHubRepoLoader()

        self.assertTrue(loader._should_exclude('node_modules/package.json'))
        self.assertTrue(loader._should_exclude('.git/config'))
        self.assertTrue(loader._should_exclude('src/__pycache__/cache.py'))
        self.assertFalse(loader._should_exclude('src/main.py'))
        self.assertFalse(loader._should_exclude('README.md'))

    def test_get_language(self):
        """Test language detection from extension."""
        loader = GitHubRepoLoader()

        self.assertEqual(loader._get_language('test.py'), 'python')
        self.assertEqual(loader._get_language('index.ts'), 'typescript')
        self.assertEqual(loader._get_language('main.go'), 'go')
        self.assertEqual(loader._get_language('lib.rs'), 'rust')
        self.assertEqual(loader._get_language('file.txt'), None)

    def test_file_content_dataclass(self):
        """Test FileContent dataclass."""
        content = FileContent(
            path='test.py',
            content='print("hello")',
            language='python',
            size_bytes=14
        )
        self.assertIsNotNone(content.sha256)
        self.assertEqual(len(content.sha256), 64)  # SHA256 hex length


class TestPatternExtractor(unittest.TestCase):
    """Tests for Pattern Extractor."""

    def test_python_extractor_dataclass(self):
        """Test Python dataclass pattern detection."""
        extractor = PythonPatternExtractor()

        code = '''
from dataclasses import dataclass

@dataclass
class User:
    name: str
    email: str
'''
        patterns = extractor.extract_patterns('test.py', code)

        pattern_names = [p.name for p in patterns]
        self.assertIn('dataclass_usage', pattern_names)

    def test_python_async_extractor(self):
        """Test Python async pattern detection."""
        extractor = PythonPatternExtractor()

        code = '''
import asyncio

async def fetch_data():
    await asyncio.sleep(1)
    return {"data": "value"}
'''
        patterns = extractor.extract_patterns('test.py', code)

        pattern_names = [p.name for p in patterns]
        self.assertIn('async_function', pattern_names)

    def test_python_exception_extractor(self):
        """Test Python exception handling detection."""
        extractor = PythonPatternExtractor()

        code = '''
class ValidationError(Exception):
    pass

def validate(data):
    try:
        if data is None:
            raise ValidationError("Data required")
    except ValidationError as e:
        logger.error(e)
'''
        patterns = extractor.extract_patterns('test.py', code)

        pattern_names = [p.name for p in patterns]
        self.assertIn('exception_handling', pattern_names)
        self.assertIn('custom_exception', pattern_names)

    def test_typescript_extractor(self):
        """Test TypeScript pattern detection."""
        extractor = TypeScriptPatternExtractor()

        code = '''
interface User {
    id: number;
    name: string;
    email?: string;
}

async function fetchUser(id: number): Promise<User> {
    const response = await fetch(`/api/users/${id}`);
    return response.json();
}
'''
        patterns = extractor.extract_patterns('test.ts', code)

        pattern_names = [p.name for p in patterns]
        self.assertIn('interface_definition', pattern_names)
        self.assertIn('async_await', pattern_names)

    def test_rust_extractor(self):
        """Test Rust pattern detection."""
        extractor = RustPatternExtractor()

        code = '''
use std::fs::File;

fn read_file(path: &str) -> Result<String, std::io::Error> {
    let mut file = File::open(path)?;
    let mut contents = String::new();
    file.read_to_string(&mut contents)?;
    Ok(contents)
}
'''
        patterns = extractor.extract_patterns('lib.rs', code)

        pattern_names = [p.name for p in patterns]
        self.assertIn('result_type', pattern_names)
        self.assertIn('error_propagation', pattern_names)

    def test_go_extractor(self):
        """Test Go pattern detection."""
        extractor = GoPatternExtractor()

        code = '''
func ProcessRequest(ctx context.Context, data []byte) error {
    result, err := doWork(ctx, data)
    if err != nil {
        return fmt.Errorf("processing failed: %w", err)
    }
    go notify(result)
    return nil
}
'''
        patterns = extractor.extract_patterns('main.go', code)

        pattern_names = [p.name for p in patterns]
        self.assertIn('error_wrapping', pattern_names)
        self.assertIn('goroutine', pattern_names)
        self.assertIn('context_usage', pattern_names)

    def test_unified_extractor(self):
        """Test unified PatternExtractor."""
        extractor = PatternExtractor()

        files = [
            {'path': 'test.py', 'content': 'async def foo(): pass', 'language': 'python'},
            {'path': 'test.ts', 'content': 'interface Foo {}', 'language': 'typescript'},
        ]

        patterns = extractor.extract_from_files(files)
        self.assertGreater(len(patterns), 0)

    def test_deduplication(self):
        """Test pattern deduplication."""
        extractor = PatternExtractor()

        patterns = [
            Pattern('test', 'category', 'file.py', 1, 5),
            Pattern('test', 'category', 'file.py', 1, 5),  # Duplicate
            Pattern('test', 'category', 'other.py', 1, 5),  # Different file
        ]

        deduped = extractor.deduplicate_patterns(patterns)
        self.assertEqual(len(deduped), 2)


class TestBestPracticesAnalyzer(unittest.TestCase):
    """Tests for Best Practices Analyzer."""

    def test_analyze_python_pattern(self):
        """Test Python pattern analysis."""
        analyzer = BestPracticesAnalyzer()

        pattern = {
            'name': 'dataclass_usage',
            'category': 'architecture',
            'file_path': 'models.py',
            'line_start': 10,
            'line_end': 15,
            'description': 'Use of @dataclass decorator',
            'example_code': '@dataclass\nclass User:',
            'trigger_keywords': ['dataclass', 'model'],
            'metadata': {'language': 'python'},
            'confidence': 0.9
        }

        analyzed = analyzer.analyze_pattern(pattern)

        self.assertIsInstance(analyzed, AnalyzedPattern)
        self.assertGreater(analyzed.best_practice_score, 0)
        self.assertGreater(analyzed.language_applicability, 0)

    def test_analyze_typescript_pattern(self):
        """Test TypeScript pattern analysis."""
        analyzer = BestPracticesAnalyzer()

        pattern = {
            'name': 'interface_definition',
            'category': 'type_safety',
            'file_path': 'types.ts',
            'line_start': 1,
            'line_end': 10,
            'description': 'TypeScript interface',
            'example_code': 'interface User { name: string; }',
            'trigger_keywords': ['interface', 'type'],
            'metadata': {'language': 'typescript'},
            'confidence': 0.9
        }

        analyzed = analyzer.analyze_pattern(pattern)
        self.assertIn('Highly applicable to typescript', analyzed.analysis_notes)

    def test_rule_generation(self):
        """Test rule generation from analyzed pattern."""
        analyzer = BestPracticesAnalyzer()

        pattern = {
            'name': 'custom_exception',
            'category': 'error_handling',
            'file_path': 'errors.py',
            'line_start': 5,
            'line_end': 10,
            'description': 'Custom exception class',
            'example_code': 'class ValidationError(Exception):',
            'trigger_keywords': ['error', 'exception'],
            'metadata': {'language': 'python'},
            'confidence': 0.9
        }

        analyzed = analyzer.analyze_pattern(pattern)
        rule = analyzed.to_rule('https://github.com/test/repo', min_confidence=0.65)

        self.assertIsNotNone(rule)
        self.assertIn('id', rule)
        self.assertIn('source', rule)
        self.assertIn('category', rule)
        self.assertEqual(rule['source'], 'https://github.com/test/repo')

    def test_confidence_threshold_filtering(self):
        """Test confidence threshold filtering."""
        analyzer = BestPracticesAnalyzer()

        # High confidence pattern
        high_conf_pattern = {
            'name': 'async_function',
            'category': 'async_patterns',
            'file_path': 'test.py',
            'line_start': 1,
            'line_end': 5,
            'description': 'Async function',
            'example_code': 'async def foo(): pass',
            'trigger_keywords': ['async'],
            'metadata': {'language': 'python'},
            'confidence': 0.95
        }

        # Low confidence pattern
        low_conf_pattern = {
            'name': 'generic_pattern',
            'category': 'general',
            'file_path': 'test.py',
            'line_start': 1,
            'line_end': 2,
            'description': 'Generic pattern',
            'example_code': 'x = 1',
            'trigger_keywords': [],
            'metadata': {'language': 'python'},
            'confidence': 0.5
        }

        analyzed_high = analyzer.analyze_pattern(high_conf_pattern)
        analyzed_low = analyzer.analyze_pattern(low_conf_pattern)

        rule_high = analyzed_high.to_rule('https://github.com/test/repo', min_confidence=0.8)
        rule_low = analyzed_low.to_rule('https://github.com/test/repo', min_confidence=0.8)

        self.assertIsNotNone(rule_high)  # Should pass threshold
        self.assertIsNone(rule_low)  # Should not pass threshold


class TestProceduralEnricher(unittest.TestCase):
    """Tests for Procedural Memory Enricher."""

    def setUp(self):
        """Set up test fixtures."""
        self.temp_dir = tempfile.mkdtemp()
        self.test_rules_path = Path(self.temp_dir) / 'rules.json'
        self.enricher = ProceduralEnricher(
            rules_path=self.test_rules_path,
            create_backup=False,
            validate_paths=False  # Disable for tests using temp directories
        )

    def tearDown(self):
        """Clean up test fixtures."""
        import shutil
        shutil.rmtree(self.temp_dir)

    def test_load_empty_rules(self):
        """Test loading non-existent rules file."""
        data = self.enricher.load_existing_rules()
        self.assertEqual(data, {'rules': []})

    def test_load_existing_rules(self):
        """Test loading existing rules."""
        existing = {'rules': [{'id': 'test-1', 'category': 'test'}]}
        with open(self.test_rules_path, 'w') as f:
            json.dump(existing, f)

        data = self.enricher.load_existing_rules()
        self.assertEqual(len(data['rules']), 1)

    def test_save_rules(self):
        """Test saving rules atomically."""
        rules_data = {'rules': [{'id': 'test-1', 'name': 'test'}]}

        self.enricher.save_rules(rules_data)

        self.assertTrue(self.test_rules_path.exists())
        with open(self.test_rules_path) as f:
            loaded = json.load(f)
        self.assertEqual(loaded, rules_data)

    def test_validate_valid_rules(self):
        """Test validation of valid rules."""
        rules = {
            'rules': [
                {
                    'id': 'test-1',
                    'source': 'https://github.com/test/repo',
                    'category': 'error_handling',
                    'pattern_name': 'custom_error',
                    'trigger_keywords': ['error', 'exception'],
                    'behavior': 'Use custom error classes',
                    'confidence': 0.9
                }
            ]
        }

        is_valid, errors = self.enricher.validate_rules(rules)
        self.assertTrue(is_valid)
        self.assertEqual(len(errors), 0)

    def test_validate_invalid_rules(self):
        """Test validation of invalid rules."""
        rules = {
            'rules': [
                {
                    'id': 'test-1',
                    # Missing required fields
                }
            ]
        }

        is_valid, errors = self.enricher.validate_rules(rules)
        self.assertFalse(is_valid)
        self.assertGreater(len(errors), 0)

    def test_deduplicate_rules(self):
        """Test rule deduplication."""
        existing = [
            {
                'id': 'existing-1',
                'category': 'error_handling',
                'pattern_name': 'custom_error',
                'confidence': 0.7
            }
        ]

        new_rules = [
            {
                'id': 'new-1',
                'category': 'error_handling',
                'pattern_name': 'custom_error',
                'confidence': 0.9  # Higher confidence
            },
            {
                'id': 'new-2',
                'category': 'async_patterns',
                'pattern_name': 'async_function',
                'confidence': 0.85
            }
        ]

        merged = self.enricher.deduplicate_rules(existing, new_rules)
        self.assertEqual(len(merged), 2)  # 1 duplicate merged + 1 new

        # Check that higher confidence rule was kept
        async_rule = next(r for r in merged if r['pattern_name'] == 'async_function')
        self.assertEqual(async_rule['confidence'], 0.85)

    def test_enrich_workflow(self):
        """Test complete enrichment workflow."""
        new_rules = [
            {
                'id': 'test-1',
                'source': 'https://github.com/test/repo',
                'category': 'error_handling',
                'pattern_name': 'custom_error',
                'trigger_keywords': ['error'],
                'behavior': 'Use custom error classes',
                'confidence': 0.9
            }
        ]

        result = self.enricher.enrich(new_rules, min_confidence=0.8)

        self.assertEqual(len(result['rules']), 1)
        self.assertTrue(self.test_rules_path.exists())

    def test_get_stats(self):
        """Test statistics generation."""
        rules = {
            'rules': [
                {
                    'id': 'test-1',
                    'source': 'https://github.com/test/repo1',
                    'category': 'error_handling',
                    'pattern_name': 'error1',
                    'trigger_keywords': [],
                    'behavior': 'Test',
                    'confidence': 0.9,
                    'language': 'python'
                },
                {
                    'id': 'test-2',
                    'source': 'https://github.com/test/repo2',
                    'category': 'async_patterns',
                    'pattern_name': 'async1',
                    'trigger_keywords': [],
                    'behavior': 'Test',
                    'confidence': 0.85,
                    'language': 'python'
                }
            ]
        }
        with open(self.test_rules_path, 'w') as f:
            json.dump(rules, f)

        stats = self.enricher.get_stats()

        self.assertEqual(stats['total_rules'], 2)
        self.assertIn('error_handling', stats['by_category'])
        self.assertIn('async_patterns', stats['by_category'])
        self.assertEqual(stats['by_language']['python'], 2)


class TestIntegration(unittest.TestCase):
    """Integration tests for the full workflow."""

    def test_full_workflow_simulation(self):
        """Simulate the complete repository learning workflow."""
        # 1. Simulate loaded files from a repository
        files = [
            {
                'path': 'models.py',
                'content': '''
from dataclasses import dataclass
from typing import Optional

@dataclass
class User:
    id: int
    name: str
    email: Optional[str] = None
''',
                'language': 'python'
            },
            {
                'path': 'api.py',
                'content': '''
import asyncio

async def fetch_user(user_id: int) -> User:
    await asyncio.sleep(0.1)
    return User(id=user_id, name="Test")
''',
                'language': 'python'
            }
        ]

        # 2. Extract patterns
        extractor = PatternExtractor()
        patterns = extractor.extract_from_files(files)

        # Convert to dict format
        pattern_dicts = [p.to_dict() for p in patterns]

        # 3. Analyze patterns
        analyzer = BestPracticesAnalyzer()
        rules = analyzer.analyze_patterns(
            pattern_dicts,
            'https://github.com/test/repo',
            min_confidence=0.7
        )

        # 4. Verify rules generated
        self.assertGreater(len(rules), 0)

        # Check rule structure
        for rule in rules:
            self.assertIn('id', rule)
            self.assertIn('source', rule)
            self.assertIn('category', rule)
            self.assertIn('behavior', rule)
            self.assertGreaterEqual(rule['confidence'], 0.7)


def main():
    """Run all tests."""
    loader = unittest.TestLoader()
    suite = unittest.TestSuite()

    # Add test classes
    test_classes = [
        TestGitHubRepoLoader,
        TestPatternExtractor,
        TestBestPracticesAnalyzer,
        TestProceduralEnricher,
        TestIntegration,
    ]

    for test_class in test_classes:
        suite.addTests(loader.loadTestsFromTestCase(test_class))

    # Run with verbosity
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)

    # Return exit code
    return 0 if result.wasSuccessful() else 1


if __name__ == '__main__':
    sys.exit(main())
