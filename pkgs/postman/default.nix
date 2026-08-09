{
  fetchurl,
  postman,
  version,
  hash,
}:

postman.overrideAttrs (oldAttrs: {
  inherit version;

  src = fetchurl {
    name = "postman-${version}.tar.gz";
    url = "https://dl.pstmn.io/download/version/${version}/linux64";
    inherit hash;
  };

  passthru = (oldAttrs.passthru or { }) // {
    updateScript = ./update.sh;
  };
})
