# See: https://www.nomadproject.io/docs/job-specification/job
{
  namespace,
  image,
  domain,
  nodeClass,
}: {
  job = {
    atalaNode = {
      constraint = [
        {
          attribute = "\${node.class}";
          operator = "=";
          value = "${nodeClass}";
        }
      ];
      datacenters = ["eu-central-1" "eu-west-1" "us-east-2"];
      group.atala-node = {
        count = 1;
        network = [
          {
            dns = [{servers = ["172.17.0.1"];}];
            mode = "bridge";
            reserved_ports = {
              atala = [
                {
                  static = 50053;
                  to = 50053;
                }
              ];
              atalaMetrics = [
                {
                  static = 9095;
                  to = 9095;
                }
              ];
              atalaStatus = [
                {
                  static = 5266;
                  to = 5266;
                }
              ];
            };
          }
        ];
        reschedule = [
          {
            delay = "30s";
            delay_function = "exponential";
            max_delay = "1h0m0s";
            unlimited = true;
          }
        ];
        service = [
          {
            address_mode = "auto";
            name = "${namespace}-atala-node";
            port = "50053";
            tags = [
              "${namespace}"
              "ingress"
              # "traefik.consulcatalog.connect=true"
              "traefik.enable=true"
              "traefik.http.routers.${namespace}-atala-node.rule=Host(`${namespace}.${domain}`)"
              "traefik.http.routers.${namespace}-atala-node.entrypoints=grpc"
              "traefik.http.routers.${namespace}-atala-node.tls=false"
              "traefik.http.services.${namespace}-atala-node.loadbalancer.server.scheme=h2c"
            ];
          }
        ];
        task.atala-node = {
          config = {
            args = [
              "-c"
              ''
                echo "Sleeping 60 seconds" && sleep 60 && /usr/local/openjdk-11/bin/java -classpath /usr/app/node.jar io.iohk.atala.prism.node.NodeApp''
            ];
            cap_add = null;
            command = "/bin/bash";
            entrypoint = null;
            force_pull = false;
            inherit image;
            interactive = null;
            ipc_mode = null;
            labels = [];
            logging = {
              config = [];
              type = "journald";
            };
            mount = null;
            ports = ["atala" "atalaMetrics" "atalaStatus"];
            sysctl = null;
          };
          driver = "docker";
          kill_signal = "SIGTERM";
          kill_timeout = "1m0s";
          resources = {
            cpu = 1000;
            memory = 2048;
          };
          template = [
            {
              change_mode = "restart";
              data = ''
                NODE_PSQL_HOST="master.${namespace}-database.service.consul"
                NODE_PSQL_DATABASE="atala"

                {{with secret "kv/nomad-cluster/${namespace}/atalaNode"}}
                NODE_PSQL_USERNAME="{{.Data.data.nodePsqlUsername}}"
                NODE_PSQL_PASSWORD="{{.Data.data.nodePsqlPassword}}"
                {{end}}

                NODE_CARDANO_DB_SYNC_HOST="master.${namespace}-database.service.consul"
                NODE_CARDANO_DB_SYNC_DATABASE="dbsync"

                {{with secret "kv/nomad-cluster/${namespace}/db-sync"}}
                NODE_CARDANO_DB_SYNC_USERNAME="{{.Data.data.pgUser}}"
                NODE_CARDANO_DB_SYNC_PASSWORD="{{.Data.data.pgPass}}"
                {{end}}

                NODE_CARDANO_WALLET_API_HOST="${namespace}-wallet.service.consul"
                NODE_CARDANO_WALLET_API_PORT="8090"

                {{with secret "kv/nomad-cluster/${namespace}/wallet"}}
                NODE_CARDANO_WALLET_PASSPHRASE="{{.Data.data.cardanoWalletInitPass}}"
                {{end}}

                NODE_CARDANO_PAYMENT_ADDRESS="addr_test1qzv6psz0xn6lrmmetptvq5nxepe2paaz4svmt5ge7l0h5exyhf9k0y43x2z2kruutzt92ful9avelvn95sl4t4fs5ejs4f8zm9"

                NODE_CARDANO_WALLET_ID="2076d57875e348137b8291f0fd8210f8866a5792"

                NODE_CARDANO_CONFIRMATION_BLOCKS="1"
                NODE_LEDGER="cardano"
              '';
              destination = "/secrets/env.sh";
              env = true;
              left_delimiter = "{{";
              perms = "0644";
              right_delimiter = "}}";
              splay = "5s";
            }
          ];
          vault = {
            change_mode = "noop";
            env = true;
            policies = ["nomad-cluster"];
          };
        };
      };
      id = "atalaNode";
      namespace = "${namespace}";
      priority = 50;
      spread = [
        {
          attribute = "\${node.datacenter}";
          weight = 100;
        }
      ];
      type = "service";
    };
  };
}
