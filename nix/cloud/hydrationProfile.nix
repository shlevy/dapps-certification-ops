{
  inputs,
  cell,
}: let
  inherit (inputs.bitte-cells) patroni;
  namespaces = ["prod"];
  components = ["database"];
in {
  # Bitte Hydrate Module
  # -----------------------------------------------------------------------
  #
  # reconcile with: `nix run .#clusters.[...].tf.[app-|secrets-]hydrate.(plan/apply)`
  default = {
    lib,
    config,
    terralib,
    ...
  }: let
    inherit (terralib) allowS3For;
    bucketArn = "arn:aws:s3:::${config.cluster.s3Bucket}";
    allowS3ForBucket = allowS3For bucketArn;
    inherit (terralib) var id;
    c = "create";
    r = "read";
    u = "update";
    d = "delete";
    l = "list";
    s = "sudo";
    secretsFolder = "encrypted";
    starttimeSecretsPath = "kv/nomad-cluster";
    runtimeSecretsPath = "runtime";
  in {
    imports = [
      (patroni.hydrationProfiles.hydrate-cluster ["prod"])
    ];
    # NixOS-level hydration
    #
    # TODO: declare as proper tf hydration
    #
    # --------------
    cluster = {
      name = "dapps-certification";
      adminNames = ["shlevy"];
      developerGithubNames = [];
      developerGithubTeamNames = ["dapps-certification-devs"];
      domain = "certification.dapps.iog.io";
      extraAcmeSANs = [];
      kms = "arn:aws:kms:eu-central-1:616347046642:key/3ac80c44-4fc1-4463-8ba2-c57d94e9cdb3";
      s3Bucket = "iog-dapps-certification-bitte";
    };
    services = {
      nomad.namespaces = {
        prod = {description = "dApps certification as a service";};
      };
    };
    # cluster level
    # --------------
    tf.hydrate-cluster.configuration = {
      # data.vault_policy_document.admin.rule = [
      #   { path = "${runtimeSecretsPath}/*"; capabilities = [ c r u d l ]; }
      # ];
      # resource.vault_mount.${runtimeSecretsPath} = {
      #   path = "${runtimeSecretsPath}";
      #   type = "kv-v2";
      #   description = "Applications can access runtime secrets if they have access credentials for them";
      # };
      locals.policies = {
        nomad.admin.namespace."*".policy = "write";
      };
    };
    # application secrets
    # --------------
    tf.hydrate-secrets.configuration = let
      _componentsXNamespaces = (
        lib.cartesianProductOfSets {
          namespace = namespaces;
          component = components;
          stage = ["starttime"];
          # stage = [ "runtime" "starttime" ];
        }
      );
      secretFile = g:
        ./.
        + "/${secretsFolder}/${g.namespace}/${g.component}-${g.namespace}-${g.stage}.enc.yaml";
      hasSecretFile = g: builtins.pathExists (secretFile g);
      secretsData.sops_file =
        builtins.foldl' (
          old: g:
            old
            // (
              lib.optionalAttrs (hasSecretFile g) {
                # Decrypting secrets from the files
                "${g.component}-secrets-${g.namespace}-${g.stage}".source_file = "${secretFile g}";
              }
            )
        ) {}
        _componentsXNamespaces;
      secretsResource.vault_generic_secret =
        builtins.foldl' (
          old: g:
            old
            // (
              lib.optionalAttrs (hasSecretFile g) (
                if g.stage == "starttime"
                then
                  {
                    # Loading secrets into the generic kv secrets resource
                    "${g.component}-${g.namespace}-${g.stage}" = {
                      path = "${starttimeSecretsPath}/${g.namespace}/${g.component}";
                      data_json = var "jsonencode(yamldecode(data.sops_file.${
                        g.component
                      }-secrets-${
                        g.namespace
                      }-${
                        g.stage
                      }.raw))";
                    };
                  }
                else
                  {
                    # Loading secrets into the generic kv secrets resource
                    "${g.component}-${g.namespace}-${g.stage}" = {
                      path = "${runtimeSecretsPath}/${g.namespace}/${g.component}";
                      data_json = var "jsonencode(yamldecode(data.sops_file.${
                        g.component
                      }-secrets-${
                        g.namespace
                      }-${
                        g.stage
                      }.raw))";
                    };
                  }
              )
            )
        ) {}
        _componentsXNamespaces;
    in {
      data = secretsData;
      resource = secretsResource;
    };
    # application state
    # --------------
    tf.hydrate-app.configuration = {};
  };
}
