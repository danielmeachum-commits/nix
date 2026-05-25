{ config, pkgs, lib, ... }:

{
  options.custom.vm = {
    enable = lib.mkEnableOption "VM support via libvirtd/QEMU-KVM";
    # Pass the AMD GPU to a guest. Requires two GPUs (or iGPU + dGPU).
    # After enabling: find your GPU's PCI IDs with `lspci -nn | grep AMD`,
    # then set `boot.extraModprobeConfig = "options vfio-pci ids=XXXX:XXXX"`.
    gpuPassthrough = lib.mkEnableOption "VFIO GPU passthrough (AMD IOMMU)";
  };

  options.custom.vmdev.enable = lib.mkEnableOption "podman container development";

  config = lib.mkMerge [
    (lib.mkIf config.custom.vm.enable {
      virtualisation.libvirtd = {
        enable = true;
        qemu = {
          runAsRoot = true;
          swtpm.enable = true;      # TPM emulation (needed for Win 11)
        };
      };

      # SPICE USB redirection from host to guest
      virtualisation.spiceUSBRedirection.enable = true;

      # virt-manager needs dconf/GSettings schemas wired up
      programs.virt-manager.enable = true;

      # GPU passthrough
      boot.kernelParams = lib.mkIf config.custom.vm.gpuPassthrough [ "amd_iommu=on" "iommu=pt" ];
      boot.initrd.kernelModules = lib.mkIf config.custom.vm.gpuPassthrough [ "vfio_pci" "vfio" "vfio_iommu_type1" ];
    })

    (lib.mkIf config.custom.vmdev.enable {
      virtualisation.podman = {
        enable = true;
        dockerCompat = true;
        dockerSocket.enable = true;
      };
    })
  ];
}
