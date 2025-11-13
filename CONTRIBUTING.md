# Contributing to MCP-ZedChat

Thank you for your interest in contributing to MCP-ZedChat! This document provides guidelines and instructions for contributing to this project.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Workflow](#development-workflow)
- [Coding Standards](#coding-standards)
- [Testing](#testing)
- [Submitting Changes](#submitting-changes)
- [Reporting Issues](#reporting-issues)

## Code of Conduct

This project follows a simple code of conduct:

- Be respectful and inclusive
- Welcome newcomers and help them learn
- Focus on constructive feedback
- Assume good intentions
- Keep discussions professional and on-topic

## Getting Started

### Prerequisites

- Swift 6.0+ (Xcode 16+)
- macOS 13.0+ or compatible platform
- Git

### Setting Up Development Environment

1. Fork the repository on GitHub
2. Clone your fork locally:
   ```bash
   git clone https://github.com/YOUR_USERNAME/MCP-ZedChat.git
   cd MCP-ZedChat
   ```

3. Add the upstream repository:
   ```bash
   git remote add upstream https://github.com/ORIGINAL_OWNER/MCP-ZedChat.git
   ```

4. Fetch dependencies:
   ```bash
   swift package resolve
   ```

5. Build the project:
   ```bash
   swift build
   ```

6. Run tests to verify everything works:
   ```bash
   swift test
   ```

## Development Workflow

### Branching Strategy

- `main` - Stable, production-ready code
- Feature branches - `feature/your-feature-name`
- Bug fix branches - `fix/issue-description`
- Documentation branches - `docs/what-you-are-documenting`

### Making Changes

1. Create a new branch from `main`:
   ```bash
   git checkout main
   git pull upstream main
   git checkout -b feature/your-feature-name
   ```

2. Make your changes following the [Coding Standards](#coding-standards)

3. Add tests for new functionality

4. Ensure all tests pass:
   ```bash
   swift test
   ```

5. Commit your changes with clear, descriptive messages:
   ```bash
   git commit -m "Add feature: description of what you did"
   ```

### Commit Message Guidelines

- Use present tense ("Add feature" not "Added feature")
- Use imperative mood ("Move cursor to..." not "Moves cursor to...")
- Limit first line to 72 characters
- Reference issues and pull requests when relevant

Examples:
- `Add timestamp tool for getting current time`
- `Fix division by zero error in calculate tool`
- `Update README with installation instructions`
- `Refactor ServerHandlers for better testability`

## Coding Standards

### Swift Style Guide

Follow the [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/):

- Use clear, descriptive names for variables and functions
- Prefer clarity over brevity
- Use camelCase for function and variable names
- Use PascalCase for type names
- Prefer structs over classes when possible
- Mark types as `final` when inheritance isn't needed

### Code Organization

```swift
// MARK: - Section Title

/// Documentation comment describing what this does
/// - Parameter name: Description of parameter
/// - Returns: Description of return value
func functionName(parameter: Type) -> ReturnType {
    // Implementation
}
```

### Error Handling

- Use `throw` for recoverable errors
- Return `Result` types for operations that can fail without being exceptional
- Use `MCPError` for MCP-specific errors
- Always provide meaningful error messages

### Concurrency

- Mark functions as `async` when they perform asynchronous work
- Use `await` explicitly rather than nested closures
- Prefer structured concurrency over callbacks
- Use actors for managing mutable state

### Documentation

- Add documentation comments (`///`) for all public types and functions
- Include parameter descriptions and return value descriptions
- Add examples for complex functionality
- Update README.md when adding new features

## Testing

### Writing Tests

- Place tests in `Tests/MCPZedChatTests/`
- Name test files with `Tests` suffix (e.g., `ServerHandlersTests.swift`)
- Use descriptive test names: `testCalculateToolReturnsCorrectSum()`
- Follow the Arrange-Act-Assert pattern
- Test both success and failure cases

Example test structure:

```swift
func testNewFeature() async throws {
    // Arrange
    let server = createTestServer()
    await ServerHandlers.registerHandlers(on: server)
    let transport = InMemoryTransport()
    try await server.start(transport: transport)
    
    // Act
    let result = try await performAction()
    
    // Assert
    XCTAssertEqual(result, expectedValue)
    
    // Cleanup
    await server.stop()
}
```

### Running Tests

```bash
# Run all tests
swift test

# Run with verbose output
swift test --verbose

# Run specific test
swift test --filter MCPZedChatTests.testEchoTool

# Run tests in parallel
swift test --parallel
```

### Test Coverage

- Aim for high test coverage on critical paths
- Test edge cases and error conditions
- Don't test trivial getters/setters
- Focus on behavior, not implementation details

## Submitting Changes

### Pull Request Process

1. Update documentation to reflect your changes
2. Add tests for new functionality
3. Ensure all tests pass locally
4. Push your changes to your fork:
   ```bash
   git push origin feature/your-feature-name
   ```

5. Create a pull request on GitHub

6. Fill out the pull request template completely

7. Link any related issues

### Pull Request Guidelines

- Keep PRs focused on a single feature or fix
- Write a clear description of what changes and why
- Include screenshots/examples for UI or behavior changes
- Respond to review feedback promptly
- Be open to suggestions and constructive criticism

### Pull Request Checklist

- [ ] Tests pass locally (`swift test`)
- [ ] New tests added for new functionality
- [ ] Documentation updated (README, code comments)
- [ ] Code follows project style guidelines
- [ ] Commit messages are clear and descriptive
- [ ] No merge conflicts with `main`
- [ ] Self-review completed

## Reporting Issues

### Bug Reports

When reporting bugs, include:

- **Description**: Clear description of the bug
- **Steps to Reproduce**: Detailed steps to reproduce the issue
- **Expected Behavior**: What you expected to happen
- **Actual Behavior**: What actually happened
- **Environment**: 
  - Swift version (`swift --version`)
  - OS version
  - Xcode version (if applicable)
- **Logs**: Relevant error messages or logs
- **Additional Context**: Screenshots, configuration files, etc.

### Feature Requests

When requesting features, include:

- **Use Case**: Why is this feature needed?
- **Proposed Solution**: How should it work?
- **Alternatives**: Other approaches you've considered
- **Impact**: Who would benefit from this feature?

### Security Issues

**Do not report security vulnerabilities in public issues.**

Instead, email security concerns to the maintainers privately.

## Development Tips

### Debugging

Enable debug logging in `main.swift`:

```swift
handler.logLevel = .debug
```

### Testing with MCP Inspector

```bash
npm install -g @modelcontextprotocol/inspector
mcp-inspector swift run mcp-zedchat
```

### Testing with Claude Desktop

Update your Claude Desktop config and check logs:
- macOS: `~/Library/Logs/Claude/mcp*.log`

### Hot Reload Development

For faster iteration, use `swift run` which automatically rebuilds on changes.

## Resources

- [MCP Specification](https://spec.modelcontextprotocol.io/)
- [MCP Swift SDK](https://github.com/modelcontextprotocol/swift-sdk)
- [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- [Swift Service Lifecycle](https://github.com/swift-server/swift-service-lifecycle)

## Questions?

If you have questions not covered here:

- Check existing issues and discussions
- Open a new discussion on GitHub
- Reach out to maintainers

## Recognition

Contributors will be recognized in:
- The project README
- Release notes
- GitHub contributors list

Thank you for contributing to MCP-ZedChat! 🚀