# pkgs/vex-v5-kernel.nix
{ lib
, rustPlatform
, fetchFromGitHub
}:

# Cross-compile VEX V5 kernel for armv7a-none-eabi
rustPlatform.buildRustPackage rec {
  pname    = "vex-v5-kernel";
  version  = "unstable-2025-05-11";

  src = fetchFromGitHub {
    owner = "vexide";
    repo  = "vex-v5-qemu";
    rev   = "f9a57b3ac86ccde612cba0ff0d01ed3f13a91194";
    sha256= "sha256-5D14xpnUbTJaWbuyb4UWde8/2HwBJZ5ELVY+0R85k6o=";
  };

  cargoLock = { lockFile = "${src}/Cargo.lock"; };

  # Build only the kernel crate for embedded
  cargoBuildFlags = [
    "--release"
    "--target"
    "armv7a-none-eabi"
    "--manifest-path"
    "${src}/packages/kernel/Cargo.toml"
  ];

  # No extra runtime dependencies
  buildInputs = [];

  # We don't install a host binary
  installPhase = ''
    echo "Kernel build complete: target artifacts in packages/kernel/target"
  '';

  meta = with lib; {
    description = "VEX V5 kernel for armv7a-none-eabi";
    homepage    = "https://github.com/vexide/vex-v5-qemu";
    license     = licenses.mit;
    maintainers = with maintainers; [ ];
    platforms   = platforms.all;
  };
}

