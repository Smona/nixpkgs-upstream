{ lib, stdenv, fetchFromGitLab, qtbase, openrgb, glib, qmake, pkg-config, bash
, wrapQtAppsHook }:

stdenv.mkDerivation rec {
  pname = "openrgb-plugin-visualmap";
  version = "0.9";

  src = fetchFromGitLab {
    owner = "OpenRGBDevelopers";
    repo = "OpenRGBVisualMapPlugin";
    rev = "c4e8b4c8c11a8cdfbe538bd6aa0e1c79a0d033b9";
    hash = "sha256-heBiSBz5VsNsQ1ap51iPyYkW8Jq/5aoHWRypIOVfUDQ=";
  };

  postPatch = ''
    # Use the source of openrgb from nixpkgs instead of the submodule
    rmdir OpenRGB
    ln -s ${openrgb.src} OpenRGB
  '';

  buildInputs = [ qtbase ];

  nativeBuildInputs = [ qmake pkg-config wrapQtAppsHook ];

  # installPhase = ''
  #   mkdir -p $out/lib
  #   cp libOpenRGBVisualMapPlugin.so $out/lib
  # '';

  meta = with lib; {
    homepage = "https://gitlab.com/OpenRGBDevelopers/OpenRGBVisualMapPlugin";
    description = "Group and organize your devices on a spatial map.";
    license = licenses.gpl2Plus;
    maintainers = with maintainers; [ smona ];
    platforms = platforms.linux;
  };
}
