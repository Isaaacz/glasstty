# glasstty: detalhes técnicos

Um rice para o **niri**.

## Instalar

(Resumo no [README](../README.md). Abaixo, o detalhe de cada parte.)

```bash
./install-niri.sh
```

O script habilita o COPR do Quickshell, instala `packages/fedora-niri.txt` com `dnf` (pede o sudo uma vez) e o pywal com `pipx`, linka `~/.config/quickshell`, `~/.config/niri/config.kdl`, `~/.config/glasstty`, `~/.config/kitty` e `~/.config/fastfetch` para este repo (arquivos seus viram `*.bak-<data>`) e copia os wallpapers para `~/Pictures/wallpapers`. Nada seu é apagado ou sobrescrito: um arquivo, pasta ou link no caminho vira `*.bak-<data>` (links seus também, com o destino anotado no resumo), e o que você já tem (templates, atalhos de app, comandos) fica como está. No fim aparece um resumo do que foi instalado, movido e mantido; se algo falhar, ele diz onde, e rodar de novo é seguro. Num terminal ele pergunta quais partes opcionais incluir, sugerindo o que combina com a máquina: **fonts** (Symbols Nerd Font), **wallpapers**, **spotify** (sugerido se o Spotify estiver instalado), **vscode** (sugerido se o VS Code estiver instalado) e **sddm** (o login com o thyx: desligado a menos que você peça, e só instala — trocar o GDM pelo SDDM continua sendo com `./sddm-thyx.sh ativar`). Depois do dnf ele confere se os programas realmente foram instalados, e guarda um log em `~/.cache/glasstty/`. `--dry-run` mostra os passos sem mudar nada; `--yes` aceita as sugestões sem perguntar; `--minimal` instala só o núcleo; `--with spotify,sddm` e `--without wallpapers` escolhem direto; `--no-packages` pula o dnf/pipx. `./uninstall-niri.sh` remove só o que é do glasstty (links para o repo, cópias ainda idênticas e arquivos gerados pelo shell, reconhecidos pela marca deles) e devolve os backups; uma cópia que você editou fica. Para entrar, saia da sessão e escolha **niri** na tela de login.

Nada é habilitado como serviço `systemd --user`. O GNOME também chega ao `graphical-session.target` e subiria a barra dentro dele. Tudo que é autostart sai do `config.kdl`, que só o niri lê.

## De onde veio cada peça

| Peça | Hyprland (original) | niri |
|---|---|---|
| Estado do compositor | `Quickshell.Hyprland` | `Compositor.qml`: `niri msg --json event-stream` + socket JSON |
| Ações (`dispatch`) | `hl.dsp.*` em Lua | `Compositor.focusWorkspace/closeWindow/...` → `{"Action":…}` |
| "Clique fora fecha" | `HyprlandFocusGrab` | `FocusGrab.qml`: camada transparente (Top) atrás do painel |
| Atalhos do shell | `GlobalShortcut` (protocolo do Hyprland) | `qs ipc call notch …` no `config.kdl` |
| Stage Manager | painel lateral próprio | Overview nativo do niri (`Super+Shift+Tab`) |
| Luz noturna | hyprsunset | wlsunset |
| Portal | xdg-desktop-portal-hyprland | xdg-desktop-portal-gnome (padrão do niri) |
| Monitores | `hyprctl eval hl.monitor` | `niri msg output NOME …` (`scripts/monitors.py`) |
| Cores das bordas | `colors-hyprland.lua` | `~/.cache/wal/colors-niri.kdl` (template do pywal, include) |
| Arredondamento | `efectos.lua` | `~/.config/niri/efeitos.kdl` (include) |

`Compositor.qml` fala só com o niri: ele monta objetos no mesmo formato dos do Hyprland, de onde o shell veio (`address`, `workspace.id`, `lastIpcObject.at/size`, `wayland`), por isso o resto do QML mudou pouco. O `id` de área de trabalho exposto é o `idx` do niri (1..N por monitor). O suporte ao Hyprland foi tirado; a tabela acima mostra o que cada peça virou no niri.

Para depurar: `qs ipc call compositor state` mostra o que o shell está vendo.

A página **Ajustes > Atalhos** (`Super+K`) lê o bloco `binds` do `config.kdl` ao vivo. A descrição de cada atalho vem do `hotkey-overlay-title`, quando existe, ou de uma tabela de ações em `SettingsShortcuts.qml`.

## Atalhos principais

`Super+D` central de controle · `Ctrl+Space` launcher · `Super+,` ajustes · `Super+K` todos os atalhos · `Super+Tab` mapa de áreas · `Super+Shift+Tab` overview do niri · `Super+T` kitty · `Super+E` arquivos · `Super+W` wallpapers · `Super+C` fecha a janela · `Super+V` flutuante · `Super+F` / `Super+Shift+F` maximiza até as bordas / tela cheia · `Super+J` largura da coluna · `Super+Shift+setas` muda a janela de lugar · `Super+Alt+←/→` empilha ou separa janelas · `Super+1..0` áreas de trabalho · `Super+L` bloqueia · `Super+Shift+E` tela de saída · `Super+Shift+S` / `Print` captura de tela · `Super+Shift+/` lista de atalhos do niri.

A lista completa e sempre atual é a de **Ajustes > Atalhos** (`Super+K`), lida do `config.kdl`; esta e a do README são resumos.

## Rices: salvar e trocar visuais

`rice salvar NOME`, `rice usar NOME`, `rice listar` e `rice atual` (em `~/.local/bin/rice`). Cada rice é uma branch deste repositório: o rice `main` é a branch principal, e os outros são `rice/NOME`. Como o shell, o niri, o kitty e os scripts são links para cá, trocar de branch troca o visual inteiro. O que fica fora do repositório (wallpaper, tema e sincronização do login, templates do pywal) é guardado em `rice/estado/` ao salvar e devolvido ao usar. Antes de trocar, as mudanças pendentes são salvas no rice em uso, então nada se perde. Para começar um rice novo, mude o visual e rode `rice salvar outro-nome`: ele parte do estado atual.

As configurações do shell (`~/.config/quickshell-rice.json`, um link para o repositório) trocam junto com o rice. Monitores, favoritos, idioma e energia são pessoais e passam de um rice para o outro sem mudar.

A Central de Controle tem uma página **Rices** (ícone de pincel, ou `qs ipc call notch controlPage 4`). Nela, você vê os rices salvos, troca com **Usar**, salva as mudanças do atual e cria um rice novo pelo nome. Do lado direito ficam as escolhas que cada rice guarda além dos arquivos:
- **Ícones:** o tema de ícones da sessão niri. "Do GNOME" segue o do GNOME.
- **Pastas na cor do tema:** liga ou desliga as pastas coloridas.
- **Tela de login:** Pocket ou o layout próprio do thyx.

Ao trocar de rice, os ícones são gerados de novo e o layout do login é aplicado. Os ícones valem para as janelas abertas depois, e o login vale no próximo login.

## Spotify (Catppuccin nas cores do wallpaper)

O Spotify usa o tema [Catppuccin para spicetify](https://github.com/catppuccin/spicetify) (MIT, copiado em `home/.config/spicetify/Themes/catppuccin`, com a licença e o commit de origem em `UPSTREAM`). As cores vêm de um esquema `pywal` que o `spicetify-catppuccin.py` gera a cada troca de wallpaper: as camadas (base, barra lateral, player, cartões) saem do fundo do pywal, e os tons pastel, das cores da paleta. O `spicetify-pywal.sh` escolhe o gerador pelo tema em uso (`catppuccin` ou o `termspot` original) e manda as cores para o Spotify aberto pela porta de depuração 9333, sem reiniciar.

O spicetify precisa poder alterar os arquivos do Spotify, então o Spotify é o Flatpak instalado só para o usuário (`flatpak install --user flathub com.spotify.Client`); o login fica em `~/.var/app`, igual ao do Flatpak do sistema. O `~/.local/bin/spotify` abre essa instalação, e o `com.spotify.Client.desktop` deste repo acrescenta a porta. Para configurar do zero, com o spicetify em `~/.spicetify`:

```bash
spicetify config spotify_path ~/.local/share/flatpak/app/com.spotify.Client/x86_64/stable/active/files/extra/share/spotify prefs_path ~/.var/app/com.spotify.Client/config/spotify/prefs
~/.config/glasstty/scripts/spicetify-catppuccin.py   # gera o color.ini (fora do git) a partir do color.base.ini
spicetify config current_theme catppuccin color_scheme pywal inject_css 1 inject_theme_js 1 replace_colors 1 overwrite_assets 1
spicetify backup apply
```

Depois de cada atualização do Spotify, rode `spicetify backup apply` de novo. Em Configurações do Spotify, a seção Catppuccin permite escolher outro tom de destaque da paleta.

## VS Code nas cores do wallpaper

O `vscode-pywal.py` escreve, a cada troca de wallpaper, duas chaves do `~/.config/Code/User/settings.json`: `workbench.colorCustomizations` (interface) e `editor.tokenColorCustomizations` (sintaxe). O VS Code aplica mudanças de configuração ao vivo, então a janela aberta muda junto. As camadas seguem as do Spotify: o editor é a base, a barra lateral e os painéis ficam um tom abaixo, e as barras de atividade, título e status são as mais escuras. O terminal usa as 16 cores do pywal, como o kitty.

O resto do `settings.json` não é alterado. Se ele tiver comentários (JSONC), ou se você já tiver cores personalizadas nessas duas chaves, o script não mexe. A cópia de antes da primeira escrita fica em `~/.cache/pocket-dots/vscode-settings.antes.json`. Para voltar ao tema normal: `~/.config/glasstty/scripts/vscode-pywal.py --off`. As configurações do VS Code são as mesmas no GNOME, então as cores valem lá também.

## Notificações em português

Os scripts traduzem as notificações pelo `lang.sh`: com o idioma do shell em `pt` (`quickshell-rice.json`), o texto em espanhol é procurado em `scripts/lang-pt.tsv`. Um texto que não estiver na tabela fica em espanhol. As notificações que o niri manda em inglês (captura de tela da ação própria do niri) aparecem traduzidas na barra e na Central, pela tabela `notifPt` do `ShellState.qml`.

## Convivência com o GNOME

O rice original troca o tema GTK e os ícones com `gsettings` a cada papel de parede. Aqui o dconf é compartilhado com o GNOME, então isso trocaria o tema dele também. Neste fork, o `gtk-pywal.sh` nunca grava no dconf; só gera o tema pywal e o link `~/.local/share/themes/pywal-gtk` (para voltar ao comportamento original, use `POCKET_GTK_GLOBAL=1`).

No niri, os apps GTK (Arquivos, Configurações…) usam as cores do wallpaper: o `config.kdl` define `GTK_THEME=pywal-gtk` só nessa sessão. As janelas abertas mudam junto com o wallpaper. Para o tema, o `gtk-pywal.sh` troca por um instante o `gtk-theme` do dconf para Adwaita e o devolve ao valor original, só como sinal para o GTK recarregar o tema do disco; como o niri fixa o tema com `GTK_THEME`, o valor em si não é usado, e o do GNOME termina igual. Para os ícones das pastas, ele regrava os favoritos do GTK com o mesmo conteúdo, o que faz o GTK recarregar o tema de ícones. Os ícones são os do GNOME (Tela-black-dark), mas as pastas seguem a cor de destaque do wallpaper. O `folders-pywal.py` gera o tema `pywal-folders-<hash>`, que herda o Tela-black-dark e só troca as pastas, e o `gtk-pywal.sh` mantém o link `~/.local/share/icons/pywal-icons` apontando para ele.

O tema de ícones é uma chave do dconf compartilhado com o GNOME, então ela não é alterada. Ao subir, o `niri.service` roda o `dconf-niri.sh`, que monta um perfil do dconf (`~/.config/pocket-dots/dconf/`). Esse perfil lê o banco normal do usuário e, por cima, um banco só de leitura com uma única chave travada: `icon-theme='pywal-icons'`. O `DCONF_PROFILE` aponta para esse perfil só no niri e nos portais de Settings (drop-ins `pocket-niri.conf` do `xdg-desktop-portal-gnome` e do `-gtk`), porque no Fedora 45 os apps GTK4 leem as configurações pelo portal. Ao sair do niri, o arquivo de ambiente é apagado e os portais reiniciam, então no GNOME nada muda. Todas as outras configurações continuam compartilhadas. Nesta sessão, o tema de ícones não pode ser trocado pelo Configurações. Os apps Qt seguem pelo plugin `gtk3` do Qt (`QT_QPA_PLATFORMTHEME=gtk3`). Para usar o tema do GNOME (Orchis-Dark-Compact) também no niri, comente a linha `GTK_THEME` no `config.kdl`.

O `gnome-control-center` se recusa a abrir fora do GNOME. O `~/.local/share/applications/org.gnome.Settings.desktop` deste repo o abre com `XDG_CURRENT_DESKTOP=GNOME`. O que você muda lá vale também para o GNOME, porque as configurações são as mesmas. Telas e Multitarefas não funcionam no niri; para monitores, use Ajustes > Telas do shell.

## Senhas (chaveiro)

O Fedora 45 guarda as senhas no oo7. No login, o GDM desbloqueia o chaveiro, mas quem sobe o `oo7-daemon` é a sessão GNOME. Sem ele, no niri o primeiro app que pedia senhas (o Brave) acordava o gnome-keyring antigo, que oferecia criar um chaveiro novo. O drop-in `~/.config/systemd/user/niri.service.d/oo7.conf` faz o niri subir o oo7 junto com ele.

## Login e tela de bloqueio (thyx)

O login pode usar o tema [thyx](https://github.com/rccyx/thyx) (MIT), que é para o SDDM. O `sddm-thyx.sh` faz a troca em duas fases: `instalar [tema]` instala o SDDM, o greeter Wayland e o tema, sem trocar o login. Depois, `ativar` acrescenta o oo7 ao PAM do SDDM (as mesmas linhas do GDM) e troca GDM → SDDM, valendo no próximo boot. `voltar` retorna ao GDM, e `tema NOME` troca entre blush, gilded, malachite e sakura. `sincronizar` faz login e bloqueio seguirem o wallpaper: a cada troca, o `login-pywal.sh` grava uma cópia bem borrada do wallpaper na pasta do tema e junta as cores do pywal (template `thyx-colors.conf`) ao layout do preset escolhido. Funciona sem sudo, porque a pasta do tema instalada pertence ao usuário. `tema NOME` desliga a sincronização. `ajustar` (também chamado pelo `ativar`) liga o toque para clicar e o teclado `br` no weston que roda o greeter, e troca o texto "Environment" do seletor de sessão por "Sessão". O cinder é um vídeo H.264 que o FFmpeg do Fedora não decodifica.

A tela de bloqueio é do próprio shell (`LockScreen.qml`). Ela lê o mesmo `theme.conf` do thyx, então login e bloqueio ficam iguais. A senha passa pelo PAM do swaylock. O `scripts/lock.sh` espera o niri confirmar o bloqueio e, se o shell falhar, cai no swaylock. Enquanto a tela está bloqueada, o shell não recarrega arquivos. Se a tela ficar travada sem campo de senha: `Ctrl+Alt+F3`, faça login e rode `pkill -x qs; niri msg action spawn -- qs` (com `NIRI_SOCKET` da sessão) ou reinicie.

## Créditos e licença

O glasstty começou como um porte do [pocket-dots](https://github.com/diegoMalagrida/pocket-dots), de Diego Malagrida, para o niri. Boa parte do shell (Quickshell) e dos scripts vem de lá, por isso o projeto segue sob a mesma licença, GPL-3.0 (`LICENSE`). O tema do Spotify é o [Catppuccin para spicetify](https://github.com/catppuccin/spicetify) (MIT) e a tela de login usa o [thyx](https://github.com/rccyx/thyx) (MIT).
