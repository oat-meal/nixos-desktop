# Per-process split lock detection workaround for Steam
# Steam's 32-bit client performs unaligned atomic operations that trigger
# bus_lock traps on Zen 4/5 CPUs, causing UI hangs and dark window restarts.
# This builds a tiny LD_PRELOAD shim that sets the process to warn-only
# mode via prctl, keeping system-wide enforcement intact.

{ pkgs, ... }:

let
  splitLockFix = pkgs.stdenv.mkDerivation {
    pname = "steam-split-lock-fix";
    version = "1.0";

    src = pkgs.writeText "split_lock_fix.c" ''
      #include <sys/prctl.h>

      #ifndef PR_SET_BUS_LOCK_DETECT
      #define PR_SET_BUS_LOCK_DETECT 44
      #endif

      #ifndef PR_BUS_LOCK_DETECT_WARN
      #define PR_BUS_LOCK_DETECT_WARN 1
      #endif

      __attribute__((constructor))
      static void disable_split_lock_trap(void) {
        prctl(PR_SET_BUS_LOCK_DETECT, PR_BUS_LOCK_DETECT_WARN, 0, 0, 0);
      }
    '';

    dontUnpack = true;

    buildPhase = ''
      $CC -shared -fPIC -o split_lock_fix.so $src
    '';

    installPhase = ''
      mkdir -p $out/lib
      cp split_lock_fix.so $out/lib/
    '';
  };
in
{
  programs.steam.package = pkgs.steam.override {
    extraEnv = {
      LD_PRELOAD = "${splitLockFix}/lib/split_lock_fix.so";
    };
  };
}
