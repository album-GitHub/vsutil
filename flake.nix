{
  description = "A collection of general-purpose VapourSynth functions to be reused in modules and scripts.";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, flake-utils }: flake-utils.lib.eachDefaultSystem (system: 
    let
      pkgs = import nixpkgs {
        inherit system;
      };

      ## Change this to update python versions.
      ## run "nix flake lock --update-input nixpkgs" after you did that.
      python = pkgs.python310;

      # On darwin it sadly needs to be monkey-patched still.
      vapoursynth_python =
        if nixpkgs.lib.hasSuffix "-darwin" system then
          python.pkgs.vapoursynth.override {
            vapoursynth = 
              pkgs.vapoursynth.overrideAttrs (old: {
                patches = [];
                meta.broken = false;
                meta.platforms = [ system ];
              });
          }
        else
          python.pkgs.vapoursynth;
    in
    {
      devShells.default = pkgs.mkShell {
        buildInputs = [
          (python.withPackages (ps: [
            vapoursynth_python
          ]))
        ];
      };
      devShell = self.devShell.${system}.default;

      packages.default = python.pkgs.buildPythonPackage {
        pname = "vsutil";
        version = 
          let 
            content = builtins.readFile ./vsutil/_metadata.py;
            version = builtins.match ".*__version__.*'(.*)'.*" content;
          in
          builtins.elemAt version 0;
        src = ./.;
        buildInputs = [
          vapoursynth_python 
        ];
        checkPhase = ''
          ${python}/bin/python -m unittest discover -s $src/tests
        '';
      };

      packages.dist = 
        let
          build_python = python.withPackages (ps: [
            ps.setuptools
            ps.wheel
          ]);
        in
        pkgs.runCommandNoCC "vsutil-dist" { src = ./.; } ''
          # Make sure the package test run.
          echo ${self.packages.${system}.default} >/dev/null

          cp -r $src/* .
          ${build_python}/bin/python setup.py bdist_wheel
          ${build_python}/bin/python setup.py sdist

          mkdir $out
          cp ./dist/* $out
        '';
      defaultPackage = self.packages.${system}.default;
    }
  );
}
