{
  inputs,
  cell,
}: let
  inherit (inputs) nixpkgs;
  inherit (inputs.nixpkgs) dockerTools;
in {
  telegraf = let
    entrypoint = nixpkgs.writeShellScript "entrypoint" ''
      exec /bin/telegraf -config /local/telegraf.config
    '';
  in
    dockerTools.buildImage {
      name = "docker.atala.iog.io/telegraf";
      contents = [nixpkgs.telegraf];
      config = {Entrypoint = [entrypoint];};
    };
}
