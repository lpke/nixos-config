{ pkgs, wine }:

let
  selawik = pkgs.fetchurl {
    url = "https://github.com/microsoft/Selawik/releases/download/1.01/Selawik_Release.zip";
    sha256 = "3f62c51e05e3b5a1e6241cf92a371f0be2ea1183aa87b30718bbd40832a8d423";
  };
  fontLicense = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/microsoft/Selawik/89362e84731d1f5777fa078fd4d5ebbd339e4378/LICENSE.txt";
    sha256 = "77b7c2506d4efb22e09c8ccf10159f4956eab3ef7c007fef95de136bcf45300c";
  };
  vcX86 = pkgs.fetchurl {
    url = "https://download.visualstudio.microsoft.com/download/pr/ece44298-3977-4f73-ab91-c13fe79cfea8/F0BAB33A302B3CDB2E11113760D016F54FD3D2632C65BA7834FAC4F0ABD7F1A3/VC_redist.x86.exe";
    sha256 = "f0bab33a302b3cdb2e11113760d016f54fd3d2632c65ba7834fac4f0abd7f1a3";
  };
  vcX64 = pkgs.fetchurl {
    url = "https://download.visualstudio.microsoft.com/download/pr/ebdab8e5-1d7b-4d9f-a11b-cbb1720c3b12/843068991DAAA1F73AD9F6239BCE4D0F6A07A51F18C37EA2A867E9BECA71295C/VC_redist.x64.exe";
    sha256 = "843068991daaa1f73ad9f6239bce4d0f6a07a51f18c37ea2a867e9beca71295c";
  };
  dxvk = pkgs.fetchurl {
    url = "https://github.com/doitsujin/dxvk/releases/download/v3.1.1/dxvk-3.1.1.tar.gz";
    sha256 = "40565b4a724aadc4433fa4e010b4b23916d9b1f1baeee64e17186db94f54e608";
  };
  vkd3d = pkgs.fetchurl {
    url = "https://github.com/HansKristian-Work/vkd3d-proton/releases/download/v3.0.1/vkd3d-proton-3.0.1.tar.zst";
    sha256 = "3cf2315522af5e43605ef6d3c41dad91387040bf97199934f3f7ab76caaa2f0c";
  };
  d3d12Shim = pkgs.pkgsCross.mingwW64.stdenv.mkDerivation {
    pname = "adobe-d3d12-shim";
    version = "0.2.2";
    src = wine.adobeSource + "/shims/d3d12";
    dontConfigure = true;
    buildPhase = ''
      $CC -O2 -shared -static -o d3d12.dll d3d12shim.c d3d12.def
    '';
    installPhase = ''
      install -Dm644 d3d12.dll "$out/d3d12.dll"
    '';
  };
in pkgs.runCommand "adobe-runtime-assets" {
  nativeBuildInputs = [ pkgs.cabextract pkgs.unzip pkgs.python3 pkgs.zstd ];
  meta.license = pkgs.lib.licenses.unfree;
} ''
  mkdir -p "$out/fonts" "$out/system32" "$out/syswow64" selawik vc32 vc64
  unzip -q ${selawik} '*.ttf' -d selawik
  python3 ${wine.adobeSource}/scripts/selawik-as-segoe.py "$out/fonts" selawik/*.ttf
  cp ${fontLicense} "$out/fonts/LICENSE.txt"

  # Wine's builtin msvcp140 reports a newer version, so Microsoft's installer
  # skips it. Extract the matched runtime set directly, as Winetricks does.
  cabextract -q -d vc32 ${vcX86}
  cabextract -q -d vc64 ${vcX64}
  cabextract -q -d vc32/min vc32/a2
  cabextract -q -d vc64/min vc64/a4
  for dll in vc32/min/*.dll_x86; do
    name=$(basename "$dll" .dll_x86)
    cp "$dll" "$out/syswow64/$name.dll"
  done
  for dll in vc64/min/*.dll_amd64; do
    name=$(basename "$dll" .dll_amd64)
    cp "$dll" "$out/system32/$name.dll"
  done
  tar -xf ${dxvk}
  tar -xf ${vkd3d}
  cp dxvk-3.1.1/x64/*.dll vkd3d-proton-3.0.1/x64/*.dll "$out/system32/"
  cp dxvk-3.1.1/x32/*.dll vkd3d-proton-3.0.1/x86/*.dll "$out/syswow64/"
  mv "$out/system32/d3d12.dll" "$out/system32/d3d12_vkd3d.dll"
  cp ${d3d12Shim}/d3d12.dll "$out/system32/d3d12.dll"
''
