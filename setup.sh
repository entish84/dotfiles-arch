#!/bin/bash

# --- Helper Functions ---
print_header() {
    gum style --foreground 212 --border-foreground 212 --border double --align center --width 60 "$1"
}

# Ensure local config files exist before starting
if [[ ! -f "bashrc_custom" || ! -f "kitty_custom.conf" ]]; then
    gum style --foreground 9 "Error: bashrc_custom or kitty_custom.conf not found in current directory."
    exit 1
fi

print_header "EndeavourOS Post-Install: Modular Edition"

# 1. System Protection (Timeshift)
if gum confirm "Create a system snapshot?"; then
    sudo pacman -S --noconfirm timeshift
    sudo timeshift --create --comments "Pre-setup snapshot" --scripted
fi

# 2. Update and Upgrade
if gum confirm "Update system packages?"; then
    gum spin --title "Updating..." -- sudo pacman -Syu --noconfirm
fi

# 3. Git & SSH Configuration
if gum confirm "Configure Git and SSH?"; then
    GIT_USER=$(gum input --placeholder "Username")
    GIT_EMAIL=$(gum input --placeholder "Email")
    git config --global user.name "$GIT_USER"
    git config --global user.email "$GIT_EMAIL"
    ssh-keygen -t ed25519 -C "$GIT_EMAIL" -f ~/.ssh/id_ed25519 -N ""
    eval "$(ssh-agent -s)" && ssh-add ~/.ssh/id_ed25519
fi

# 4. GNU Stow Dotfiles Management (Safety First)
if gum confirm "Sync Dotfiles using GNU Stow?"; then
    sudo pacman -S --noconfirm stow
    # The script assumes it is already running INSIDE the cloned dotfiles folder
    DOT_DIR=$(pwd)
    
    for folder in bash kitty; do
        # Safety: Backup existing files if they are not symlinks
        stow --adopt -nv "$folder" 2>&1 | grep "existing target is not a symlink" | awk '{print $NF}' | while read -r file; do
            mv "$HOME/$file" "$HOME/${file}.bak"
        done
        stow -D "$folder" && stow "$folder"
    done
    gum style --foreground 10 "Dotfiles linked successfully."
fi

# 5. Environment Tools (Kitty, Zoxide, eza, etc.)
if gum confirm "Install Fonts, Kitty, and CLI Tools?"; then
    sudo pacman -S --noconfirm ttf-jetbrains-mono-nerd kitty zoxide eza fzf bat micro fastfetch bash-completion
    # Oh-My-Bash (Unattended)
    bash -c "$(curl -fsSL https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh)" --unattended
fi

# 6. AUR Helper & Dev Tools
if ! command -v yay &> /dev/null; then
    git clone https://aur.archlinux.org/yay.git && cd yay && makepkg -si --noconfirm && cd ..
fi
yay -S --noconfirm dotnet-sdk visual-studio-code-bin foliate

# 7. Popular Apps Selection
print_header "Select Apps"
APPS=$(gum choose --no-limit "discord" "spotify" "vlc" "obs-studio" "gimp" "brave-bin" "bitwarden" "telegram-desktop" "libreoffice-fresh" "qbittorrent")
for APP in $APPS; do yay -S --noconfirm "$APP"; done

# 8. Dev Tools & Docker Rights
print_header "Select Dev Tools"
DEV_TOOLS=$(gum choose --no-limit "base-devel" "docker" "nodejs" "npm" "python-pip" "go" "rustup" "postman-bin" "lazygit" "btop")
for TOOL in $DEV_TOOLS; do
    if [[ "$TOOL" == "docker" ]]; then
        sudo pacman -S --noconfirm docker && sudo systemctl enable --now docker && sudo usermod -aG docker "$USER"
    else yay -S --noconfirm "$TOOL"; fi
done

# 9. Flatpak Integration
if gum confirm "Install Flatpak apps?"; then
    sudo pacman -S --noconfirm flatpak
    FLAT_APPS=$(gum choose --no-limit "org.mozilla.firefox" "com.slack.Slack" "org.signal.Signal" "com.github.tchx84.Flatseal")
    for F_APP in $FLAT_APPS; do flatpak install -y flathub "$F_APP"; done
fi

# 10. Cleanup
sudo pacman -Rns $(pacman -Qtdq) --noconfirm && yay -Sc --noconfirm

print_header "Setup Complete! Reboot to apply changes."
