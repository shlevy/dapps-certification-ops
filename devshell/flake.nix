{
  description = "Atala Repository top-level development shell";
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
  inputs.devshell.url = "github:numtide/devshell?ref=refs/pull/169/head";
  inputs.alejandra.url = "github:kamadorueda/alejandra";
  inputs.alejandra.inputs.treefmt.url = "github:divnix/blank";
  inputs.flake-utils.url = "github:numtide/flake-utils";
  inputs.main.url = "path:../.";
  outputs = inputs:
    inputs.flake-utils.lib.eachSystem ["x86_64-linux" "x86_64-darwin"] (
      system: let
        inherit
          (inputs.main.inputs.std.deSystemize system inputs)
          main
          devshell
          nixpkgs
          alejandra
          ;
        inherit
          (main.inputs.std.deSystemize system inputs.main.inputs)
          bitte-cells
          bitte
          std
          ;
        inherit
          (std.deSystemize system bitte.inputs)
          cli
          ;
        inherit (main.clusters.dapps-certification) _proto;
      in {
        devShells.__default = devshell.legacyPackages.mkShell (
          {
            extraModulesPath,
            pkgs,
            ...
          }: {
            name = nixpkgs.lib.mkForce "dapps-certification";
            imports = [
              cli.devshellModules.bitte
              std.std.devshellProfiles.default
              bitte-cells.patroni.devshellProfiles.default
            ];
            bitte = {
              domain = "certification.dapps.iog.io";
              cluster = "dapps-certification";
              namespace = "prod";
              provider = "AWS";
              cert = null;
              aws_profile = "dapps-prod";
              aws_region = "eu-central-1";
              aws_autoscaling_groups =
                _proto.config.cluster.awsAutoScalingGroups;
            };
            cellsFrom = "./nix";
            packages = [
              # formatters
              alejandra.defaultPackage
            ];
          }
        );
      }
    );
}
