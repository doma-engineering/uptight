{
    inputs = {
        nixpkgs.url = "github:NixOS/nixpkgs";
        goo.url = "github:doma-engineering/goo-1.14?ref=v1.14";
    };

    outputs = {self, nixpkgs, goo}:
        let pkgs = nixpkgs.legacyPackages.x86_64-linux;
        in {
            defaultPackage.x86_64-linux = pkgs.hello;

            devShell.x86_64-linux =
                pkgs.mkShell {
                    buildInputs = [
                        pkgs.erlangR24
                        goo.defaultPackage.x86_64-linux
                        pkgs.libsodium
                        pkgs.inotify-tools
                        # Helpers
                        pkgs.httpie
                        pkgs.jq
                        pkgs.yq
                        pkgs.dig
                        # Stuff that has to be externally configured
                        pkgs.gnupg
                        pkgs.darcs
                        ## Stuff that isn't yet implemented
                        # domaPakages.passveil
                        ## Stuff that doesn't work
                        # pkgs.yggdrasil
                    ];
                    LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath [ pkgs.libsodium ];
                };
        };
}
