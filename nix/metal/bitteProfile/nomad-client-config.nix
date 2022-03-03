{
  config,
  lib,
  ...
}: {
  services.nomad.client = {
    chroot_env = {
      "/etc/passwd" = "/etc/passwd";
      "/etc/resolv.conf" = "/etc/resolv.conf";
      "/etc/services" = "/etc/services";
      "/etc/ssl/certs/ca-bundle.crt" = "/etc/ssl/certs/ca-bundle.crt";
      "/etc/ssl/certs/ca-certificates.crt" = "/etc/ssl/certs/ca-certificates.crt";
    };
  };
}
