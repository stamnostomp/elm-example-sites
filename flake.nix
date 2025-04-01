{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    flake-utils.url ="github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};


        # Helper for runnig elm live
        elmLiveCommand = pkgs.writeShellScriptBin "elm-dev" ''
          ${pkgs.elmPackages.elm-live}/bin/elm-live src/Main.elm \
            --start-page=public/index.html \
            --port=8000\
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
            export HOME=$TMPDIR
            export JS="elm.js"
          '';

          buildPhase = ''
            # Build with detailed debug output and more memory
            elm make src/Main.elm --output=elm.js --optimize --report=json || elm make src/Main.elm --output=elm.js --optimize

            # Only uglify if the build succeeded
            if [ -f elm.js ]; then
              uglifyjs elm.js --compress "pure_funcs=[F2,F3,F4,F5,F6,F7,F8,F9,A2,A3,A4,A5,A6,A7,A8,A9],pure_getters,keep_fargs=false,unsafe_comps,unsafe" | uglifyjs --mangle --output elm.js
            fi
          '';

          installPhase = ''
            mkdir -p $out/bin
            mkdir -p $out/share/elm-app

            cp elm.js $out/share/elm-app/
            cp -r public/* $out/share/elm-app/

            # Create a simple script to run the app
            cat > $out/bin/elm-app << EOF
            #!/bin/sh
            echo "Opening Elm app in your default browser..."
            cd $out/share/elm-app
            exec python3 -m http.server 8000
            EOF

            chmod +x $out/bin/elm-app
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
          ];

          shellHook =  ''
            echo "Elm development environment loaded!"
            echo "Available commands:"
            echo "elm-dev - start elm live dev server"
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
