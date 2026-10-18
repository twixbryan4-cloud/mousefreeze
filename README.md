# Huss Valley Panel

Primeira versão do painel em Luau, inspirada no vídeo de referência. O catálogo e a categoria de facas não fazem parte deste projeto. O rodapé do vídeo mostra “Chicken or Hero”; o vídeo, sozinho, não revela os eventos, argumentos ou estrutura interna usados pelas automações.

## Executar

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/twixbryan4-cloud/mousefreeze/main/main.lua"))()
```

O arquivo é independente e não baixa bibliotecas de interface. A compatibilidade com a versão instalada do Delta precisa ser verificada dentro do Roblox.

## Interface e recursos implementados

- Boas-vindas com avatar, painel escuro, destaque coral, barra de ícones, duas colunas, opções expansíveis e transição leve de texto.
- Categorias: Combat, AI, ESP, World, Automation, Performance, Emotes e Config.
- Ajuste à tela, arrastar pela parte superior, botão flutuante, minimizar e alternar pela tecla Right Shift. A tecla pode ser alterada em Config.
- Velocidade local, fly com controles verticais por toque, noclip, deslocamento adicional, salto no ar, spin, primeira pessoa, FOV, mouse livre, iluminação e X-Ray locais.
- Player Lock On com raio, previsão, suavização e filtro de time opcional. Mira em jogadores vivos; não presume papéis internos nem executa uma captura específica do jogo.
- ESP de jogadores: caixas, nomes, linhas, vida, distância, articulações, ponto na cabeça, direção de visão, cores por time e Highlight. Inclui preview estático do próprio avatar.
- Auto Attack e Auto Use Gears ativam a ferramenta equipada. Auto Revive e Auto Pick somente acionam ProximityPrompts reconhecidos, próximos e habilitados, quando o executor oferece `fireproximityprompt`. Auto Revive não implementa reviver a si mesmo por um evento desconhecido.
- Redução de texturas, efeitos, materiais, sombras e neblina; restauração dos valores anteriores; limite de FPS somente quando o executor oferece `setfpscap`. Restaurar o limite anterior depende de `getfpscap`.
- Anti-Idle por evento do cliente e reconexão ao servidor. O sistema AFK próprio do jogo é separado.
- Lista dos emotes já equipados no avatar; salvar, carregar e excluir configurações. Sem acesso a arquivos, as configurações duram apenas na sessão do executor.

Alterações no cliente podem ser corrigidas pelo servidor. Estes recursos não equivalem a contornar a validação do jogo.

## Integrações ainda pendentes

Auto Dash, Auto Zone, Auto Down, Auto Tackle, Dash Cooldown, Auto Ability, Runner AI, Catcher AI, Auto Spin Wheel, Auto Claim Journey, Auto Map Vote, Disable Anti-AFK do jogo, Hit Box, Leaderboard Visuals e Gems & Coins precisam de mapeamento específico do Huss Valley. Seus controles recusam ativação enquanto não houver um adaptador correspondente. Nenhum evento ou argumento foi inventado a partir do vídeo.

Para a próxima etapa, execute o painel no jogo e use **Config > Suite > Copiar diagnóstico**. O texto contém caminhos/classes de eventos, prompts e alguns atributos de equipe/estado publicados pelo jogo. Ele fica na área de transferência ou em um campo de texto; não é enviado automaticamente. Esse levantamento identifica a estrutura, mas argumentos e comportamento dos eventos ainda precisam ser confirmados antes da integração.

O ponto de integração é `getgenv().HussValleyPanel.RegisterAction(nome, callback)`. Os nomes esperados constam em `requiresAdapter` no código. O callback recebe `Enabled`, `Player` e `Config`; durante a execução recebe também `Character`, `Delta` e `IsActive()`. Adaptadores que cedem a execução devem conferir `IsActive()` antes de continuar. A desativação e o encerramento chamam o callback com `Enabled = false`.

## Validação e ciclo de vida

Foram verificados a sintaxe e os fluxos de controles usando APIs simuladas: construção das oito categorias, navegação, expansão, toque, validação de valores, bloqueio de recursos sem integração, movimento, colisão, câmera, ESP, configurações, restauração, encerramento e reexecução. Isso não substitui o teste no Roblox/Delta; não há uma sessão desse jogo disponível neste ambiente.

As opções começam desligadas. O ESP possui frequência e distância configuráveis. Varreduras do cenário são feitas por lote ao ativar recursos ou solicitar o diagnóstico. Fechar pelo X ou por Destroy Menu desconecta os eventos, remove objetos locais e tenta restaurar as propriedades alteradas. Executar novamente substitui a instância anterior.

## Referências das APIs do motor

- [LinearVelocity](https://create.roblox.com/docs/reference/engine/classes/LinearVelocity)
- [Highlight](https://create.roblox.com/docs/reference/engine/classes/Highlight)
- [Humanoid](https://create.roblox.com/docs/reference/engine/classes/Humanoid)
- [Animação de interface](https://create.roblox.com/docs/ui/animation)
