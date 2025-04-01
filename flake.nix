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
            -- -- output=elm.js --debug
        '';

        elmApp = pkgs.stdenv.mkDerivation {
          name = "elm-example-pages";
          src = ./.;

          buildInputs = with pkgs; [
            elmPackages.elm
            nodejs
            uglify-js
          ];

          configuerPhase = ''
            export HOME=$TMPDIR
            export JS="elm.js"
          '';

          buildPhase = ''
            elm make src/Main.elm --output=public/elm.js --optimize
            uglifyjs public/elm.js --compress "pure_funcs=[F2,F3,F4,F5,F6,F7,F8,F9,A2,A3,A4,A5,A6,A7,A8,A9],pure_getters,keep_fargs=false,unsafe_comps,unsafe" | uglifyjs --mangle --output public/elm.js
          '';

          installPhase = ''
            mkdir -p $out/bin
            mkdir -P $out/share/elm-app

            cp public/elm.js $out/share/elm-app/
            cp public/style.css $out/share/elm-app/
            cp public/index.html $out/share/elm-app/

            cat > $out/bin/elm-app >>EOF
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
            echo "Availible command:"
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
