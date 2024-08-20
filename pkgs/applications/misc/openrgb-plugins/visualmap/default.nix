{ lib, stdenv, fetchFromGitLab, qtbase, openrgb, glib, qmake, pkg-config, bash
, wrapQtAppsHook }:

stdenv.mkDerivation rec {
  pname = "openrgb-plugin-visualmap";
  version = "0.9";

  src = fetchFromGitLab {
    owner = "OpenRGBDevelopers";
    repo = "OpenRGBVisualMapPlugin";
    rev = "release_${version}";
    hash = "sha256-8w5f/aZcnWKht8Af2S9ekD/cXyi7Nlklf85YMAHU3+M=";
  };

  postPatch = ''
    # Use the source of openrgb from nixpkgs instead of the submodule
    rmdir OpenRGB
    ln -s ${openrgb.src} OpenRGB
  '';

  buildInputs = [ qtbase glib ];

  nativeBuildInputs = [ qmake pkg-config wrapQtAppsHook ];

  installPhase = ''
    mkdir -p $out/lib
    cp libOpenRGBVisualMapPlugin.so $out/lib
  '';

  meta = with lib; {
    homepage = "https://gitlab.com/OpenRGBDevelopers/OpenRGBVisualMapPlugin";
    description = "Group and organize your devices on a spatial map.";
    license = licenses.gpl2Plus;
    maintainers = with maintainers; [ smona ];
    platforms = platforms.linux;
  };
}
