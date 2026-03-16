{
  description = "Neovim derivation";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    gen-luarc.url = "github:mrcjkb/nix-gen-luarc-json";

    # Add bleeding-edge plugins here.
    # They can be updated with `nix flake update` (make sure to commit the generated flake.lock)
    # wf-nvim = {
    #   url = "github:Cassin01/wf.nvim";
    #   flake = false;
    # };
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    ...
  }: let
    systems = [ "x86_64-linux" "aarch64-darwin" ];

    # This is where the Neovim derivation is built.
    neovim-overlay = import ./nix/neovim-overlay.nix {inherit inputs;};

    forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f {
      pkgs = import nixpkgs { inherit system; overlays = [
        # Import the overlay, so that the final Neovim derivation(s) can be accessed via pkgs.<nvim-pkg>
        self.overlays.default

        # This adds a function can be used to generate a .luarc.json
        # containing the Neovim API all plugins in the workspace directory.
        # The generated file can be symlinked in the devShell's shellHook.
        inputs.gen-luarc.overlays.default
      ]; };
    });
  in
  {
    packages = forAllSystems ({ pkgs }: rec {
      default = nvim;
      nvim = pkgs.nvim-pkg;
    });

    devShells = forAllSystems ({ pkgs }: {
      default = pkgs.mkShell {
        name = "nvim-devShell";
        buildInputs = with pkgs; [
          # Tools for Lua and Nix development, useful for editing files in this repo
          lua-language-server
          nil
          stylua
          luajitPackages.luacheck
          nvim-dev
        ];
        shellHook = ''
          # symlink the .luarc.json generated in the overlay
          ln -fs ${pkgs.nvim-luarc-json} .luarc.json
          # allow quick iteration of lua configs
          ln -Tfns $PWD/nvim ~/.config/nvim-dev
        '';
      };
    });

    # You can add this overlay to your NixOS configuration
    overlays.default = neovim-overlay;
  };
}
