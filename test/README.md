# Obsession Tracker - Test Suite

This directory contains comprehensive tests for the Obsession Tracker Flutter application, covering both unit tests for business logic and widget tests for UI components.

## 📁 Test Structure

```
test/
├── core/                           # Core layer tests
│   ├── models/                     # Data model tests
│   │   ├── breadcrumb_test.dart
│   │   ├── tracking_session_test.dart
│   │   └── waypoint_test.dart
│   ├── services/                   # Service layer tests
│   │   └── location_service_test.dart
│   ├── providers/                  # State management tests
│   │   └── location_provider_test.dart
│   └── widgets/                    # Shared widget tests
│       └── adaptive_layout_test.dart
├── features/                       # Feature layer tests
│   ├── home/                       # Home feature tests
│   │   └── presentation/pages/
│   │       ├── home_page_test.dart
│   │       └── adaptive_home_page_test.dart
│   ├── map/                        # Map feature tests
│   │   └── presentation/
│   │       ├── pages/map_page_test.dart
│   │       └── widgets/
│   │           ├── trail_color_legend_test.dart
│   │           └── trail_color_selector_test.dart
│   ├── sessions/                   # Sessions feature tests
│   │   └── presentation/pages/
│   │       └── session_list_page_test.dart
│   ├── statistics/                 # Statistics feature tests
│   │   └── presentation/widgets/
│   │       ├── statistics_overlay_test.dart
│   │       └── statistics_panel_test.dart
│   ├── tracking/                   # Tracking feature tests
│   │   └── presentation/pages/
│   │       └── tracking_page_test.dart
│   └── waypoints/                  # Waypoints feature tests
│       └── presentation/widgets/
│           ├── waypoint_count_chip_test.dart
│           └── waypoint_creation_dialog_test.dart
├── test_runner.dart                # Comprehensive test runner
└── README.md                       # This file
```

## 🧪 Test Categories

### Core Layer Tests

- **Models**: Data structure validation, serialization, business logic
- **Services**: External service integration, API calls, data processing
- **Providers**: State management, reactive updates, provider behavior
- **Widgets**: Shared UI components, adaptive layouts, responsive design

### Feature Layer Tests

- **Home**: Main navigation, welcome screens, adaptive layouts
- **Map**: Map display, trail visualization, color customization
- **Sessions**: Session management, list display, filtering
- **Statistics**: Real-time stats, overlays, configuration
- **Tracking**: GPS tracking, session controls, location display
- **Waypoints**: Waypoint creation, photo capture, type selection

## 🚀 Running Tests

### Run All Tests

```bash
# Run complete test suite
flutter test test/test_runner.dart

# Run with coverage report
flutter test --coverage test/test_runner.dart

# Generate HTML coverage report
genhtml coverage/lcov.info -o coverage/html
```

### Run Specific Test Groups

```bash
# Core layer tests only
flutter test test/test_runner.dart --name "Core Layer Tests"

# Feature layer tests only
flutter test test/test_runner.dart --name "Feature Layer Tests"

# Specific feature tests
flutter test test/test_runner.dart --name "Home Feature"
flutter test test/test_runner.dart --name "Map Feature"
flutter test test/test_runner.dart --name "Tracking Feature"
```

### Run Individual Test Files

```bash
# Single test file
flutter test test/core/models/tracking_session_test.dart

# Specific test group within a file
flutter test test/features/home/presentation/pages/home_page_test.dart --name "HomePage Widget Tests"
```

## 📊 Test Coverage Goals

| Component       | Target Coverage | Current Status  |
| --------------- | --------------- | --------------- |
| Core Models     | 95%+            | ✅ Comprehensive |
| Core Services   | 90%+            | ✅ Comprehensive |
| Core Providers  | 90%+            | ✅ Comprehensive |
| Core Widgets    | 85%+            | ✅ Comprehensive |
| Feature Pages   | 80%+            | ✅ Comprehensive |
| Feature Widgets | 80%+            | ✅ Comprehensive |

## 🎯 Test Types and Patterns

### Unit Tests

- **Models**: Validation, serialization, business rules
- **Services**: API integration, data processing, error handling
- **Providers**: State management, reactive behavior

### Widget Tests

- **Rendering**: UI component display and layout
- **Interaction**: User input, gestures, navigation
- **State**: Widget state changes, provider integration
- **Accessibility**: Screen reader support, text scaling
- **Responsive**: Different screen sizes and orientations

### Test Patterns Used

- **Arrange-Act-Assert**: Clear test structure
- **Given-When-Then**: Behavior-driven test descriptions
- **Mock Objects**: Isolated testing with controlled dependencies
- **Golden Tests**: Visual regression testing for complex widgets
- **Accessibility Tests**: Large text scaling, semantic labels

## 🛠️ Testing Best Practices

### Test Organization

- Group related tests logically
- Use descriptive test names
- Follow consistent naming conventions
- Separate unit and widget tests

### Test Quality

- Test one thing at a time
- Use meaningful assertions
- Include edge cases and error scenarios
- Test accessibility features

### Mock Strategy

- Mock external dependencies
- Use simple test implementations
- Avoid over-mocking internal components
- Test real integrations where appropriate

### Performance

- Keep tests fast and focused
- Use `pumpAndSettle()` for animations
- Clean up resources in `tearDown()`
- Avoid unnecessary widget rebuilds

## 🔧 Test Configuration

### Dependencies

```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  mockito: ^5.4.0
  build_runner: ^2.4.0
```

### Test Environment

- Flutter SDK: Latest stable
- Dart SDK: Latest stable
- Test runner: Built-in Flutter test runner
- Coverage: LCOV format

## 📈 Continuous Integration

### GitHub Actions

```yaml
- name: Run Tests
  run: flutter test test/test_runner.dart

- name: Generate Coverage
  run: flutter test --coverage test/test_runner.dart

- name: Upload Coverage
  uses: codecov/codecov-action@v3
  with:
    file: coverage/lcov.info
```

### Quality Gates

- All tests must pass
- Coverage threshold: 80%+
- No test warnings or errors
- Performance benchmarks met

## 🐛 Debugging Tests

### Common Issues

- **Provider not found**: Ensure proper ProviderScope setup
- **Widget not found**: Check widget tree structure and keys
- **Async issues**: Use `pumpAndSettle()` for animations
- **Mock failures**: Verify mock setup and expectations

### Debug Commands

```bash
# Verbose test output
flutter test --verbose test/test_runner.dart

# Debug specific test
flutter test test/path/to/test.dart --name "specific test name"

# Run tests in debug mode
flutter test --debug test/test_runner.dart
```

## 📚 Additional Resources

- [Flutter Testing Documentation](https://docs.flutter.dev/testing)
- [Widget Testing Guide](https://docs.flutter.dev/cookbook/testing/widget)
- [Riverpod Testing](https://riverpod.dev/docs/cookbooks/testing)
- [Accessibility Testing](https://docs.flutter.dev/development/accessibility-and-localization/accessibility)

## 🤝 Contributing

When adding new features:

1. Write tests first (TDD approach)
2. Ensure comprehensive coverage
3. Follow existing test patterns
4. Update this documentation
5. Run full test suite before submitting

---

**Last Updated**: January 2025
**Test Count**: 15+ test files covering core and feature layers
**Coverage Target**: 80%+ overall, 90%+ for critical components
