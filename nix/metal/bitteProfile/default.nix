{
  inputs,
  cell,
}: let
  inherit (inputs.bitte-cells) patroni;
in {
  default = {
    self,
    lib,
    pkgs,
    config,
    terralib,
    bittelib,
    ...
  } @ args: let
    inherit (self.inputs) bitte;
    inherit (bittelib) mkNomadHostVolumesConfig;
    inherit (config) cluster;
    inherit (import ./security-group-rules.nix args) securityGroupRules;
  in {
    imports = [];
    secrets.encryptedRoot = ./encrypted;
    nix = {
      binaryCaches = ["https://hydra.iohk.io"];
      binaryCachePublicKeys = ["hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ="];
    };
    cluster = {
      s3CachePubKey = lib.fileContents ./encrypted/nix-public-key-file;
      flakePath = "${self}";
      awsAutoScalingGroups = let
        defaultModules = [
          (bitte + "/profiles/client.nix")
          ./secrets.nix
          ./nomad-client-config.nix
          (
            {
              boot.kernelModules = ["softdog"];
              #
              # Watchdog events will be logged but not force the nomad client node to restart
              # Comment this line out to allow forced watchdog restarts
              # Patroni HA Postgres jobs will utilize watchdog and log additional info if it's available
              boot.extraModprobeConfig = "options softdog soft_noboot=1";
            }
          )
        ];
      in
        lib.listToAttrs (
          lib.forEach [
            {
              region = "eu-central-1";
              desiredCapacity = 3;
              instanceType = "t3a.2xlarge";
              volumeSize = 500;
              modules =
                defaultModules
                ++ [
                  (patroni.nixosProfiles.client "prod")
                ];
              node_class = "prod";
            }
          ] (args: let
            attrs = ({
              desiredCapacity = 1;
              instanceType = "t3a.large";
              associatePublicIP = true;
              maxInstanceLifetime = 0;
              iam.role = cluster.iam.roles.client;
              iam.instanceProfile.role = cluster.iam.roles.client;

              securityGroupRules = {
                inherit (securityGroupRules) internet internal ssh;
              };
            }
            // args);
            asgName = "client-${attrs.region}-${
              builtins.replaceStrings [''.''] [''-''] attrs.instanceType
            }-${args.node_class}";
          in
            lib.nameValuePair asgName attrs)
        );
      coreNodes = {
        core-1 = {
          instanceType = "t3a.medium";
          privateIP = "172.16.0.10";
          subnet = cluster.vpc.subnets.core-1;
          volumeSize = 100;
          modules = [
            (bitte + /profiles/core.nix)
            (bitte + /profiles/bootstrapper.nix) # doubles up as non-tf reconciliation looper
            ./secrets.nix
          ];
          securityGroupRules = {inherit (securityGroupRules) internet internal ssh;};
        };
        core-2 = {
          instanceType = "t3a.medium";
          privateIP = "172.16.1.10";
          subnet = cluster.vpc.subnets.core-2;
          volumeSize = 100;
          modules = [(bitte + /profiles/core.nix) ./secrets.nix];
          securityGroupRules = {inherit (securityGroupRules) internet internal ssh;};
        };
        core-3 = {
          instanceType = "t3a.medium";
          privateIP = "172.16.2.10";
          subnet = cluster.vpc.subnets.core-3;
          volumeSize = 100;
          modules = [(bitte + /profiles/core.nix) ./secrets.nix];
          securityGroupRules = {inherit (securityGroupRules) internet internal ssh;};
        };
        monitoring = {
          instanceType = "t3a.xlarge";
          privateIP = "172.16.0.20";
          subnet = cluster.vpc.subnets.core-1;
          volumeSize = 300;
          modules = [(bitte + /profiles/monitoring.nix) ./secrets.nix];

          securityGroupRules = {
            inherit
              (securityGroupRules)
              internet
              internal
              ssh
              http
              https
              ;
          };
        };
        routing = {
          instanceType = "t3a.small";
          privateIP = "172.16.1.20";
          subnet = cluster.vpc.subnets.core-2;
          volumeSize = 30;
          route53.domains = [
            "*.${cluster.domain}"
            "consul.${cluster.domain}"
            "monitoring.${cluster.domain}"
            "nomad.${cluster.domain}"
            "vault.${cluster.domain}"
          ];
          modules = [(bitte + /profiles/routing.nix) ./secrets.nix];
          securityGroupRules = {
            inherit
              (securityGroupRules)
              internet
              internal
              ssh
              http
              routing
              ;
          };
        };
        # GlusterFS storage nodes
        storage-0 = {
          instanceType = "t3a.small";
          privateIP = "172.16.0.30";
          subnet = config.cluster.vpc.subnets.core-1;
          volumeSize = 40;
          ebsVolume = {
            iops = 3000; # 3000..16000
            size = 500; # GiB
            type = "gp3";
            throughput = 125; # 125..1000 MiB/s
          };

          modules = [(bitte + /profiles/glusterfs/storage.nix)];

          securityGroupRules = {
            inherit (securityGroupRules) internal internet ssh;
          };
        };

        storage-1 = {
          instanceType = "t3a.small";
          privateIP = "172.16.1.20";
          subnet = config.cluster.vpc.subnets.core-2;
          volumeSize = 40;
          ebsVolume = {
            iops = 3000; # 3000..16000
            size = 500; # GiB
            type = "gp3";
            throughput = 125; # 125..1000 MiB/s
          };

          modules = [(bitte + /profiles/glusterfs/storage.nix)];

          securityGroupRules = {
            inherit (securityGroupRules) internal internet ssh;
          };
        };

        storage-2 = {
          instanceType = "t3a.small";
          privateIP = "172.16.2.20";
          subnet = config.cluster.vpc.subnets.core-3;
          volumeSize = 40;
          ebsVolume = {
            iops = 3000; # 3000..16000
            size = 500; # GiB
            type = "gp3";
            throughput = 125; # 125..1000 MiB/s
          };

          modules = [(bitte + /profiles/glusterfs/storage.nix)];

          securityGroupRules = {
            inherit (securityGroupRules) internal internet ssh;
          };
        };
      };
    };
  };
}
