{ lib
, rustPlatform
, fetchFromGitHub
, qemu
, webkitgtk_4_1
, libsoup_3
, pkg-config
, glib
, gtk3
, vte
, libvirt
, libvirt-glib
, libxml2
, gtk-vnc
, spice-gtk
, usbredir
, makeWrapper
}:

# Build host-side simulator
rustPlatform.buildRustPackage rec {
  pname   = "vex-v5-simulator";
  version = "unstable-2025-05-11";

  src = fetchFromGitHub {
    owner = "vexide";
    repo  = "vex-v5-qemu";
    rev   = "f9a57b3ac86ccde612cba0ff0d01ed3f13a91194";
    sha256= "sha256-5D14xpnUbTJaWbuyb4UWde8/2HwBJZ5ELVY+0R85k6o=";
  };

  cargoLock = { lockFile = "${src}/Cargo.lock"; };

  nativeBuildInputs = [ pkg-config makeWrapper ];
  buildInputs = [ glib gtk3 vte libvirt libvirt-glib libxml2 gtk-vnc spice-gtk usbredir qemu webkitgtk_4_1 libsoup_3 ];
  installPhase = ''
    mkdir -p $out/bin
    cp ${src}/simulator/target/release/simulator $out/bin/vex-v5-qemu
    wrapProgram $out/bin/vex-v5-qemu \
      --prefix PATH : ${lib.makeBinPath [ qemu ]} \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath buildInputs}
  '';

  meta = with lib; {
    description = "VEX V5 simulator for host";
    homepage    = "https://github.com/vexide/vex-v5-qemu";
    license     = licenses.mit;
    maintainers = with maintainers; [ ];
    platforms   = platforms.linux;
  };
}
