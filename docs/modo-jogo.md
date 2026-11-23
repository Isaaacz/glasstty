# Modo jogo

Botão 󰊴 no Control Centre (ou "Modo jogo" no launcher, ou `qs ipc call gamemode toggle`).
Com o modo ligado e um jogo rodando, a barra mostra FPS, CPU, GPU e temperatura ao lado da bateria.
Com o modo desligado, nada é lido.

## De onde vêm os números

Só o processo do jogo sabe o próprio FPS, então quem mede é o **MangoHud**.
O overlay dele é desenhado **totalmente transparente** (`alpha=0.0`, `background_alpha=0.0`), e ele grava
um CSV a cada 500 ms em `~/.var/app/com.valvesoftware.Steam/cache/mangohud/`.
`quickshell/scripts/gamestats.sh` lê o arquivo mais recente. Se o arquivo ficar 3 s sem receber dados, o jogo acabou.

Não use `no_display` para esconder o overlay: ele também para o log, e aí a barra nunca recebe números.
Para ver o overlay por cima do jogo, ponha `alpha=1.0` e `background_alpha=0.45` no template.

## Configuração (uma vez, Steam Flatpak)

Vale para todos os jogos **Vulkan**, sem opção de inicialização por jogo:

```bash
flatpak install --user flathub org.freedesktop.Platform.VulkanLayer.MangoHud//26.08
flatpak override --user com.valvesoftware.Steam \
  --filesystem=xdg-cache/wal:ro \
  --env=MANGOHUD=1 \
  --env=MANGOHUD_CONFIGFILE=$HOME/.cache/wal/colors-mangohud.conf
```

- `MANGOHUD=1` cobre os jogos Vulkan: a maioria dos jogos de Windows no Proton (DXVK/VKD3D) e os jogos Vulkan nativos.
- Jogos **OpenGL** precisam da opção de inicialização
  `/usr/lib/extensions/vulkan/MangoHud/bin/mangohud %command%`.
  **Não** coloque o `LD_PRELOAD` do shim como variável global no override: ele trava o
  `steam-runtime-launch-client` a 100% de CPU e nenhum jogo abre.
- A Steam e o `steamwebhelper` estão na lista de exceções embutida do MangoHud e não são afetados.
- A config vem do template do pywal `wal/templates/colors-mangohud.conf`, que acompanha as cores do wallpaper.

Troque `26.08` pelo branch do runtime da Steam: `flatpak info --user com.valvesoftware.Steam | grep Runtime`.
Reinicie a Steam depois de mudar o override.

Para desfazer: `flatpak override --user --reset com.valvesoftware.Steam`.
