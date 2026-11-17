{
  description = "Thulium Flutter development environment";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      devShells = forAllSystems (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config = {
              android_sdk.accept_license = true;
              allowUnfreePredicate = pkg:
                (pkg.meta.homepage or "") == "https://developer.android.com/tools";
            };
          };
          androidSdk = pkgs.androidenv.composeAndroidPackages {
            platformVersions = [ "36" ];
            buildToolsVersions = [ "36.0.0" ];
            includeNDK = true;
            ndkVersions = [ "28.2.13676358" ];
          };
        in
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              flutter
              git
              just
              jdk17
              androidSdk.androidsdk
            ] ++ pkgs.lib.optionals pkgs.stdenv.isLinux [ pkgs.libsecret ];

            ANDROID_HOME = "${androidSdk.androidsdk}/libexec/android-sdk";
            ANDROID_SDK_ROOT = "${androidSdk.androidsdk}/libexec/android-sdk";

            shellHook = ''
              echo "Thulium Flutter and Android development shell ready."
            '';
          };
        });
    };
}
