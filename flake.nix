{
  description = "queued-build-hook - a Nix post-build-hook with some superpowers";

  outputs = { self, nixpkgs }:
  let
    system = "x86_64-linux";
    pkgs = import nixpkgs { inherit system; };
    lib = pkgs.lib;
    queued-build-hook = import ./default.nix { inherit pkgs lib; };
    enqueue-hook = pkgs.writeScript "post-build-hook-enqueue.sh" ''
      #!${pkgs.runtimeShell}
      exec ${self.packages.x86_64-linux.queued-build-hook}/bin/queued-build-hook queue --socket /run/queued-build-hook.sock
    '';
    dequeue-hook = ./dummy-hook.sh;
    user = "queued-build-hook";
  in
  {
    devShell."${system}" = import ./shell.nix { inherit pkgs; };

    packages."${system}".queued-build-hook = queued-build-hook;

    nixosModule = { config, pkgs, lib, modulesPath, ... }:
    let
      cfg = config.queued-build-hook;
    in
    {
      # TODO: allow only root user write to socket
      # TODO: ensure only service can read from socket
      # TODO: add configurable options
      #       - service user should be able to pass secrets (signing key)?
      options.queued-build-hook = {
        enable = lib.mkEnableOption "queued-build-hook service";
        enqueue-hook = lib.mkOption {
          type = lib.types.path;
          default = enqueue-hook;
          example = "You should usually not have to change this option.";
          description = "The hook that you have to put into nix.extraOptions as a post-build-hook to perform the enqueue operation.";
        };
        dequeue-hook = lib.mkOption {
          type = lib.types.path;
          default = dequeue-hook;
          example = "TODO";
          description = "The actual hook that you want to execute asynchronously.";
        };
        queue-binary-path = lib.mkOption {
          type = lib.types.path;
          default = queued-build-hook/bin/queued-build-hook;
          example = "You should usually not have to change this option.";
          description = "TODO";
        };
      };

      config = lib.mkIf cfg.enable {
        users.users.${user} = {
          isSystemUser = true;
        };

        systemd = {
          sockets.queued-build-hook = {
            description = "socket for root to enqueue built hooks that called asyncly by service";
            wantedBy = [ "sockets.target" ];
            before = [ "multi-user.target" ];
            socketConfig = {
              ListenStream = "/run/queued-build-hook.sock";
              SocketMode = "0600";
              SocketUser = "root";
              # accept must be false so (Accept=no)
              # so that only one service unit
              # is spawned for all connections
              Accept = false;
            };
          };

          services.queued-build-hook = {
            wantedBy = [ "multi-user.target" ];

            serviceConfig = {
              User = user;
              Type = "simple";
              ExecStart = "${queued-build-hook}/bin/queued-build-hook daemon --hook ${cfg.dequeue-hook}";
            };
          };
        };
      };
    };

    checks."${system}" = {
      integration-tests = import ./vm-test.nix {
        makeTest = import (nixpkgs + "/nixos/tests/make-test-python.nix");
        inherit pkgs;
        queued-build-hook-module = self.nixosModule;
      };
    };
    defaultPackage."${system}" = self.packages."${system}".queued-build-hook;
  };
}
