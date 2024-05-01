{ lib, pkgs, config, ... }:
with lib;
let cfg = config.virtualisation.vfio;
in
{
  options.virtualisation.vfio = {
    enable = mkEnableOption "VFIO Configuration";
    IOMMUType = mkOption {
      type = types.enum [ "intel" "amd" ];
      example = "intel";
      description = "Type of the IOMMU used";
    };
    devices = mkOption {
      type = types.listOf (types.strMatching "[0-9a-f]{4}:[0-9a-f]{4}");
      default = [ ];
      example = [ "10de:1b80" "10de:10f0" ];
      description = "PCI IDs of devices to bind to vfio-pci";
    };
    disableEFIfb = mkOption {
      type = types.bool;
      default = false;
      example = true;
      description = "Disables the usage of the EFI framebuffer on boot.";
    };
    blacklistNvidia = mkOption {
      type = types.bool;
      default = false;
      description = "Add Nvidia GPU modules to blacklist";
    };
    ignoreMSRs = mkOption {
      type = types.bool;
      default = false;
      example = true;
      description =
        "Enables or disables kvm guest access to model-specific registers";
    };
    applyACSpatch = mkOption {
      type = types.bool;
      default = false;
      example = true;
      description = "Apply ACS patches to split devices in the same IOMMU group";
    };
  };

  config = lib.mkIf cfg.enable {
    services.udev.extraRules = ''
      SUBSYSTEM=="vfio", OWNER="root", GROUP="kvm"
    '';

    boot.kernelModules = [
      "vfio"
      "vfio_pci"
      "vfio_iommu_type1"
      "vfio_virqfd"
    ];
    boot.kernelParams = (if cfg.IOMMUType == "intel" then [
      "intel_iommu=on"
      "intel_iommu=igfx_off"
    ] else
      [ "amd_iommu=on" ]) ++ (optional (builtins.length cfg.devices > 0)
      ("vfio-pci.ids=" + builtins.concatStringsSep "," cfg.devices))
    ++ (optionals cfg.applyACSpatch [
      "pcie_acs_override=downstream,multifunction"
      "pci=nomsi"
    ]) ++ (optional cfg.disableEFIfb "video=efifb:off")
    ++ (optionals cfg.ignoreMSRs [
      "kvm.ignore_msrs=1"
      "kvm.report_ignored_msrs=0"
    ]);

    boot.blacklistedKernelModules =
      optionals cfg.blacklistNvidia [ "nvidia" "nouveau" ];
  };
}
