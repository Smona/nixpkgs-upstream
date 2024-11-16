{ lib
, stdenv
, cmake
, buildGo122Module
, makeWrapper
, fetchFromGitHub
, pythonPackages
, pkg-config
, systemd
, hostname
, withSystemd ? lib.meta.availableOn stdenv.hostPlatform systemd
, extraTags ? [ ]
, testers
, datadog-agent
}:

let
  # keep this in sync with github.com/DataDog/agent-payload dependency
  payloadVersion = "5.0.124";
  python = pythonPackages.python;
  owner   = "DataDog";
  repo    = "datadog-agent";
  goPackagePath = "github.com/${owner}/${repo}";
  version = "7.56.2";

  src = fetchFromGitHub {
    inherit owner repo;
    rev = version;
    hash = "sha256-rU3eg92MuGs/6r7oJho2roeUCZoyfqYt1xOERoRPqmQ=";
  };
  rtloader = stdenv.mkDerivation {
    pname = "datadog-agent-rtloader";
    src = "${src}/rtloader";
    inherit version;
    nativeBuildInputs = [ cmake ];
    buildInputs = [ python ];
    cmakeFlags = ["-DBUILD_DEMO=OFF" "-DDISABLE_PYTHON2=ON"];
  };

in buildGo122Module rec {
  pname = "datadog-agent";
  inherit src version;

  doCheck = false;

  vendorHash = if stdenv.isDarwin
               then "sha256-Siy3OhCAQOl/KcB+/fCOMTrf2rSEcesvOUL5gwVqCFA="
               else "sha256-/zrV+CiifuDnuEBZpnNXh0g0RnF2pcq4fQkhm3/c4ao=";

  subPackages = [
    "cmd/agent"
    "cmd/cluster-agent"
    "cmd/dogstatsd"
    "cmd/trace-agent"
    "cmd/system-probe"
  ];


  nativeBuildInputs = [ pkg-config makeWrapper ];
  buildInputs = [rtloader] ++ lib.optionals withSystemd [ systemd ];
  PKG_CONFIG_PATH = "${python}/lib/pkgconfig";

  tags = [
    "ec2"
    "python"
    "process"
    "log"
    "secrets"
    "zlib"
  ]
  ++ lib.optionals withSystemd [ "systemd" ]
  ++ extraTags;

  ldflags = [
    "-X ${goPackagePath}/pkg/version.Commit=${src.rev}"
    "-X ${goPackagePath}/pkg/version.AgentVersion=${version}"
    "-X ${goPackagePath}/pkg/serializer.AgentPayloadVersion=${payloadVersion}"
    "-X ${goPackagePath}/pkg/collector/python.pythonHome3=${python}"
    "-X ${goPackagePath}/pkg/config.DefaultPython=3"
    "-r ${python}/lib"
  ];

  # DataDog use paths relative to the agent binary, so fix these.
  postPatch = ''
    sed -e "s|PyChecksPath =.*|PyChecksPath = \"$out/${python.sitePackages}\"|" \
        -e "s|distPath =.*|distPath = \"$out/share/datadog-agent\"|" \
        -i cmd/agent/common/path/path_nix.go
    sed -e "s|/bin/hostname|${lib.getBin hostname}/bin/hostname|" \
        -i pkg/util/hostname/fqdn_nix.go
  '';

  overrideModAttrs = {
    # postPatch is inherited by the go modules fixed-output derivation by default,
    # but patching /bin paths there like we do above will introduce forbidden paths in the output.
    postPatch = null;
  };

  # Install the config files and python modules from the "dist" dir
  # into standard paths.
  postInstall = ''
    mkdir -p $out/${python.sitePackages} $out/share/datadog-agent
    cp -R --no-preserve=mode $src/cmd/agent/dist/conf.d $out/share/datadog-agent
    rm -rf $out/share/datadog-agent/conf.d/{apm.yaml.default,process_agent.yaml.default,winproc.d}
    cp -R $src/cmd/agent/dist/{checks,utils,config.py} $out/${python.sitePackages}

    wrapProgram "$out/bin/agent" \
      --set PYTHONPATH "$out/${python.sitePackages}" --set PATH "${python}/bin"''
      + lib.optionalString withSystemd " --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ (lib.getLib systemd) rtloader ]}";

  passthru.tests.version = testers.testVersion {
    package = datadog-agent;
    command = "agent version";
  };

  meta = with lib; {
    description = ''
      Event collector for the DataDog analysis service
      -- v6 new golang implementation.
    '';
    homepage    = "https://www.datadoghq.com";
    license     = licenses.bsd3;
    maintainers = with maintainers; [ thoughtpolice domenkozar ];
  };
}
