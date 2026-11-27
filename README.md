# aeonshell

<p align="center">
  <img src="./quickshell/assets/logo.png" alt="aeonshell logo" width="140">
</p>

A Wayland desktop for **Hyprland**, built with **Quickshell**. Change your
wallpaper and the whole UI — bar, control center, launcher, notifications,
kitty, and cava — repaints itself to match, powered by **matugen** with a
built-in native **ColorQuantizer** fallback.

https://github.com/user-attachments/assets/5c14767b-d2c9-4ad7-b5de-51701005499c

---

## Features

- Top bar — workspaces, clock, tray, media player, notifications, settings, power
- Control center — native Wi-Fi (`Quickshell.Networking`), Bluetooth (`Quickshell.Bluetooth`), PipeWire audio (`Quickshell.Services.Pipewire`), weather widget (Open-Meteo, no API key needed)
- App launcher with a built-in wallpaper picker — type `>wallpaper` to browse
  and apply static (`awww`) or animated (`mpvpaper`) wallpapers right from the launcher
- Notification center with popups (urgency styling, grouping, DND toggle)
- Screenshot tool (`grim` + `slurp` + `swappy`) + clipboard history (`cliphist`), both on hotkeys
- Power menu — lock, exit Hyprland, suspend, reboot, power off
- Wallpaper changes → theme updates automatically via `matugen` (or built-in `ColorQuantizer` if `matugen` isn't installed), recoloring Quickshell, kitty, and cava natively without touching Hyprland config files or background watcher scripts
- Matching lock screen (Hyprlock)

| Desktop                               | Control center                                      |
| ------------------------------------- | --------------------------------------------------- |
| ![desktop](./screenshots/desktop.png) | ![Control center](./screenshots/control-center.png) |

| Launcher                                | Notifications                                     |
| --------------------------------------- | ------------------------------------------------- |
| ![Launcher](./screenshots/launcher.png) | ![Notifications](./screenshots/notifications.png) |

![Hyprlock](./screenshots/hyprlock.png)

---

## What's where

- `hypr/` — Hyprland Lua config (compositor, keybinds, autostart, wallpaper restore)
- `quickshell/` — the autonomous shell UI & system integrations (bar, popups, theming, native Qt/Quickshell APIs)
- `cava/` — cava (audio visualizer) config and shaders/themes (automatically recolored by `Colors.qml` on wallpaper change)
- `fastfetch/`, `kitty/` — terminal setup (banner, terminal)
- `zsh/` — optional, feel free to keep your own shell instead

---

## Install

```bash
git clone https://github.com/pzwt4cc/aeonshell
cd aeonshell

mkdir -p ~/.config/{hypr,quickshell,fastfetch,kitty,cava}
cp -r hypr/. ~/.config/hypr/
cp -r quickshell/. ~/.config/quickshell/
cp -r fastfetch/. ~/.config/fastfetch/
cp -r kitty/. ~/.config/kitty/
cp -r cava/. ~/.config/cava/
cp hypr/conf/local.lua ~/.config/hypr/conf/local.lua
cp zsh/.zshrc zsh/.p10k.zsh zsh/.zsh_plugins.txt ~/

# Hyprland calls restore-wallpaper.sh on startup, so it needs the executable bit.
chmod +x ~/.config/hypr/script/*.sh
```

### What to install

**Official repos:**

```bash
sudo pacman -S --needed \
  hyprland hyprlock xdg-desktop-portal-hyprland xdg-desktop-portal \
  qt6-wayland qt6ct kitty pcmanfm-qt \
  networkmanager nm-connection-editor \
  bluez bluez-utils \
  pipewire pipewire-pulse pipewire-alsa wireplumber \
  wl-clipboard cliphist grim slurp swappy \
  udiskie ffmpeg \
  fastfetch fzf yazi tty-clock cava
```

> Network, Bluetooth, audio sliders/routing, weather (HTTP), file/text dialogs,
> system info (`/proc`), and Hyprland window/IPC events are handled natively
> inside Quickshell (`Quickshell.Networking`, `Quickshell.Bluetooth`,
> `Quickshell.Services.Pipewire`, `Quickshell.Hyprland`, `QtQuick.Effects`) —
> no `qt6-5compat`, `gtk3`, `pywal`, `jq`, `curl`, `python`, `socat`, or
> `inotify-tools` needed.

Want zsh as your shell? Install it separately — skip this if you'd rather
keep your current shell:

```bash
sudo pacman -S zsh
```

**AUR** (via `yay`/`paru`):

```bash
yay -S --needed \
  quickshell-git awww mpvpaper matugen-bin \
  zen-browser-bin bibata-cursor-theme \
  otf-font-awesome ttf-jetbrains-mono-nerd zsh-antidote \
  kvantum gpu-screen-recorder-ui peazip mousepad
```

> `awww` handles static wallpapers and `mpvpaper` handles video wallpapers from
> `>wallpaper`. `matugen-bin` is recommended for Material You color extraction;
> if absent, Quickshell automatically falls back to its built-in `ColorQuantizer`.

Optional, install only if you use them:

```bash
sudo pacman -S openrgb
```

```bash
yay -S codium zed thunderbird localsend
```

---

## Set up

1. Edit `~/.config/hypr/conf/local.lua` for your machine (monitors, GPU,
   autostart entries — comments inside explain each part).
2. Drop a few images or videos into `~/Pictures/Wallpapers` — it's created
   automatically on first launch if it doesn't exist.
3. Open the **app launcher**, type `>` to enter command mode, then
   `wallpaper` to browse and apply one. Quickshell generates the color palette
   directly and updates `~/.cache/aeonshell/colors.json`, kitty, and cava
   automatically.
4. Set your avatar and weather city from aeonshell's settings window
   (optional) — saved to `~/.config/quickshell/avatar.png` and
   `~/.config/quickshell/weather_city.conf` respectively.
5. Launch Hyprland — everything else starts on its own.
6. If you're using zsh as your shell: `chsh -s $(which zsh)`. Plugins
   install themselves on first launch.

Screen recording is handled by `gsr-ui` (starts automatically) rather than
a hotkey script — open it from its tray icon or app launcher entry.

### Shell settings

Bar position, tray/player visibility, notification grouping, wallpaper
directory, and edge-to-edge mode are all changeable from the settings window
and persist autonomously via `QtCore.Settings` in
`~/.config/quickshell/settings.conf` — completely separate from your Hyprland
config directory.

As with any setup, your default file manager, browser, and so on can be
set once near the top of `~/.config/hypr/conf/bind.lua`.

---

## License

MIT — see [LICENSE](./LICENSE).

---

---

# RU - aeonshell

Wayland-окружение для **Hyprland**, собранное на **Quickshell**.
При смене обоев вся оболочка перекрашивается вслед за ними: панель, центр
управления, лаунчер, уведомления, kitty и cava — через **matugen** со
встроенным нативным fallback на **ColorQuantizer**.

---

## Имеется:

- Верхняя панель — рабочие столы, часы, трей, медиаплеер, уведомления, настройки, питание
- Центр управления — нативный Wi-Fi (`Quickshell.Networking`), Bluetooth (`Quickshell.Bluetooth`), звук через PipeWire (`Quickshell.Services.Pipewire`), виджет погоды (Open-Meteo, без API-ключа)
- Лаунчер приложений со встроенным выбором обоев — ввод `>wallpaper`,
  чтобы посмотреть и применить статичные (`awww`) или видео-обои (`mpvpaper`) прямо из лаунчера
- Центр уведомлений с всплывающими попапами (группировка, DND)
- Инструмент скриншотов (`grim` + `slurp` + `swappy`) + история буфера обмена (`cliphist`), оба по горячим клавишам
- Меню питания — блокировка, выход из Hyprland, сон, перезагрузка, выключение
- Смена обоев → палитра генерируется через `matugen` (или встроенным `ColorQuantizer`, если `matugen` не установлен), обновляя Quickshell, kitty и cava напрямую без записи в конфиги Hyprland и без фоновых watcher-скриптов
- Экран блокировки (Hyprlock)

---

## Места файлов конфигурации

- `hypr/` — Lua-конфиг Hyprland (композитор, биндинги, автозапуск, восстановление обоев)
- `quickshell/` — сама оболочка (панель, попапы, системные интеграции и автотемизация)
- `cava/` — конфиг cava (аудио-визуализатор) и шейдеры/темы (цвета обновляются напрямую из `Colors.qml`)
- `fastfetch/`, `kitty/` — настройка терминала
- `zsh/` — опционально, можно оставить ваш шелл

---

## Установка

```bash
git clone https://github.com/pzwt4cc/aeonshell
cd aeonshell

mkdir -p ~/.config/{hypr,quickshell,fastfetch,kitty,cava}
cp -r hypr/. ~/.config/hypr/
cp -r quickshell/. ~/.config/quickshell/
cp -r fastfetch/. ~/.config/fastfetch/
cp -r kitty/. ~/.config/kitty/
cp -r cava/. ~/.config/cava/
cp hypr/conf/local.lua ~/.config/hypr/conf/local.lua
cp zsh/.zshrc zsh/.p10k.zsh zsh/.zsh_plugins.txt ~/

# Hyprland запускает restore-wallpaper.sh при старте, поэтому нужен бит исполнения.
chmod +x ~/.config/hypr/script/*.sh
```

### Установка зависимостей

**Из официальных репозиториев:**

```bash
sudo pacman -S --needed \
  hyprland hyprlock xdg-desktop-portal-hyprland xdg-desktop-portal \
  qt6-wayland qt6ct kitty pcmanfm-qt \
  networkmanager nm-connection-editor \
  bluez bluez-utils \
  pipewire pipewire-pulse pipewire-alsa wireplumber \
  wl-clipboard cliphist grim slurp swappy \
  udiskie ffmpeg \
  fastfetch fzf yazi tty-clock cava
```

> Сеть, Bluetooth, громкость, погода (HTTP), выбор файлов и ввод текста,
> системные метрики (`/proc`) и события Hyprland работают нативно внутри
> Quickshell (`Quickshell.Networking`, `Quickshell.Bluetooth`,
> `Quickshell.Services.Pipewire`, `Quickshell.Hyprland`, `QtQuick.Effects`) —
> зависимости вроде `qt6-5compat`, `gtk3`, `pywal`, `jq`, `curl`, `python`,
> `socat` и `inotify-tools` больше не требуются.

Установка zsh, если не нужен — пропустите:

```bash
sudo pacman -S zsh
```

**Из AUR** (через `yay`/`paru`):

```bash
yay -S --needed \
  quickshell-git awww mpvpaper matugen-bin \
  zen-browser-bin bibata-cursor-theme \
  otf-font-awesome ttf-jetbrains-mono-nerd zsh-antidote \
  kvantum gpu-screen-recorder-ui peazip mousepad
```

> `awww` отвечает за статичные обои, а `mpvpaper` — за видео-обои в `>wallpaper`.
> `matugen-bin` рекомендуется для генерации палитры Material You; если он не
> установлен, оболочка автоматически использует встроенный `ColorQuantizer`.

Опционально:

```bash
sudo pacman -S openrgb
```

```bash
yay -S codium zed thunderbird localsend
```

---

## Настройка

1. Отредактируй `~/.config/hypr/conf/local.lua` под себя (мониторы, GPU,
   автозапуск — внутри есть комментарии и примеры к каждой части).
2. Скинь несколько изображений или видео в `~/Pictures/Wallpapers` — при первом
   запуске папка создаётся автоматически, если её нет.
3. Открой **лаунчер приложений**, набери `>`, чтобы войти в командный
   режим, затем `wallpaper` — выбери и примени обои. Quickshell сам сгенерирует
   палитру и обновит цвета оболочки, kitty и cava.
4. Задай аватар и город для погоды в окне настроек aeonshell (по желанию)
   (сохраняются в `~/.config/quickshell/avatar.png` и `~/.config/quickshell/weather_city.conf` соответственно).
5. Запусти Hyprland — всё остальное стартует само.
6. При выборе zsh шеллом по умолчанию сделай: `chsh -s $(which zsh)`. Плагины
   ставятся сами при первом запуске.

Запись экрана делает `gsr-ui` (стартует автоматически):
открывай его из иконки в трее или из лаунчера приложений (также в нём имеются встроенные горячие клавиши).

### Настройки шелла

Положение панели, видимость трея/плеера, группировка уведомлений, папка обоев
и режим edge-to-edge меняются прямо из окна настроек и сохраняются автономно
через `QtCore.Settings` в `~/.config/quickshell/settings.conf` — без записи
каких-либо файлов в директорию конфигурации Hyprland.

Как и в обычных сборках, настроить по умолчанию файловый менеджер, браузер и прочее
можно один раз в `~/.config/hypr/conf/bind.lua` в самом начале.

---

## Лицензия

MIT — см. [LICENSE](./LICENSE).
