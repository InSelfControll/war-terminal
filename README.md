# Warp Terminal on NixOS with Flake or Non-Flake Setup

This guide shows how to add the **Warp Terminal** package to your NixOS configuration using an overlay.  
You can apply this either in your system-wide `configuration.nix` or in your per-user **Home Manager** configuration.

---
## 0. Clone the repo into a path you would like
```bash
chmod +X warp-latest.sh
Run - warp-latest.sh
./warp-latest.sh
```
This will take about a minute if your internet fast - downloading warp-terminal for updating HASHES in versions.json for completing the build and update locally.

## 1. Adding the Overlay

Add the following snippet to your configuration:

```nix
nixpkgs.overlays = [
  (self: super: {
    warp-terminal = super.callPackage ./warp/package.nix { };
  })
];
```

### Where to Put This Snippet
- **System-wide (configuration.nix):**  
  Place it inside the `nixpkgs` section of your `/etc/nixos/configuration.nix`.  
  This will make `warp-terminal` available to all users on the system.

- **User profile (Home Manager):**  
  Place it inside your `home.nix` (or `home-manager` config).  
  This makes the package available only for your user.

---

## 2. Adding Warp Terminal to Packages

After defining the overlay, you need to add `warp-terminal` to your package list:

- In **configuration.nix**:
  ```nix
  environment.systemPackages = with pkgs; [
    warp-terminal
  ];
  ```

- In **Home Manager** (`home.nix`):
  ```nix
  home.packages = with pkgs; [
    warp-terminal
  ];
  ```

---

## 3. Apply Configuration

After updating your configuration, rebuild:

- **System-wide:**
  ```bash
  sudo nixos-rebuild switch
  ```
- **Home Manager only:**
  ```bash
  home-manager switch
  ```

---

## Summary

1. Add the overlay snippet to either `configuration.nix` or `home-manager` config.  
2. Add `warp-terminal` to the appropriate package list.  
3. Rebuild your system or Home Manager config.  

Now `warp-terminal` will be available for you to run! 🚀
