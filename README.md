# aeonshell

<p align="center">
  <img src="./quickshell/assets/logo.png" alt="aeonshell logo" width="140">
</p>

A Wayland desktop for **Hyprland**, built with **Quickshell**. Change your
wallpaper and the whole UI — bar, control center, launcher, notifications,
even the lock screen — repaints itself to match, powered by **pywal**.

https://github.com/user-attachments/assets/5c14767b-d2c9-4ad7-b5de-51701005499c

---

## Features

- Top bar — workspaces, clock, tray, audio/network/bluetooth, media player
- Control center — wifi, bluetooth, audio, weather widget (Open-Meteo, no API key needed)
- App launcher with a built-in wallpaper picker — type `>wallpaper` to browse
  and apply wallpapers right from the launcher, no external app needed
- Notification center with popups (urgency styling, grouping, DND toggle)
- Screenshot tool + clipboard history, both on hotkeys
- Power menu — lock, exit Hyprland, suspend, reboot, power off
- Wallpaper changes → entire theme updates automatically via pywal
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

- `hypr/` — Hyprland config (compositor, keybinds, autostart)
- `quickshell/` — the shell itself (bar, popups, everything you see)
- `cava/` — cava (audio visualizer) config, shaders/themes, and the pywal
  template that recolors it
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

# cava.conf here is a pywal template, not the cava app config itself — it
# needs to live in wal's templates dir so `wal` regenerates cava's colors
# (~/.cache/wal/cava.conf) on every wallpaper change.
mkdir -p ~/.config/wal/templates
cp ~/.config/cava/cava.conf ~/.config/wal/templates/cava.conf

# Hyprland calls these scripts directly (exec/bind), so they need the
# executable bit.
chmod +x ~/.config/hypr/script/*.sh
```

### What to install

**Official repos:**

```bash
sudo pacman -S --needed \
  hyprland hyprlock xdg-desktop-portal-hyprland xdg-desktop-portal \
  qt6-wayland qt6ct qt6-5compat gtk3 kitty pcmanfm-qt xorg-xrandr \
  networkmanager network-manager-applet nm-connection-editor \
  bluez bluez-utils blueman \
  pipewire pipewire-pulse pipewire-alsa wireplumber pavucontrol \
  wl-clipboard cliphist grim slurp swappy \
  jq curl python zenity inotify-tools udiskie ffmpeg \
  fastfetch fzf yazi tty-clock cava
```

> `qt6-5compat` provides the `Qt5Compat.GraphicalEffects` QML module the shell
> uses for shadows/blur, and `gtk3` provides `gtk-launch`, which the app
> launcher uses to start apps. Neither is pulled in automatically by
> `quickshell-git`, so they need to be installed explicitly.

> `cava` won't recolor itself on its own — `colors_in_wallpaper.sh` (started
> automatically by Hyprland) watches `~/.cache/wal/colors` and rewrites
> `~/.config/cava/config` for you every time the wallpaper changes, as long
> as `cava.conf` was copied into wal's templates dir as shown above.

Want zsh as your shell? Install it separately — skip this if you'd rather
keep your current shell:

```bash
sudo pacman -S zsh
```

**AUR** (via `yay`/`paru`):

```bash
yay -S --needed \
  quickshell-git awww python-pywal \
  zen-browser-bin bibata-cursor-theme \
  otf-font-awesome ttf-jetbrains-mono-nerd zsh-antidote \
  kvantum gpu-screen-recorder-ui peazip mousepad \ mpvpaper
```

> `awww` is the wallpaper daemon the launcher's `>wallpaper` picker drives
> directly (plus `wal` from `python-pywal` for re-theming) — you don't need
> waypaper, swww, or any other separate wallpaper app.

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
2. Drop a few images into `~/Pictures/Wallpapers` — it's created
   automatically on first launch if it doesn't exist.
3. Open the **app launcher**, type `>` to enter command mode, then
   `wallpaper` to browse and apply one. This also generates your first
   pywal color theme — everything re-colors from here on automatically
   whenever you switch wallpapers.
4. Set your avatar and weather city from aeonshell's settings window
   (optional) — saved to `~/.config/quickshell/avatar.png` and
   `~/.config/quickshell/weather_city.conf` respectively.
5. Launch Hyprland — everything else starts on its own.
6. If you're using zsh as your shell: `chsh -s $(which zsh)`. Plugins
   install themselves on first launch.

Screen recording is handled by `gsr-ui` (starts automatically) rather than
a hotkey script — open it from its tray icon or app launcher entry.

### Shell settings

Bar position, tray/player visibility, notification grouping, and
edge-to-edge mode are all changeable from the settings window and save
automatically to `~/.config/hypr/conf/quickshell.lua` — it's fully
rewritten on every change, so there's no need to edit it by hand. If you
want future custom keybinds to live in the same file, source it once from
`hyprland.lua`:

```
source = ~/.config/hypr/conf/quickshell.lua
```

As with any setup, your default file manager, browser, and so on can be
set once near the top of `~/.config/hypr/conf/bind.lua`.

---

## License

MIT — see [LICENSE](./LICENSE).

---

---

# RU - aeonshell

Wayland-окружение для **Hyprland**, собранное на **Quickshell**.
Кратко: при смене обоев — вся оболочка перекрашивается вслед за ними: панель, центр
управления, лаунчер и тд., всё через **pywal**.

---

## Имеется:

- Верхняя панель — рабочие столы, часы, трей, аудио/сеть/bluetooth, медиаплеер
- Центр управления — wifi, bluetooth, звук, виджет погоды (Open-Meteo, без API-ключа)
- Лаунчер приложений со встроенным выбором обоев — ввод `>wallpaper`,
  чтобы посмотреть и применить обои прямо из лаунчера, без сторонних приложений
- Центр уведомлений с всплывающими попапами
- Инструмент скриншотов + история буфера обмена, оба по горячим клавишам
- Меню питания — блокировка, выход из Hyprland, сон, перезагрузка, выключение
- Смена обоев → вся тема обновляется автоматически через pywal
- Экран блокировки (Hyprlock)

---

## Места файлов конфигурации

- `hypr/` — конфиг Hyprland (компоситор, биндинги, автозапуск)
- `quickshell/` — сама оболочка (панель, попапы, всё, что видно на экране)
- `cava/` — конфиг cava (аудио-визуализатор), шейдеры/темы и шаблон pywal,
  которым она перекрашивается
- `fastfetch/`, `kitty/` — настройка терминала
- `zsh/` - опционально, можно оставить ваш шелл

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

# cava.conf здесь — это шаблон pywal, а не конфиг самой cava — его нужно
# положить в папку шаблонов wal, чтобы `wal` пересобирал цвета cava
# (~/.cache/wal/cava.conf) при каждой смене обоев.
mkdir -p ~/.config/wal/templates
cp ~/.config/cava/cava.conf ~/.config/wal/templates/cava.conf

# Hyprland вызывает эти скрипты напрямую (exec/bind), поэтому им нужен
# бит исполнения.
chmod +x ~/.config/hypr/script/*.sh
```

### Установка зависимостей

**Из официальных репозиториев:**

```bash
sudo pacman -S --needed \
  hyprland hyprlock xdg-desktop-portal-hyprland xdg-desktop-portal \
  qt6-wayland qt6ct qt6-5compat gtk3 kitty pcmanfm-qt xorg-xrandr \
  networkmanager network-manager-applet nm-connection-editor \
  bluez bluez-utils blueman \
  pipewire pipewire-pulse pipewire-alsa wireplumber pavucontrol \
  wl-clipboard cliphist grim slurp swappy \
  jq curl python zenity inotify-tools udiskie ffmpeg \
  fastfetch fzf yazi tty-clock cava
```

> `qt6-5compat` даёт QML-модуль `Qt5Compat.GraphicalEffects`, которым оболочка
> рисует тени/блюр, а `gtk3` даёт `gtk-launch`, через который лаунчер
> запускает приложения. Ни то, ни другое `quickshell-git` не тянет
> автоматически, так что их нужно ставить отдельно.

> Сама по себе `cava` не перекрашивается — скрипт `colors_in_wallpaper.sh`
> (стартует автоматически вместе с Hyprland) следит за
> `~/.cache/wal/colors` и переписывает `~/.config/cava/config` при каждой
> смене обоев, но только если `cava.conf` был скопирован в папку шаблонов
> wal, как показано выше.

Установка zsh, если не нужен - пропустите

```bash
sudo pacman -S zsh
```

**Из AUR** (через `yay`/`paru`):

```bash
yay -S --needed \
  quickshell-git awww python-pywal \
  zen-browser-bin bibata-cursor-theme \
  otf-font-awesome ttf-jetbrains-mono-nerd zsh-antidote \
  kvantum gpu-screen-recorder-ui peazip mousepad \ mpvpaper
```

> `awww` (он же swww, теперь awww) — демон обоев, которым лаунчер напрямую управляет через `>wallpaper`

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
2. Скинь несколько изображений в `~/Pictures/Wallpapers` — при первом
   запуске папка создаётся автоматически, если её нет.
3. Открой **лаунчер приложений**, набери `>`, чтобы войти в командный
   режим, затем `wallpaper` — выбери и примени обои. Заодно
   сгенерируется первая цветовая тема pywal — дальше всё перекрашивается
   само при каждой смене обоев.
4. Задай аватар и город для погоды в окне настроек aeonshell (по желанию)
   (сохраняются в `~/.config/quickshell/avatar.png` и `~/.config/quickshell/weather_city.conf` соответственно).
5. Запусти Hyprland — всё остальное стартует само.
6. При выборе zsh шеллом по умолчанию, сделай: `chsh -s $(which zsh)`. Плагины
   ставятся сами при первом запуске.

Запись экрана делает `gsr-ui` (стартует автоматически)
открывай его из иконки в трее или из лаунчера приложений (так же в нём имеются встроенные горячие клавиши).

### Настройки шелла

Положение панели, видимость трея/плеера, группировка уведомлений и
режим edge-to-edge меняются прямо из окна настроек и сохраняются
автоматически в `~/.config/hypr/conf/quickshell.lua` — файл полностью
перезаписывается при каждом изменении, редактировать его руками НЕ
нужно. Этот файл уже прописан в `hyprland.lua`:

```
source = ~/.config/hypr/conf/quickshell.lua
```

Как и в обычных сборках, настроить по-умолчанию файловый менеджер, браузер и прочее
можно один раз в `~/.config/hypr/conf/bind.lua` в самом начале.

---

## Лицензия

MIT — см. [LICENSE](./LICENSE).
