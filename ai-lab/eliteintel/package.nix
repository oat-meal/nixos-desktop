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
  version = "1.0.0032";

  assets = stdenv.mkDerivation {
    pname = "eliteintel-assets";
    inherit version;
    src = fetchurl {
      url = "https://github.com/stone-alex/EliteIntel/releases/download/v-${version}/elite_intel_-${version}.zip";
      hash = "sha256-7/VEDST1YR3IHTWtU25XD9D7w7bi6WgbAAZqpE6U3xY=";
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
      # Java/AWT renders blank under tiling Wayland compositors (e.g. MangoWM) without this.
      export _JAVA_AWT_WM_NONREPARENTING=1

      assets=${assets}/share/eliteintel
      # The app hardcodes this as its data home (config, ed-journal, ed-bindings).
      rundir="$HOME/.var/app/elite.intel.app"
      mkdir -p "$rundir"
      for a in elite_intel.jar native parakeet tts; do
        ln -sfn "$assets/$a" "$rundir/$a"
      done

      # Auto-link the Elite Dangerous journal (+ bindings if present) from the
      # Proton prefix, so the journal monitor works without manual setup.
      for lib in "$HOME/.local/share/Steam" /storage/steam; do
        jp="$lib/steamapps/compatdata/359320/pfx/drive_c/users/steamuser/Saved Games/Frontier Developments/Elite Dangerous"
        [ -d "$jp" ] && ln -sfn "$jp" "$rundir/ed-journal"
        bp="$lib/steamapps/compatdata/359320/pfx/drive_c/users/steamuser/AppData/Local/Frontier Developments/Elite Dangerous/Options/Bindings"
        [ -d "$bp" ] && ln -sfn "$bp" "$rundir/ed-bindings"
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
