{
  description = "Elm Examples Hub with WebSocket Chat Server";

  # Declarative, reproducible input sources
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  # System-agnostic output generation
  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        # Import the package set for the current system
        pkgs = nixpkgs.legacyPackages.${system};

        # Haskell WebSocket Chat Server Build
        chatServer = pkgs.haskellPackages.developPackage {
          root = ./src/Chat;
          name = "elm-chat-server";

          # Customize Haskell package build
          modifier = drv:
            pkgs.haskell.lib.overrideCabal drv (oldAttrs: {
              # Essential build tools
              buildTools = (oldAttrs.buildTools or []) ++ [
                pkgs.haskellPackages.cabal-install
                pkgs.pkg-config
              ];

              # Add zlib and other necessary libraries
              buildInputs = (oldAttrs.buildInputs or []) ++ [
                pkgs.zlib
                pkgs.zlib.dev
                pkgs.libffi
              ];

              # Configure library paths
              configureFlags = (oldAttrs.configureFlags or []) ++ [
                "--extra-include-dirs=${pkgs.zlib.dev}/include"
                "--extra-lib-dirs=${pkgs.zlib}/lib"
              ];

              # Disable unnecessary build steps
              enableLibraryProfiling = false;
              enableExecutableProfiling = false;
              doHaddock = false;
              doCheck = false;
              doBenchmark = false;
            });
        };

        # Elm Application Build Derivation
        elmApp = pkgs.stdenv.mkDerivation {
          name = "elm-examples-hub";
          src = ./.;

          buildInputs = with pkgs; [
            elmPackages.elm
            nodejs
            uglify-js
          ];

          buildPhase = ''
            # Prepare build directory
            mkdir -p build/public

            # Compile Elm application
            elm make src/Main.elm --optimize --output=build/elm.js

            # Minify JavaScript
            uglifyjs build/elm.js --compress --mangle --output=build/elm.min.js

            # Copy static files
            cp -r public/* build/public/ 2>/dev/null || true

            # Explicitly copy websocket.js with verbose output
            echo "Copying WebSocket JavaScript file..."
            cp -v src/Chat/websocket.js build/public/websocket.js

            # Verify the file was copied
            ls -l build/public/websocket.js
          '';

          installPhase = ''
            # Create output directory
            mkdir -p $out/share/elm-app

            # Copy all files from build/public to output
            cp -r build/public/* $out/share/elm-app/

            # Copy minified Elm JS
            cp build/elm.min.js $out/share/elm-app/elm.js

            # Extra verification
            echo "Files in output directory:"
            ls -l $out/share/elm-app/
          '';
        };
        # Comprehensive Development Shell
        devShell = pkgs.mkShell {
          buildInputs = with pkgs; [
            # Elm Tools
            elmPackages.elm
            elmPackages.elm-format
            elmPackages.elm-live
            elmPackages.elm-test

            # JavaScript and Node Utilities
            nodejs
            nodePackages.npm
            uglify-js

            # Haskell Development
            haskellPackages.cabal-install
            haskellPackages.ghc
            haskellPackages.haskell-language-server

            # System Libraries
            zlib
            zlib.dev
            libffi
            pkg-config

            # Custom Development Scripts
            (pkgs.writeShellScriptBin "elm-dev" ''
              cp src/Chat/websocket.js public/websocket.js
              elm-live src/Main.elm \
                --start-page=public/index.html \
                --port=8000 \
                -- --output=public/elm.js
            '')

            (pkgs.writeShellScriptBin "start-chat-server" ''
              cd src/Chat
              cabal run
            '')
          ];

          # Helpful Shell Configuration
          shellHook = ''
            echo "🌳 Elm Examples Hub Development Environment 🌳"
            echo "Available commands:"
            echo "  elm-dev           - Start development server"
            echo "  start-chat-server - Start WebSocket chat server"
            echo "  elm make          - Compile Elm application"
            echo "  elm-format        - Format Elm code"

            # Configure library paths
            export PKG_CONFIG_PATH="${pkgs.zlib.dev}/lib/pkgconfig:$PKG_CONFIG_PATH"
          '';
        };

      in {
        # Expose Packages and Development Shell
        packages = {
          default = elmApp;
          app = elmApp;
          chatServer = chatServer;
        };

        devShells.default = devShell;

        # Executable Applications
        apps = {
          default = {
            type = "app";
            program = "${elmApp}/bin/run-elm-app";
          };
          chatServer = {
            type = "app";
            program = "${chatServer}/bin/elm-chat-server";
          };
        };
      }
    );
}
