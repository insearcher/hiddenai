# Contributing to HiddenAI

Thank you for your interest in contributing to HiddenAI! This document provides guidelines and instructions for contributing to this project.

## Code of Conduct

Please be respectful and considerate of others when contributing to this project. We aim to foster an inclusive and welcoming community.

## Getting Started

1. Fork the repository
2. Clone your fork: `git clone https://github.com/insearcher/hiddenai.git`
3. Create a new branch for your changes: `git checkout -b feature/your-feature-name`
4. Make your changes
5. Test your changes thoroughly
6. Commit your changes: `git commit -m "Add your descriptive commit message"`
7. Push to your branch: `git push origin feature/your-feature-name`
8. Create a Pull Request

## Development Environment

- macOS 12.0+
- Xcode 14.0+
- Swift 5.7+

## Project Structure

- **HiddenAIClient/** - Main application code
  - **Application/** - App lifecycle and entry point
  - **DI/** - Dependency injection container
  - **Features/** - Feature-specific UI and logic
  - **Managers/** - Service managers
  - **Services/** - Core functionality services
  - **UI/** - UI components and themes

## Coding Standards

- Follow Swift style guidelines
- Use meaningful variable and function names
- Add comments for complex logic
- Create unit tests for new functionality when possible
- Keep functions small and focused on a single responsibility

## Pull Request Process

1. Update the README.md with details of your changes if necessary
2. Ensure your code builds and passes all tests
3. Make sure your code follows the project's coding standards
4. Your Pull Request will be reviewed by the maintainers
5. Address any requested changes
6. Once approved, your PR will be merged

## Feature Requests

If you have ideas for new features, please open an issue with the following:

1. A clear and descriptive title
2. A detailed description of the proposed feature
3. Any relevant examples or mockups

## Bug Reports

When reporting bugs, please include:

1. A clear and descriptive title
2. Steps to reproduce the issue
3. Expected behavior
4. Actual behavior
5. Screenshots (if applicable)
6. Your environment (macOS version, app version)

## License

By contributing to this project, you agree that your contributions will be licensed under the project's [MIT License](LICENSE.md).
