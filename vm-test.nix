{ pkgs, makeTest, queued-build-hook-module, queued-build-hook-binary-path, ... }:

# this code is inspired by
# https://www.haskellforall.com/2020/11/how-to-use-nixos-for-lightweight.html
# and
# https://github.com/Mic92/cntr/blob/2a1dc7b2de304b42fe342e2f7edd1a8f8d4ab6db/vm-test.nix
let
  piaPort = 8001;
  sensorPort = 5002;
  sensorProcessUser = "sensor";
  magicPackageName = "nae3ahMu";
  enqueue-hook = pkgs.writeScript "post-build-hook.sh" ''
          #!${pkgs.runtimeShell}
          exec ${queued-build-hook-binary-path} queue --socket /run/queued-build-hook.sock
          '';
in
  makeTest {
    name = "pia-registers-at-sensor-on-startup";
    system = "x86_64-linux";

    nodes = {
      build = { config, pkgs, ... }: {

        imports = [ queued-build-hook-module ];

        networking.firewall.allowedTCPPorts = [ sensorPort ];

        users = {
          mutableUsers = false;

          users = {
            root.password = "";
            ${sensorProcessUser}.isSystemUser = true;
          };
        };

        nix.extraOptions = ''
          post-build-hook = ${enqueue-hook}
        '';

        environment.etc."build.nix" = {
          mode = "0555";
          text = ''
            derivation {
              name = "${magicPackageName}";
              builder = "/bin/sh";
              args = [ /etc/builder.sh ];
              system = builtins.currentSystem;
            }
          '';
        };

        environment.etc."builder.sh" = {
          mode = "0555";
          text = ''
            declare -xp
            echo foo > $out
          '';
        };
      };
      cache = { config, pkgs, ... }: {

        imports = [ queued-build-hook-module ];

        networking.firewall.allowedTCPPorts = [ sensorPort ];

        users = {
          mutableUsers = false;

          users = {
            root.password = "";
            ${sensorProcessUser}.isSystemUser = true;
          };
        };
      };
    };

    testScript = ''
      import signal
      # unhandeled signal will end test run
      # this terminates the test more quickly
      signal.alarm(30)

      start_all()

      build.wait_for_unit("queued-build-hook.service")
      build.fail("journalctl -u queued-build-hook.service | grep ${magicPackageName}")
      build.succeed("${pkgs.nix}/bin/nix-build --impure /etc/build.nix")
      build.succeed("journalctl -u queued-build-hook.service | grep ${magicPackageName}")

      #pia.wait_for_unit("pia.service")
      #pia.wait_for_open_port(${toString piaPort})

      '';
  } {
    inherit pkgs;
    inherit (pkgs) system;
  }
