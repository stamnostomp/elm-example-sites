{
  description = "Elm Examples Hub with WebSocket Chat Server";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        # Create a wrapper script that generates a precompiled elm.js file
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

        # Build the Haskell WebSocket Chat Server
        chatServer = pkgs.haskellPackages.developPackage {
          root = ./src/Chat;
          name = "elm-chat-server";
          modifier = drv:
            pkgs.haskell.lib.overrideCabal drv (oldAttrs: {
              buildTools = (oldAttrs.buildTools or []) ++ [
                pkgs.haskellPackages.cabal-install
              ];
              enableLibraryProfiling = false;
              enableExecutableProfiling = false;
              doHaddock = false;
              doCheck = false;
              doBenchmark = false;
            });
        };

        # Script to run both the Elm app and chat server
        runBothScript = pkgs.writeShellScriptBin "run-elm-with-chat" ''
          #!/usr/bin/env bash
          set -euo pipefail

          echo "Starting Elm WebSocket Chat Server and Elm App"
          echo "================================================"

          # Start the Haskell chat server in the background
          echo "Starting Chat Server on port 9160..."
          ${chatServer}/bin/elm-chat-server &
          CHAT_SERVER_PID=$!

          # Give it a moment to start
          sleep 1

          # Start the Elm development server
          echo "Starting Elm development server..."
          ${elmLiveCommand}/bin/elm-dev

          # When elm-dev is terminated, also kill the chat server
          kill $CHAT_SERVER_PID
          echo "Both servers have been stopped."
        '';

        # New script to install required Elm packages for WebSocket functionality
        elmPackageSetupScript = pkgs.writeShellScriptBin "setup-elm-websocket" ''
          #!/usr/bin/env bash
          set -euo pipefail

          echo "Installing required Elm WebSocket packages..."

          # Check if elm is available
          if ! command -v elm &> /dev/null; then
            echo "Error: elm is not installed or not in path"
            exit 1
          fi

          # Install the required packages - use --yes to auto-accept
          echo "Installing billstclair/elm-port-funnel..."
          elm install billstclair/elm-port-funnel --yes

          echo "Installing billstclair/elm-port-funnel-websocket..."
          elm install billstclair/elm-port-funnel-websocket --yes

          echo "Installing billstclair/elm-websocket-client... (fallback option)"
          elm install billstclair/elm-websocket-client --yes

          # Create the ports JavaScript file if it doesn't exist
          if [ ! -f "public/port-funnel.js" ]; then
            echo "Creating port-funnel.js helper file in public directory..."
            mkdir -p public
            cat > public/port-funnel.js << 'EOF'
// Port Funnel support for Elm WebSocket
(function() {
    // Set up ports for the Elm app
    function setupPorts(app) {
        if (!app.ports || !app.ports.cmdPort || !app.ports.subPort) {
            console.error("Required ports not found in Elm application");
            return;
        }

        // Handle commands from Elm
        app.ports.cmdPort.subscribe(function(data) {
            if (data && data.module === "WebSocket") {
                handleWebSocketCommand(data.tag, data.args, app.ports.subPort.send);
            }
        });

        console.log("Port Funnel WebSocket setup complete");
    }

    // WebSocket connections
    var sockets = {};

    // Handle WebSocket commands
    function handleWebSocketCommand(tag, args, sendBack) {
        console.log("WebSocket command:", tag, args);

        switch (tag) {
            case "open":
                openSocket(args.url, args.name, sendBack);
                break;
            case "send":
                sendMessage(args.name, args.message, sendBack);
                break;
            case "close":
                closeSocket(args.name, args.code, args.reason, sendBack);
                break;
        }
    }

    // Open a WebSocket connection
    function openSocket(url, name, sendBack) {
        if (sockets[name]) {
            closeSocket(name, 1000, "Reopening", sendBack);
        }

        try {
            var socket = new WebSocket(url);
            sockets[name] = socket;

            socket.onopen = function() {
                sendBack({
                    module: "WebSocket",
                    tag: "response",
                    args: {
                        name: name,
                        response: { type: "connected" }
                    }
                });
            };

            socket.onmessage = function(event) {
                sendBack({
                    module: "WebSocket",
                    tag: "response",
                    args: {
                        name: name,
                        response: {
                            type: "messageReceived",
                            message: event.data
                        }
                    }
                });
            };

            socket.onclose = function(event) {
                delete sockets[name];
                sendBack({
                    module: "WebSocket",
                    tag: "response",
                    args: {
                        name: name,
                        response: {
                            type: "disconnected",
                            code: event.code,
                            reason: event.reason
                        }
                    }
                });
            };

            socket.onerror = function(error) {
                sendBack({
                    module: "WebSocket",
                    tag: "response",
                    args: {
                        name: name,
                        response: {
                            type: "error",
                            error: "WebSocket error"
                        }
                    }
                });
            };
        } catch (error) {
            sendBack({
                module: "WebSocket",
                tag: "response",
                args: {
                    name: name,
                    response: {
                        type: "error",
                        error: error.message
                    }
                }
            });
        }
    }

    // Send a message through the WebSocket
    function sendMessage(name, message, sendBack) {
        var socket = sockets[name];
        if (socket && socket.readyState === WebSocket.OPEN) {
            socket.send(message);
        } else {
            sendBack({
                module: "WebSocket",
                tag: "response",
                args: {
                    name: name,
                    response: {
                        type: "error",
                        error: "WebSocket not open"
                    }
                }
            });
        }
    }

    // Close a WebSocket connection
    function closeSocket(name, code, reason, sendBack) {
        var socket = sockets[name];
        if (socket) {
            try {
                socket.close(code || 1000, reason || "");
                delete sockets[name];
            } catch (error) {
                sendBack({
                    module: "WebSocket",
                    tag: "response",
                    args: {
                        name: name,
                        response: {
                            type: "error",
                            error: error.message
                        }
                    }
                });
            }
        }
    }

    // Expose the setup function
    window.portFunnelSetup = {
        websocket: setupPorts
    };
})();
EOF

            echo "Created port-funnel.js helper file in public directory"
          fi

          # Update index.html to include the port funnel script if needed
          if [ -f "public/index.html" ] && ! grep -q "port-funnel.js" "public/index.html"; then
            echo "Adding port-funnel.js script reference to index.html..."
            sed -i 's|</head>|    <script src="port-funnel.js"></script>\n</head>|' public/index.html
          fi

          echo "WebSocket setup complete!"
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
                <script src="port-funnel.js"></script>
              </head>
              <body>
                <div id="elm-app"></div>
                <script src="elm.js"></script>
                <script>
                  var app = Elm.Main && Elm.Main.init ?
                    Elm.Main.init({
                      node: document.getElementById("elm-app")
                    }) : null;

                  // Set up port funnel for WebSocket if available
                  if (app && window.portFunnelSetup && window.portFunnelSetup.websocket) {
                    window.portFunnelSetup.websocket(app);
                  }
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
            elmPackageSetupScript # New WebSocket setup script

            # Haskell development tools
            haskellPackages.cabal-install
            haskellPackages.ghc
            haskellPackages.haskell-language-server

            # Combined run script
            runBothScript
          ];

          shellHook = ''
            echo "Elm Examples Hub development environment loaded!"
            echo ""
            echo "Available commands:"
            echo "  elm-dev            - Start elm live dev server"
            echo "  prebuild-elm       - Create a prebuilt elm.js file for use with nix build"
            echo "  setup-elm-websocket - Install required Elm WebSocket packages and create helper JS"
            echo "  run-elm-with-chat  - Run both the Elm app and the WebSocket chat server"
            echo ""
            echo "To create a production build:"
            echo "  1. Run 'prebuild-elm' to create the optimized JavaScript file"
            echo "  2. Run a) 'nix build .#app' to build just the Elm app"
            echo "        b) 'nix build .#chatServer' to build just the WebSocket server"
            echo "        c) 'nix build' to build both"
            echo ""
            echo "For WebSocket functionality:"
            echo "  1. First run 'setup-elm-websocket' to install necessary packages"
            echo "  2. Make sure your Main.elm is changed to 'port module Main exposing (main)'"
            echo "  3. Add the port declarations to your Main.elm file"
            echo ""
          '';
        };

      in
      {
        packages = {
          default = elmApp;
          app = elmApp;
          chatServer = chatServer;
        };

        devShells.default = devShell;

        apps = {
          default = {
            type = "app";
            program = "${elmApp}/bin/elm-app";
          };

          chatServer = {
            type = "app";
            program = "${chatServer}/bin/elm-chat-server";
          };

          combined = {
            type = "app";
            program = "${runBothScript}/bin/run-elm-with-chat";
          };
        };
      }
    );
}
