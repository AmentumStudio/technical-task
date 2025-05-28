{
  inputs = {
    nixpkgs.url = "github:cachix/devenv-nixpkgs/rolling";
    nixpkgs-python = {
      url = "github:cachix/nixpkgs-python";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    systems.url = "github:nix-systems/default";
    devenv = {
      url = "github:cachix/devenv";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  nixConfig = {
    extra-trusted-public-keys = "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw=";
    extra-substituters = "https://devenv.cachix.org";
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-python,
      devenv,
      systems,
      ...
    }@inputs:
    let
      forEachSystem = nixpkgs.lib.genAttrs (import systems);
      projects = [
        "default"
        "greeter"
      ];
      forEachProject = nixpkgs.lib.genAttrs projects;
    in
    {
      packages = forEachSystem (
        system:
        forEachProject (
          project:
          let
            config = self.devShells.${system}.${project}.config;
          in
          {
            "${project}-devenv-up" = config.procfileScript;
            "${project}-devenv-test" = config.test;
          }
        )
      );

      devShells = forEachSystem (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          pkgs-python = nixpkgs-python.packages.${system};
          python-with-lsp =
            version:
            (pkgs-python."${version}".withPackages (
              ps: with ps; [
                # LSP
                python-lsp-server
                python-lsp-jsonrpc
                python-lsp-ruff
                # Dev extensions
                importlib
                importlib_metadata
                packaging
                tomli
              ]
            ));
          greeter = devenv.lib.mkShell {
            inherit inputs pkgs;
            modules = [
              {
                enterShell = ''
                  echo "devenv==greeter";
                '';
                languages.python = {
                  enable = true;
                  directory = "./containers/greeter/buildcontext";
                  package = python-with-lsp "3.13.2";
                  uv = {
                    enable = true;
                    sync = {
                      # pyproject.toml has to exist
                      enable = true;
                      allExtras = true;
                      arguments = [
                        "--all-groups"
                      ];
                    };
                  };
                };
              }
            ];
          };
        in
        {
          default = greeter;
          greeter = greeter;
        }
      );
    };
}
