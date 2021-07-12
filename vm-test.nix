{ pkgs, makeTest, queued-build-hook-module, ... }:

# this code is inspired by
# https://www.haskellforall.com/2020/11/how-to-use-nixos-for-lightweight.html
# and
# https://github.com/Mic92/cntr/blob/2a1dc7b2de304b42fe342e2f7edd1a8f8d4ab6db/vm-test.nix
let
  piaPort = 8001;
  sensorPort = 5002;
  sensorProcessUser = "sensor";
in
  makeTest {
    name = "pia-registers-at-sensor-on-startup";
    system = "x86_64-linux";

    nodes = {
      sensor = { config, pkgs, ... }: {

        imports = [ queued-build-hook-module ];

        networking.firewall.allowedTCPPorts = [ sensorPort ];

        users = {
          mutableUsers = false;

          users = {
            root.password = "";
            ${sensorProcessUser}.isSystemUser = true;
          };
        };

        #systemd.services.sensor-init = {
        #};
      };
    };

    testScript = ''
      # this terminates the test more quickly
      # TODO: re-add this when gitlab runner is faster
      # import signal
      # unhandeled signal will end test run
      # signal.alarm(90)

      start_all()

      sensor.wait_for_unit("sensor.service")
      sensor.wait_for_open_port(${toString sensorPort})

      pia.wait_for_unit("pia.service")
      pia.wait_for_open_port(${toString piaPort})

      '';

    #skipLint = true;
  } {
    inherit pkgs;
    inherit (pkgs) system;
  }
