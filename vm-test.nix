{ pkgs, makeTest, queued-build-hook-module, ... }:

# this code is inspired by
# https://www.haskellforall.com/2020/11/how-to-use-nixos-for-lightweight.html
# and
# https://github.com/Mic92/cntr/blob/2a1dc7b2de304b42fe342e2f7edd1a8f8d4ab6db/vm-test.nix
let
  magicPackageName = "nae3ahMu";
in
  makeTest {
    name = "build-host-uploads-path-to-cache";
    system = "x86_64-linux";

    nodes = {
      build = { config, pkgs, ... }:
      let
        dequeue-hook = pkgs.writeScript "ssh-copy-to-cache-hook.sh" ''
          #!${pkgs.stdenv.shell}
          set -eu
          set -f # disable globbing
          export IFS=' '

          echo "Copying received paths" $OUT_PATHS
          export NIX_SSHOPTS="-o StrictHostKeyChecking=accept-new -i $CREDENTIALS_DIRECTORY/build_host_ssh_key -v"
          ${pkgs.nix}/bin/nix copy --to ssh://recv@cache $OUT_PATHS
          echo "Done copying"
        '';
      in {
        imports = [ queued-build-hook-module ];

        queued-build-hook = {
          enable = true;
          inherit dequeue-hook;
        };

        users = {
          mutableUsers = false;

          users = {
            root.password = "";
          };
        };

        nix.extraOptions = ''
          post-build-hook = ${config.queued-build-hook.enqueue-hook}
        '';

        systemd.services.queued-build-hook.path = [ pkgs.openssh pkgs.nix ];
        systemd.services.queued-build-hook.serviceConfig = {
          BindReadOnlyPaths = "/etc/ssh";
          LoadCredential = "build_host_ssh_key:/etc/build_host_ssh_key";
        };

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

        # this is a big issue
        # the ssh key should not come from the store
        # only done like this for the test
        environment.etc."build_host_ssh_key" = {
          mode = "0600";
          source = ./build_host_ssh_key;
        };
      };
      cache = { config, pkgs, ... }: {

        nix.trustedUsers = [ "root" "recv" ];

        services.openssh = {
          enable = true;
          passwordAuthentication = false;
        };

        users = {
          mutableUsers = false;
          users = {
            recv = {
              openssh.authorizedKeys.keyFiles = [ ./build_host_ssh_key.pub ];
              isSystemUser = true;
              shell = pkgs.bash;
            };
            root.password = "";
          };
        };
      };
    };

    testScript = ''
      import signal
      # unhandeled signal will end test run
      # this terminates the test more quickly
      signal.alarm(60)

      start_all()

      build.wait_for_unit("queued-build-hook.service")
      build.wait_for_unit("multi-user.target")
      cache.wait_for_unit("multi-user.target")
      build.fail("journalctl -u queued-build-hook.service | grep ${magicPackageName}")
      build.succeed("${pkgs.nix}/bin/nix-build --impure /etc/build.nix")

      build.wait_until_succeeds("journalctl -u queued-build-hook.service | grep ${magicPackageName}")
      build.wait_until_succeeds("journalctl -u queued-build-hook.service | grep Done.copying")
      cache.wait_until_succeeds("ls /nix/store | grep ${magicPackageName}")
    '';
  } {
    inherit pkgs;
    inherit (pkgs) system;
  }
