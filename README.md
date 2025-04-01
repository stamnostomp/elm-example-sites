# Elm Examples Hub

A collection of Elm example applications demonstrating the Elm architecture and various UI components.

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

This project is configured for automatic deployment to GitHub Pages when changes are pushed to the main branch.

### Manual Deployment

You can also trigger a deployment manually:

1. Go to the GitHub repository
2. Navigate to the "Actions" tab
3. Select the "Deploy Elm Application" workflow
4. Click "Run workflow"

### Local Preview of Production Build

To preview the production build locally:

```bash
# Build the application
nix build

# Serve the built files
cd result/share/elm-app
python -m http.server
```

Then visit http://localhost:8000 in your browser.

## License

This project is licensed under the MIT License - see the LICENSE file for details.
