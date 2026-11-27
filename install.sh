#!/usr/bin/env bash
#
# aeonshell installer & updater
#
# Supports fresh Arch installs, updates (git pull + smart config update +
# new dependency checks + live Hyprland/Quickshell reload), and config-only deploys.
#
set -uo pipefail

# ---------------------------------------------------------------------------
# Colors & UI helpers (detected before tee redirection)
# ---------------------------------------------------------------------------
if [ -t 1 ]; then
    C_RESET=$(tput sgr0 2>/dev/null || true)
    C_BOLD=$(tput bold 2>/dev/null || true)
    C_DIM=$(tput dim 2>/dev/null || true)
    C_GREEN=$(tput setaf 2 2>/dev/null || true)
    C_YELLOW=$(tput setaf 3 2>/dev/null || true)
    C_RED=$(tput setaf 1 2>/dev/null || true)
    C_CYAN=$(tput setaf 6 2>/dev/null || true)
else
    C_RESET="" C_BOLD="" C_DIM="" C_GREEN="" C_YELLOW="" C_RED="" C_CYAN=""
fi

LANG_CHOICE=""
MODE="" # full | update | configs
SKIP_PULL=0
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/aeonshell"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="$HOME/aeonshell-backup-$TIMESTAMP"
LOG_FILE="${_AEONSHELL_LOG_FILE:-$CACHE_DIR/install-$TIMESTAMP.log}"

CONFIG_MODULES=(hypr quickshell)
PRESERVED_HYPR_FILES=(
    "hypr/conf/monitor.lua"
    "hypr/conf/keyboard.lua"
)

PACMAN_DEPS=(
    hyprland hyprlock xdg-desktop-portal-hyprland xdg-desktop-portal
    qt6-wayland qt6ct kitty pcmanfm-qt
    networkmanager nm-connection-editor
    bluez bluez-utils
    pipewire pipewire-pulse pipewire-alsa wireplumber
    wl-clipboard cliphist grim slurp swappy
    udiskie ffmpeg
)

AUR_DEPS=(
    quickshell-git awww mpvpaper
    bibata-cursor-theme ttf-jetbrains-mono-nerd
)

OPTIONAL_DEPS=(
    matugen-bin
)

declare -A PKG_STATUS=()
FAILURES=()
AUR_HELPER=""
AUR_CONFIRMED=0
AUR_DECLINED=0
AUR_IN_PROGRESS=0
BACKUP_CREATED=0
SMART_UPDATE=0

# ---------------------------------------------------------------------------
# Translations (EN / RU)
# ---------------------------------------------------------------------------
declare -A T_EN=(
    [subtitle]="Autonomous Quickshell + Hyprland installer & updater"
    [log_path]="Log: %s"

    [mode_title]="Action"
    [mode_install_full]="  [1] Full install — dependencies + configs (default)"
    [mode_install_update]="  [2] Update — git pull + update configs & missing packages"
    [mode_install_configs]="  [3] Configs only — copy hypr & quickshell without packages"
    [mode_update_first]="  [1] Update aeonshell — git pull + smart config update (default)"
    [mode_update_full]="  [2] Full reinstall — check all packages + replace configs"
    [mode_update_configs]="  [3] Configs only — copy local hypr & quickshell without pull/packages"
    [mode_invalid]="Please choose 1, 2, or 3."

    [no_root]="Run this script as a regular user, not root (sudo will be used when needed)."
    [distro_unsupported]="Only Arch Linux and Arch-based distros (pacman) are supported."
    [pacman_missing]="'pacman' not found on PATH."
    [internet_fail]="No internet connection (could not reach archlinux.org)."

    [updating_repo]="Checking repository updates"
    [repo_not_git]="Not a git repository — updating from local files."
    [repo_dirty]="Local uncommitted changes detected in repo — skipping git pull."
    [repo_offline]="Could not reach git remote — continuing with local files."
    [repo_up_to_date]="Repository is already up to date."
    [repo_pulling]="Pulling %s new commit(s)..."
    [repo_pulled]="Repository updated."
    [repo_pull_failed]="git pull failed (fast-forward not possible) — continuing with local files."
    [repo_self_updated]="Installer script updated — reloading..."

    [checking_existing]="Checking existing configs"
    [no_conflicts]="No conflicting configs in %s."
    [found_conflicts]="Existing configs found:"
    [conflict_prompt]="  [B] Back up to %s and install (default)\n  [o] Overwrite without backup\n  [c] Cancel"
    [update_conflict_prompt]="  [S] Smart update — back up + update, keep monitor.lua & keyboard.lua (default)\n  [b] Clean replace — back up + overwrite all files\n  [o] Overwrite all without backup\n  [c] Cancel"
    [backed_up]="Backed up existing configs to %s"
    [overwriting]="Overwriting existing configs without backup."
    [cancelled]="Cancelled. Nothing was changed."
    [invalid_boc]="Please enter b, o, or c."
    [invalid_sboc]="Please enter s, b, o, or c."

    [aur_interrupt]="AUR build is in progress. Interrupting may leave a pacman lock or partial build."
    [aur_abort_prompt]="Type ABORT to quit, or press Enter to continue: "
    [aur_aborted]="Aborted during AUR build. If needed, run 'sudo rm -f /var/lib/pacman/db.lck'."
    [aur_continuing]="Continuing AUR build."

    [resolving_deps]="Checking packages"
    [deps_summary]="Packages: %d already installed, %d from official repos, %d from AUR"
    [deps_all_installed]="All required packages are already installed."
    [update_new_deps_prompt]="Found %d missing required package(s): %s. Install now? [Y/n] "
    [update_deps_skipped]="Skipped installing missing packages."
    [pkg_not_found]="%s was not found in official repos or AUR — skipping."

    [refreshing_db]="Refreshing pacman databases"
    [refresh_db_failed]="Could not refresh pacman databases — continuing anyway."
    [installing_pacman]="Installing official-repo packages (%d)"
    [pacman_done]="Official-repo packages installed."
    [pacman_batch_fallback]="Batch install hit an error — retrying package by package."

    [optional_matugen_prompt]="Install optional 'matugen-bin' from AUR for wallpaper palette extraction? (built-in ColorQuantizer works without it) [Y/n] "
    [aur_install_prompt]="Install %d AUR package(s) (%s)? [Y/n] "
    [aur_skipped]="AUR packages skipped by user."
    [aur_helper_found]="Using AUR helper: %s"
    [yay_missing]="No AUR helper (yay/paru) found. Install yay-bin from AUR? [Y/n] "
    [yay_installing]="Installing yay-bin..."
    [yay_failed]="Failed to install yay-bin — AUR packages skipped."
    [installing_aur]="Installing AUR packages (%d)"
    [aur_done]="AUR packages installed."
    [aur_batch_fallback]="AUR batch install hit an error — retrying package by package."

    [copying_configs]="Deploying configs to %s"
    [module_copied]="%s deployed (%d files)"
    [module_failed]="Failed to deploy %s"
    [preserved_file]="Preserved %s (new template is in repo)"
    [bind_updated]="bind.lua was updated (your previous version is in %s)"
    [scripts_fixed]="Made %d script(s) executable."
    [wallpapers_dir]="Wallpapers folder ready: %s"

    [services_title]="System services"
    [service_prompt]="Enable and start %s now? [y/N] "
    [service_enabled]="%s enabled and started."
    [service_failed]="Could not enable %s."

    [reload_title]="Live reload"
    [reload_prompt]="Reload Hyprland and restart Quickshell now to apply updates? [Y/n] "
    [reload_done]="Hyprland reloaded and Quickshell restarted."
    [reload_skipped]="Skipped live reload — restart Quickshell or log back in when ready."

    [report_title]="Summary"
    [report_installed]="Installed"
    [report_present]="Already present"
    [report_skipped]="Skipped"
    [report_failed]="Failed"
    [report_backup]="Backup: %s"
    [report_failures]="Issues encountered:"
    [report_clean]="Finished cleanly."

    [next_title]="Next steps"
    [next_1]="Review %s~/.config/hypr/conf/%s (monitor.lua, keyboard.lua, bind.lua) if needed."
    [next_2]="Add wallpapers/videos to %s~/Pictures/Wallpapers%s."
    [next_3]="Press %sSuper + D%s and run %s>wallpaper%s; open Settings from the bar gear icon."

    [fail_pkg_not_found]="%s — not found in pacman or AUR"
    [fail_pkg_install]="%s (%s) — installation failed"
    [fail_aur_declined]="%s — skipped (AUR not confirmed)"
    [fail_yay]="yay-bin — failed to install"
    [fail_config]="%s — config copy/verification failed"
    [warn_line]="Unexpected warning at line %s."
)

declare -A T_RU=(
    [subtitle]="Установщик и обновлятор автономной оболочки Quickshell + Hyprland"
    [log_path]="Лог: %s"

    [mode_title]="Действие"
    [mode_install_full]="  [1] Полная установка — пакеты + конфиги (по умолчанию)"
    [mode_install_update]="  [2] Обновление — git pull + обновить конфиги и недостающие пакеты"
    [mode_install_configs]="  [3] Только конфиги — скопировать hypr и quickshell без пакетов"
    [mode_update_first]="  [1] Обновить aeonshell — git pull + умное обновление конфигов (по умолчанию)"
    [mode_update_full]="  [2] Полная переустановка — проверить пакеты + заменить все конфиги"
    [mode_update_configs]="  [3] Только конфиги — скопировать локальные hypr и quickshell без pull/пакетов"
    [mode_invalid]="Введите 1, 2 или 3."

    [no_root]="Запускайте скрипт от обычного пользователя, не от root (sudo запросится сам)."
    [distro_unsupported]="Поддерживаются только Arch Linux и дистрибутивы на базе Arch (pacman)."
    [pacman_missing]="Команда 'pacman' не найдена в PATH."
    [internet_fail]="Нет подключения к интернету (archlinux.org недоступен)."

    [updating_repo]="Проверка обновлений репозитория"
    [repo_not_git]="Папка не является git-репозиторием — обновляем из локальных файлов."
    [repo_dirty]="В репозитории есть локальные правки — пропускаем git pull."
    [repo_offline]="Удалённый репозиторий недоступен — продолжаем с локальными файлами."
    [repo_up_to_date]="Репозиторий уже актуальной версии."
    [repo_pulling]="Загрузка обновлений (%s коммит(ов))..."
    [repo_pulled]="Репозиторий обновлён."
    [repo_pull_failed]="Не удалось выполнить git pull (нужен ручной merge) — продолжаем с локальными файлами."
    [repo_self_updated]="Скрипт установки обновился — перезапуск..."

    [checking_existing]="Проверка существующих конфигов"
    [no_conflicts]="Конфликтующих конфигов в %s не найдено."
    [found_conflicts]="Найдены установленные конфиги:"
    [conflict_prompt]="  [B] Сделать бэкап в %s и установить (по умолчанию)\n  [o] Перезаписать без бэкапа\n  [c] Отмена"
    [update_conflict_prompt]="  [S] Умное обновление — бэкап + обновление, сохранить monitor.lua и keyboard.lua (по умолчанию)\n  [b] Полная замена — бэкап + перезаписать все файлы\n  [o] Перезаписать всё без бэкапа\n  [c] Отмена"
    [backed_up]="Бэкап сохранён в %s"
    [overwriting]="Перезапись существующих конфигов без бэкапа."
    [cancelled]="Отменено. Ничего не изменено."
    [invalid_boc]="Введите b, o или c."
    [invalid_sboc]="Введите s, b, o или c."

    [aur_interrupt]="Идёт сборка пакета из AUR. Прерывание может оставить блокировку pacman или битый кэш."
    [aur_abort_prompt]="Введите ABORT для выхода, или нажмите Enter для продолжения: "
    [aur_aborted]="Прервано во время сборки AUR. При необходимости выполните 'sudo rm -f /var/lib/pacman/db.lck'."
    [aur_continuing]="Продолжаем сборку AUR."

    [resolving_deps]="Проверка пакетов"
    [deps_summary]="Пакеты: %d уже установлено, %d из официальных реп, %d из AUR"
    [deps_all_installed]="Все нужные пакеты уже установлены."
    [update_new_deps_prompt]="Найдено %d недостающих пакет(ов): %s. Установить сейчас? [Y/n] "
    [update_deps_skipped]="Установка недостающих пакетов пропущена."
    [pkg_not_found]="%s не найден ни в официальных репозиториях, ни в AUR — пропуск."

    [refreshing_db]="Обновление базы пакетов pacman"
    [refresh_db_failed]="Не удалось обновить базу pacman — продолжаем с текущим кэшем."
    [installing_pacman]="Установка пакетов из официальных репозиториев (%d)"
    [pacman_done]="Пакеты из официальных репозиториев установлены."
    [pacman_batch_fallback]="Ошибка пакетной установки — пробуем устанавливать по одному."

    [optional_matugen_prompt]="Установить опциональный 'matugen-bin' из AUR для генерации палитры? (без него работает встроенный ColorQuantizer) [Y/n] "
    [aur_install_prompt]="Установить %d пакет(ов) из AUR (%s)? [Y/n] "
    [aur_skipped]="Установка пакетов AUR пропущена пользователем."
    [aur_helper_found]="Используется AUR-хелпер: %s"
    [yay_missing]="Не найден AUR-хелпер (yay/paru). Установить yay-bin из AUR? [Y/n] "
    [yay_installing]="Установка yay-bin..."
    [yay_failed]="Не удалось установить yay-bin — пакеты AUR пропущены."
    [installing_aur]="Установка пакетов из AUR (%d)"
    [aur_done]="Пакеты из AUR установлены."
    [aur_batch_fallback]="Ошибка пакетной установки AUR — пробуем устанавливать по одному."

    [copying_configs]="Установка конфигов в %s"
    [module_copied]="%s установлен (%d файлов)"
    [module_failed]="Не удалось скопировать %s"
    [preserved_file]="Сохранён ваш %s (новый шаблон остался в репо)"
    [bind_updated]="bind.lua обновлён (ваша старая версия сохранена в %s)"
    [scripts_fixed]="Выданы права на запуск для %d скрипт(ов)."
    [wallpapers_dir]="Папка для обоев готова: %s"

    [services_title]="Системные службы"
    [service_prompt]="Включить и запустить %s сейчас? [y/N] "
    [service_enabled]="Служба %s включена и запущена."
    [service_failed]="Не удалось включить %s."

    [reload_title]="Применение обновлений"
    [reload_prompt]="Перезагрузить Hyprland и перезапустить Quickshell прямо сейчас? [Y/n] "
    [reload_done]="Hyprland перезагружен, Quickshell перезапущен."
    [reload_skipped]="Перезапуск пропущен — обновите сессию вручную, когда будет удобно."

    [report_title]="Итоги"
    [report_installed]="Установлено"
    [report_present]="Уже было"
    [report_skipped]="Пропущено"
    [report_failed]="Ошибки"
    [report_backup]="Бэкап: %s"
    [report_failures]="Не удалось завершить:"
    [report_clean]="Завершено без ошибок."

    [next_title]="Дальнейшие шаги"
    [next_1]="При необходимости проверьте %s~/.config/hypr/conf/%s (monitor.lua, keyboard.lua, bind.lua)."
    [next_2]="Добавьте картинки или видео в %s~/Pictures/Wallpapers%s."
    [next_3]="Нажмите %sSuper + D%s и введите %s>wallpaper%s; настройки — через шестерёнку на панели."

    [fail_pkg_not_found]="%s — не найден в pacman или AUR"
    [fail_pkg_install]="%s (%s) — ошибка установки"
    [fail_aur_declined]="%s — пропущен (AUR не подтверждён)"
    [fail_yay]="yay-bin — не удалось установить"
    [fail_config]="%s — ошибка копирования или проверки конфига"
    [warn_line]="Предупреждение на строке %s."
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

step() { printf "\n%s::%s %s%s%s\n" "$C_CYAN$C_BOLD" "$C_RESET" "$C_BOLD" "$1" "$C_RESET"; }
ok()   { printf "  %s✓%s %s\n" "$C_GREEN$C_BOLD" "$C_RESET" "$1"; }
info() { printf "  %s·%s %s\n" "$C_DIM" "$C_RESET" "$1"; }
warn() { printf "  %s!%s %s\n" "$C_YELLOW$C_BOLD" "$C_RESET" "$1"; }
err()  { printf "  %s✗%s %s\n" "$C_RED$C_BOLD" "$C_RESET" "$1" >&2; }

trap 'warn "$(t warn_line "$LINENO")"' ERR

aur_sigint_handler() {
    if [ "$AUR_IN_PROGRESS" = "1" ]; then
        printf "\n"
        warn "$(t aur_interrupt)"
        local confirm
        read -rp "  $(t aur_abort_prompt)" confirm
        if [ "$confirm" = "ABORT" ]; then
            err "$(t aur_aborted)"
            exit 130
        fi
        info "$(t aur_continuing)"
    else
        printf "\n"
        exit 130
    fi
}
trap aur_sigint_handler SIGINT

# ---------------------------------------------------------------------------
# CLI arguments
# ---------------------------------------------------------------------------
print_help() {
    cat <<'EOF'
aeonshell installer & updater

Usage: ./install.sh [options]
  --lang en|ru     Skip language prompt
  -u, --update     Update mode (git pull + smart config update + check new deps)
  --configs-only   Only copy local hypr & quickshell configs (skip pull & packages)
  --skip-pull      Skip git pull in update mode
  -h, --help       Show this help
EOF
}

parse_args() {
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --lang)
                shift
                case "${1:-}" in
                    en|EN) LANG_CHOICE="en" ;;
                    ru|RU) LANG_CHOICE="ru" ;;
                    *) echo "Unknown language: ${1:-}" >&2; exit 1 ;;
                esac
                ;;
            -u|--update)
                MODE="update"
                ;;
            --configs-only)
                MODE="configs"
                ;;
            --skip-pull)
                SKIP_PULL=1
                ;;
            -h|--help)
                print_help
                exit 0
                ;;
            *)
                echo "Unknown option: $1" >&2
                print_help
                exit 1
                ;;
        esac
        shift
    done
}

# ---------------------------------------------------------------------------
# Header, language, mode, logging
# ---------------------------------------------------------------------------
print_header() {
    if [ "${_AEONSHELL_REEXEC:-0}" = "1" ]; then
        return 0
    fi
    printf "\n  %saeonshell%s %s· installer%s\n" "$C_CYAN$C_BOLD" "$C_RESET" "$C_DIM" "$C_RESET"
    printf "  %s────────────────────────────────────────%s\n" "$C_DIM" "$C_RESET"
}

ask_language() {
    if [ -n "$LANG_CHOICE" ]; then
        [ "${_AEONSHELL_REEXEC:-0}" != "1" ] && info "$(t subtitle)"
        return
    fi
    printf "\n  %sLanguage / Язык:%s\n" "$C_BOLD" "$C_RESET"
    printf "    [1] English (default)\n"
    printf "    [2] Русский\n"
    local choice
    while true; do
        read -rp "  > " choice
        case "$choice" in
            ""|1|en|EN|english|English) LANG_CHOICE="en"; break ;;
            2|ru|RU|ру|Ру|русский|Русский) LANG_CHOICE="ru"; break ;;
            *) printf "    Enter 1 or 2 / Введите 1 или 2\n" ;;
        esac
    done
    info "$(t subtitle)"
}

require_not_root() {
    if [ "$(id -u)" -eq 0 ]; then
        err "$(t no_root)"
        exit 1
    fi
}

setup_logging() {
    mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || {
        LOG_FILE="/tmp/aeonshell-install-$TIMESTAMP.log"
    }
    exec > >(tee -a "$LOG_FILE") 2>&1
    if [ "${_AEONSHELL_REEXEC:-0}" != "1" ]; then
        info "$(t log_path "$LOG_FILE")"
    fi
}

has_existing_configs() {
    local m
    for m in "${CONFIG_MODULES[@]}"; do
        [ -e "$CONFIG_DIR/$m" ] && return 0
    done
    return 1
}

ask_mode() {
    [ -n "$MODE" ] && return 0

    step "$(t mode_title)"
    local installed=0 choice
    has_existing_configs && installed=1

    if [ "$installed" -eq 1 ]; then
        printf "%s\n" "$(t mode_update_first)"
        printf "%s\n" "$(t mode_update_full)"
        printf "%s\n" "$(t mode_update_configs)"
        while true; do
            read -rp "  > " choice
            case "$choice" in
                ""|1) MODE="update"; break ;;
                2)    MODE="full"; break ;;
                3)    MODE="configs"; break ;;
                *)    warn "$(t mode_invalid)" ;;
            esac
        done
    else
        printf "%s\n" "$(t mode_install_full)"
        printf "%s\n" "$(t mode_install_update)"
        printf "%s\n" "$(t mode_install_configs)"
        while true; do
            read -rp "  > " choice
            case "$choice" in
                ""|1) MODE="full"; break ;;
                2)    MODE="update"; break ;;
                3)    MODE="configs"; break ;;
                *)    warn "$(t mode_invalid)" ;;
            esac
        done
    fi
}

# ---------------------------------------------------------------------------
# System / network checks
# ---------------------------------------------------------------------------
require_arch() {
    if [ ! -f /etc/arch-release ] && ! grep -qiE '^ID(_LIKE)?=.*arch' /etc/os-release 2>/dev/null; then
        err "$(t distro_unsupported)"
        exit 1
    fi
    if ! command -v pacman >/dev/null 2>&1; then
        err "$(t pacman_missing)"
        exit 1
    fi
}

require_internet() {
    if command -v curl >/dev/null 2>&1 && curl -fsS --max-time 5 https://archlinux.org >/dev/null 2>&1; then
        return 0
    fi
    if command -v ping >/dev/null 2>&1 && ping -c1 -W3 archlinux.org >/dev/null 2>&1; then
        return 0
    fi
    err "$(t internet_fail)"
    exit 1
}

# ---------------------------------------------------------------------------
# Git repository self-update (Update mode)
# ---------------------------------------------------------------------------
update_repo_if_needed() {
    [ "$MODE" = "update" ] || return 0
    [ "$SKIP_PULL" -eq 1 ] && return 0

    step "$(t updating_repo)"

    if [ ! -d "$REPO_DIR/.git" ] || ! command -v git >/dev/null 2>&1; then
        info "$(t repo_not_git)"
        return 0
    fi

    if [ -n "$(git -C "$REPO_DIR" status --porcelain 2>/dev/null)" ]; then
        warn "$(t repo_dirty)"
        return 0
    fi

    if ! git -C "$REPO_DIR" fetch --quiet origin 2>/dev/null; then
        warn "$(t repo_offline)"
        return 0
    fi

    local upstream behind old_hash new_hash
    upstream="$(git -C "$REPO_DIR" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)"
    [ -z "$upstream" ] && upstream="origin/main"

    behind="$(git -C "$REPO_DIR" rev-list --count "HEAD..$upstream" 2>/dev/null || echo 0)"
    if [ "$behind" -eq 0 ]; then
        ok "$(t repo_up_to_date)"
        return 0
    fi

    old_hash="$(sha256sum "$REPO_DIR/install.sh" 2>/dev/null | awk '{print $1}')"
    info "$(t repo_pulling "$behind")"
    if git -C "$REPO_DIR" pull --ff-only --quiet; then
        ok "$(t repo_pulled)"
        new_hash="$(sha256sum "$REPO_DIR/install.sh" 2>/dev/null | awk '{print $1}')"
        if [ -n "$old_hash" ] && [ "$old_hash" != "$new_hash" ] && [ "${_AEONSHELL_REEXEC:-0}" != "1" ]; then
            info "$(t repo_self_updated)"
            exec env _AEONSHELL_REEXEC=1 _AEONSHELL_LOG_FILE="$LOG_FILE" \
                "$REPO_DIR/install.sh" --lang "$LANG_CHOICE" --update --skip-pull
        fi
    else
        warn "$(t repo_pull_failed)"
    fi
}

# ---------------------------------------------------------------------------
# Existing configs handling & backup
# ---------------------------------------------------------------------------
handle_existing_configs() {
    step "$(t checking_existing)"

    local conflicts=() m
    for m in "${CONFIG_MODULES[@]}"; do
        [ -e "$CONFIG_DIR/$m" ] && conflicts+=("$CONFIG_DIR/$m")
    done

    if [ "${#conflicts[@]}" -eq 0 ]; then
        ok "$(t no_conflicts "$CONFIG_DIR")"
        return 0
    fi

    warn "$(t found_conflicts)"
    local c
    for c in "${conflicts[@]}"; do
        printf "    - %s\n" "$c"
    done

    local choice
    if [ "$MODE" = "update" ]; then
        while true; do
            printf "\n%b\n" "$(t update_conflict_prompt)"
            read -rp "  > " choice
            case "$choice" in
                ""|s|S)
                    SMART_UPDATE=1
                    _backup_conflicts "${conflicts[@]}"
                    break
                    ;;
                b|B)
                    SMART_UPDATE=0
                    _backup_conflicts "${conflicts[@]}"
                    break
                    ;;
                o|O)
                    SMART_UPDATE=0
                    warn "$(t overwriting)"
                    for c in "${conflicts[@]}"; do rm -rf "$c"; done
                    break
                    ;;
                c|C)
                    info "$(t cancelled)"
                    exit 0
                    ;;
                *)
                    warn "$(t invalid_sboc)"
                    ;;
            esac
        done
    else
        while true; do
            printf "\n%b\n" "$(t conflict_prompt "$BACKUP_DIR")"
            read -rp "  > " choice
            case "$choice" in
                ""|b|B)
                    _backup_conflicts "${conflicts[@]}"
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
                    warn "$(t invalid_boc)"
                    ;;
            esac
        done
    fi
}

_backup_conflicts() {
    local c rel
    mkdir -p "$BACKUP_DIR"
    for c in "$@"; do
        rel="${c#"$CONFIG_DIR"/}"
        mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
        mv "$c" "$BACKUP_DIR/$rel"
    done
    BACKUP_CREATED=1
    ok "$(t backed_up "$BACKUP_DIR")"
}

# ---------------------------------------------------------------------------
# Package resolution & installation
# ---------------------------------------------------------------------------
detect_aur_helper() {
    if command -v yay >/dev/null 2>&1; then
        AUR_HELPER="yay"
    elif command -v paru >/dev/null 2>&1; then
        AUR_HELPER="paru"
    else
        AUR_HELPER=""
    fi
}

pkg_installed() {
    pacman -Qi "$1" >/dev/null 2>&1
}

pkg_source() {
    local pkg="$1"
    if pacman -Si "$pkg" >/dev/null 2>&1; then
        printf 'pacman\n'
        return
    fi
    if [ -n "$AUR_HELPER" ] && "$AUR_HELPER" -Si "$pkg" >/dev/null 2>&1; then
        printf 'aur\n'
        return
    fi
    if command -v curl >/dev/null 2>&1; then
        local resp
        resp="$(curl -fsS --max-time 8 "https://aur.archlinux.org/rpc/v5/info?arg[]=$pkg" 2>/dev/null || true)"
        if printf '%s' "$resp" | grep -q '"resultcount":[1-9]'; then
            printf 'aur\n'
            return
        fi
    fi
    printf 'none\n'
}

ensure_aur_helper() {
    detect_aur_helper
    if [ -n "$AUR_HELPER" ]; then
        info "$(t aur_helper_found "$AUR_HELPER")"
        return 0
    fi

    local reply
    read -rp "  $(t yay_missing)" reply
    case "$reply" in
        ""|y|Y) ;;
        *) return 1 ;;
    esac

    info "$(t yay_installing)"
    AUR_IN_PROGRESS=1
    sudo pacman -S --needed --noconfirm base-devel git || true

    local tmp
    tmp="$(mktemp -d)"
    if git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin" \
        && (cd "$tmp/yay-bin" && makepkg -si --noconfirm); then
        rm -rf "$tmp"
        AUR_IN_PROGRESS=0
        AUR_HELPER="yay"
        return 0
    fi

    rm -rf "$tmp"
    AUR_IN_PROGRESS=0
    err "$(t yay_failed)"
    FAILURES+=("$(t fail_yay)")
    return 1
}

confirm_aur() {
    [ "$AUR_CONFIRMED" -eq 1 ] && return 0
    [ "$AUR_DECLINED" -eq 1 ] && return 1

    local pkglist reply
    pkglist="$(IFS=', '; echo "$*")"
    read -rp "  $(t aur_install_prompt "$#" "$pkglist")" reply
    case "$reply" in
        ""|y|Y)
            AUR_CONFIRMED=1
            return 0
            ;;
        *)
            AUR_DECLINED=1
            warn "$(t aur_skipped)"
            return 1
            ;;
    esac
}

install_batch() {
    local mgr="$1"; shift
    local pkgs=("$@")
    [ "${#pkgs[@]}" -eq 0 ] && return 0

    local batch_ok=1
    if [ "$mgr" = "pacman" ]; then
        sudo pacman -S --needed --noconfirm "${pkgs[@]}" || batch_ok=0
    else
        AUR_IN_PROGRESS=1
        "$AUR_HELPER" -S --needed --noconfirm "${pkgs[@]}" || batch_ok=0
        AUR_IN_PROGRESS=0
    fi

    if [ "$batch_ok" -eq 1 ]; then
        local p
        for p in "${pkgs[@]}"; do PKG_STATUS[$p]="installed"; done
        return 0
    fi

    if [ "$mgr" = "pacman" ]; then
        warn "$(t pacman_batch_fallback)"
    else
        warn "$(t aur_batch_fallback)"
    fi

    local p pkg_ok
    for p in "${pkgs[@]}"; do
        if pkg_installed "$p"; then
            PKG_STATUS[$p]="present"
            continue
        fi
        pkg_ok=1
        if [ "$mgr" = "pacman" ]; then
            sudo pacman -S --needed --noconfirm "$p" || pkg_ok=0
        else
            AUR_IN_PROGRESS=1
            "$AUR_HELPER" -S --needed --noconfirm "$p" || pkg_ok=0
            AUR_IN_PROGRESS=0
        fi
        if [ "$pkg_ok" -eq 1 ] && pkg_installed "$p"; then
            PKG_STATUS[$p]="installed"
        else
            PKG_STATUS[$p]="failed"
            FAILURES+=("$(t fail_pkg_install "$p" "$mgr")")
        fi
    done
}

install_dependencies() {
    [ "$MODE" = "configs" ] && return 0

    require_arch
    step "$(t resolving_deps)"

    local missing_required=()
    local already_count=0
    local pkg
    for pkg in "${PACMAN_DEPS[@]}" "${AUR_DEPS[@]}"; do
        if pkg_installed "$pkg"; then
            PKG_STATUS[$pkg]="present"
            already_count=$((already_count + 1))
        else
            missing_required+=("$pkg")
        fi
    done

    local want_optional=()
    if [ "$MODE" = "full" ]; then
        for pkg in "${OPTIONAL_DEPS[@]}"; do
            if pkg_installed "$pkg"; then
                PKG_STATUS[$pkg]="present"
                already_count=$((already_count + 1))
            else
                local reply
                read -rp "  $(t optional_matugen_prompt)" reply
                case "$reply" in
                    ""|y|Y) want_optional+=("$pkg") ;;
                    *) PKG_STATUS[$pkg]="skipped" ;;
                esac
            fi
        done
    fi

    local to_check=("${missing_required[@]}" "${want_optional[@]}")
    if [ "${#to_check[@]}" -eq 0 ]; then
        ok "$(t deps_all_installed)"
        return 0
    fi

    if [ "$MODE" = "update" ]; then
        local pkglist reply
        pkglist="$(IFS=', '; echo "${to_check[*]}")"
        read -rp "  $(t update_new_deps_prompt "${#to_check[@]}" "$pkglist")" reply
        case "$reply" in
            ""|y|Y) ;;
            *)
                for pkg in "${to_check[@]}"; do PKG_STATUS[$pkg]="skipped"; done
                info "$(t update_deps_skipped)"
                return 0
                ;;
        esac
    fi

    require_internet
    step "$(t refreshing_db)"
    sudo pacman -Sy || warn "$(t refresh_db_failed)"

    detect_aur_helper
    local pacman_queue=() aur_queue=() src
    for pkg in "${to_check[@]}"; do
        src="$(pkg_source "$pkg")"
        case "$src" in
            pacman) pacman_queue+=("$pkg") ;;
            aur)    aur_queue+=("$pkg") ;;
            *)
                PKG_STATUS[$pkg]="failed"
                FAILURES+=("$(t fail_pkg_not_found "$pkg")")
                warn "$(t pkg_not_found "$pkg")"
                ;;
        esac
    done

    if [ "${#pacman_queue[@]}" -eq 0 ] && [ "${#aur_queue[@]}" -eq 0 ]; then
        return 0
    fi

    info "$(t deps_summary "$already_count" "${#pacman_queue[@]}" "${#aur_queue[@]}")"

    if [ "${#pacman_queue[@]}" -gt 0 ]; then
        step "$(t installing_pacman "${#pacman_queue[@]}")"
        install_batch pacman "${pacman_queue[@]}"
        ok "$(t pacman_done)"
    fi

    if [ "${#aur_queue[@]}" -gt 0 ]; then
        if confirm_aur "${aur_queue[@]}" && ensure_aur_helper; then
            step "$(t installing_aur "${#aur_queue[@]}")"
            install_batch aur "${aur_queue[@]}"
            ok "$(t aur_done)"
        else
            for pkg in "${aur_queue[@]}"; do
                pkg_installed "$pkg" && continue
                PKG_STATUS[$pkg]="skipped"
                FAILURES+=("$(t fail_aur_declined "$pkg")")
            done
        fi
    fi
}

# ---------------------------------------------------------------------------
# Deploy configs, preserve user hardware configs on Smart Update, verify
# ---------------------------------------------------------------------------
deploy_configs() {
    step "$(t copying_configs "$CONFIG_DIR")"
    mkdir -p "$CONFIG_DIR"

    local m src_count dst_count
    for m in "${CONFIG_MODULES[@]}"; do
        mkdir -p "$CONFIG_DIR/$m"
        if cp -r "$REPO_DIR/$m/." "$CONFIG_DIR/$m/"; then
            rm -f "$CONFIG_DIR/quickshell/.qmlls.ini"
            src_count=$(find "$REPO_DIR/$m" -type f 2>/dev/null | wc -l)
            dst_count=$(find "$CONFIG_DIR/$m" -type f 2>/dev/null | wc -l)
            if [ "$src_count" -gt 0 ] && [ "$dst_count" -ge "$src_count" ]; then
                ok "$(t module_copied "$m" "$dst_count")"
            else
                err "$(t module_failed "$m")"
                FAILURES+=("$(t fail_config "$m")")
            fi
        else
            err "$(t module_failed "$m")"
            FAILURES+=("$(t fail_config "$m")")
        fi
    done

    if [ "$SMART_UPDATE" -eq 1 ] && [ "$BACKUP_CREATED" -eq 1 ]; then
        local rel backed
        for rel in "${PRESERVED_HYPR_FILES[@]}"; do
            backed="$BACKUP_DIR/$rel"
            if [ -f "$backed" ] && [ -f "$CONFIG_DIR/$rel" ] && ! cmp -s "$backed" "$CONFIG_DIR/$rel"; then
                cp "$backed" "$CONFIG_DIR/$rel"
                info "$(t preserved_file "$rel")"
            fi
        done

        local old_bind="$BACKUP_DIR/hypr/conf/bind.lua"
        local new_bind="$CONFIG_DIR/hypr/conf/bind.lua"
        if [ -f "$old_bind" ] && [ -f "$new_bind" ] && ! cmp -s "$old_bind" "$new_bind"; then
            warn "$(t bind_updated "$old_bind")"
        fi
    fi

    local fixed=0 f
    if [ -d "$CONFIG_DIR/hypr/script" ]; then
        for f in "$CONFIG_DIR"/hypr/script/*.sh; do
            [ -e "$f" ] || continue
            if [ ! -x "$f" ]; then
                chmod +x "$f" 2>/dev/null && fixed=$((fixed + 1))
            fi
        done
    fi
    [ "$fixed" -gt 0 ] && info "$(t scripts_fixed "$fixed")"

    mkdir -p "$HOME/Pictures/Wallpapers"
    ok "$(t wallpapers_dir "$HOME/Pictures/Wallpapers")"
}

# ---------------------------------------------------------------------------
# Systemd services & live session reload
# ---------------------------------------------------------------------------
offer_services() {
    [ "$MODE" = "full" ] || return 0
    command -v systemctl >/dev/null 2>&1 || return 0

    local needed=() svc
    for svc in NetworkManager bluetooth; do
        if systemctl list-unit-files "${svc}.service" >/dev/null 2>&1 \
            && ! systemctl is-enabled "${svc}.service" >/dev/null 2>&1; then
            needed+=("${svc}.service")
        fi
    done

    [ "${#needed[@]}" -eq 0 ] && return 0

    step "$(t services_title)"
    local reply
    for svc in "${needed[@]}"; do
        read -rp "  $(t service_prompt "$svc")" reply
        case "$reply" in
            y|Y)
                if sudo systemctl enable --now "$svc"; then
                    ok "$(t service_enabled "$svc")"
                else
                    warn "$(t service_failed "$svc")"
                fi
                ;;
        esac
    done
}

offer_live_reload() {
    [ "$MODE" = "update" ] || return 0
    [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] || return 0
    command -v hyprctl >/dev/null 2>&1 || return 0

    step "$(t reload_title)"
    local reply
    read -rp "  $(t reload_prompt)" reply
    case "$reply" in
        ""|y|Y)
            hyprctl reload >/dev/null 2>&1 || true
            if command -v quickshell >/dev/null 2>&1; then
                pkill -x quickshell >/dev/null 2>&1 || true
                sleep 0.3
                nohup quickshell >/dev/null 2>&1 </dev/null &
            fi
            ok "$(t reload_done)"
            ;;
        *)
            info "$(t reload_skipped)"
            ;;
    esac
}

# ---------------------------------------------------------------------------
# Final report
# ---------------------------------------------------------------------------
print_summary() {
    step "$(t report_title)"

    local pkg inst=0 pres=0 skip=0 fail=0
    for pkg in "${!PKG_STATUS[@]}"; do
        case "${PKG_STATUS[$pkg]}" in
            installed) inst=$((inst + 1)) ;;
            present)   pres=$((pres + 1)) ;;
            skipped)   skip=$((skip + 1)) ;;
            failed)    fail=$((fail + 1)) ;;
        esac
    done

    if [ "$MODE" != "configs" ]; then
        printf "  %s%-16s%s %d   %s%-16s%s %d   %s%-10s%s %d   %s%-8s%s %d\n" \
            "$C_GREEN" "$(t report_installed):" "$C_RESET" "$inst" \
            "$C_DIM" "$(t report_present):" "$C_RESET" "$pres" \
            "$C_YELLOW" "$(t report_skipped):" "$C_RESET" "$skip" \
            "$C_RED" "$(t report_failed):" "$C_RESET" "$fail"
    fi

    [ "$BACKUP_CREATED" -eq 1 ] && info "$(t report_backup "$BACKUP_DIR")"
    info "$(t log_path "$LOG_FILE")"

    if [ "${#FAILURES[@]}" -gt 0 ]; then
        printf "\n  %s%s%s\n" "$C_YELLOW$C_BOLD" "$(t report_failures)" "$C_RESET"
        local item
        for item in "${FAILURES[@]}"; do
            printf "    %s✗%s %s\n" "$C_RED" "$C_RESET" "$item"
        done
    else
        ok "$(t report_clean)"
    fi

    step "$(t next_title)"
    printf "  1. %s\n" "$(t next_1 "$C_BOLD" "$C_RESET")"
    printf "  2. %s\n" "$(t next_2 "$C_BOLD" "$C_RESET")"
    printf "  3. %s\n\n" "$(t next_3 "$C_BOLD" "$C_RESET" "$C_BOLD" "$C_RESET")"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
    parse_args "$@"
    print_header
    ask_language
    require_not_root
    setup_logging
    ask_mode
    update_repo_if_needed
    handle_existing_configs
    install_dependencies
    deploy_configs
    offer_services
    offer_live_reload
    print_summary
}

main "$@"
