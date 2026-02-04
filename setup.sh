#!/bin/bash

# --- Pre-flight Checks ---
# Check for gum (used for UI) and install if missing
if ! command -v gum &> /dev/null; then
    echo "gum not found, installing..."
    sudo pacman -S --noconfirm gum
fi

# --- Helper Functions ---
print_header() {
    gum style --foreground 212 --border-foreground 212 --border double --align center --width 60 "$1"
}

print_header "EndeavourOS Post-Install: Modular Edition"

# 1. System Protection (Timeshift)
if gum confirm "Create a system snapshot?"; then
    sudo pacman -S --noconfirm timeshift
    sudo timeshift --create --comments "Pre-setup snapshot" --scripted
fi

# 2. Update and Upgrade
if gum confirm "Update system packages?"; then
    if gum confirm "Refresh mirrors with Reflector?"; then
        sudo pacman -S --noconfirm reflector
        sudo reflector --latest 20 --protocol https --sort rate --save /etc/pacman.d/mirrorlist
    fi
    gum spin --title "Updating..." -- sudo pacman -Syu --noconfirm
fi

# 3. Git & SSH Configuration
if gum confirm "Configure Git and SSH?"; then
    GIT_USER=$(gum input --placeholder "Username")
    GIT_EMAIL=$(gum input --placeholder "Email")
    git config --global user.name "$GIT_USER"
    git config --global user.email "$GIT_EMAIL"
    if [ ! -f ~/.ssh/id_ed25519 ]; then
        ssh-keygen -t ed25519 -C "$GIT_EMAIL" -f ~/.ssh/id_ed25519 -N ""
        eval "$(ssh-agent -s)" && ssh-add ~/.ssh/id_ed25519
    fi
fi

# 4. Environment Tools (Kitty, Zoxide, eza, fzf, etc.)
if gum confirm "Install Fonts, Kitty, Zsh, and CLI Tools?"; then
    sudo pacman -S --noconfirm ttf-jetbrains-mono-nerd kitty zoxide eza fzf bat micro fastfetch bash-completion fd ripgrep yazi zsh
fi

# 5. Shell Setup (Zsh + Oh My Zsh + Powerlevel10k)
if gum confirm "Setup Zsh with Oh My Zsh & Powerlevel10k?"; then
    # Install Oh My Zsh if not present
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        print_header "Installing Oh My Zsh..."
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    fi

    # Install Powerlevel10k Theme
    if [ ! -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k" ]; then
        print_header "Installing Powerlevel10k..."
        git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
    fi

    # Install Zsh Plugins
    PLUGIN_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins"
    mkdir -p "$PLUGIN_DIR"

    declare -A plugins
    plugins=(
        ["zsh-autosuggestions"]="https://github.com/zsh-users/zsh-autosuggestions"
        ["zsh-syntax-highlighting"]="https://github.com/zsh-users/zsh-syntax-highlighting.git"
        ["zsh-autocomplete"]="https://github.com/marlonrichert/zsh-autocomplete.git"
        ["zsh-history-substring-search"]="https://github.com/zsh-users/zsh-history-substring-search"
    )

    for plugin in "${!plugins[@]}"; do
        if [ ! -d "$PLUGIN_DIR/$plugin" ]; then
            print_header "Installing $plugin..."
            git clone "${plugins[$plugin]}" "$PLUGIN_DIR/$plugin"
        fi
    done

    # Change default shell to zsh
    if [ "$SHELL" != "$(which zsh)" ]; then
        print_header "Changing default shell to Zsh..."
        sudo chsh -s "$(which zsh)" "$USER"
    fi
fi

# 6. Dank Linux (DMS) Configuration
if gum confirm "Install and Configure Dank Linux (DMS)?"; then
    print_header "Setting up Dank Linux (DMS)..."
    
    # Add Dank Linux Repository to pacman
    if ! grep -q "danklinux" /etc/pacman.conf; then
        echo -e "\n[danklinux]\nSigLevel = Optional TrustAll\nServer = https://repo.danklinux.com/arch/\$arch" | sudo tee -a /etc/pacman.conf
        sudo pacman -Sy
    fi

    # Install DMS components and dependencies (including matugen for color generation)
    sudo pacman -S --noconfirm dms-shell-bin matugen-bin
    
    # Initialize DMS (this creates starter configs)
    dms setup
fi

# 7. GNU Stow Dotfiles Management (Safety First)
if gum confirm "Sync Dotfiles using GNU Stow?"; then
    sudo pacman -S --noconfirm stow
    
    # Use .config instead of kitty to match repo structure
    # Added 'zsh' to the list
    for folder in bash zsh .config; do
        if [[ -d "$folder" ]]; then
            print_header "Stowing $folder..."
            # Safety: Backup existing files if they are not symlinks
            # We use -v 2 to get the list of files that would be linked
            stow --adopt -nv "$folder" 2>&1 | grep "existing target is not a symlink" | awk '{print $NF}' | while read -r file; do
                if [[ -e "$HOME/$file" ]]; then
                    mv "$HOME/$file" "$HOME/${file}.bak"
                fi
            done
            stow -D "$folder" && stow "$folder"
        fi
    done
    
    # Fix for missing included kitty configs to prevent errors
    if [ -d "$HOME/.config/kitty" ]; then
        touch "$HOME/.config/kitty/dank-tabs.conf"
        touch "$HOME/.config/kitty/dank-theme.conf"
        touch "$HOME/.config/kitty/current-theme.conf"
    fi

    gum style --foreground 10 "Dotfiles linked successfully."
fi

# 8. AUR Helper & Dev Tools
if ! command -v yay &> /dev/null; then
    print_header "Installing yay..."
    TEMP_DIR=$(mktemp -d)
    git clone https://aur.archlinux.org/yay.git "$TEMP_DIR/yay"
    pushd "$TEMP_DIR/yay" > /dev/null || exit
    makepkg -si --noconfirm
    popd > /dev/null || exit
    rm -rf "$TEMP_DIR"
fi
yay -S --noconfirm dotnet-sdk visual-studio-code-bin foliate

# 9. Popular Apps Selection
print_header "Select Apps"
APPS=$(gum choose --no-limit "discord" "spotify" "vlc" "obs-studio" "gimp" "brave-bin" "bitwarden" "telegram-desktop" "libreoffice-fresh" "qbittorrent")
for APP in $APPS; do yay -S --noconfirm "$APP"; done

# 10. Dev Tools & Docker Rights
print_header "Select Dev Tools"
DEV_TOOLS=$(gum choose --no-limit "base-devel" "docker" "nodejs" "npm" "python-pip" "go" "rustup" "postman-bin" "lazygit" "btop" "composer" "php")
for TOOL in $DEV_TOOLS; do
    if [[ "$TOOL" == "docker" ]]; then
        sudo pacman -S --noconfirm docker && sudo systemctl enable --now docker && sudo usermod -aG docker "$USER"
    else yay -S --noconfirm "$TOOL"; fi
done

# 11. Flatpak Integration
if gum confirm "Install Flatpak apps?"; then
    sudo pacman -S --noconfirm flatpak
    FLAT_APPS=$(gum choose --no-limit "org.mozilla.firefox" "com.slack.Slack" "org.signal.Signal" "com.github.tchx84.Flatseal")
    for F_APP in $FLAT_APPS; do flatpak install -y flathub "$F_APP"; done
fi

# 12. Cleanup
sudo pacman -Rns $(pacman -Qtdq) --noconfirm && yay -Sc --noconfirm

print_header "Setup Complete! Reboot to apply changes."
