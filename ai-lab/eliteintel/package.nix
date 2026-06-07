# EliteIntel — AI voice co-pilot for Elite Dangerous (declarative package).
# Upstream ships a release zip (jar + bundled sherpa-onnx native libs + Parakeet/
# Kokoro ONNX models). We fetch it, autoPatchelf the native libs, and wrap with
# temurin. To update: bump `version` + `hash` (upstream releases ~daily).

{ stdenv
, lib
, fetchurl
, unzip
, autoPatchelfHook
, writeShellApplication
, temurin-bin
, coreutils
, makeDesktopItem
, symlinkJoin
}:

let
  version = "1.0.0022";

  assets = stdenv.mkDerivation {
    pname = "eliteintel-assets";
    inherit version;
    src = fetchurl {
      url = "https://github.com/stone-alex/EliteIntel/releases/download/v-${version}/elite_intel_-${version}.zip";
      hash = "sha256-3w8ThF8aCiA3pFdoBhzQKpYyWy5lMVqd9aO9+3djeZA=";
    };
    nativeBuildInputs = [ unzip autoPatchelfHook ];
    buildInputs = [ stdenv.cc.cc.lib ]; # libstdc++/libgcc_s for sherpa-onnx
    unpackPhase = "unzip -q $src -d unpacked";
    dontBuild = true;
    installPhase = ''
      d=$out/share/eliteintel
      mkdir -p "$d"
      cp -r unpacked/elite_intel.jar unpacked/native unpacked/parakeet unpacked/tts "$d"/
      find "$d/native" -name '*.dll' -delete
    '';
  };

  # The app wants a writable install dir; symlink the read-only store assets into
  # a per-user runtime dir and run from there (config/logs land beside them).
  launcher = writeShellApplication {
    name = "eliteintel";
    runtimeInputs = [ temurin-bin coreutils ];
    text = ''
      assets=${assets}/share/eliteintel
      rundir="''${XDG_DATA_HOME:-$HOME/.local/share}/eliteintel"
      mkdir -p "$rundir"
      for a in elite_intel.jar native parakeet tts; do
        ln -sfn "$assets/$a" "$rundir/$a"
      done
      cd "$rundir"
      exec java -Xmx6g -Djava.library.path="$rundir/native" -jar "$rundir/elite_intel.jar" "$@"
    '';
  };

  desktop = makeDesktopItem {
    name = "eliteintel";
    desktopName = "EliteIntel";
    comment = "AI voice co-pilot for Elite Dangerous";
    exec = "eliteintel";
    categories = [ "Game" ];
    terminal = false;
  };
in
symlinkJoin {
  name = "eliteintel-${version}";
  paths = [ launcher desktop ];
  meta = {
    description = "AI voice co-pilot for Elite Dangerous (local STT/TTS, LLM via Ollama)";
    homepage = "https://github.com/stone-alex/EliteIntel";
    platforms = [ "x86_64-linux" ];
  };
}
