{
  description = "Elm Examples Hub with sandbox-compatible builds";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        # Create a wrapper script that generates a precompiled elm.js file
        # This script should be run on your development machine, not during the build
        elmPrebuilderScript = pkgs.writeShellScriptBin "prebuild-elm" ''
          #!/usr/bin/env bash
          set -euo pipefail

          echo "Pre-building Elm application locally..."

          # Ensure elm is installed
          if ! command -v elm &> /dev/null; then
            echo "Error: elm is not installed. Please install it with 'npm install -g elm'"
            exit 1
          fi

          # Compile the app
          elm make src/Main.elm --optimize --output=prebuilt-elm.js

          # Minify if uglifyjs is available
          if command -v uglifyjs &> /dev/null; then
            echo "Minifying JavaScript..."
            uglifyjs prebuilt-elm.js --compress "pure_funcs=[F2,F3,F4,F5,F6,F7,F8,F9,A2,A3,A4,A5,A6,A7,A8,A9],pure_getters,keep_fargs=false,unsafe_comps,unsafe" | uglifyjs --mangle --output=prebuilt-elm.min.js
            mv prebuilt-elm.min.js prebuilt-elm.js
          fi

          echo "Done! The prebuilt file is at: prebuilt-elm.js"
          echo "You can now run 'nix build' to create the full application."
        '';

        # Helper script for running elm live in development
        elmLiveCommand = pkgs.writeShellScriptBin "elm-dev" ''
          # Run elm-live
          ${pkgs.elmPackages.elm-live}/bin/elm-live src/Main.elm \
            --start-page=public/index.html \
            --port=8000 \
            --host=localhost \
            --pushstate \
            --hot \
            -- --output=elm.js --debug
        '';

        elmApp = pkgs.stdenv.mkDerivation {
          name = "elm-example-pages";
          src = ./.;

          buildInputs = with pkgs; [
            elmPackages.elm
            nodejs
            uglify-js
          ];

          configurePhase = ''
            echo "Configuring build..."
          '';

          buildPhase = ''
            echo "Building Elm application..."

            mkdir -p build

            # Check if a prebuilt elm.js exists
            if [ -f prebuilt-elm.js ]; then
              echo "Using prebuilt Elm JavaScript file"
              cp prebuilt-elm.js build/elm.js
            else
              # If not, provide a placeholder with instructions
              echo "No prebuilt Elm file found. Creating a placeholder."
              cat > build/elm.js << EOF
            // This is a placeholder for the Elm-generated JavaScript
            console.log("This is a placeholder for the Elm application.");
            document.addEventListener('DOMContentLoaded', function() {
              var appEl = document.getElementById('elm-app');
              if (appEl) {
                appEl.innerHTML = '<div style="padding: 20px; text-align: center; font-family: sans-serif;">' +
                  '<h2>Elm Application Placeholder</h2>' +
                  '<p>To create a working build, run these commands on your development machine:</p>' +
                  '<pre style="background: #f0f0f0; padding: 10px; display: inline-block; text-align: left; margin: 20px;">npm install -g elm uglify-js<br>elm make src/Main.elm --optimize --output=prebuilt-elm.js<br>nix build</pre>' +
                  '<p>Or run locally with: <code>nix develop</code> followed by <code>elm-dev</code></p>' +
                  '</div>';
              }
            });
            EOF
            fi
          '';

          installPhase = ''
            echo "Installing Elm application..."

            # Create output directories
            mkdir -p $out/bin
            mkdir -p $out/share/elm-app

            # Copy the compiled JS
            cp build/elm.js $out/share/elm-app/

            # Copy all files from public directory if it exists
            if [ -d public ]; then
              cp -r public/* $out/share/elm-app/
            fi

            # Ensure index.html exists
            if [ ! -f $out/share/elm-app/index.html ]; then
              cat > $out/share/elm-app/index.html << EOF
            <!DOCTYPE html>
            <html lang="en">
              <head>
                <meta charset="utf-8" />
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
                <title>Elm Examples Hub</title>
                <link rel="stylesheet" href="style.css">
              </head>
              <body>
                <div id="elm-app"></div>
                <script src="elm.js"></script>
                <script>
                  var app = Elm.Main && Elm.Main.init ?
                    Elm.Main.init({
                      node: document.getElementById("elm-app")
                    }) : null;
                </script>
              </body>
            </html>
            EOF
            fi

            # Create a launcher script
            cat > $out/bin/elm-app << EOF
            #!/bin/sh
            echo "Opening Elm app in your default browser..."
            cd $out/share/elm-app
            exec python3 -m http.server 8000
            EOF

            chmod +x $out/bin/elm-app

            echo "Installation complete! Files installed:"
            ls -la $out/share/elm-app/
          '';
        };

        devShell = pkgs.mkShell {
          buildInputs = with pkgs; [
            elmPackages.elm
            elmPackages.elm-format
            elmPackages.elm-live
            elmPackages.elm-test
            elmPackages.elm-review
            elmPackages.elm-analyse
            nodejs
            elmLiveCommand
            elmPrebuilderScript  # Include our prebuilder script
          ];

          shellHook = ''
            echo "Elm development environment loaded!"
            echo ""
            echo "Available commands:"
            echo "  elm-dev     - Start elm live dev server"
            echo "  prebuild-elm - Create a prebuilt elm.js file for use with nix build"
            echo ""
            echo "To create a production build:"
            echo "  1. Run 'prebuild-elm' to create the optimized JavaScript file"
            echo "  2. Run 'nix build' to create the full application"
            echo ""
          '';
        };

      in
      {
        packages.default = elmApp;
        devShells.default = devShell;

        apps.default = {
          type = "app";
          program = "${elmApp}/bin/elm-app";
        };
      }
    );
}
