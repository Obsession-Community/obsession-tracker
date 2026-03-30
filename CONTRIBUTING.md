# Contributing to Obsession Tracker

Thank you for your interest in contributing to Obsession Tracker! This document provides guidelines and information for contributors.

## Table of Contents

1. [Code of Conduct](#code-of-conduct)
2. [Getting Started](#getting-started)
3. [Development Process](#development-process)
4. [Coding Standards](#coding-standards)
5. [Testing Requirements](#testing-requirements)
6. [Privacy Considerations](#privacy-considerations)
7. [Submitting Changes](#submitting-changes)
8. [Issue Guidelines](#issue-guidelines)
9. [Feature Requests](#feature-requests)
10. [Documentation](#documentation)

## Code of Conduct

This project adheres to the [Contributor Covenant Code of Conduct](CODE_OF_CONDUCT.md).
By participating, you are expected to uphold this code. Please report unacceptable
behavior to **conduct@obsessiontracker.com**.

## Getting Started

### Prerequisites

Before contributing, ensure you have:

- Flutter 3.x or later installed
- Dart SDK 3.x or later
- Git configured with your GitHub account
- IDE with Flutter support (VS Code or Android Studio recommended)
- Understanding of the project's privacy-first principles

### Development Environment Setup

1. **Fork the repository** to your GitHub account
2. **Clone your fork** locally:
   ```bash
   git clone https://github.com/YOUR_USERNAME/obsession-tracker.git
   cd obsession-tracker
   ```

3. **Add upstream remote**:
   ```bash
   git remote add upstream https://github.com/Obsession-Community/obsession-tracker.git
   ```

4. **Install dependencies**:
   ```bash
   flutter pub get
   ```

5. **Run tests** to ensure everything works:
   ```bash
   flutter test
   ```

### First-Time Contributors

Good first issues are labeled with `good-first-issue`. These typically include:
- Documentation improvements
- UI/UX enhancements
- Test coverage improvements
- Bug fixes with clear reproduction steps

## Development Process

### Branching Strategy

- **main**: Production-ready code
- **develop**: Integration branch for features
- **feature/**: Individual feature branches
- **bugfix/**: Bug fix branches
- **milestone/**: Milestone-specific work

### Workflow

1. **Create a branch** from `develop`:
   ```bash
   git checkout develop
   git pull upstream develop
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes** following coding standards
3. **Write tests** for new functionality
4. **Run quality checks**:
   ```bash
   flutter test
   flutter analyze
   dart format .
   ```

5. **Commit your changes** with descriptive messages
6. **Push to your fork** and create a pull request

### Commit Message Guidelines

Use clear, descriptive commit messages:

```
type(scope): brief description

- Detailed explanation of changes
- Why the change was made
- Any breaking changes

Fixes #123
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation
- `style`: Formatting changes
- `refactor`: Code restructuring
- `test`: Adding tests
- `chore`: Maintenance tasks

**Scopes:**
- `tracking`: GPS and location features
- `ui`: User interface changes
- `db`: Database operations
- `export`: Data export/import
- `security`: Privacy and security features

**Examples:**
```
feat(tracking): add configurable GPS update intervals

- Allow users to set update frequency from 5-30 seconds
- Improves battery life for longer expeditions
- Maintains accuracy for treasure hunting needs

Fixes #45
```

## Coding Standards

### Dart/Flutter Guidelines

Follow the project's coding standards as outlined in [docs/development-guidelines.md](docs/development-guidelines.md):

- **Effective Dart**: Follow official Dart style guide
- **Meaningful Names**: Use descriptive variable and function names
- **Self-Documenting Code**: Write code that explains its purpose
- **Privacy by Design**: Never log sensitive location data

### Code Organization

```dart
// Import order:
// 1. Dart core libraries
import 'dart:async';

// 2. Flutter libraries
import 'package:flutter/material.dart';

// 3. Third-party packages (alphabetical)
import 'package:geolocator/geolocator.dart';

// 4. Local imports (alphabetical)
import '../domain/entities/session.dart';
```

### Naming Conventions

- **Classes**: PascalCase (`SessionManager`)
- **Functions/Variables**: camelCase (`startTracking`)
- **Constants**: lowerCamelCase (`defaultTrackingInterval`)
- **Files**: snake_case (`session_manager.dart`)
- **Private Members**: prefix with underscore (`_validateGps`)

## Testing Requirements

### Test Coverage Standards

- **Business Logic**: 90%+ coverage required
- **UI Components**: 80%+ coverage
- **Critical Paths**: 100% coverage (data loss prevention, privacy)

### Test Types

#### Unit Tests
```dart
group('SessionManager', () {
  test('should create new tracking session', () async {
    // Arrange
    final sessionManager = SessionManager(mockRepository);

    // Act
    final result = await sessionManager.startSession('Test Adventure');

    // Assert
    expect(result, isA<Success>());
  });
});
```

#### Widget Tests
```dart
testWidgets('TrackingButton displays correct state', (tester) async {
  await tester.pumpWidget(TestApp(child: TrackingButton()));

  expect(find.text('Start Tracking'), findsOneWidget);
});
```

#### Integration Tests
```dart
testWidgets('complete tracking workflow', (tester) async {
  // Test full user journey from start to finish
});
```

### Running Tests

```bash
# All tests
flutter test

# With coverage
flutter test --coverage

# Integration tests
flutter test integration_test/

# Specific test file
flutter test test/unit/session_manager_test.dart
```

## Privacy Considerations

### Core Privacy Principles

1. **Local-First**: All core features must work offline
2. **No Tracking**: Never collect user behavior data
3. **Minimal Permissions**: Request only necessary permissions
4. **Secure by Default**: Encrypt sensitive data
5. **User Control**: Users own and control their data

### Privacy Guidelines for Contributors

- **Never log GPS coordinates** in production code
- **Encrypt sensitive data** before storage
- **Use mock data** in tests and examples
- **Document privacy implications** of new features
- **Consider privacy in UI/UX design**

### Code Review Privacy Checklist

- [ ] No location data in logs or debug output
- [ ] Sensitive data properly encrypted
- [ ] No unauthorized network requests
- [ ] Privacy-preserving defaults
- [ ] Clear user consent for optional features

## Submitting Changes

### Pull Request Process

1. **Ensure your PR addresses an existing issue** or create one first
2. **Fill out the PR template** completely
3. **Include screenshots** for UI changes
4. **Update documentation** if needed
5. **Add tests** for new functionality
6. **Verify all checks pass**

### PR Title Format

```
type(scope): brief description (#issue-number)
```

Example:
```
feat(tracking): add battery optimization settings (#123)
```

### PR Description Template

```markdown
## Description
Brief description of changes and motivation.

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Testing
- [ ] Unit tests pass
- [ ] Integration tests pass
- [ ] Manual testing completed
- [ ] Privacy review completed

## Screenshots
Include screenshots for UI changes.

## Checklist
- [ ] Code follows style guidelines
- [ ] Self-reviewed code
- [ ] Commented complex algorithms
- [ ] Updated documentation
- [ ] No breaking changes or documented
- [ ] Privacy implications considered

## Related Issues
Fixes #123
Related to #456
```

### Review Process

1. **Automated Checks**: CI/CD runs tests and analysis
2. **Privacy Review**: Maintainer reviews privacy implications
3. **Code Review**: Technical review by maintainers
4. **Testing**: Manual testing of changes
5. **Approval**: Two maintainer approvals required
6. **Merge**: Squash and merge to maintain clean history

## Issue Guidelines

### Bug Reports

Use the bug report template and include:

- **Device Information**: OS version, device model
- **App Version**: Current version number
- **Steps to Reproduce**: Clear, numbered steps
- **Expected Behavior**: What should happen
- **Actual Behavior**: What actually happens
- **Screenshots**: Visual evidence if applicable
- **Logs**: Relevant error messages (no location data!)

### Example Bug Report

```markdown
**Device Info:**
- OS: iOS 16.1
- Device: iPhone 14 Pro
- App Version: 1.2.0

**Steps to Reproduce:**
1. Start tracking session
2. Take photo at waypoint
3. Stop tracking
4. Open session details

**Expected:** Photo should appear in session
**Actual:** Photo is missing from session

**Screenshots:** [attached]
```

## Feature Requests

### Feature Request Guidelines

- **Check existing issues** to avoid duplicates
- **Align with project goals** and privacy principles
- **Consider milestone roadmap** timing
- **Provide detailed use cases** and benefits
- **Include mockups** for UI features

### Feature Request Template

```markdown
## Feature Description
Clear description of the proposed feature.

## Use Case
Why is this feature needed? Who would use it?

## Privacy Considerations
How does this feature align with privacy principles?

## Implementation Ideas
Any thoughts on how to implement this?

## Alternatives Considered
Other solutions you've considered.

## Additional Context
Screenshots, mockups, or examples.
```

## Documentation

### Documentation Standards

- **Clear and Concise**: Easy to understand
- **Examples Included**: Show don't just tell
- **Privacy Focused**: Highlight privacy features
- **User-Centric**: Written from user perspective
- **Up-to-Date**: Maintained with code changes

### Documentation Types

- **User Guide**: End-user documentation
- **API Documentation**: Internal and external APIs
- **Architecture**: Technical system design
- **Development Guidelines**: Coding standards
- **Milestones**: Project roadmap and progress

### Contributing to Documentation

1. **Use clear language** appropriate for the audience
2. **Include examples** and screenshots where helpful
3. **Maintain consistent formatting** with existing docs
4. **Test instructions** by following them yourself
5. **Update related documentation** when making changes

## Getting Help

### Communication Channels

- **GitHub Issues**: Bug reports and feature requests
- **GitHub Discussions**: General questions and ideas
- **Code Reviews**: Technical discussion on PRs
- **Documentation**: First check existing docs

### Maintainer Contact

For urgent privacy or security concerns, contact maintainers directly through GitHub.

### Response Times

- **Bug Reports**: 48-72 hours initial response
- **Feature Requests**: 1 week initial review
- **Pull Requests**: 1 week for first review
- **Security Issues**: 24 hours response

## Recognition

Contributors will be recognized in:
- Project README.md
- Release notes for significant contributions
- Special recognition for milestone contributions

Thank you for contributing to Obsession Tracker! Together we're building the best privacy-first adventure tracking app for explorers and treasure hunters worldwide.

**Happy hunting!** 🏴‍☠️
