#!/bin/bash

# Author lucapxl 
# Date  2026-04-05

######################
# Defining some variables needed during the installation
######################
USERDIR=$(echo "/home/$SUDO_USER")
TOOLSDIR=$(echo "$USERDIR/_tools")
SCRIPTDIR=$(dirname "$0")

######################
# Packages
######################
PACKAGES="firefox bash-completion vim neovim mousepad fastfetch"          # basic software
PACKAGES=" $PACKAGES labwc"                                               # labwc
PACKAGES=" $PACKAGES waybar swaylock wlogout wlopm swayidle"              # main wayland tools (bar, lock screen, logout menu, brightness manager, wallpaper manager)
PACKAGES=" $PACKAGES dbus-1-daemon gnome-keyring"                         # keychain for KeePassXC, SSH keys and nextcloud
PACKAGES=" $PACKAGES rofi rofi-calc"                                      # Menu for labwc
PACKAGES=" $PACKAGES wdisplays kanshi brightnessctl gammastep"            # Graphical monitor manager and profile manager, brightness manager and gamma changer
PACKAGES=" $PACKAGES dunst libnotify-tools playerctl"                     # Graphical Notification manager and Player buttons manager
PACKAGES=" $PACKAGES pavucontrol pipewire"                                # audio devices manager
PACKAGES=" $PACKAGES grim slurp swaybg"                                   # screenshot and region selection tools
PACKAGES=" $PACKAGES adwaita-icon-theme papirus-icon-theme kf6-breeze-icons" # icon package
PACKAGES=" $PACKAGES tuigreet greetd"                                     # login manager
PACKAGES=" $PACKAGES intel-media-driver"                                  # video drivers
PACKAGES=" $PACKAGES foot thunar thunar-archive-plugin thunar-volman tumbler galculator eom"  # terminal, file manager, flatpak calculator and image viewer
PACKAGES=" $PACKAGES flatpak xdg-desktop-portal-gtk"                      # flatpak
PACKAGES=" $PACKAGES nextcloud-desktop tmux"                              # nextcloud
PACKAGES=" $PACKAGES adwaita-fonts inter-fonts inter-variable-fonts google-noto-coloremoji-fonts" # fonts
PACKAGES=" $PACKAGES btop ncdu"                                           # other tweaks
PACKAGES=" $PACKAGES blueman"                                             # bluetooth utils
PACKAGES=" $PACKAGES tar wget unzip xz bat"                               # other utils

######################
# Making sure the user running has root privileges
######################
if [ "$EUID" -ne 0 ]; then
  echo "Please run with sudo"
  exit
fi

if [[ -z "$SUDO_USER" ]]; then
  echo "Please run with sudo from your user, not from the root user directly"
  exit
fi

######################
# Output function
######################
function logMe {
    echo "=== [INFO] " $1
    sleep 3
}

######################
# Output function
######################
function logError {
    echo "=== [ERROR] " $1
    sleep 1
}

######################
# creating necessary folders
######################
logMe "Creating necessary folders"
mkdir -p $TOOLSDIR
mkdir -p $USERDIR/.config
cd $TOOLSDIR

######################
# adding aliases for zypper
######################
logMe "Adding zypper bash aliases"
grep -qi "alias zypper=.*" $USERDIR/.bashrc || echo "alias zypper='sudo zypper'" >> $USERDIR/.bashrc

######################
# setting variables
######################
logMe "Setting variables"
echo "XDG_RUNTIME_DIR=/run/user/$(id -u)" >> $USERDIR/.pam_environment

######################
# Installing necessary packages
######################
logMe "Installing necessary packages via zypper"
sudo zypper install -y $PACKAGES > /dev/null

######################
# Installing flathub and flatpaks
######################
logMe "Installing Flathub"
flatpak install flathub org.keepassxc.KeePassXC -y
flatpak install flathub com.visualstudio.code -y

######################
# enabling greetd at start and switching target to graphical
######################
logMe "Configuring greetd/tuigreet login manager"
sed -i 's/^command.*/command = "tuigreet --cmd \x27dbus-run-session labwc\x27"/' /etc/greetd/config.toml

systemctl enable greetd.service
systemctl set-default graphical.target

######################
# Installing nerdfonts
######################
logMe "Installing nerdfonts SauceCodePro"
mkdir -p "$USERDIR/.local/share/fonts/"
TEMP_DIR=$(mktemp -d)
wget -O "$TEMP_DIR/font.zip" "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/SourceCodePro.zip"
unzip "$TEMP_DIR/font.zip" -d "$TEMP_DIR"
mv "$TEMP_DIR"/*.{ttf,otf} "$USERDIR/.local/share/fonts/"
rm -rf "$TEMP_DIR"

logMe "Installing nerdfonts Symbols"
TEMP_DIR=$(mktemp -d)
wget -O "$TEMP_DIR/font.zip" "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/NerdFontsSymbolsOnly.zip"
unzip "$TEMP_DIR/font.zip" -d "$TEMP_DIR"
mv "$TEMP_DIR"/*.{ttf,otf} "$USERDIR/.local/share/fonts/"
rm -rf "$TEMP_DIR"

chown -R $SUDO_USER:$SUDO_USER "$USERDIR/.local/share/fonts/"
fc-cache -f -v

######################
# Installing gtk-adw theme
######################
logMe "Installing gtk-adw theme"
TEMP_DIR=$(mktemp -d)
cd $TEMP_DIR
wget https://github.com/lassekongo83/adw-gtk3/releases/download/v6.4/adw-gtk3v6.4.tar.xz
tar xvf adw-gtk3v6.4.tar.xz 
mkdir -p "$USERDIR/.local/share/themes"
mv adw-gtk3 adw-gtk3-dark "$USERDIR/.local/share/themes"
chown -R $SUDO_USER:$SUDO_USER "$USERDIR/.local/share/themes"
cd $TOOLSDIR
rm -rf "$TEMP_DIR"
sudo flatpak override --filesystem=xdg-data/themes
sudo flatpak mask org.gtk.Gtk3theme.adw-gtk3
sudo flatpak mask org.gtk.Gtk3theme.adw-gtk3-dark

######################
# recursively fix ownership for .config directory
######################
chown -R $SUDO_USER:$SUDO_USER $USERDIR

######################
# Download and apply config files
######################
logMe "Applying config files"
cd $TOOLSDIR
git clone https://github.com/lucapxl/dotconfig.git
cd dotconfig
chown -R $SUDO_USER:$SUDO_USER .
sudo -u $SUDO_USER bash apply_configs.sh

######################
# Enabling NetworkManager to group netadmin
######################
logMe "Creating netadmin and give it access to NetworkManager"
groupadd netadmin
usermod -aG netadmin $SUDO_USER
cp "$SCRIPTDIR/10-network.rules" /etc/polkit-1/rules.d/
chown root:root /etc/polkit-1/rules.d/10-network.rules

######################
# all done, rebooting
######################
logMe "[DONE] Installation completed!"
systemctl reboot