{ config, pkgs, lib, ... }:

let
  cfg = config.custom.cac;

  # Fetches the DoD PKCS#7 bundle and unpacks it into individual PEMs + one concatenated bundle.
  # Bump `version` and re-prefetch the hash when DISA publishes a new archive.
  dodCerts = pkgs.stdenv.mkDerivation {
    pname = "dod-pki-bundle";
    version = "2026-06";
    src = pkgs.fetchurl {
      url  = "https://dl.dod.cyber.mil/wp-content/uploads/pki-pke/zip/unclass-certificates_pkcs7_DoD.zip";
      hash = "sha256-Mlla2+dS31gjzt0sak8gbAf8w8FSD7gxAVIE6fu3VxE=";
    };
    nativeBuildInputs = [ pkgs.unzip pkgs.openssl ];
    dontUnpack = true;
    buildPhase = ''
      mkdir work && cd work
      unzip $src
      for p7b in $(find . -name '*.pem.p7b'); do
        pem="$(basename "$p7b" .pem.p7b).pem"
        openssl pkcs7 -in "$p7b" -inform DER -print_certs -out "$pem" 2>/dev/null \
          || openssl pkcs7 -in "$p7b" -inform PEM -print_certs -out "$pem"
      done
      cat *.pem > dod-bundle.crt
    '';
    installPhase = ''
      mkdir -p $out
      cp *.pem $out/
      cp dod-bundle.crt $out/
    '';
  };
in {
  options.custom.cac = {
    enable = lib.mkEnableOption "DoD CAC/PIV smartcard support and root CA trust";
  };

  config = lib.mkIf cfg.enable {
    # Smart card daemon. `pcsc_scan` (from pcsc-tools) confirms the reader sees the CAC.
    services.pcscd.enable = true;

    environment.systemPackages = with pkgs; [
      opensc      # PKCS#11 provider + opensc-tool
      pcsc-tools  # pcsc_scan for debugging
    ];

    # Register OpenSC's PKCS#11 module system-wide via p11-kit.
    environment.etc."pkcs11/modules/opensc.module".text = ''
      module: ${pkgs.opensc}/lib/opensc-pkcs11.so
    '';

    # System-wide trust for DoD roots (openssl/curl/wget/Chromium, and Firefox via ImportEnterpriseRoots).
    security.pki.certificateFiles = [ "${dodCerts}/dod-bundle.crt" ];
  };
}
