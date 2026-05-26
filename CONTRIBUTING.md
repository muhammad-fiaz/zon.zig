# Contributing to zon.zig

Thank you for your interest in contributing to zon.zig! This document provides guidelines and information for contributors.

## Code of Conduct

Please be respectful and constructive in all interactions. We welcome contributors of all experience levels.

## Getting Started

1. Fork the repository
2. Clone your fork: `git clone https://github.com/YOUR_USERNAME/zon.zig.git`
3. Create a feature branch: `git checkout -b feature/your-feature`
4. Make your changes
5. Run tests: `zig build test`
6. Format code: `zig fmt src/ examples/`
7. Commit your changes: `git commit -m "Add your feature"`
8. Push to your fork: `git push origin feature/your-feature`
9. Open a Pull Request

## Development Setup

### Prerequisites

- Zig 0.16.0 or later
- Git

### Building

```bash
# Run tests
zig build test

# Build library
zig build

# Run example
zig build example

# Format code
zig fmt src/ examples/
```

## Pull Request Guidelines

- Keep PRs focused on a single feature or fix
- Include tests for new functionality
- Update documentation as needed
- Follow existing code style
- Write clear commit messages

## Reporting Issues

When reporting issues, please include:

- Zig version (`zig version`)
- Operating system and version
- Minimal code example that reproduces the issue
- Expected vs actual behavior

## Code Style

- Follow Zig standard library conventions
- Use meaningful variable and function names
- Add comments for complex logic
- Keep functions focused and small

## Testing

All new features should include tests. Run the test suite before submitting:

```bash
zig build test
```

## Documentation

- Update README.md for user-facing changes
- Add docstrings to public functions
- Update VitePress docs in `docs/` for significant features

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
