# ComfyUI — workstation image-generation render node (podman, ROCm 7.2 / gfx1201, RX 9070 XT).
#
# A dedicated second ComfyUI on the workstation's discrete GPU, separate from the
# server's gfx1151 instance (../ai/comfyui.nix). This gives image generation a fast,
# dedicated GPU and takes it OFF the shared server GPU (so Ollama and image gen stop
# contending). Imported by hosts/workstation only. See docs/ai-lab.md for the wider
# image-generation capability and its consumers.
#
# Bound to LOOPBACK: image-gen consumers run on this same host, so ComfyUI never needs
# to be reachable off-box. (The server instance is wg0-bound; this one is 127.0.0.1.)
#
# Data: the full ComfyUI tree (core + custom_nodes code + models) lives on the
# storage/comfyui dataset, rsynced from the server — see the deploy notes below.

{ pkgs, lib, ... }:

{
  virtualisation.podman.enable = true;
  virtualisation.oci-containers.backend = "podman";

  # First start may build/load the ~18 GB image; default ~5 min is too short.
  systemd.services.podman-comfyui-render.serviceConfig.TimeoutStartSec = lib.mkForce "30min";

  virtualisation.oci-containers.containers.comfyui-render = {
    # Locally-derived gfx1201 image — see ai-lab/comfyui/Containerfile.gfx1201 for the
    # build command. localhost/ prefix = no registry pull. (The "-ww" in the tag is the
    # existing build-artifact name; kept to avoid an 18 GB rebuild-just-to-retag.)
    image = "localhost/comfyui-gfx1201-ww:v2";
    ports = [ "127.0.0.1:8188:8188" ];          # loopback only — consumers are local
    volumes = [ "/storage/comfyui:/opt/ComfyUI" ]; # full ComfyUI tree (rsynced from server)

    # RDNA4 stability: ComfyUI sees the HIP/ROCm card as "cuda:0" (HIP impersonates
    # CUDA), so it auto-enables two Nvidia-only optimizations — async multi-stream
    # weight offloading and pinned host memory — which trigger a GPU coredump on
    # gfx1201 during the heavy tiled SD-upscale stage (UltimateSDUpscale re-diffusing
    # 1024x1024 tiles). Base render + FaceDetailer survive; the upscale faulted hard.
    # Disabling both makes the full hi-res/detail/upscale pipeline complete cleanly
    # (verified 2026-06-20: 86s end-to-end, no coredump). hipBLASLt/MIOpen env-var
    # workarounds did NOT help — the offload path is the real cause. We override the
    # entrypoint (the image WORKDIR is /opt/ComfyUI) to inject the two flags.
    entrypoint = "python3";
    cmd = [ "main.py" "--listen" "0.0.0.0" "--port" "8188" "--disable-async-offload" "--disable-pinned-memory" ];

    environment = {
      # Pin to the discrete 9070 XT (gfx1201, ROCm device index 0); hides the 9950X
      # iGPU (gfx1036, index 1) so HIP never lands on the weak integrated GPU. Verified
      # index on this host 2026-06-16. No HSA_OVERRIDE — gfx1201 is native on ROCm 7.2.
      ROCR_VISIBLE_DEVICES = "0";
    };
    extraOptions = [
      "--device=/dev/kfd"
      "--device=/dev/dri"            # full DRI — passing only one render node breaks HIP topology enumeration
      # No --group-add: the yanwk/openSUSE base image has no 'video'/'render' group, so
      # podman's name lookup fails ("Unable to find group video"). The GPU device nodes
      # are world-rw (666), so the container needs no supplementary group to use them
      # (verified on-host: the GO/NO-GO stress ran with no group-add).
      "--security-opt=seccomp=unconfined"
      "--shm-size=8g"
    ];
  };

  # Diagnostics for the discrete GPU (rocminfo/rocm-smi were absent on this host).
  environment.systemPackages = with pkgs; [ rocmPackages.rocminfo rocmPackages.rocm-smi ];

  # ComfyUI's rootful container uses the render group for /dev/dri/renderD128.
  users.users.oat.extraGroups = lib.mkAfter [ "render" ];
}
