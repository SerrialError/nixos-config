{ pkgs }:

pkgs.stdenv.mkDerivation {
  name = "sddm-theme";
  src = pkgs.fetchFromGitHub {
    owner = "SerrialError";
    repo = "sddm-sugar-dark";
    rev = "ac02264eafe7730f748d1867f9510e199cf62593";
    sha256 = "1qc46sfgk9qza01w1583sbvrrxdxkfrlpd834bbkr9yzdmp4bbyw";
  };
  installPhase = ''
    mkdir -p $out
    cp -R ./* $out/
    cd $out/
  '';
}
