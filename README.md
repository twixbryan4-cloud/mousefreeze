# Huss Valley Panel

Versão 0.4.0 do painel em Luau, inspirada no vídeo de referência. O catálogo e a categoria de facas não fazem parte deste projeto. O diagnóstico recebido confirmou o Huss Valley (place 107535308163741 / universe 10764627709) e a pasta `ReplicatedStorage.ChickenOrHero`. Os nomes dos eventos não revelam seus argumentos nem a lógica que o servidor executa.

## Integrações da versão 0.4.0

As oito partes da sessão enviada trouxeram os formatos de ataque, tackle, dash e habilidade, além de respostas e vereditos do jogo. A versão 0.4.0 usa esses formatos em quatro controles que começam desligados. A implementação foi testada com APIs simuladas; a execução e a aceitação dentro do Huss Valley/Delta ainda precisam ser verificadas pelo usuário.

- **Auto Attack:** quando o jogador é Catcher e está em `RunState = Active`, seleciona um Runner próximo e envia o pedido de melee observado. Há somente um pedido pendente por vez. O intervalo combina a configuração do painel, um limite local de 0,85 segundo e `readyAt` recebido do jogo. A distância configurada seleciona alvos; não altera a caixa de colisão nem garante um acerto a essa distância. Na ausência do remote, permanece a ativação genérica da ferramenta equipada.
- **Auto Tackle:** seleciona um Runner ativo no alcance configurado, envia posição/direção atuais, velocidade horizontal medida e horário do servidor, e aguarda `TackleResult`. Também respeita `TackleReadyAt`. Alcance configurável de 2 a 12 studs, começando em 6.
- **Auto Dash:** durante uma rodada ativa e enquanto há movimento, envia os dois vetores horizontais observados. A direção lateral é escolhida em relação ao movimento. Aguarda `DashReady = true` e mantém um intervalo local mínimo de 0,85 segundo durante o atraso de replicação. Não altera atributos de cooldown nem velocidade do dash.
- **Auto Ability:** usa a habilidade equipada quando um oponente está no alcance configurado, começando em 18 studs. Usa o formato de seis argumentos observado, inclusive as posições nil, e aguarda `AbilityReadyAt` e os tempos específicos publicados. O efeito depende da habilidade equipada e da validação do jogo.

Esses comandos só são instalados no universe Huss Valley quando os respectivos remotes existem. Remotes carregados depois são reconhecidos por evento. Personagens sem papel publicado, estados Lobby/Waiting/Safe e alvos reconhecidos como seguros não recebem pedidos de ataque. Os pedidos usam IDs novos e `Workspace:GetServerTimeNow()`; não repetem IDs ou horários da sessão gravada. Recusas produzem uma pausa adicional, e pedidos sem resposta expiram em cinco segundos. Desativar o recurso ou fechar o painel impede novas ações agendadas.

O status distingue comando enviado, pedido aceito, pedido recusado e veredito de acerto. Um `MeleeEvent` aceito não significa que alguém foi atingido: a amostra contém um `HitReplayEvent` do servidor com `accepted = false` e `reason = shielded`. O estado do painel nunca transforma isso em uma promessa de Anti-Hit. O escudo observado é uma mecânica do jogo; o registro não mostra como conceder imunidade permanente.

### Formatos observados

| Ação | Remote relativo a ReplicatedStorage | Argumentos enviados |
| --- | --- | --- |
| Melee | ChickenOrHero.Game.MeleeEvent | `{id, direction, at, position}` |
| Tackle | ChickenOrHero.Game.GameAction | `"Tackle", {id, direction, at, position, speed}` |
| Dash | ChickenOrHero.Presentation.BoostRequest | vetor de movimento, vetor lateral |
| Habilidade | ChickenOrHero.Gear.GearEvent | `"UseAbility", nil, direção, id, nil, nil` |

A resposta de melee chega como `id, accepted, metadata`; tackle usa `"TackleResult", id, accepted, metadata`. Respostas `PredictionResult` de Gear são correlacionadas pelo `requestId`, quando disponíveis. O painel não interfere nos handlers existentes e ignora respostas que não correspondem aos seus pedidos. `HitReplayEvent/Verdict` é tratado separadamente e só atualiza o resultado de IDs recentes reconhecidos como pertencentes ao painel.

O ESP e os filtros de time agora usam `GameRole` quando há Runner/Catcher publicados, mesmo se `Team` estiver vazio. Catcher aparece em vermelho e Runner em verde; o time Roblox continua como alternativa quando não há papel conhecido.

### Correção adicional do resumo

A sessão da versão 0.3.1 agrupou IDs UUID variáveis como se fossem ações diferentes. Isso esgotou os 64 grupos e deixou 15 eventos amostrados fora do resumo, incluindo informações de RescueEvent e VowAbilityEvent que aparecem somente nos contadores. A versão 0.4.0 normaliza esses IDs na chave do grupo, preservando os argumentos originais. Também separa resultados por item/tipo/motivo e evita duplicar uma amostra idêntica nos campos first/latest da exportação compacta. Os limites de memória continuam em vigor.

A amostra também mostrou emotes Play/Stop, Gear Use e votação como `"Vote", mapa, identificador`. Isso não confirma a origem/validade do terceiro argumento da votação nem todos os pré-requisitos de equipamentos. Auto Map Vote e Auto Revive por remote permanecem pendentes; os comportamentos anteriores por ferramenta/prompt continuam disponíveis. Auto Zone precisa vincular o ponto seguro ao mapa e lado corretos; a posição de um único marcador Safe não foi usada como destino universal.

API nativa: `HussValleyPanel.Native.AttackNearest(alcance)`, `.Tackle()`, `.Dash()`, `.UseAbility()` e `.Status`. Os controles automáticos usam essas funções, que também verificam o estado da rodada em chamadas manuais. Os snapshots do diagnóstico incluem os contadores dos comandos nativos. Adaptadores externos registrados explicitamente continuam tendo prioridade.

## Correção do gravador na versão 0.3.1

A amostra recebida registrou 2.112 eventos em aproximadamente 255 segundos e descartou 1.512. A versão 0.3.0 tratava qualquer atributo como mais importante que uma chamada remota. As atualizações frequentes de `Character.DashCooldownUntil` acabaram expulsando argumentos de ações do histórico, embora os contadores de chamadas permanecessem no relatório. O trecho enviado também terminou antes do fim do JSON.

A correção conserva o limite de memória e muda a retenção:

- `DashCooldownUntil` recebe uma amostra a cada cinco segundos e `MovementState`, no máximo duas por segundo. `attributeStats` conserva contagem de mudanças, primeira referência, último valor/horário e quantidade de alterações agrupadas. Mudanças de papel, captura e booleanos de atividade continuam sendo registradas individualmente.
- O histórico de 600 eventos compartilha espaço com reservas para saída (180), entrada (140), sinais locais importantes (100), outros estados (80) e telemetria repetitiva (100). Cada grupo pode ocupar espaço ocioso; quando o histórico enche, um grupo sobrecarregado não pode apagar outro abaixo de sua reserva. Eventos antigos do próprio grupo ainda podem ser substituídos.
- `remoteSamples` guarda a primeira e a amostra mais recente por caminho, direção e identificador de ação, independentemente da remoção no histórico cronológico. São até 64 grupos, com no máximo duas amostras por grupo. O identificador vem do primeiro argumento de texto ou de campos conhecidos do primeiro argumento em tabela; não se presume que isso revele o significado da ação. O contador `remoteSampleEventsOmitted` informa eventos amostrados que não entraram nesse arquivo de amostras quando ele atingiu o limite.
- Ao parar o modo geral, o painel copia um **resumo de ações**, em partes, com os argumentos preservados e até 24 marcadores recentes. **Copiar resumo de ações** recria essa exportação; **Copiar próxima parte** continua o resumo. O JSON completo continua disponível em **Salvar JSON** e **Copiar tudo**. Salvar o arquivo não muda a sequência de partes do resumo.
- `GameRole` e `RunState`, observados na amostra real, também aparecem no diagnóstico estático. O modo **Aguardar meu hit** reconhece a transição `GameRole: Runner → Catcher` como um sinal a analisar; uma entrada no papel de Catcher a partir do lobby não dispara essa detecção. Isso não prova dano nem invulnerabilidade.

O registro confirmou que a observação de saída funcionou na sessão enviada (`outbound = installed`, sem erros do coletor). `MeleeEvent`, `BoostRequest` e outros endpoints tiveram chamadas contadas. O trecho recebido não preserva argumentos suficientes para implementar esses comandos. Os valores de vida permaneceram em 100 e `healthDecreases` foi zero; as regras de captura/morte ainda precisam ser determinadas pelos eventos e estados correspondentes. Atributos de horário são mantidos no domínio original, sem presumir que todos usem o mesmo relógio.

O teste de regressão reproduz 2.040 mudanças do contador, alternâncias de movimento e uma segunda enxurrada de estados. Ele falha na versão 0.3.0 por perda dos argumentos e passa na 0.3.1, preservando chamadas raras, marcadores e sinais locais. Também foram verificados ocupação das reservas, arquivo independente de amostras, limites do resumo, nova detecção por `GameRole` e limpeza. São testes com APIs simuladas; a correção ainda precisa ser executada no Roblox/Delta.

## Gravador geral na versão 0.3.0

Abra **Config > Gravador geral** pelo botão **+** e toque em **Iniciar gravação geral**. Também há **Gravar rodada inteira** em Combat > Anti-Hit. Pode começar no lobby: esse modo fica ligado por até 30 minutos, acompanha respawns e continua gravando após dano ou morte.

A barra superior permanece disponível quando o menu é minimizado. Logo após cada situação, use **Hit**, **Caí**, **Matei**, **Zona**, **Revivi** ou **Habil.** para associar o que aconteceu na tela ao horário e ao estado do personagem. Os marcadores são relatos manuais: não significam que o painel já identificou a regra interna do jogo. Tente incluir uma ação por vez e deixe alguns segundos entre elas. Uma amostra como runner e outra como catcher podem fornecer informações diferentes.

O gravador acompanha:

- Vida, morte, estados do Humanoid, atributos relevantes do jogador/personagem, time e respawns.
- Posição, velocidade e ferramenta equipada nos snapshots e marcadores.
- Ativação de ferramentas, prompts acionados pelo jogador local e mudanças nos valores de `leaderstats`.
- Valores de estado e atributos publicados em `ChickenOrHero`/`ChickenOrHero.Game` e remotes de gameplay, habilidades, progressão, emotes, recompensas e demais grupos incluídos.
- Contatos físicos do HumanoidRootPart com peças cujos caminhos contenham zone, safe, finish ou checkpoint. São pistas com posição/tamanho da peça; zonas calculadas por região ou com outros nomes podem não produzir esse evento.
- Eventos recebidos e, quando o executor permitir, argumentos das chamadas de saída `:FireServer(...)` e `:InvokeServer(...)`. A observação não dispara chamadas adicionais nem altera argumentos ou resultados.

A captura de saída requer `getrawmetatable`, `getnamecallmethod`, `setreadonly`, `isreadonly` e `newcclosure`. O status/relatório informa `installed`, `chainReused`, `unavailable` ou `setupFailed`. A presença dessas APIs não prova compatibilidade com a versão do Delta instalada. Chamadas feitas diretamente como `remote.FireServer(remote, ...)` podem passar fora do observador; respostas de RemoteFunction e callbacks `OnClientInvoke` não são registrados. Quando o executor não permite observar a saída, os outros coletores continuam funcionando.

### Copiar ou salvar o resultado

1. Use **Parar** na barra superior ou **Encerrar e copiar** no cartão. O painel copia a primeira parte do resumo de ações e mostra `parte 1/N`.
2. Envie essa parte e use **Copiar próxima parte** para copiar as seguintes, até enviar todas. Cada mensagem leva um identificador da sessão e sua numeração. As partes são fragmentos, na ordem, do JSON indicado no cabeçalho (`ações` ou `completo`).
3. **Copiar tudo** copia o registro completo. **Salvar JSON** cria `huss-valley-trace-<sessão>.json` nos arquivos do executor, quando há `writefile`; também é possível enviar esse arquivo inteiro. Sem clipboard, há um campo selecionável.

O histórico cronológico é limitado a 600 eventos, com a retenção por grupo descrita acima. As amostras independentes e os resumos de atributos têm seus próprios limites. Eventos recebidos são amostrados até quatro vezes por segundo por endpoint; os de saída, até oito. Os contadores registram chamadas observadas e amostras omitidas. Um burst pode omitir uma ação específica; se isso acontecer, uma gravação curta focada nessa ação ajuda a reduzir a ambiguidade. Há limites adicionais de 160 remotes, 100 valores, oito argumentos, profundidade de tabela de três níveis, 12 campos por tabela e strings de até 96 bytes; valores maiores são resumidos. As partes copiadas têm até 9.000 bytes de JSON, além do cabeçalho, sem dividir caracteres UTF-8.

Chat, remotes administrativos/privados, áudio, bots e replicação contínua não são coletados. Textos curtos dos remotes de gameplay incluídos são preservados para mapear ações; chaves como token, secret, password e auth são omitidas/redigidas. O resultado permanece no dispositivo até ser compartilhado pelo usuário. Nenhum código do servidor é obtido, e proximidade temporal entre eventos não prova a causa de um hit ou uma eliminação.

Ao encerrar, os listeners são desconectados. O observador de saída restaura a função anterior quando ainda ocupa o topo da cadeia; se outro script adicionou um observador depois, a coleta é desativada sem remover o script posterior. Essa ponte inativa é reaproveitada em vez de empilhar novas pontes a cada gravação.

API adicional: `StartGeneralDiagnostics()`, `MarkDiagnostics("Zona")`, `StopHitDiagnostics(true)`, `CopyActionDiagnostics()`, `CopyNextDiagnosticsPart(indiceOpcional)`, `CopyHitDiagnostics()` e `SaveDiagnostics()`. O último resultado geral fica em `LastGeneralDiagnostics`. As funções de gameplay pendentes continuam precisando de integrações confirmadas; gravar um evento não as implementa automaticamente.

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

### Registro de hits na versão 0.2.1

Abra **Combat > Anti-Hit (pendente)** pelo botão **+** e escolha **Aguardar meu hit**. É possível ativar ainda no lobby: o gravador aguarda até 15 minutos, inclusive durante a partida que já está em andamento. Ele tenta detectar queda de vida, morte ou mudança de estado local que indique captura. Ao observar um desses sinais, coleta mais 5 segundos e copia o resultado. Um hit que acontecer naturalmente durante o jogo pode fornecer a amostra; não há uma janela inicial de apenas 20 segundos para esse modo.

Caso o jogo use sinais diferentes dos que são observados, **Encerrar e copiar** permite obter o registro manualmente. **Gravar 20s agora** continua disponível para uma amostra curta imediata. Se a cópia automática não estiver disponível no executor, o texto aparece num campo selecionável. Depois é possível usar **Copiar último registro**.

O registro inclui mudanças de vida/estado do personagem local e resumos de sete eventos relacionados a dano, captura ou controle de movimento. Enquanto aguarda, mantém um histórico curto e limita a frequência de amostragem dos eventos; após o sinal, mantém até 160 entradas. Os listeners são removidos ao concluir, encerrar ou fechar o painel, inclusive se o personagem renascer. Os handlers existentes do jogo continuam em execução. O resultado permanece local até o usuário compartilhar o texto.

O registro não contém código do servidor. Eventos próximos no tempo não provam uma relação de causa, e nenhum hit é bloqueado pelo gravador. A análise serve para decidir o próximo passo; ainda não confirma a viabilidade de invulnerabilidade no cliente.

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
- Auto Attack usa a integração de melee descrita acima quando disponível; Auto Use Gears continua ativando a ferramenta equipada. Auto Revive e Auto Pick somente acionam ProximityPrompts reconhecidos, próximos e habilitados, quando o executor oferece `fireproximityprompt`. Auto Revive não implementa reviver a si mesmo por um evento desconhecido.
- Redução de texturas, efeitos, materiais, sombras e neblina; restauração dos valores anteriores; limite de FPS somente quando o executor oferece `setfpscap`. Restaurar o limite anterior depende de `getfpscap`.
- Anti-Idle por evento do cliente e reconexão ao servidor. O sistema AFK próprio do jogo é separado.
- Lista dos emotes já equipados no avatar; salvar, carregar e excluir configurações. Sem acesso a arquivos, as configurações duram apenas na sessão do executor.

Alterações no cliente podem ser corrigidas pelo servidor. Estes recursos não equivalem a contornar a validação do jogo.

## Integrações ainda pendentes

Auto Zone, Auto Down, Dash Cooldown, Runner AI, Catcher AI, Auto Spin Wheel, Auto Claim Journey, Auto Map Vote, Disable Anti-AFK do jogo, Hit Box, Leaderboard Visuals, Gems & Coins e Anti-Hit precisam de mapeamento específico do Huss Valley. Seus controles recusam ativação enquanto não houver um adaptador correspondente. Nenhum evento ou argumento foi inventado a partir do vídeo ou dos nomes recebidos no diagnóstico.

Para a próxima etapa, execute o painel no jogo e use **Config > Suite > Copiar diagnóstico**. O texto contém caminhos/classes de eventos, prompts e alguns atributos de equipe/estado publicados pelo jogo. Ele fica na área de transferência ou em um campo de texto; não é enviado automaticamente. Esse levantamento identifica a estrutura, mas argumentos e comportamento dos eventos ainda precisam ser confirmados antes da integração.

O ponto de integração é `getgenv().HussValleyPanel.RegisterAction(nome, callback)`. Os nomes esperados constam em `requiresAdapter` no código. O callback recebe `Enabled`, `Player` e `Config`; durante a execução recebe também `Character`, `Delta` e `IsActive()`. Adaptadores que cedem a execução devem conferir `IsActive()` antes de continuar. A desativação e o encerramento chamam o callback com `Enabled = false`.

## Validação e ciclo de vida

A versão 0.4.0 verifica os quatro formatos de saída, preservação de nils, IDs e horários novos, gates de papel/estado/alvo, cooldowns, correlação de respostas, recusa por escudo e encerramento sem novos comandos. Um teste separado reproduz cem UUIDs variáveis sem encher o arquivo de ações e preserva distinções entre respostas de equipamentos e motivos de veredito. Os testes anteriores de interface, recursos locais e exportação continuam sendo executados. Essas verificações usam APIs simuladas e não medem sucesso contra o servidor real.

A versão 0.3.0 foi verificada com APIs simuladas para continuidade durante lobby/dano/morte/respawn, coleta de remotes e valores tardios, filtros, limites, marcadores e limpeza. A captura de saída preservou argumentos, nils, retornos, erros e o comportamento de espera simulado de InvokeServer; foram verificados restauração, coexistência com um observador posterior e fallback sem APIs. A exportação foi verificada com JSON longo contendo UTF-8, recomposição exata das partes, salvamento, campo selecionável e isolamento de timers de sessões anteriores. Esses testes não executam o motor Roblox nem o Delta.

Foram verificados a sintaxe e os fluxos de controles usando APIs simuladas: construção das oito categorias, navegação, expansão, toque, validação de valores, bloqueio de recursos sem integração, movimento, colisão, câmera, ESP, configurações, restauração, encerramento e reexecução. A versão 0.2 também verifica transparência dos cartões, dimensões da tela, avisos opcionais, migração de configurações, novos membros do personagem, reaproveitamento do preview, interpolação e restauração após respawn. Isso não substitui o teste no Roblox/Delta; não há uma sessão desse jogo disponível neste ambiente.

As opções começam desligadas. O ESP possui frequência e distância configuráveis. Varreduras do cenário são feitas por lote ao ativar recursos ou solicitar o diagnóstico. Fechar pelo X ou por Destroy Menu desconecta os eventos, remove objetos locais e tenta restaurar as propriedades alteradas. Executar novamente substitui a instância anterior.

## Referências das APIs do motor

- [LinearVelocity](https://create.roblox.com/docs/reference/engine/classes/LinearVelocity)
- [Highlight](https://create.roblox.com/docs/reference/engine/classes/Highlight)
- [Humanoid](https://create.roblox.com/docs/reference/engine/classes/Humanoid)
- [Animação de interface](https://create.roblox.com/docs/ui/animation)
