#!/usr/bin/env bash
#
# aeonshell installer
#
# Copies hypr/quickshell/fastfetch/kitty (and optionally zsh) configs into
# ~/.config, installs pacman + AUR dependencies (via yay), and offers to
# back up any conflicting configs you already have.
#
set -euo pipefail

# ---------------------------------------------------------------------------
# Pretty output
# ---------------------------------------------------------------------------
if [ -t 1 ]; then
    C_RESET=$(tput sgr0)
    C_BOLD=$(tput bold)
    C_GREEN=$(tput setaf 2)
    C_YELLOW=$(tput setaf 3)
    C_RED=$(tput setaf 1)
    C_BLUE=$(tput setaf 4)
    C_CYAN=$(tput setaf 6)
else
    C_RESET="" C_BOLD="" C_GREEN="" C_YELLOW="" C_RED="" C_BLUE="" C_CYAN=""
fi

# Default before the language prompt runs, so anything that fires before
# that point (shouldn't happen, but just in case) still prints in English
# instead of crashing on an unset variable.
LANG_CHOICE="en"

# ---------------------------------------------------------------------------
# Translation tables
#
# t "<key>" [printf args...] prints the string for the current LANG_CHOICE.
# Strings may contain %s/%d placeholders — extra args are passed straight
# to printf, same rules as printf itself.
# ---------------------------------------------------------------------------
declare -A T_EN=(
    [lang_prompt_title]="Choose a language for hints:"
    [lang_prompt_opt_en]="  [1] English"
    [lang_prompt_opt_ru]="  [2] Russian (Русский)"
    [lang_prompt_invalid]="Please enter 1 or 2."

    [checking_distro]="Checking distro"
    [distro_unsupported_1]="This installer only supports Arch Linux and Arch-based distros (pacman + AUR)."
    [distro_unsupported_2]="Your system doesn't look like one of those — aborting so nothing gets touched."
    [pacman_missing]="'pacman' was not found on PATH. Aborting."
    [distro_ok]="Arch-based system detected."

    [no_root]="Please run this as your normal user, not root (it uses sudo where needed)."

    [checking_existing]="Checking for existing configs"
    [no_conflicts]="No existing configs in the way."
    [found_conflicts]="Found existing config(s) that aeonshell would overwrite:"
    [what_to_do]="What do you want to do?"
    [opt_backup]="  [b] Back up to %s, then install"
    [opt_overwrite]="  [o] Overwrite in place (no backup)"
    [opt_cancel]="  [c] Cancel"
    [prompt_choice]="> "
    [backed_up]="Backed up to %s"
    [overwriting]="Overwriting without backup, as requested."
    [cancelled]="Cancelled. Nothing was changed."
    [enter_boc]="Please enter b, o, or c."

    [aur_interrupt_1]="You're in the middle of an AUR build/install."
    [aur_interrupt_2]="Interrupting now can leave a half-built package, a locked pacman"
    [aur_interrupt_3]="database, or a broken yay cache behind."
    [aur_abort_prompt]="Type ABORT to force-quit anyway, or press Enter to keep going: "
    [aur_aborted_1]="Aborting mid-AUR-install at your request."
    [aur_aborted_2]="You may need to run 'sudo rm /var/lib/pacman/db.lck' and/or"
    [aur_aborted_3]="clean '~/.cache/yay' before trying again."
    [aur_continuing]="Continuing the AUR install."

    [aur_notice_title]="AUR packages — please read before continuing"
    [aur_confirm_prompt]="Type CONFIRM to proceed with AUR installation, or anything else to cancel: "
    [aur_not_confirmed]="AUR installation not confirmed — stopping here. Nothing else was changed."
    [aur_confirmed]="Confirmed — proceeding with AUR installation."

    [checking_yay]="Checking for an AUR helper (yay)"
    [yay_present]="yay is already installed."
    [yay_installing]="yay not found — installing it."
    [yay_failed]="yay installation failed. Install it manually and re-run this script."
    [yay_installed]="yay installed."

    [installing_pacman]="Installing official-repo packages"
    [pacman_deps_done]="Official-repo packages installed."

    [installing_aur]="Installing AUR packages"
    [aur_deps_done]="AUR packages installed."

    [optional_step]="Optional extras"
    [optional_prompt]="Install optional extras (openrgb, codium, thunderbird, localsend)? [y/N] "
    [optional_done]="Optional extras installed."
    [optional_skip]="Skipping optional extras."

    [shell_step]="Shell"
    [shell_current]="Your current login shell is: %s"
    [shell_already_zsh]="You're already on zsh — set up the included config anyway? [y/N] "
    [shell_offer]="Install zsh and set up the included config (your current shell, %s, is left untouched unless you say so next)? [y/N] "
    [shell_kept]="Keeping %s as-is — skipping zsh setup."

    [copying_configs]="Copying configs into %s"
    [local_conf_created]="Created hypr/conf/local.conf from the example — edit it for your machine."
    [local_conf_exists]="hypr/conf/local.conf already exists, leaving it as-is."
    [configs_copied]="Configs copied."
    [zsh_dotfiles_copied]="zsh dotfiles copied to %s."
    [chsh_prompt]="Switch your login shell from %s to zsh now? [y/N] "
    [chsh_done]="Login shell changed to zsh (takes effect on next login)."
    [chsh_kept]="Keeping %s as your login shell — run 'chsh -s \$(which zsh)' later if you change your mind."

    [done_step]="Done"
    [all_done]="aeonshell is installed."
    [next_steps_title]="Next steps:"
    [next_step_1]="Edit %s~/.config/hypr/conf/local.conf%s for your monitors/GPU."
    [next_step_2]="Drop some wallpapers into %s~/Pictures/Wallpapers%s."
    [next_step_3]="Log into Hyprland, open the launcher, type %s>wallpaper%s to pick one"
    [next_step_3b]="and generate your first pywal theme."

    [err_generic]="Something went wrong on line %s. Nothing after that point was applied."
)

declare -A T_RU=(
    [lang_prompt_title]="Выберите язык подсказок:"
    [lang_prompt_opt_en]="  [1] Английский (English)"
    [lang_prompt_opt_ru]="  [2] Русский"
    [lang_prompt_invalid]="Введите 1 или 2."

    [checking_distro]="Проверка дистрибутива"
    [distro_unsupported_1]="Этот установщик поддерживает только Arch Linux и Arch-based дистрибутивы (pacman + AUR)."
    [distro_unsupported_2]="Ваша система не похожа на них — прерываю, ничего не тронуто."
    [pacman_missing]="'pacman' не найден в PATH. Прерываю."
    [distro_ok]="Обнаружена система на базе Arch."

    [no_root]="Запустите скрипт от обычного пользователя, не от root (sudo вызывается там, где нужно)."

    [checking_existing]="Проверка существующих конфигов"
    [no_conflicts]="Конфликтующих конфигов не найдено."
    [found_conflicts]="Найдены существующие конфиги, которые aeonshell перезапишет:"
    [what_to_do]="Что делать?"
    [opt_backup]="  [b] Забэкапить в %s, затем установить"
    [opt_overwrite]="  [o] Перезаписать на месте (без бэкапа)"
    [opt_cancel]="  [c] Отмена"
    [prompt_choice]="> "
    [backed_up]="Забэкапировано в %s"
    [overwriting]="Перезаписываю без бэкапа, как вы попросили."
    [cancelled]="Отменено. Ничего не изменено."
    [enter_boc]="Введите b, o или c."

    [aur_interrupt_1]="Сейчас идёт сборка/установка пакета из AUR."
    [aur_interrupt_2]="Прерывание сейчас может оставить недособранный пакет, залоченную базу"
    [aur_interrupt_3]="pacman или сломанный кэш yay."
    [aur_abort_prompt]="Напечатайте ABORT, чтобы всё же прервать, или нажмите Enter, чтобы продолжить: "
    [aur_aborted_1]="Прерываю установку AUR по вашему запросу."
    [aur_aborted_2]="Возможно, понадобится выполнить 'sudo rm /var/lib/pacman/db.lck' и/или"
    [aur_aborted_3]="очистить '~/.cache/yay' перед повторной попыткой."
    [aur_continuing]="Продолжаю установку AUR."

    [aur_notice_title]="Пакеты из AUR — прочитайте перед продолжением"
    [aur_confirm_prompt]="Напечатайте CONFIRM, чтобы продолжить установку AUR, или что угодно другое для отмены: "
    [aur_not_confirmed]="Установка AUR не подтверждена — останавливаюсь здесь. Больше ничего не изменено."
    [aur_confirmed]="Подтверждено — продолжаю установку AUR."

    [checking_yay]="Проверка AUR-хелпера (yay)"
    [yay_present]="yay уже установлен."
    [yay_installing]="yay не найден — устанавливаю."
    [yay_failed]="Установка yay не удалась. Установите его вручную и запустите скрипт заново."
    [yay_installed]="yay установлен."

    [installing_pacman]="Установка пакетов из официальных репозиториев"
    [pacman_deps_done]="Пакеты из официальных репозиториев установлены."

    [installing_aur]="Установка пакетов из AUR"
    [aur_deps_done]="Пакеты из AUR установлены."

    [optional_step]="Опциональные пакеты"
    [optional_prompt]="Установить опциональные пакеты (openrgb, codium, thunderbird, localsend)? [y/N] "
    [optional_done]="Опциональные пакеты установлены."
    [optional_skip]="Пропускаю опциональные пакеты."

    [shell_step]="Шелл"
    [shell_current]="Ваш текущий логин-шелл: %s"
    [shell_already_zsh]="У вас уже zsh — всё равно накатить конфиг из репозитория? [y/N] "
    [shell_offer]="Установить zsh и настроить конфиг из репозитория (ваш текущий шелл, %s, останется нетронутым, если не согласитесь на следующем шаге)? [y/N] "
    [shell_kept]="Оставляю %s как есть — пропускаю настройку zsh."

    [copying_configs]="Копирование конфигов в %s"
    [local_conf_created]="Создан hypr/conf/local.conf из примера — отредактируйте его под свою машину."
    [local_conf_exists]="hypr/conf/local.conf уже существует, оставляю как есть."
    [configs_copied]="Конфиги скопированы."
    [zsh_dotfiles_copied]="Дотфайлы zsh скопированы в %s."
    [chsh_prompt]="Сменить логин-шелл с %s на zsh прямо сейчас? [y/N] "
    [chsh_done]="Логин-шелл изменён на zsh (вступит в силу при следующем входе)."
    [chsh_kept]="Оставляю %s как логин-шелл — выполните 'chsh -s \$(which zsh)' позже, если передумаете."

    [done_step]="Готово"
    [all_done]="aeonshell установлен."
    [next_steps_title]="Дальнейшие шаги:"
    [next_step_1]="Отредактируйте %s~/.config/hypr/conf/local.conf%s под свои мониторы/GPU."
    [next_step_2]="Скиньте несколько обоев в %s~/Pictures/Wallpapers%s."
    [next_step_3]="Войдите в Hyprland, откройте лаунчер, наберите %s>wallpaper%s, чтобы выбрать обои"
    [next_step_3b]="и сгенерировать первую тему pywal."

    [err_generic]="Что-то пошло не так на строке %s. Всё, что шло после этого места, не применилось."
)

t() {
    local key="$1"; shift || true
    local ref="T_EN"
    [ "$LANG_CHOICE" = "ru" ] && ref="T_RU"
    local -n table="$ref"
    local fmt="${table[$key]:-$key}"
    if [ "$#" -gt 0 ]; then
        # shellcheck disable=SC2059
        printf -- "$fmt" "$@"
    else
        printf '%s' "$fmt"
    fi
}

info()  { printf "%s[*]%s %s\n" "$C_BLUE$C_BOLD" "$C_RESET" "$1"; }
ok()    { printf "%s[✓]%s %s\n" "$C_GREEN$C_BOLD" "$C_RESET" "$1"; }
warn()  { printf "%s[!]%s %s\n" "$C_YELLOW$C_BOLD" "$C_RESET" "$1"; }
err()   { printf "%s[✗]%s %s\n" "$C_RED$C_BOLD" "$C_RESET" "$1" >&2; }
step()  { printf "\n%s==>%s %s%s%s\n" "$C_CYAN$C_BOLD" "$C_RESET" "$C_BOLD" "$1" "$C_RESET"; }

trap 'err "$(t err_generic "$LINENO")"; exit 1' ERR

banner() {
    printf "%s\n" "$C_CYAN$C_BOLD"
    cat <<'EOF'
   __ _  ___  ___  _ __  ___| |__   ___| |
  / _` |/ _ \/ _ \| '_ \/ __| '_ \ / _ \ |
 | (_| |  __/ (_) | | | \__ \ | | |  __/ |
  \__,_|\___|\___/|_| |_|___/_| |_|\___|_|
EOF
    printf "%s\n\n" "$C_RESET"
}

# ---------------------------------------------------------------------------
# Language selection — first thing the script asks
# ---------------------------------------------------------------------------
ask_language() {
    printf "%sChoose a language for hints / Выберите язык подсказок:%s\n" "$C_BOLD" "$C_RESET"
    printf "  [1] English\n"
    printf "  [2] Русский\n"
    local choice
    while true; do
        read -rp "> " choice
        case "$choice" in
            1) LANG_CHOICE="en"; break ;;
            2) LANG_CHOICE="ru"; break ;;
            en|EN|english|English) LANG_CHOICE="en"; break ;;
            ru|RU|ру|Ру|русский|Русский) LANG_CHOICE="ru"; break ;;
            *)
                printf "Please enter 1 or 2 / Введите 1 или 2\n"
                ;;
        esac
    done
}

# ---------------------------------------------------------------------------
# Sanity checks
# ---------------------------------------------------------------------------
require_arch() {
    step "$(t checking_distro)"
    if [ ! -f /etc/arch-release ] && ! grep -qiE '^ID(_LIKE)?=.*arch' /etc/os-release 2>/dev/null; then
        err "$(t distro_unsupported_1)"
        err "$(t distro_unsupported_2)"
        exit 1
    fi
    if ! command -v pacman >/dev/null 2>&1; then
        err "$(t pacman_missing)"
        exit 1
    fi
    ok "$(t distro_ok)"
}

require_not_root() {
    if [ "$(id -u)" -eq 0 ]; then
        err "$(t no_root)"
        exit 1
    fi
}

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="$HOME/aeonshell-backup-$TIMESTAMP"

CONFIG_MODULES=(hypr quickshell fastfetch kitty)
HOME_FILES=(.zshrc .p10k.zsh .zsh_plugins.txt)

# ---------------------------------------------------------------------------
# Backup or overwrite existing configs
# ---------------------------------------------------------------------------
handle_existing_configs() {
    step "$(t checking_existing)"

    local conflicts=()
    for m in "${CONFIG_MODULES[@]}"; do
        [ -e "$CONFIG_DIR/$m" ] && conflicts+=("$CONFIG_DIR/$m")
    done
    for f in "${HOME_FILES[@]}"; do
        [ -e "$HOME/$f" ] && conflicts+=("$HOME/$f")
    done

    if [ "${#conflicts[@]}" -eq 0 ]; then
        ok "$(t no_conflicts)"
        return
    fi

    warn "$(t found_conflicts)"
    for c in "${conflicts[@]}"; do printf "    - %s\n" "$c"; done

    local choice
    while true; do
        printf "\n%s%s%s\n" "$C_BOLD" "$(t what_to_do)" "$C_RESET"
        printf "%s\n" "$(t opt_backup "$BACKUP_DIR")"
        printf "%s\n" "$(t opt_overwrite)"
        printf "%s\n" "$(t opt_cancel)"
        read -rp "$(t prompt_choice)" choice
        case "$choice" in
            b|B)
                mkdir -p "$BACKUP_DIR"
                for c in "${conflicts[@]}"; do
                    mkdir -p "$BACKUP_DIR/$(dirname "${c#$HOME/}")"
                    mv "$c" "$BACKUP_DIR/${c#$HOME/}"
                done
                ok "$(t backed_up "$BACKUP_DIR")"
                break
                ;;
            o|O)
                warn "$(t overwriting)"
                for c in "${conflicts[@]}"; do rm -rf "$c"; done
                break
                ;;
            c|C)
                info "$(t cancelled)"
                exit 0
                ;;
            *)
                warn "$(t enter_boc)"
                ;;
        esac
    done
}

# ---------------------------------------------------------------------------
# Guard against interrupting mid-AUR-build
#
# Ctrl+C in the middle of makepkg/yay can leave a half-built package,
# a locked pacman db, or a corrupted AUR helper cache behind. We can't
# (and shouldn't try to) make the process literally unkillable — that
# would risk trapping the user in an unresponsive terminal, which is
# worse. Instead: while AUR_IN_PROGRESS=1, Ctrl+C pauses and asks for an
# explicit "ABORT" before actually quitting, so it's a deliberate choice
# rather than a reflexive keypress mid-build.
# ---------------------------------------------------------------------------
AUR_IN_PROGRESS=0

aur_sigint_handler() {
    if [ "$AUR_IN_PROGRESS" = "1" ]; then
        printf "\n"
        warn "$(t aur_interrupt_1)"
        warn "$(t aur_interrupt_2)"
        warn "$(t aur_interrupt_3)"
        local confirm
        read -rp "$(t aur_abort_prompt)" confirm
        if [ "$confirm" = "ABORT" ]; then
            err "$(t aur_aborted_1)"
            err "$(t aur_aborted_2)"
            err "$(t aur_aborted_3)"
            exit 130
        else
            info "$(t aur_continuing)"
        fi
    else
        exit 130
    fi
}
trap aur_sigint_handler SIGINT

AUR_NOTICE_EN='The AUR (Arch User Repository) hosts build scripts (PKGBUILDs) submitted
by the community - they are not reviewed or vetted by Arch or by us.
Installing from the AUR means downloading and running someone elses
build script with your privileges (via sudo). Its widely used and
generally safe, but it isnt the same trust level as official repo
packages - youre relying on each packages maintainer.

This step installs: yay (AUR helper, if not already present),
quickshell-git, awww, python-pywal, zen-browser-bin, bibata-cursor-theme,
otf-font-awesome, ttf-jetbrains-mono-nerd, zsh-antidote, kvantum,
gpu-screen-recorder-ui, peazip, xfce4-mousepad.

If you want to inspect a package first, each one can be reviewed at:
  https://aur.archlinux.org/packages/<name>

Once you confirm, the whole AUR step runs without further prompts.'

AUR_NOTICE_RU='AUR (Arch User Repository) хранит скрипты сборки (PKGBUILD),
присланные сообществом — их не проверяет ни Arch, ни мы. Установка
из AUR означает скачивание и запуск чужого скрипта сборки с вашими
правами (через sudo). Это широко используется и в целом безопасно,
но это не тот же уровень доверия, что официальные репозитории — вы
полагаетесь на мейнтейнера каждого пакета.

Этот шаг установит: yay (AUR-хелпер, если его ещё нет),
quickshell-git, awww, python-pywal, zen-browser-bin, bibata-cursor-theme,
otf-font-awesome, ttf-jetbrains-mono-nerd, zsh-antidote, kvantum,
gpu-screen-recorder-ui, peazip, xfce4-mousepad.

Если хотите посмотреть пакет заранее, каждый можно проверить тут:
  https://aur.archlinux.org/packages/<name>

После подтверждения весь шаг AUR пройдёт без дополнительных вопросов.'

confirm_aur() {
    step "$(t aur_notice_title)"
    printf "%s" "$C_YELLOW$C_BOLD$C_RESET"
    if [ "$LANG_CHOICE" = "ru" ]; then
        printf "%s\n" "$AUR_NOTICE_RU"
    else
        printf "%s\n" "$AUR_NOTICE_EN"
    fi
    local confirm
    read -rp "$(t aur_confirm_prompt)" confirm
    if [ "$confirm" != "CONFIRM" ]; then
        err "$(t aur_not_confirmed)"
        exit 1
    fi
    ok "$(t aur_confirmed)"
}

# ---------------------------------------------------------------------------
# yay
# ---------------------------------------------------------------------------
ensure_yay() {
    step "$(t checking_yay)"
    if command -v yay >/dev/null 2>&1; then
        ok "$(t yay_present)"
        return
    fi

    info "$(t yay_installing)"
    AUR_IN_PROGRESS=1
    sudo pacman -S --needed --noconfirm base-devel git

    local tmp
    tmp="$(mktemp -d)"
    git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin"
    (cd "$tmp/yay-bin" && makepkg -si --noconfirm)
    rm -rf "$tmp"
    AUR_IN_PROGRESS=0

    if ! command -v yay >/dev/null 2>&1; then
        err "$(t yay_failed)"
        exit 1
    fi
    ok "$(t yay_installed)"
}

# ---------------------------------------------------------------------------
# Dependencies
# ---------------------------------------------------------------------------
install_pacman_deps() {
    step "$(t installing_pacman)"
    sudo pacman -S --needed --noconfirm \
        hyprland hyprlock xdg-desktop-portal-hyprland xdg-desktop-portal \
        qt6-wayland qt6ct qt6-5compat gtk3 kitty pcmanfm-qt xorg-xrandr \
        networkmanager network-manager-applet nm-connection-editor \
        bluez bluez-utils blueman \
        pipewire pipewire-pulse pipewire-alsa wireplumber pavucontrol \
        wl-clipboard cliphist grim slurp swappy \
        jq curl python zenity inotify-tools udiskie \
        fastfetch fzf yazi tty-clock
    ok "$(t pacman_deps_done)"
}

install_aur_deps() {
    step "$(t installing_aur)"
    AUR_IN_PROGRESS=1
    yay -S --needed --noconfirm \
        quickshell-git awww python-pywal \
        zen-browser-bin bibata-cursor-theme \
        otf-font-awesome ttf-jetbrains-mono-nerd zsh-antidote \
        kvantum gpu-screen-recorder-ui peazip xfce4-mousepad
    AUR_IN_PROGRESS=0
    ok "$(t aur_deps_done)"
}

install_optional_deps() {
    step "$(t optional_step)"
    read -rp "$(t optional_prompt)" reply
    case "$reply" in
        y|Y)
            sudo pacman -S --needed --noconfirm openrgb
            AUR_IN_PROGRESS=1
            yay -S --needed --noconfirm codium thunderbird localsend
            AUR_IN_PROGRESS=0
            ok "$(t optional_done)"
            ;;
        *)
            info "$(t optional_skip)"
            ;;
    esac
}

want_zsh() {
    step "$(t shell_step)"
    local current_shell
    current_shell="$(basename "${SHELL:-unknown}")"
    info "$(t shell_current "$current_shell")"

    if [ "$current_shell" = "zsh" ]; then
        read -rp "$(t shell_already_zsh)" reply
    else
        read -rp "$(t shell_offer "$current_shell")" reply
    fi

    case "$reply" in
        y|Y) return 0 ;;
        *)
            info "$(t shell_kept "$current_shell")"
            return 1
            ;;
    esac
}

# ---------------------------------------------------------------------------
# Copy configs
# ---------------------------------------------------------------------------
copy_configs() {
    step "$(t copying_configs "$CONFIG_DIR")"

    mkdir -p "$CONFIG_DIR"/{hypr,quickshell,fastfetch,kitty}
    cp -r "$REPO_DIR/hypr/." "$CONFIG_DIR/hypr/"
    cp -r "$REPO_DIR/quickshell/." "$CONFIG_DIR/quickshell/"
    cp -r "$REPO_DIR/fastfetch/." "$CONFIG_DIR/fastfetch/"
    cp -r "$REPO_DIR/kitty/." "$CONFIG_DIR/kitty/"

    if [ ! -f "$CONFIG_DIR/hypr/conf/local.conf" ]; then
        cp "$REPO_DIR/hypr/conf/local.conf.example" "$CONFIG_DIR/hypr/conf/local.conf"
        info "$(t local_conf_created)"
    else
        info "$(t local_conf_exists)"
    fi

    chmod +x "$CONFIG_DIR"/hypr/script/*.sh
    ok "$(t configs_copied)"

    if want_zsh; then
        cp "$REPO_DIR/zsh/.zshrc" "$REPO_DIR/zsh/.p10k.zsh" "$REPO_DIR/zsh/.zsh_plugins.txt" "$HOME/"
        ok "$(t zsh_dotfiles_copied "$HOME")"
        sudo pacman -S --needed --noconfirm zsh
        local prev_shell
        prev_shell="$(basename "${SHELL:-unknown}")"
        read -rp "$(t chsh_prompt "$prev_shell")" reply
        case "$reply" in
            y|Y)
                chsh -s "$(command -v zsh)"
                ok "$(t chsh_done)"
                ;;
            *) info "$(t chsh_kept "$prev_shell")" ;;
        esac
    fi
}

mkdir_wallpapers() {
    mkdir -p "$HOME/Pictures/Wallpapers"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
    banner
    ask_language
    require_not_root
    require_arch
    handle_existing_configs
    install_pacman_deps
    confirm_aur
    ensure_yay
    install_aur_deps
    install_optional_deps
    copy_configs
    mkdir_wallpapers

    step "$(t done_step)"
    ok "$(t all_done)"
    printf "\n%s\n" "$(t next_steps_title)"
    printf "  1. %s\n" "$(t next_step_1 "$C_BOLD" "$C_RESET")"
    printf "  2. %s\n" "$(t next_step_2 "$C_BOLD" "$C_RESET")"
    printf "  3. %s\n" "$(t next_step_3 "$C_BOLD" "$C_RESET")"
    printf "     %s\n\n" "$(t next_step_3b)"
}

main "$@"
