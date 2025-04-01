# Elm Examples Hub

A collection of interactive Elm example applications demonstrating the Elm architecture and various UI components.

## Live Demo

**[View the live application](https://stamnostomp.github.io/elm-example-sites/)**

Explore the working examples directly in your browser without installation.

## Examples Included

- **Counter**: A simple counter demonstrating basic Elm architecture
- **Todo List**: A task management application with filtering and editing capabilities
- **Calculator**: A basic calculator with arithmetic operations

## Development

This project uses Nix flakes for reproducible development environments and builds.

### Prerequisites

- [Nix](https://nixos.org/download.html) with flakes enabled

### Local Development

```bash
# Enter the development shell with all needed dependencies
nix develop

# Start the development server
elm-dev
```

The application will be available at http://localhost:8000.

### Building for Production

```bash
# Build the optimized application
nix build
```

The built application will be in `result/share/elm-app/`.

## Deployment

This project is configured for automatic deployment to GitHub Pages when changes are pushed to the main branch. You can view the deployed application at:

https://stamnostomp.github.io/elm-example-sites/

### Manual Deployment

You can also trigger a deployment manually:

1. Go to the GitHub repository
2. Navigate to the "Actions" tab
3. Select the "Deploy Elm Application" workflow
4. Click "Run workflow"

## License

This project is licensed under the MIT License - see the LICENSE file for details.
