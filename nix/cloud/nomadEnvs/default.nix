{
  inputs,
  cell,
}: let
  inherit (inputs) data-merge;
  inherit (inputs.bitte-cells) cardano patroni;
  prod = {
    namespace = "prod";
    datacenters = ["eu-central-1"];
    domain = "atala.iog.io";
    nodeClass = "prod";
  };
  prod-atala' = import ./atalaNode/default.nix {
    image = "ghcr.io/input-output-hk/prism-node:1.2-9f683bc7";
    namespace = "prod";
    domain = "atala.iog.io";
    nodeClass = "prod";
  };
in {
  # rename to: testnetdev
  prod = let
    dbEnv = {
      DB = "cicero";
      WALG_S3_PREFIX = "s3://iog-dapps-certification-bitte/backups/prod/walg";
    };
  in {
    database = data-merge.merge (patroni.nomadJob.default (prod // {scaling = 1;})) {
      job.database.group.database.task.patroni.env = dbEnv;
      job.database.group.database.task.backup-walg.env = dbEnv;
    };
  };
}
