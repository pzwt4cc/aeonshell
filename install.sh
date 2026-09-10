#!/usr/bin/env bash
#
# aeonshell installer
#
# Copies hypr/quickshell/fastfetch/kitty (and optionally zsh) configs into
# ~/.config, installs pacman + AUR dependencies, and offers to back up any
# conflicting configs you already have.
#
# Robustness additions over a "naive" installer:
#   - every package's real source (official repos vs AUR) is looked up at
#     run time; if a package isn't where the maintainers expected it, the
#     script automatically tries the other one instead of just failing.
#   - a batch package install that fails is retried package-by-package, so
#     one broken/renamed package can't block everything else.
#   - configs are verified after copying (file counts, executable bits),
#     not just "cp and hope".
#   - everything is logged to a file, and a full ok/skipped/failed report is
#     printed at the very end so you know exactly what happened.
#
set -uo pipefail
# Deliberately NOT using -e: individual package/step failures are recorded
# and reported at the end instead of killing the whole run. Fatal
# environment problems (wrong distro, no network, running as root) still
# call `exit` explicitly where it actually matters.

# ---------------------------------------------------------------------------
# Pretty output (color support is detected before we start logging to a
# file, since a pipe isn't a tty and would otherwise disable colors)
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

    [log_saved_to]="Full log of this run is being saved to %s"

    [checking_distro]="Checking distro"
    [distro_unsupported_1]="This installer only supports Arch Linux and Arch-based distros (pacman + AUR)."
    [distro_unsupported_2]="Your system doesn't look like one of those — aborting so nothing gets touched."
    [pacman_missing]="'pacman' was not found on PATH. Aborting."
    [distro_ok]="Arch-based system detected."

    [no_root]="Please run this as your normal user, not root (it uses sudo where needed)."

    [checking_internet]="Checking internet connection"
    [internet_ok]="Internet connection looks fine."
    [internet_fail]="Couldn't reach the network (archlinux.org / aur.archlinux.org). Check your connection and re-run."

    [refreshing_db]="Refreshing package databases (pacman -Sy)"
    [refresh_db_done]="Package databases refreshed."
    [refresh_db_failed]="Couldn't refresh package databases — continuing anyway, but package lookups below may be based on a stale cache."

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
    [aur_not_confirmed]="AUR installation not confirmed — those packages will be marked as skipped, everything else continues."
    [aur_confirmed]="Confirmed — proceeding with AUR installation."

    [checking_yay]="Checking for an AUR helper (yay)"
    [yay_present]="yay is already installed."
    [yay_installing]="yay not found — installing it."
    [yay_failed]="yay installation failed. AUR packages will be marked as failed; install yay manually and re-run to pick them up."
    [yay_installed]="yay installed."

    [resolving_deps]="Resolving where each package actually comes from"
    [source_switch]="%s isn't where it's normally expected — found it in %s instead, will install from there."
    [pkg_not_found_anywhere]="%s wasn't found in the official repos or the AUR — skipping it."

    [installing_pacman]="Installing official-repo packages"
    [pacman_deps_done]="Official-repo packages installed."
    [pacman_deps_already]="All official-repo packages are already installed — skipping."
    [pacman_batch_failed]="The batch install hit a problem — retrying package by package to isolate it."

    [installing_aur]="Installing AUR packages"
    [aur_deps_done]="AUR packages installed."
    [aur_deps_already]="All AUR packages are already installed — skipping the AUR step entirely."
    [aur_batch_failed]="The AUR batch install hit a problem — retrying package by package to isolate it."
    [retry_attempt]="Retrying (attempt %d)..."

    [optional_step]="Optional extras"
    [optional_already]="All optional extras are already installed — skipping."
    [optional_prompt]="Install optional extras (openrgb, thunderbird, codium, localsend)? [y/N] "
    [optional_aur_warning]="Some of these come from the AUR (community-maintained, unreviewed build scripts) — same trust model explained earlier."
    [optional_done]="Optional extras step finished."
    [optional_skip]="Skipping optional extras."

    [shell_step]="Shell"
    [shell_current]="Your current login shell is: %s"
    [shell_already_zsh]="You're already on zsh — set up the included config anyway? [y/N] "
    [shell_offer]="Install zsh and set up the included config (your current shell, %s, is left untouched unless you say so next)? [y/N] "
    [shell_kept]="Keeping %s as-is — skipping zsh setup."

    [copying_configs]="Copying configs into %s"
    [module_copied]="%s copied."
    [module_copy_failed]="Failed to copy %s — check the log above for the error."
    [configs_copied]="Configs copied."
    [zsh_dotfiles_copied]="zsh dotfiles copied to %s."
    [zsh_dotfiles_failed]="Couldn't copy one or more zsh dotfiles."
    [local_conf_created]="Created hypr/conf/local.conf from the example — edit it for your machine."
    [local_conf_exists]="hypr/conf/local.conf already exists — leaving it alone."
    [local_conf_failed]="Couldn't create hypr/conf/local.conf from the example."
    [chsh_prompt]="Switch your login shell from %s to zsh now? [y/N] "
    [chsh_done]="Login shell changed to zsh (takes effect on next login)."
    [chsh_failed]="Couldn't change the login shell — you can run 'chsh -s \$(which zsh)' yourself later."
    [chsh_kept]="Keeping %s as your login shell — run 'chsh -s \$(which zsh)' later if you change your mind."

    [verifying_configs]="Verifying copied configs"
    [config_verified]="%s looks complete (%d file(s))."
    [config_mismatch]="%s looks incomplete: %d file(s) in the repo vs %d in ~/.config — something may not have copied."
    [scripts_executable]="hypr scripts are executable."
    [scripts_not_executable]="%d hypr script(s) are missing the executable bit — fixed."

    [report_title]="Install summary"
    [report_ok]="Installed OK"
    [report_skipped]="Skipped"
    [report_failed]="Failed"
    [report_failed_list]="The following did not complete:"
    [report_all_good]="Everything completed with no failures. 🎉"
    [report_log_hint]="Full details are in the log file: %s"

    [fail_pkg_not_found]="%s — not found in either the official repos or the AUR"
    [fail_pkg_not_confirmed]="%s — AUR install wasn't confirmed"
    [fail_pkg_install]="%s (%s) — install command failed"
    [fail_config_module]="config module '%s' — file count mismatch after copying"
    [fail_local_conf]="hypr/conf/local.conf — could not be created"
    [fail_yay]="yay — could not be installed, all AUR packages skipped"
    [fail_zsh_dotfiles]="zsh dotfiles — copy failed"
    [fail_chsh]="login shell — could not be changed to zsh"

    [done_step]="Done"
    [all_done]="aeonshell is installed."
    [next_steps_title]="Next steps:"
    [next_step_1]="Edit %s~/.config/hypr/conf/local.conf%s for your monitors/GPU."
    [next_step_2]="Drop some wallpapers into %s~/Pictures/Wallpapers%s."
    [next_step_3]="Log into Hyprland, open the launcher, type %s>wallpaper%s to pick one"
    [next_step_3b]="and generate your first pywal theme."

    [err_generic]="Something went wrong on line %s."
)

declare -A T_RU=(
    [lang_prompt_title]="Выберите язык подсказок:"
    [lang_prompt_opt_en]="  [1] Английский (English)"
    [lang_prompt_opt_ru]="  [2] Русский"
    [lang_prompt_invalid]="Введите 1 или 2."

    [log_saved_to]="Полный лог этого запуска сохраняется в %s"

    [checking_distro]="Проверка дистрибутива"
    [distro_unsupported_1]="Этот установщик поддерживает только Arch Linux и Arch-based дистрибутивы (pacman + AUR)."
    [distro_unsupported_2]="Ваша система не похожа на них — прерываю, ничего не тронуто."
    [pacman_missing]="'pacman' не найден в PATH. Прерываю."
    [distro_ok]="Обнаружена система на базе Arch."

    [no_root]="Запустите скрипт от обычного пользователя, не от root (sudo вызывается там, где нужно)."

    [checking_internet]="Проверка подключения к интернету"
    [internet_ok]="С интернетом всё в порядке."
    [internet_fail]="Не удалось достучаться до сети (archlinux.org / aur.archlinux.org). Проверьте соединение и запустите снова."

    [refreshing_db]="Обновление баз пакетов (pacman -Sy)"
    [refresh_db_done]="Базы пакетов обновлены."
    [refresh_db_failed]="Не удалось обновить базы пакетов — продолжаю, но проверки ниже могут опираться на устаревший кэш."

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
    [aur_not_confirmed]="Установка AUR не подтверждена — эти пакеты будут помечены как пропущенные, всё остальное продолжится."
    [aur_confirmed]="Подтверждено — продолжаю установку AUR."

    [checking_yay]="Проверка AUR-хелпера (yay)"
    [yay_present]="yay уже установлен."
    [yay_installing]="yay не найден — устанавливаю."
    [yay_failed]="Установка yay не удалась. Пакеты из AUR будут помечены как неудавшиеся — установите yay вручную и запустите скрипт заново."
    [yay_installed]="yay установлен."

    [resolving_deps]="Определяю, откуда на самом деле берётся каждый пакет"
    [source_switch]="%s не там, где обычно ожидается — найден в %s, поставлю оттуда."
    [pkg_not_found_anywhere]="%s не найден ни в официальных репозиториях, ни в AUR — пропускаю."

    [installing_pacman]="Установка пакетов из официальных репозиториев"
    [pacman_deps_done]="Пакеты из официальных репозиториев установлены."
    [pacman_deps_already]="Все пакеты из официальных репозиториев уже установлены — пропускаю."
    [pacman_batch_failed]="Пакетная установка споткнулась — пробую по одному пакету, чтобы найти виновника."

    [installing_aur]="Установка пакетов из AUR"
    [aur_deps_done]="Пакеты из AUR установлены."
    [aur_deps_already]="Все пакеты из AUR уже установлены — полностью пропускаю AUR-шаг."
    [aur_batch_failed]="Пакетная установка AUR споткнулась — пробую по одному пакету, чтобы найти виновника."
    [retry_attempt]="Повторная попытка (№ %d)..."

    [optional_step]="Опциональные пакеты"
    [optional_already]="Все опциональные пакеты уже установлены — пропускаю."
    [optional_prompt]="Установить опциональные пакеты (openrgb, thunderbird, codium, localsend)? [y/N] "
    [optional_aur_warning]="Часть из них — из AUR (скрипты сборки от сообщества, без проверки) — тот же уровень доверия, что описан выше."
    [optional_done]="Шаг с опциональными пакетами завершён."
    [optional_skip]="Пропускаю опциональные пакеты."

    [shell_step]="Шелл"
    [shell_current]="Ваш текущий логин-шелл: %s"
    [shell_already_zsh]="У вас уже zsh — всё равно накатить конфиг из репозитория? [y/N] "
    [shell_offer]="Установить zsh и настроить конфиг из репозитория (ваш текущий шелл, %s, останется нетронутым, если не согласитесь на следующем шаге)? [y/N] "
    [shell_kept]="Оставляю %s как есть — пропускаю настройку zsh."

    [copying_configs]="Копирование конфигов в %s"
    [module_copied]="%s скопирован."
    [module_copy_failed]="Не удалось скопировать %s — смотрите ошибку в логе выше."
    [configs_copied]="Конфиги скопированы."
    [zsh_dotfiles_copied]="Дотфайлы zsh скопированы в %s."
    [zsh_dotfiles_failed]="Не удалось скопировать один или несколько дотфайлов zsh."
    [local_conf_created]="Создан hypr/conf/local.conf из примера — отредактируйте его под своё железо."
    [local_conf_exists]="hypr/conf/local.conf уже существует — оставляю как есть."
    [local_conf_failed]="Не удалось создать hypr/conf/local.conf из примера."
    [chsh_prompt]="Сменить логин-шелл с %s на zsh прямо сейчас? [y/N] "
    [chsh_done]="Логин-шелл изменён на zsh (вступит в силу при следующем входе)."
    [chsh_failed]="Не удалось сменить логин-шелл — позже можно выполнить 'chsh -s \$(which zsh)' самостоятельно."
    [chsh_kept]="Оставляю %s как логин-шелл — выполните 'chsh -s \$(which zsh)' позже, если передумаете."

    [verifying_configs]="Проверка скопированных конфигов"
    [config_verified]="%s выглядит полным (%d файл(ов))."
    [config_mismatch]="%s выглядит неполным: %d файл(ов) в репозитории против %d в ~/.config — что-то могло не скопироваться."
    [scripts_executable]="Скрипты hypr исполняемые."
    [scripts_not_executable]="%d скрипт(ов) hypr были без бита исполнения — исправлено."

    [report_title]="Итоги установки"
    [report_ok]="Установлено успешно"
    [report_skipped]="Пропущено"
    [report_failed]="Не удалось"
    [report_failed_list]="Не завершилось следующее:"
    [report_all_good]="Всё прошло без единой ошибки. 🎉"
    [report_log_hint]="Все подробности — в файле лога: %s"

    [fail_pkg_not_found]="%s — не найден ни в официальных репозиториях, ни в AUR"
    [fail_pkg_not_confirmed]="%s — установка из AUR не была подтверждена"
    [fail_pkg_install]="%s (%s) — команда установки завершилась с ошибкой"
    [fail_config_module]="модуль конфига '%s' — не совпало количество файлов после копирования"
    [fail_local_conf]="hypr/conf/local.conf — не удалось создать"
    [fail_yay]="yay — не удалось установить, все пакеты AUR пропущены"
    [fail_zsh_dotfiles]="дотфайлы zsh — копирование не удалось"
    [fail_chsh]="логин-шелл — не удалось сменить на zsh"

    [done_step]="Готово"
    [all_done]="aeonshell установлен."
    [next_steps_title]="Дальнейшие шаги:"
    [next_step_1]="Отредактируйте %s~/.config/hypr/conf/local.conf%s под свои мониторы/GPU."
    [next_step_2]="Скиньте несколько обоев в %s~/Pictures/Wallpapers%s."
    [next_step_3]="Войдите в Hyprland, откройте лаунчер, наберите %s>wallpaper%s, чтобы выбрать обои"
    [next_step_3b]="и сгенерировать первую тему pywal."

    [err_generic]="Что-то пошло не так на строке %s."
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

# Unexpected (not-explicitly-handled) errors still get logged with a line
# number instead of silently vanishing, but they no longer kill the whole
# script — everything that matters is wrapped in its own error handling
# below, and the final report tells you what did or didn't finish.
trap 'warn "$(t err_generic "$LINENO")"' ERR

banner() {
    printf "%s\n" "$C_CYAN$C_BOLD"
    cat <<'EOF'
   __ _  ___  ___  _ __  ___| |__   ___| | |
  / _` |/ _ \/ _ \| '_ \/ __| '_ \ / _ \ | |
 | (_| |  __/ (_) | | | \__ \ | | |  __/ | |
  \__,_|\___|\___/|_| |_|___/_| |_|\___|_|_|
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
# Logging — everything from here on is duplicated into a log file, so you
# have a complete record to check (or to attach to a bug report) even after
# the terminal scrolls past it.
# ---------------------------------------------------------------------------
setup_logging() {
    LOG_FILE="$HOME/aeonshell-install-$(date +%Y%m%d-%H%M%S).log"
    exec > >(tee -a "$LOG_FILE") 2>&1
    info "$(t log_saved_to "$LOG_FILE")"
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

check_internet() {
    step "$(t checking_internet)"
    if command -v curl >/dev/null 2>&1 && curl -fsS --max-time 5 https://archlinux.org >/dev/null 2>&1; then
        ok "$(t internet_ok)"; return
    fi
    if command -v ping >/dev/null 2>&1 && ping -c1 -W3 archlinux.org >/dev/null 2>&1; then
        ok "$(t internet_ok)"; return
    fi
    err "$(t internet_fail)"
    exit 1
}

refresh_pacman_db() {
    step "$(t refreshing_db)"
    if sudo pacman -Sy; then
        ok "$(t refresh_db_done)"
    else
        warn "$(t refresh_db_failed)"
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
# Final report bookkeeping
#
# PKG_STATUS[pkg] = ok|skipped|failed for every package we ever considered
# (required + optional, pacman + AUR). FAILURES holds human-readable lines
# for anything — package or otherwise — that didn't fully succeed, printed
# verbatim in the final report.
# ---------------------------------------------------------------------------
declare -A PKG_STATUS=()
FAILURES=()
AUR_CONFIRMED=0
AUR_DECLINED=0

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
                    mkdir -p "$BACKUP_DIR/$(dirname "${c#"$HOME"/}")"
                    mv "$c" "$BACKUP_DIR/${c#"$HOME"/}"
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

AUR_NOTICE_EN_HEAD='The AUR (Arch User Repository) hosts build scripts (PKGBUILDs) submitted
by the community - they are not reviewed or vetted by Arch or by us.
Installing from the AUR means downloading and running someone elses
build script with your privileges (via sudo). Its widely used and
generally safe, but it isnt the same trust level as official repo
packages - youre relying on each packages maintainer.

This step installs: yay (AUR helper, if not already present),'

AUR_NOTICE_EN_TAIL='
If you want to inspect a package first, each one can be reviewed at:
  https://aur.archlinux.org/packages/<name>

Once you confirm, the whole AUR step runs without further prompts.'

AUR_NOTICE_RU_HEAD='AUR (Arch User Repository) хранит скрипты сборки (PKGBUILD),
присланные сообществом — их не проверяет ни Arch, ни мы. Установка
из AUR означает скачивание и запуск чужого скрипта сборки с вашими
правами (через sudo). Это широко используется и в целом безопасно,
но это не тот же уровень доверия, что официальные репозитории — вы
полагаетесь на мейнтейнера каждого пакета.

Этот шаг установит: yay (AUR-хелпер, если его ещё нет),'

AUR_NOTICE_RU_TAIL='
Если хотите посмотреть пакет заранее, каждый можно проверить тут:
  https://aur.archlinux.org/packages/<name>

После подтверждения весь шаг AUR пройдёт без дополнительных вопросов.'

# confirm_aur <pkg...> — shows the AUR trust notice for the given package
# list and asks for an explicit CONFIRM. Only asked once per run: after the
# first CONFIRM (or decline), later calls short-circuit on AUR_CONFIRMED /
# AUR_DECLINED instead of asking again.
confirm_aur() {
    if [ "$AUR_CONFIRMED" -eq 1 ]; then return 0; fi
    if [ "$AUR_DECLINED" -eq 1 ]; then return 1; fi

    step "$(t aur_notice_title)"
    local pkglist
    pkglist="$(IFS=', '; echo "$*")"
    if [ "$LANG_CHOICE" = "ru" ]; then
        printf "%s\n%s.\n%s\n" "$AUR_NOTICE_RU_HEAD" "$pkglist" "$AUR_NOTICE_RU_TAIL"
    else
        printf "%s\n%s.\n%s\n" "$AUR_NOTICE_EN_HEAD" "$pkglist" "$AUR_NOTICE_EN_TAIL"
    fi
    local confirm
    read -rp "$(t aur_confirm_prompt)" confirm
    if [ "$confirm" != "CONFIRM" ]; then
        AUR_DECLINED=1
        warn "$(t aur_not_confirmed)"
        return 1
    fi
    AUR_CONFIRMED=1
    ok "$(t aur_confirmed)"
    return 0
}

# ---------------------------------------------------------------------------
# yay
# ---------------------------------------------------------------------------
ensure_yay() {
    if command -v yay >/dev/null 2>&1; then
        return 0
    fi

    step "$(t checking_yay)"
    info "$(t yay_installing)"
    AUR_IN_PROGRESS=1
    sudo pacman -S --needed --noconfirm base-devel git

    local tmp
    tmp="$(mktemp -d)"
    if git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin" \
        && (cd "$tmp/yay-bin" && makepkg -si --noconfirm); then
        rm -rf "$tmp"
        AUR_IN_PROGRESS=0
        ok "$(t yay_installed)"
        return 0
    fi

    rm -rf "$tmp"
    AUR_IN_PROGRESS=0
    err "$(t yay_failed)"
    FAILURES+=("$(t fail_yay)")
    return 1
}

# ---------------------------------------------------------------------------
# Dependencies
#
# These lists are still split by "where we normally expect to find it" —
# that's useful documentation and matches the README — but nothing below
# actually trusts the split blindly: pkg_source() looks each one up for
# real before deciding how to install it, so a package that moved between
# the official repos and the AUR (or was miscategorized) still installs
# correctly instead of just failing.
# ---------------------------------------------------------------------------
PACMAN_DEPS=(
    hyprland hyprlock xdg-desktop-portal-hyprland xdg-desktop-portal
    qt6-wayland qt6ct qt6-5compat gtk3 kitty pcmanfm-qt xorg-xrandr
    networkmanager network-manager-applet nm-connection-editor
    bluez bluez-utils blueman
    pipewire pipewire-pulse pipewire-alsa wireplumber pavucontrol
    wl-clipboard cliphist grim slurp swappy
    jq curl python zenity inotify-tools udiskie
    fastfetch fzf yazi ffmpeg socat mousepad
)

AUR_DEPS=(
    quickshell-git awww python-pywal mpvpaper
    zen-browser-bin bibata-cursor-theme
    otf-font-awesome ttf-jetbrains-mono-nerd zsh-antidote
    kvantum gpu-screen-recorder-ui peazip tty-clock
)

OPTIONAL_PACMAN_DEPS=(openrgb thunderbird)
OPTIONAL_AUR_DEPS=(codium localsend)

# pkg_installed <name> — true if a package is already installed (works for
# both official-repo and AUR packages, pacman -Qi covers both once installed).
pkg_installed() {
    pacman -Qi "$1" >/dev/null 2>&1
}

# pkg_source <name> — prints "pacman", "aur", or "none": where the package
# actually is right now, checked live rather than assumed from our lists.
# Falls back to a plain AUR RPC lookup via curl when yay isn't installed
# yet, so we can make this decision before ever touching yay/makepkg.
pkg_source() {
    local pkg="$1"
    if pacman -Si "$pkg" >/dev/null 2>&1; then
        printf 'pacman\n'
        return
    fi
    if command -v yay >/dev/null 2>&1; then
        if yay -Si "$pkg" >/dev/null 2>&1; then
            printf 'aur\n'
            return
        fi
    elif command -v curl >/dev/null 2>&1; then
        local resp
        resp="$(curl -fsS --max-time 10 "https://aur.archlinux.org/rpc/v5/info?arg[]=$pkg" 2>/dev/null || true)"
        if printf '%s' "$resp" | grep -q '"resultcount":[1-9]'; then
            printf 'aur\n'
            return
        fi
    fi
    printf 'none\n'
}

# resolve_pkg_list <array-name> <pacman-queue-name> <aur-queue-name> —
# for every not-yet-installed package in the source array, figures out its
# real source and appends it to the right queue. Packages found nowhere are
# marked failed immediately (with a reason) so the final report is precise.
resolve_pkg_list() {
    local -n src="$1" pacman_q="$2" aur_q="$3"
    local pkg source expected
    for pkg in "${src[@]}"; do
        if pkg_installed "$pkg"; then
            PKG_STATUS[$pkg]="ok"
            continue
        fi
        source="$(pkg_source "$pkg")"
        case "$source" in
            pacman) pacman_q+=("$pkg") ;;
            aur)    aur_q+=("$pkg") ;;
            *)
                PKG_STATUS[$pkg]="failed"
                FAILURES+=("$(t fail_pkg_not_found "$pkg")")
                warn "$(t pkg_not_found_anywhere "$pkg")"
                ;;
        esac
    done
}

# install_batch <pacman|aur> <pkg...> — installs a batch of same-source
# packages. If the whole batch fails (one bad/renamed/conflicting package
# is enough to do that with pacman/yay), falls back to installing each
# package on its own so the rest still get installed and we know exactly
# which one(s) failed and why.
install_batch() {
    local mgr="$1"; shift
    local pkgs=("$@")
    [ "${#pkgs[@]}" -eq 0 ] && return 0

    local batch_ok=1
    if [ "$mgr" = "pacman" ]; then
        sudo pacman -S --needed --noconfirm "${pkgs[@]}" || batch_ok=0
    else
        AUR_IN_PROGRESS=1
        yay -S --needed --noconfirm "${pkgs[@]}" || batch_ok=0
        AUR_IN_PROGRESS=0
    fi

    if [ "$batch_ok" -eq 1 ]; then
        local p
        for p in "${pkgs[@]}"; do PKG_STATUS[$p]="ok"; done
        return 0
    fi

    if [ "$mgr" = "pacman" ]; then
        warn "$(t pacman_batch_failed)"
    else
        warn "$(t aur_batch_failed)"
    fi

    local p
    for p in "${pkgs[@]}"; do
        if pkg_installed "$p"; then
            PKG_STATUS[$p]="ok"
            continue
        fi
        local pkg_ok=1
        if [ "$mgr" = "pacman" ]; then
            sudo pacman -S --needed --noconfirm "$p" || pkg_ok=0
        else
            AUR_IN_PROGRESS=1
            yay -S --needed --noconfirm "$p" || pkg_ok=0
            AUR_IN_PROGRESS=0
        fi
        if [ "$pkg_ok" -eq 1 ] && pkg_installed "$p"; then
            PKG_STATUS[$p]="ok"
        else
            PKG_STATUS[$p]="failed"
            FAILURES+=("$(t fail_pkg_install "$p" "$mgr")")
        fi
    done
}

install_all_deps() {
    step "$(t resolving_deps)"
    local pacman_queue=() aur_queue=()
    resolve_pkg_list PACMAN_DEPS pacman_queue aur_queue
    resolve_pkg_list AUR_DEPS pacman_queue aur_queue

    if [ "${#pacman_queue[@]}" -gt 0 ]; then
        step "$(t installing_pacman)"
        install_batch pacman "${pacman_queue[@]}"
        ok "$(t pacman_deps_done)"
    else
        ok "$(t pacman_deps_already)"
    fi

    if [ "${#aur_queue[@]}" -gt 0 ]; then
        if confirm_aur "${aur_queue[@]}" && ensure_yay; then
            step "$(t installing_aur)"
            install_batch aur "${aur_queue[@]}"
            ok "$(t aur_deps_done)"
        else
            local p
            for p in "${aur_queue[@]}"; do
                pkg_installed "$p" && continue
                PKG_STATUS[$p]="failed"
                FAILURES+=("$(t fail_pkg_not_confirmed "$p")")
            done
        fi
    else
        ok "$(t aur_deps_already)"
    fi
}

install_optional_deps() {
    step "$(t optional_step)"

    local candidates=("${OPTIONAL_PACMAN_DEPS[@]}" "${OPTIONAL_AUR_DEPS[@]}")
    local todo=() pkg
    for pkg in "${candidates[@]}"; do
        pkg_installed "$pkg" || todo+=("$pkg")
    done

    if [ "${#todo[@]}" -eq 0 ]; then
        ok "$(t optional_already)"
        for pkg in "${candidates[@]}"; do PKG_STATUS[$pkg]="ok"; done
        return
    fi

    read -rp "$(t optional_prompt)" reply
    case "$reply" in
        y|Y)
            local opt_pacman=() opt_aur=() src
            for pkg in "${todo[@]}"; do
                src="$(pkg_source "$pkg")"
                case "$src" in
                    pacman) opt_pacman+=("$pkg") ;;
                    aur)    opt_aur+=("$pkg") ;;
                    *)
                        PKG_STATUS[$pkg]="failed"
                        FAILURES+=("$(t fail_pkg_not_found "$pkg")")
                        ;;
                esac
            done
            [ "${#opt_pacman[@]}" -gt 0 ] && install_batch pacman "${opt_pacman[@]}"
            if [ "${#opt_aur[@]}" -gt 0 ]; then
                warn "$(t optional_aur_warning)"
                if ensure_yay; then
                    install_batch aur "${opt_aur[@]}"
                else
                    for pkg in "${opt_aur[@]}"; do
                        PKG_STATUS[$pkg]="failed"
                        FAILURES+=("$(t fail_pkg_not_confirmed "$pkg")")
                    done
                fi
            fi
            ok "$(t optional_done)"
            ;;
        *)
            info "$(t optional_skip)"
            for pkg in "${todo[@]}"; do PKG_STATUS[$pkg]="skipped"; done
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
    mkdir -p "$CONFIG_DIR"

    local m
    for m in "${CONFIG_MODULES[@]}"; do
        mkdir -p "$CONFIG_DIR/$m"
        if cp -r "$REPO_DIR/$m/." "$CONFIG_DIR/$m/"; then
            ok "$(t module_copied "$m")"
        else
            err "$(t module_copy_failed "$m")"
            FAILURES+=("$(t fail_config_module "$m")")
        fi
    done

    if [ -d "$CONFIG_DIR/hypr/script" ]; then
        chmod +x "$CONFIG_DIR"/hypr/script/*.sh 2>/dev/null || true
    fi

    # hypr/conf/local.conf.example -> hypr/conf/local.conf, only if it
    # doesn't already exist (never clobber a machine-specific config the
    # user has already customized on a previous run).
    local example="$REPO_DIR/hypr/conf/local.conf.example"
    local target="$CONFIG_DIR/hypr/conf/local.conf"
    if [ -f "$example" ]; then
        if [ -f "$target" ]; then
            info "$(t local_conf_exists)"
        elif cp "$example" "$target"; then
            ok "$(t local_conf_created)"
        else
            err "$(t local_conf_failed)"
            FAILURES+=("$(t fail_local_conf)")
        fi
    fi

    ok "$(t configs_copied)"

    if want_zsh; then
        if cp "$REPO_DIR/zsh/.zshrc" "$REPO_DIR/zsh/.p10k.zsh" "$REPO_DIR/zsh/.zsh_plugins.txt" "$HOME/"; then
            ok "$(t zsh_dotfiles_copied "$HOME")"
        else
            err "$(t zsh_dotfiles_failed)"
            FAILURES+=("$(t fail_zsh_dotfiles)")
        fi

        if pkg_installed zsh || sudo pacman -S --needed --noconfirm zsh; then
            PKG_STATUS[zsh]="ok"
        else
            PKG_STATUS[zsh]="failed"
            FAILURES+=("$(t fail_pkg_install zsh pacman)")
        fi

        local prev_shell
        prev_shell="$(basename "${SHELL:-unknown}")"
        read -rp "$(t chsh_prompt "$prev_shell")" reply
        case "$reply" in
            y|Y)
                if command -v zsh >/dev/null 2>&1 && chsh -s "$(command -v zsh)"; then
                    ok "$(t chsh_done)"
                else
                    err "$(t chsh_failed)"
                    FAILURES+=("$(t fail_chsh)")
                fi
                ;;
            *) info "$(t chsh_kept "$prev_shell")" ;;
        esac
    fi
}

# verify_configs — sanity-checks what actually landed on disk instead of
# just trusting that `cp` succeeding means everything is in place.
verify_configs() {
    step "$(t verifying_configs)"

    local m src_count dst_count
    for m in "${CONFIG_MODULES[@]}"; do
        src_count=$(find "$REPO_DIR/$m" -type f 2>/dev/null | wc -l)
        dst_count=$(find "$CONFIG_DIR/$m" -type f 2>/dev/null | wc -l)
        if [ "$src_count" -gt 0 ] && [ "$dst_count" -ge "$src_count" ]; then
            ok "$(t config_verified "$m" "$dst_count")"
        else
            err "$(t config_mismatch "$m" "$src_count" "$dst_count")"
            FAILURES+=("$(t fail_config_module "$m")")
        fi
    done

    local bad_scripts=0 f
    if [ -d "$CONFIG_DIR/hypr/script" ]; then
        for f in "$CONFIG_DIR"/hypr/script/*.sh; do
            [ -e "$f" ] || continue
            [ -x "$f" ] || { chmod +x "$f" 2>/dev/null; bad_scripts=$((bad_scripts + 1)); }
        done
    fi
    if [ "$bad_scripts" -eq 0 ]; then
        ok "$(t scripts_executable)"
    else
        warn "$(t scripts_not_executable "$bad_scripts")"
    fi
}

mkdir_wallpapers() {
    mkdir -p "$HOME/Pictures/Wallpapers"
}

# ---------------------------------------------------------------------------
# Final report — this is the "did it actually work" answer, independent of
# whatever scrolled by earlier.
# ---------------------------------------------------------------------------
print_final_report() {
    step "$(t report_title)"

    local pkg ok_count=0 skip_count=0 fail_count=0
    for pkg in "${!PKG_STATUS[@]}"; do
        case "${PKG_STATUS[$pkg]}" in
            ok) ok_count=$((ok_count + 1)) ;;
            skipped) skip_count=$((skip_count + 1)) ;;
            failed) fail_count=$((fail_count + 1)) ;;
        esac
    done

    printf "  %s%s:%s %d\n" "$C_GREEN" "$(t report_ok)" "$C_RESET" "$ok_count"
    printf "  %s%s:%s %d\n" "$C_YELLOW" "$(t report_skipped)" "$C_RESET" "$skip_count"
    printf "  %s%s:%s %d\n" "$C_RED" "$(t report_failed)" "$C_RESET" "$fail_count"

    if [ "${#FAILURES[@]}" -gt 0 ]; then
        printf "\n%s\n" "$(t report_failed_list)"
        local f
        for f in "${FAILURES[@]}"; do
            printf "    %s✗%s %s\n" "$C_RED" "$C_RESET" "$f"
        done
        printf "\n%s\n" "$(t report_log_hint "$LOG_FILE")"
    else
        ok "$(t report_all_good)"
    fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
    banner
    ask_language
    setup_logging
    require_not_root
    require_arch
    check_internet
    refresh_pacman_db
    handle_existing_configs
    install_all_deps
    install_optional_deps
    copy_configs
    verify_configs
    mkdir_wallpapers
    print_final_report

    step "$(t done_step)"
    ok "$(t all_done)"
    printf "\n%s\n" "$(t next_steps_title)"
    printf "  1. %s\n" "$(t next_step_1 "$C_BOLD" "$C_RESET")"
    printf "  2. %s\n" "$(t next_step_2 "$C_BOLD" "$C_RESET")"
    printf "  3. %s\n" "$(t next_step_3 "$C_BOLD" "$C_RESET")"
    printf "     %s\n\n" "$(t next_step_3b)"
}

main "$@"
