{
  description = "Atala Bitte-based deployment";
  inputs.std.url = "github:divnix/std/v22-03-07";
  inputs.data-merge.url = "github:divnix/data-merge";
  inputs = {
    # --- Bitte Stack ----------------------------------------------
    bitte.url = "github:input-output-hk/bitte/bitte-with-glusterfs";
    bitte-cells.url = "github:input-output-hk/bitte-cells/cardano-glusterfs";
    # --------------------------------------------------------------
    # --- Auxiliary Nixpkgs ----------------------------------------
    nixpkgs.follows = "std/nixpkgs";
  };
  outputs = inputs:
    inputs.std.growOn {
      inherit inputs;
      as-nix-cli-epiphyte = false;
      cellsFrom = ./nix;
      # debug = ["cells" "cloud" "nomadEnvs"];
      organelles = [
        (inputs.std.data "nomadEnvs")
        (inputs.std.functions "bitteProfile") # To be managed by devops
        # (inputs.std.installables "packages") # Managed by application team (under cloud)
        (inputs.std.functions "hydrationProfile") # Managed by application team
      ];
    }
    # soil (TODO: eat up soil)
    (
      let
        system = "x86_64-linux";
      in
        inputs.bitte.lib.mkBitteStack {
          inherit inputs;
          inherit (inputs) self;
          domain = "certification.dapps.iog.io";
          bitteProfile = inputs.self.${system}.metal.bitteProfile.default;
          nomadEnvs = inputs.self.${system}.cloud.nomadEnvs;
          hydrationProfile = inputs.self.${system}.cloud.hydrationProfile.default;
          deploySshKey = "./secrets/ssh-dapps-certification";
        }
    );
  # --- Flake Local Nix Configuration ----------------------------
  nixConfig = {
    extra-substituters = [
      # "s3://iog-atala-bitte/infra/binary-cache/?region=eu-central-1"
      "https://hydra.iohk.io"
    ];
    extra-trusted-public-keys = [
      # "atala-testnet-0:otGI8c4lhgZP//m6xtpYOhNp4mlfr5i0j0TY1bibzHU="
      "hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ="
    ];
    # post-build-hook = "./upload-to-cache.sh";
    allow-import-from-derivation = "true";
  };
  # --------------------------------------------------------------
}
