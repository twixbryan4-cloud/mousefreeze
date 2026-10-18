# Huss Valley Panel

Versão 0.2.0 do painel em Luau, inspirada no vídeo de referência. O catálogo e a categoria de facas não fazem parte deste projeto. O diagnóstico recebido confirmou o Huss Valley (place 107535308163741 / universe 10764627709) e a pasta `ReplicatedStorage.ChickenOrHero`. Os nomes dos eventos não revelam seus argumentos nem a lógica que o servidor executa.

## Alterações da versão 0.2.0

- Botão **UI** no topo, acessível em qualquer categoria: escala de 0,45x a 1,60x e transparência de 0% a 85%. O tamanho final continua limitado à tela. A transparência afeta fundo, cartões, botões e campos; os textos permanecem legíveis.
- Avisos compactos, animados e opcionais ao ativar/desativar uma opção. Carregar uma configuração não gera uma sequência de avisos para cada chave.
- Um único ouvinte global para movimentação dos sliders e arrasto, em lugar dos 20 da versão anterior.
- Cache de referências dos personagens, lista de jogadores e peças do noclip; as peças novas entram por evento. O noclip não faz uma varredura do personagem a cada quadro.
- Seleção de alvo a 10 Hz, com mira atualizada após a câmera. ESP com frequência ajustável, interpolação opcional, dimensões do personagem em cache e menos alterações de propriedades quando os dados não mudam.
- Preview de avatar reaproveitado, rainbow separado da atualização completa do tema e reconhecimento de prompts somente quando necessário.
- Ajustes do FPS Booster feitos juntos no mesmo instante são agrupados em uma passagem. A lista de objetos é reaproveitada enquanto ele está ligado, com novos objetos acompanhados por evento.
- Configurações antigas de opacidade são convertidas para o novo controle de transparência.

Estas são reduções de trabalho verificadas em simulação; não representam uma medição de ganho de FPS no celular.

## Anti-Hit

O item **Combat > Anti-Hit (pendente)** informa que a proteção ainda não foi implementada nem validada. Ele não ativa sem uma integração real. O diagnóstico identifica `MeleeEvent`, `GameAction`, `MovementGuardEvent` e eventos de replicação, mas não demonstra como hits e mortes são decididos. Alterar a vida exibida ou criar um ForceField somente no cliente não provaria invulnerabilidade no servidor. O código não faz nenhuma dessas simulações de proteção e não dispara eventos com argumentos presumidos.

## Executar

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/twixbryan4-cloud/mousefreeze/main/main.lua"))()
```

O arquivo é independente e não baixa bibliotecas de interface. A compatibilidade com a versão instalada do Delta precisa ser verificada dentro do Roblox.

## Interface e recursos implementados

- Boas-vindas com avatar, painel escuro, destaque coral, barra de ícones, duas colunas, opções expansíveis e transição leve de texto.
- Categorias: Combat, AI, ESP, World, Automation, Performance, Emotes e Config.
- Ajuste à tela, arrastar pela parte superior, botão flutuante, botão UI para escala/transparência, minimizar e alternar pela tecla Right Shift. A tecla pode ser alterada em Config.
- Velocidade local, fly com controles verticais por toque, noclip, deslocamento adicional, salto no ar, spin, primeira pessoa, FOV, mouse livre, iluminação e X-Ray locais.
- Player Lock On com raio, previsão, suavização e filtro de time opcional. Mira em jogadores vivos; não presume papéis internos nem executa uma captura específica do jogo.
- ESP de jogadores: caixas, nomes, linhas, vida, distância, articulações, ponto na cabeça, direção de visão, cores por time e Highlight. Inclui preview estático do próprio avatar.
- Auto Attack e Auto Use Gears ativam a ferramenta equipada. Auto Revive e Auto Pick somente acionam ProximityPrompts reconhecidos, próximos e habilitados, quando o executor oferece `fireproximityprompt`. Auto Revive não implementa reviver a si mesmo por um evento desconhecido.
- Redução de texturas, efeitos, materiais, sombras e neblina; restauração dos valores anteriores; limite de FPS somente quando o executor oferece `setfpscap`. Restaurar o limite anterior depende de `getfpscap`.
- Anti-Idle por evento do cliente e reconexão ao servidor. O sistema AFK próprio do jogo é separado.
- Lista dos emotes já equipados no avatar; salvar, carregar e excluir configurações. Sem acesso a arquivos, as configurações duram apenas na sessão do executor.

Alterações no cliente podem ser corrigidas pelo servidor. Estes recursos não equivalem a contornar a validação do jogo.

## Integrações ainda pendentes

Auto Dash, Auto Zone, Auto Down, Auto Tackle, Dash Cooldown, Auto Ability, Runner AI, Catcher AI, Auto Spin Wheel, Auto Claim Journey, Auto Map Vote, Disable Anti-AFK do jogo, Hit Box, Leaderboard Visuals, Gems & Coins e Anti-Hit precisam de mapeamento específico do Huss Valley. Seus controles recusam ativação enquanto não houver um adaptador correspondente. Nenhum evento ou argumento foi inventado a partir do vídeo ou dos nomes recebidos no diagnóstico.

Para a próxima etapa, execute o painel no jogo e use **Config > Suite > Copiar diagnóstico**. O texto contém caminhos/classes de eventos, prompts e alguns atributos de equipe/estado publicados pelo jogo. Ele fica na área de transferência ou em um campo de texto; não é enviado automaticamente. Esse levantamento identifica a estrutura, mas argumentos e comportamento dos eventos ainda precisam ser confirmados antes da integração.

O ponto de integração é `getgenv().HussValleyPanel.RegisterAction(nome, callback)`. Os nomes esperados constam em `requiresAdapter` no código. O callback recebe `Enabled`, `Player` e `Config`; durante a execução recebe também `Character`, `Delta` e `IsActive()`. Adaptadores que cedem a execução devem conferir `IsActive()` antes de continuar. A desativação e o encerramento chamam o callback com `Enabled = false`.

## Validação e ciclo de vida

Foram verificados a sintaxe e os fluxos de controles usando APIs simuladas: construção das oito categorias, navegação, expansão, toque, validação de valores, bloqueio de recursos sem integração, movimento, colisão, câmera, ESP, configurações, restauração, encerramento e reexecução. A versão 0.2 também verifica transparência dos cartões, dimensões da tela, avisos opcionais, migração de configurações, novos membros do personagem, reaproveitamento do preview, interpolação e restauração após respawn. Isso não substitui o teste no Roblox/Delta; não há uma sessão desse jogo disponível neste ambiente.

As opções começam desligadas. O ESP possui frequência e distância configuráveis. Varreduras do cenário são feitas por lote ao ativar recursos ou solicitar o diagnóstico. Fechar pelo X ou por Destroy Menu desconecta os eventos, remove objetos locais e tenta restaurar as propriedades alteradas. Executar novamente substitui a instância anterior.

## Referências das APIs do motor

- [LinearVelocity](https://create.roblox.com/docs/reference/engine/classes/LinearVelocity)
- [Highlight](https://create.roblox.com/docs/reference/engine/classes/Highlight)
- [Humanoid](https://create.roblox.com/docs/reference/engine/classes/Humanoid)
- [Animação de interface](https://create.roblox.com/docs/ui/animation)
