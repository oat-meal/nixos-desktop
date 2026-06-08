# ComfyUI — image generation service (podman, ROCm/gfx1151).
# wg0-only. ComfyUI isn't in nixpkgs and PyTorch+ROCm on gfx1151 is impractical to
# package natively, so it runs as a pinned community container off AMD's rocm/pytorch
# base. Data (models/outputs) lives on the /storage/comfyui dataset.

{ ... }:

{
  virtualisation.podman.enable = true;
  virtualisation.oci-containers.backend = "podman";

  virtualisation.oci-containers.containers.comfyui = {
    image = "docker.io/ignatberesnev/comfyui-gfx1151:latest"; # TODO: pin by digest
    ports = [ "10.100.0.2:8188:8188" ]; # wg0 only
    volumes = [ "/storage/comfyui:/opt/ComfyUI" ]; # models, output, custom nodes persist here
    environment = {
      HSA_OVERRIDE_GFX_VERSION = "11.0.0"; # gfx1100 mapping (gfx1151 ROCm, as with Ollama)
    };
    extraOptions = [
      "--device=/dev/kfd"
      "--device=/dev/dri"
      "--group-add=video"
      "--group-add=render"
      "--shm-size=8g"
    ];
  };

  networking.firewall.interfaces."wg0".allowedTCPPorts = [ 8188 ];
}
