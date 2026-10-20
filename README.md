# Huss Valley Panel

Versão 0.6.4 do painel em Luau, inspirada no vídeo de referência. O catálogo e a categoria de facas não fazem parte deste projeto. O diagnóstico recebido confirmou o Huss Valley (place 107535308163741 / universe 10764627709) e a pasta `ReplicatedStorage.ChickenOrHero`. Os nomes dos eventos não revelam seus argumentos nem a lógica que o servidor executa.

## Entradas móveis e ações independentes na versão 0.6.4

Foi corrigido um caminho que podia acionar outra ação com Auto Ability desligado: quando não conseguia usar o botão nativo, Auto Dash enviava uma tecla virtual, Q por padrão. A função real dessa tecla pertence ao jogo. Esse envio não passava pelo toggle de Auto Ability e podia conflitar com o controle de entrada usado pela interface móvel. A reprodução simulada demonstra esse caminho; não identifica com certeza a causa exclusiva da partida relatada, pois não há gravação daquele incidente.

Auto Dash agora usa o botão do jogo nos dispositivos com toque e nunca envia uma tecla virtual nesses dispositivos. **Fallback por tecla (PC)** começa desligado, inclusive ao carregar perfis antigos. Em dispositivos sem toque, só funciona após ativação explícita e fora do modo de gamepad; a tecla escolhida precisa corresponder ao dash configurado no jogo. Se o botão estiver ausente, o status informa isso. Novos botões do jogo invalidam o cache imediatamente. Uma falha em um callback ou sinal já tentado não provoca uma segunda tentativa por outro sinal ou tecla. Falhas de acionamento têm uma espera de 0,5 segundo antes de nova tentativa, sem reduzir a checagem normal de alcance por quadro.

Cada ativação de adaptador recebe uma geração e o personagem correspondente. Desligar e ligar novamente ou trocar de personagem invalida tarefas anteriores, inclusive a continuação do Auto Dash entre callbacks. Entradas de teclado pertencentes ao painel são liberadas ao desligar o fallback, mudar a tecla, desativar o Dash, renascer ou destruir o painel; timers antigos não liberam uma entrada mais nova. O teste manual **Testar dash agora** continua sendo uma solicitação explícita e obedece ao bloqueio de teclado no toque.

O método nativo de habilidade e o envio correspondente também verificam `autoAbility`; uma chamada antiga não envia `UseAbility` depois de desligado. No Huss Valley, Auto Attack não tenta mais ativar uma Tool genérica se MeleeEvent estiver temporariamente ausente. Auto Use Gears usa o comando separado `GearEvent("Use", nil, nil, requestId, nil, nil)` observado no trace do RescueKit, preservando a escolha de gear do jogo. Não chama Tool:Activate nesse jogo. O uso de gear exige Auto Use Gears ligado e conserva o intervalo configurado, a espera por resposta correlacionada, GearReadyAt e as recusas do servidor. As respostas de gear e habilidade são distinguidas pelo identificador do pedido. Em outros jogos, o uso genérico da ferramenta equipada permanece disponível.

Anti-Idle por mouse é desligado com aviso quando ocorre um pedido em um dispositivo com toque; não envia clique de mouse nesse caso. O painel não força a visibilidade do analógico, não troca o controlador de movimento e não habilita controles que o próprio jogo tenha bloqueado durante seus estados.

A sintaxe completa passou, junto de 3 asserções que reproduzem o caminho defeituoso da 0.6.3 e 56 verificações da correção: toque com e sem botão, ausência de tarefas ociosas, fallback opcional no PC, gamepad, erro parcial de callback, cancelamento após yield, desligamento e reativação, respawn, liberação de teclas, habilidade desligada, uso separado de gear, formato dos argumentos nil, correlação de respostas, cooldowns, remotes ausentes, transporte com falha e adaptadores externos. ESP, shaders, Freeze de até 3 segundos, perfis, diagnósticos e Speed Boost foram comparados com a versão anterior e preservados. Os testes usam APIs simuladas; o resultado no Roblox/Delta ainda precisa ser conferido no dispositivo.

## Otimização interna na versão 0.6.3

As opções, os valores iniciais, os alcances e os intervalos foram preservados. O Freeze continua com duração configurável até 3 segundos. O ESP continua acompanhando poses e câmera por quadro, e a aquisição nativa de alvos continua em cada Heartbeat quando a ação está disponível.

O ESP compartilha a inversão do CFrame da raiz entre as partes do corpo, evita criar o vetor intermediário de meia dimensão de cada parte e reutiliza a projeção de partes compartilhadas entre ossos e marcadores no mesmo quadro. O cache de projeções é invalidado em cada atualização; não armazena posições de quadros anteriores. Cabeça e direção só são projetadas quando seus marcadores estão ligados. Chams sozinho não executa projeções 2D. Cores e opções visuais estáticas são ajustadas na atualização de dados ou imediatamente ao mudar um controle; coordenadas e vida continuam atualizadas por quadro. Retângulos, linhas e ponto da cabeça deixam de reconstruir suas dimensões de GUI quando as coordenadas não mudam.

Dash, Tackle e Ability verificam disponibilidade e alcance antes de criar uma tarefa. Só uma tentativa pronta para agir abre a tarefa, e todas as condições são verificadas novamente durante sua execução. Assim, a espera por cooldown, resposta do jogo ou entrada de um alvo no alcance não cria uma tarefa por recurso a cada quadro. Adaptadores externos mantêm seu agendamento, cancelamento e proteção contra sobreposição. Mensagens de status iguais não repetem acessos ao rótulo da interface.

Auto Pick e Auto Revive verificam primeiro a distância atual; a leitura e a normalização do texto só acontecem para prompts próximos. Os textos e a posição continuam sendo lidos ao vivo, sem um intervalo adicional de detecção. Os botões de Auto Jump e Freeze suspendem a atualização periódica da interface quando ambos estão desligados e reutilizam o estado visual enquanto texto, cores e segundo exibido do cooldown não mudam. Os pedidos de salto, a pausa do Freeze e seus intervalos foram mantidos.

A comparação executou as funções das versões 0.6.2 e 0.6.3 com a mesma cena simulada de 20 rigs R15 durante 120 quadros. O ESP básico passou de 26.400 para 21.600 chamadas de projeção (18,2% menos); com esqueleto, traço, direção e ponto da cabeça, de 98.400 para 60.000 (39,0% menos). As dimensões do corpo ainda foram calculadas em todos os 2.400 pares personagem/quadro. Com os personagens e a câmera parados, a reconstrução de UDim2 dos marcadores passou de 4.800 no modo básico e 88.800 no modo completo para zero após a preparação inicial. Chams sozinho passou de 2.400 projeções para zero.

Com as três ações nativas ligadas e nenhum alvo no alcance durante 120 quadros, foram criadas zero tarefas, contra 360 antes. Com 500 prompts distantes durante 60 quadros, a normalização de rótulos passou de 30.000 para zero. Os testes também verificaram a primeira ação ao entrar no alcance, alvos saindo antes de uma tarefa executar, limites exatos, movimento do esqueleto, cooldowns e transições dos botões. A sintaxe completa, as 264 asserções de regressão e as 35 verificações adicionais da versão otimizada passaram. Essas são contagens de operações com APIs simuladas; não medem FPS nem uso de CPU/GPU no Roblox ou no celular.

## Duração do Freeze na versão 0.6.2

**World > Freeze > Duração da travada** aceita de 0,05 a 3 segundos, com incrementos de 0,01 segundo. O máximo anterior era 0,30 segundo. O slider, a validação dos perfis e o limite aplicado durante a execução foram ampliados juntos; valores acima de 0,30 segundo também podem ser salvos e carregados. A duração inicial continua em 0,12 segundo e os perfis existentes mantêm seus valores. O intervalo entre usos continua configurável de 0,5 a 5 segundos. A execução local fica pausada durante toda a duração escolhida e retorna automaticamente.

## ESP, alcance e intervalos na versão 0.6.1

O ESP calcula as caixas somente com as partes diretas do corpo R6/R15. Ferramentas, acessórios, efeitos de habilidades e hitboxes auxiliares deixaram de influenciar o tamanho. O HumanoidRootPart só fornece o tamanho como fallback de um rig sem partes reconhecidas. As dimensões e a pose são calculadas a cada quadro, respeitando a escala e a rotação das partes; não dependem mais da frequência dos textos. A projeção oculta caixas que atravessam o plano próximo da câmera e limita o retângulo ao viewport. O esqueleto ignora juntas que levam a peças fora do corpo direto. Isso corrige fontes identificadas no código que podiam gerar caixas enormes; não confirma qual peça específica causou o problema no Huss Valley.

**Dados / cores**, de 2 a 30 Hz, agora regula textos, cores e a atualização da lista de partes do corpo. Movimento, dimensões, barras de vida e projeção permanecem por quadro. ESP de times, filtros e opções anteriores foram preservados.

Auto Dash, Auto Tackle e Auto Ability nativos verificam proximidade em cada Heartbeat, retirando a espera de 0,25 segundo da aquisição. Seus próprios intervalos, papéis, estado da rodada, disponibilidade e respostas do servidor continuam válidos. Adaptadores externos, inclusive funções que substituem um adaptador nativo, conservam a cadência de 0,25 segundo e recebem o tempo real acumulado em Delta. Tarefas pendentes não se sobrepõem e são verificadas novamente antes de executar. Auto Zone continua sendo uma única tentativa imediata por ativação.

Auto Attack usa o delay configurado como intervalo mínimo entre envios, sem o piso local fixo de 0,85 segundo que havia no caminho nativo. Continua aguardando a resposta, readyAt e o recuo após recusa do servidor. O fallback por Tool não gasta o intervalo quando não existe alvo ou ferramenta habilitada. Auto Use Gears também começa seu intervalo quando consegue acionar a ferramenta. Auto Pick e Auto Revive buscam prompts a cada quadro quando estão prontos; ficar fora do alcance não consome o intervalo. Há proteção contra reentrada enquanto uma chamada de prompt estiver pendente.

Lock On adquire e descarta alvos em cada Heartbeat, retirando o intervalo de 0,1 segundo da seleção. Os limites de studs são inclusivos. Attack, Tackle e Ability usam a direção atual do personagem quando os centros dos dois personagens coincidem, evitando uma direção horizontal zerada.

As verificações usam posições atualmente replicadas ao cliente, com distância tridimensional entre raízes ou até o prompt. Não eliminam ping, frames perdidos nem cooldown imposto pelo jogo. Freeze suspende intencionalmente a execução local durante sua pausa e também interrompe essas verificações nesse período. Auto Jump e os demais controles de tempo foram revisados; seus intervalos e comportamento foram mantidos.

A sintaxe do arquivo completo e 263 asserções simuladas passaram: 134 de geometria/projeção, 56 de alcances/agendamento/comandos nativos e 73 de integração do ESP. Foram cobertos efeitos e acessórios gigantes, raiz ampliada, R6/R15 com escala e rotação, proximidade da câmera, respawn, ESP de times, 2 Hz de metadados com movimento por quadro, limites exatos de studs, passagem rápida, 30/60/120 FPS, frames longos, alvos sobrepostos, cancelamento, pendências e intervalos do servidor. Esses testes executam as funções do arquivo com APIs simuladas; o resultado no Roblox/Delta ainda precisa ser conferido no jogo.

## Carregamento, botões e perfis na versão 0.6.0

A abertura usa uma tela escura em azul-marinho, detalhes em azul, lavanda e coral, monograma HV, avatar e saudação. A barra tem gradiente, brilho em movimento, porcentagem e mensagens das etapas de construção, conexão e leitura dos perfis. A entrada e a saída são suaves; a janela e os atalhos aguardam o fim dessa apresentação. O visual é feito com GUI nativa, sem tema de Halloween nem imagens externas de fundo. A apresentação dura pelo menos 1,35 segundo antes da transição de saída.

Em **World > Auto Jump**, ligar a opção mostra um botão flutuante; tocar nesse botão inicia ou para os saltos. Desligar a opção esconde o botão e interrompe os saltos. O intervalo vai de 0,1 a 1 segundo. A rotina pede saltos quando o personagem está no chão, vivo, fora de um assento, sem estar ancorado e com o estado Jumping disponível; não altera JumpPower nem implementa salto no ar. Fly e campo de texto em foco suspendem novos pedidos. Morte, troca de personagem e carregamento de perfil interrompem a execução transitória.

Em **World > Freeze**, ligar a opção mostra o segundo botão. Ele provoca uma pausa real e breve da execução local, de 0,05 a 0,30 segundo, começando em 0,12 segundo. A implementação ocupa intencionalmente o cliente somente durante esse intervalo limitado e volta automaticamente; não ancora o personagem, altera sua posição ou congela outros clientes. O intervalo entre usos é configurável de 0,5 a 5 segundos, começando em 1. O botão distingue pronto, congelamento e cooldown. Pedidos duplicados são recusados; desligar, renascer ou encerrar cancela um pedido que ainda não começou. Isso não implementa nem demonstra proteção contra hits.

Os dois atalhos começam escondidos, podem ser arrastados livremente por mouse/toque e aparecem ou somem com fade. Arrastar não dispara sua ação. Suas posições, a posição da janela e a do botão de abertura fazem parte do perfil salvo.

**ESP > ESP de times** fica junto das opções anteriores. Pode ser ativado sozinho e mostra o jogador e o nome do time com a cor da equipe. Quando o jogador é neutro ou não possui Team, usa Runner/Catcher publicado pelo jogo, ou “Sem time” se nenhum deles estiver disponível. Nesse modo, caixas, ossos, linhas comuns, barra de vida e ponto da cabeça ficam ocultos; ao desligá-lo, as preferências geométricas anteriores voltam sem serem sobrescritas. Chams e View Tracer continuam controles independentes. O movimento dos rótulos mantém a projeção por quadro da versão anterior.

**Config > Configs** agora possui um campo de nome, lista rolável, seleção destacada, Save Config, Load Config, Delete Config e Atualizar lista. Selecionar uma linha não aplica o perfil: é preciso tocar em Load Config. Salvar inclui os valores e as opções atuais e seleciona o perfil na lista. Load e Delete usam a linha selecionada, mesmo que o campo de nome tenha sido editado para preparar uma cópia. Carregar um perfil antigo aplica os valores iniciais às opções novas que ele não contém; valores false são preservados e a opacidade antiga é migrada para transparência.

Os JSONs continuam em `HussValleyPanel/`, com um índice `_index.json` para reconstruir a lista após outra execução. Quando listfiles está disponível, arquivos antigos ainda sem índice também são encontrados, inclusive com separadores de caminho Windows. Os nomes reservados de metadados não podem ser usados para perfis. Uma falha de gravação conserva a nova configuração na sessão e informa essa limitação; a gravação só é considerada persistente após leitura de confirmação. Falhas ao apagar mantêm o perfil na lista. Sem as APIs de arquivo, a lista dura somente na sessão do executor.

Auto-Load aponta para um perfil salvo e selecionado. Selecionar ou carregar outro perfil não troca esse apontamento; excluir o perfil designado desativa o carregamento automático.

A validação passou em 72 verificações de construção, abertura/limpeza, Auto Jump, Freeze limitado, cancelamento, perfis, persistência, falhas de arquivo, migração, seleção sem aplicação, layouts e ESP de times. Também passaram as 21 verificações anteriores de ponteiro/transições e as 68 de ESP por quadro, além da sintaxe do arquivo completo. São simulações das APIs; a aparência, a execução no Delta e o comportamento do servidor ainda precisam ser conferidos no Roblox.

## ESP e janela na versão 0.5.1

As caixas, os traços, o esqueleto, a direção do olhar e o ponto da cabeça agora são projetados a cada quadro, depois da atualização da câmera e do Lock On do próprio painel. Foi removida a interpolação de posições antigas, que fazia o marcador perseguir alvos rápidos. A projeção acompanha a posição que o cliente possui naquele quadro; não prevê posições futuras nem corrige atrasos de replicação do servidor.

O controle **Dados / contorno**, de 2 a 30 Hz, limita a leitura de cores/textos e a atualização das dimensões do avatar; não limita mais o movimento dos marcadores. As posições dos ossos e a barra de vida acompanham cada quadro. A lista de juntas permanece em cache e os objetos visuais continuam sendo reutilizados. A chave antiga `smoothESP` é aceita nas configurações anteriores, mas não reativa a interpolação atrasada.

O topo da janela e o botão de abertura podem ser arrastados por mouse ou toque em qualquer direção, inclusive além das bordas da tela. O ajuste de escala e as mudanças de orientação não reposicionam nem prendem os elementos ao viewport. Cada alvo aceita um ponteiro por vez; perder o foco libera o arraste. Arrastar o botão não é tratado como um clique para abrir o menu.

Ao abrir, o botão desaparece com um fade de 0,18 s. Ao recolher pelo **X**, pelo botão de minimizar ou pela marca HV, ele reaparece suavemente na posição em que foi deixado. Cliques rápidos cancelam a transição anterior e continuam a partir da transparência atual. O X recolhe a janela e mantém a sessão e os recursos ativos. **Config > Suite > Destroy Menu** continua encerrando o painel e restaurando seus efeitos. A opção antiga de manter o logo sobre a janela aberta foi retirada; a chave `floating` ainda é aceita ao ler configurações anteriores, e o botão fica disponível quando a janela está recolhida.

A validação desta mudança passou em 21 verificações simuladas de ponteiro/transições e 68 de ESP, incluindo alternância de 50 studs por quadro, mudança da câmera, cache de dados, filtros e limpeza. A sintaxe completa e as 88 verificações anteriores de shaders/Auto Zone também passaram. Esses testes não executam a interface nem a renderização dentro do Roblox/Delta.

## Shaders na versão 0.5.0

**Shaders > Corredor MM2** liga um visual inspirado na referência enviada: iluminação neutra, contraste moderado, bloom leve, sombras e reflexos nativos do ambiente em superfícies planas. Há controles separados para pisos/tetos e paredes, exposição, saturação, temperatura e acabamento liso opcional. Texturas e materiais originais ficam preservados por padrão; o acabamento liso altera Material/MaterialVariant somente enquanto ligado. Os controles são salvos nas configurações existentes.

Esta implementação usa iluminação e pós-processamento nativos, sem instalar um renderizador externo, SSR ou reflexos espelhados de moedas/personagens como os do vídeo. O resultado dos reflexos depende do material, da iluminação e da qualidade gráfica do Roblox. `Reflectance` e `EnvironmentSpecularScale` não são uma reprodução do renderizador demonstrado na referência.

O controle continua ligado ao mudar de mapa. Descendentes adicionados e peças transmitidas por streaming entram numa fila processada em lotes; peças removidas saem do cache e recuperam seus valores antes de serem reaproveitadas. Para mapas que reutilizam instâncias sem reparentear, os candidatos já conhecidos são reconciliados em lotes após dois segundos sem trabalho pendente. Isso não repete `workspace:GetDescendants()` a cada quadro. Partes de personagens, ferramentas, acessórios, objetos locais, peças móveis, áreas invisíveis e volumes sem uma face plana identificável ficam de fora.

As mudanças da iluminação do mapa são acompanhadas e os dois efeitos próprios são recriados se o jogo os remover. Os efeitos de cor/bloom já existentes no jogo são preservados e podem influenciar o resultado. Desligar restaura os valores anteriores ou a mudança mais recente observada do jogo, destrói somente os efeitos próprios, cancela tarefas antigas e desconecta os cinco observadores desta área. Encerrar por Destroy Menu ou reexecutar o painel faz a mesma limpeza; recolher a janela mantém o efeito ativo.

Shaders, FPS Booster, Low render quality e Environment/Fullbright são mutuamente exclusivos para evitar que uma área sobrescreva o visual da outra. Ligar Shaders desliga esses três controles; ligar um deles desliga Shaders antes de aplicar a alteração. A barra lateral acomoda a nona categoria sem aumentar o painel. O Auto Zone e os demais recursos de gameplay não foram reescritos.

## Auto Zone por TP na versão 0.4.3

Ligar **Combat > Auto Zone** aplica um único TP imediatamente, sem esperar o ciclo de 0,25 s dos outros adaptadores. O recurso exige um runner vivo com `RunState` Active ou Safe. Não repete o TP enquanto o controle permanece ligado; desligar e ligar novamente cria uma nova tentativa. Respawn desliga o controle.

A sessão `1792375962-232233` confirmou `RunState=Safe`, `SafeSide=B` e a posição do HumanoidRootPart `(105.64381408691406, 22.99999237060547, 126.02445220947266)`. O destino inicial usa esse ponto somente quando ele corresponde à geometria de uma área Safe carregada, com altura e limites locais compatíveis, sem indicação de lado A. Quando disponível, a referência ActiveMap/CurrentMap ou o mapa sob o personagem limita a busca. Mais de um mapa compatível sem uma referência atual é tratado como ambíguo. O registro não contém o caminho dessa peça; a detecção real ainda precisa ser conferida no Delta.

Se o painel não identificar a zona, ele desliga o controle e explica o motivo. **Marcar zona aqui** permite registrar a posição atual quando o jogo já informa Safe e SafeSide A/B. Essa marca fica vinculada à instância carregada do mapa e dura somente nesta execução do painel; não é salva como coordenada universal em configurações. Depois de marcar, desligue e ligue Auto Zone para usar o ponto. Superfícies globais como Terrain não identificam um mapa para essa marcação.

O movimento preserva a orientação e o deslocamento do pivot do personagem e zera suas velocidades residuais. Após 0,8 s, o status distingue posição corrigida pelo jogo, TP local ainda sem confirmação e estado Safe no lado esperado. O painel não altera RunState/SafeSide nem envia remotes para forjar a chegada. Desativar, fechar ou substituir o personagem cancela a verificação anterior. APIs: `Native.TeleportZone()`, `Native.CaptureZone()` e `Native.CancelZone()`; o adaptador AutoZone recebe uma chamada imediata por ativação e outra ao desligar.

## Auto Dash por proximidade na versão 0.4.1

O usuário esclareceu que a distância desejada é a **proximidade do inimigo**. Em **Combat > Auto Dash**, os novos controles são:

- **Alcance do inimigo:** de 2 a 100 studs, começando em 15. O dash automático só tenta acionar quando existe um oponente vivo e elegível dentro desse raio, incluindo a borda. Esse valor não define o comprimento do dash.
- **Delay:** de 0,25 a 10 segundos, começando em 1. É o intervalo mínimo entre entradas acionadas. A verificação automática ocorre a cada 0,25 segundo; a disponibilidade e as regras do jogo continuam podendo exigir um intervalo maior. O limite fixo anterior de 0,85 segundo foi removido do Auto Dash.
- **Tecla do dash (fallback):** Q, E, F, LeftShift, LeftControl ou Space. Deve ser a tecla que o jogo realmente usa para dash. Q é apenas o valor inicial editável; a gravação anterior não confirmou o binding de teclado.
- **Testar dash agora:** tenta a mesma entrada sem exigir inimigo próximo nem o estado Active. O jogo continua decidindo se permite dash naquele contexto. O teste não liga o toggle automático, não substitui o cooldown e pode ser usado para verificar a entrada enquanto se aguarda a próxima rodada.

O disparo automático deixa de exigir `Humanoid.MoveDirection` diferente de zero e de fabricar um vetor lateral. Ele procura um botão de dash reconhecível no `PlayerGui`, visível e fora do próprio painel. Quando disponíveis, os callbacks Luau já conectados a Activated/MouseButton1Click são acionados sem substituir ou desconectar os handlers do jogo. Na ausência desse caminho, tenta uma pressão curta da tecla configurada por VirtualInputManager, se o executor permitir. O teclado não é acionado enquanto há um campo de texto em foco ou a tecla já está pressionada. Botões novos são encontrados em varreduras espaçadas em três segundos; o HUD não é varrido a cada quadro.

Esse caminho substitui o envio isolado de `BoostRequest` usado pela versão 0.4.0. A amostra mostrou esse pedido de rede, mas não demonstrou que ele, sozinho, inicia o movimento local. A nova implementação entrega a entrada ao controlador do próprio jogo, que pode enviar os pedidos necessários e aplicar seus pré-requisitos. Nenhuma posição, velocidade, animação ou atributo de cooldown é forçado pelo painel.

O status distingue **entrada acionada** de **mudança em DashCount**. O coletor confere o contador por até 0,8 segundo após a tentativa e informa quando o dash não foi confirmado por esse sinal. Uma mudança nesse atributo é apenas observação do cliente, não um veredito de movimento do servidor. Se botão e tecla não puderem ser acionados, o painel informa entrada indisponível. A confirmação depende da interface real do jogo e das APIs do Delta, ainda não disponíveis nesta simulação.

Alcance, delay e tecla são salvos nas configurações. Desligar Auto Dash, renascer ou fechar o painel libera qualquer tecla mantida pelo recurso. `Native.Dash()` usa a proximidade normal; `Native.Dash(true)` corresponde ao teste manual. `dashSide` antigo permanece aceito ao ler configurações anteriores, mas não aparece como controle nem dirige a entrada nova.

A regressão verifica o raio exato, inimigo fora do raio, intervalos configurados, disparo parado, cooldown, papéis, estado seguro, foco de texto, preservação dos callbacks, fallback de tecla, liberação ao desligar/fechar, teste manual, persistência e ausência de varreduras do HUD com o recurso desligado. Esses testes usam o motor simulado e não demonstram sucesso no servidor real.

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

A amostra também mostrou emotes Play/Stop, Gear Use e votação como `"Vote", mapa, identificador`. Isso não confirma a origem/validade do terceiro argumento da votação nem todos os pré-requisitos de equipamentos. Auto Map Vote e Auto Revive por remote permanecem pendentes; os comportamentos anteriores por ferramenta/prompt continuam disponíveis. O Auto Zone foi integrado na versão 0.4.3 com o registro posterior e a validação de destino descritos acima.

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

### Capturar o próprio escudo na versão 0.4.2

Em **Combat > Anti-Hit (pendente) > +**, escolha **Gravar meu escudo** antes de equipar ou ativar o `OneHitShield` pelos controles do jogo. Pode iniciar no lobby e esperar a rodada: a captura dura até 15 minutos e acompanha respawns. Use **Marcar escudo ativado** após a ativação. Se ocorrer um ataque, marque **Hit** na barra superior e termine em **Encerrar e copiar** ou **Parar**. Envie as partes numeradas; **Config > Gravador geral > Copiar próxima parte** continua a mesma exportação. Não é preciso deixar o personagem morrer para registrar o uso do item.

Esse modo observa somente `GearEvent`, `ArmoryEvent`, `MeleeEvent`, `GameAction`, `HitReplayEvent` e o evento `Death` do chrono. As saídas preservam o formato original, incluindo nils e IDs. Ele não usa, equipa, compra nem consome o escudo automaticamente. O `State` recebido no `ArmoryEvent` tem um resumo separado do inventário `gear`, incluindo `OneHitShield`, para evitar que um campo aninhado fique escondido pela truncagem da mensagem inteira.

As amostras recebem `subject`: `localRequest` para solicitações do cliente ou respostas correlacionadas; `localActor` para eventos que identificam seu personagem como autor; `localTarget` quando seu ID/modelo aparece como alvo ou candidato; `unattributed` quando falta essa identificação. Eventos explicitamente atribuídos a outros jogadores são descartados e contados em `excludedOtherPlayerEvents`. IDs de solicitações e ataques ficam em um cache de até 64 entradas, com janela de correlação de 20 segundos. Um alvo listado em `Attack` ainda não confirma acerto nem proteção. Os registros anteriores mostraram efeitos de `OneHitShield` e um veredito `shielded` para outros jogadores; não confirmaram o mecanismo no personagem local.

O resumo `HussValleyShieldSummary` preserva uma sequência de até 80 eventos de interesse: solicitações/respostas selecionadas, mudanças de atributos de proteção, vida, papel/estado da rodada, respawn e marcadores. Guarda até 16 amostras do inventário, com contadores explícitos de descarte. Campos sem dono continuam incertos. O arquivo completo pode ser salvo pelos controles existentes. A próxima integração depende de confirmar ativação, recusa por escudo no alvo local, consumo, duração e condições de reutilização; a captura não estabelece uma falha nem imunidade permanente.

API: `HussValleyPanel.StartShieldDiagnostics()`, `HussValleyPanel.MarkDiagnostics("Escudo ativado")` e `HussValleyPanel.StopHitDiagnostics(true)`.

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

Auto Down, Dash Cooldown, Runner AI, Catcher AI, Auto Spin Wheel, Auto Claim Journey, Auto Map Vote, Disable Anti-AFK do jogo, Hit Box, Leaderboard Visuals, Gems & Coins e Anti-Hit precisam de mapeamento específico do Huss Valley. Seus controles recusam ativação enquanto não houver um adaptador correspondente. Nenhum evento ou argumento foi inventado a partir do vídeo ou dos nomes recebidos no diagnóstico.

Para a próxima etapa, execute o painel no jogo e use **Config > Suite > Copiar diagnóstico**. O texto contém caminhos/classes de eventos, prompts e alguns atributos de equipe/estado publicados pelo jogo. Ele fica na área de transferência ou em um campo de texto; não é enviado automaticamente. Esse levantamento identifica a estrutura, mas argumentos e comportamento dos eventos ainda precisam ser confirmados antes da integração.

O ponto de integração é `getgenv().HussValleyPanel.RegisterAction(nome, callback)`. Os nomes esperados constam em `requiresAdapter` no código. O callback recebe `Enabled`, `Player` e `Config`; durante a execução recebe também `Character`, `Delta` e `IsActive()`. Adaptadores que cedem a execução devem conferir `IsActive()` antes de continuar. A desativação e o encerramento chamam o callback com `Enabled = false`.

## Validação e ciclo de vida

A versão 0.5.0 passou em 62 verificações simuladas do módulo Shaders, setter, configurações e controles gráficos existentes, cobrindo callbacks imediatos e adiados: aplicação inicial, streaming, troca e reaproveitamento de mapas, limpeza de peças antigas, restauração, filtros de geometria, efeitos removidos pelo mapa, iluminação alterada pelo jogo, parâmetros, salvamento/carregamento e conflitos gráficos. A sintaxe do arquivo completo e os 26 casos anteriores do Auto Zone também passaram. Esses testes não executam a renderização Roblox/Delta; a semelhança visual e o desempenho no aparelho ainda precisam de validação no jogo.

A versão 0.4.3 passou na verificação de sintaxe do arquivo inteiro e em 26 casos simulados do Auto Zone: ativação imediata, ausência de repetição, confirmação por estado/lado, correção de posição, zona ausente, altura e orientação da área, conflito de lado, mapa atual e ambiguidade, marcação manual, substituição do mapa, rejeição de Terrain como identidade, cancelamento, falha de TP, preservação de adaptadores externos e das rotinas periódicas, papel, captura, espera, morte e universe incorreto. Esses casos executam o controlador, o setter e o despacho extraídos do próprio arquivo; não executam Roblox/Delta nem confirmam aceitação pelo servidor.

A versão 0.4.2 reproduz uma sequência de uso do próprio escudo, resposta ao pedido, ataque com o jogador local como candidato, veredito `shielded`, consumo e captura posterior. Verifica que tráfego de outros jogadores não ocupa a amostragem local, dados sem identidade continuam incertos, IDs antigos expiram, nils/handlers são preservados, nenhum comando adicional é enviado pelo gravador e o modo continua até o encerramento ou seu limite de 15 minutos. Essa validação usa APIs simuladas; o uso real do escudo ainda precisa ser registrado no jogo.

A versão 0.4.1 acrescenta o teste específico do Auto Dash por proximidade e atualiza o teste de integrações para confirmar que o controlador do jogo é acionado sem exigir caminhada. Todos os demais testes de interface, protocolos, gravação e exportação permanecem na validação.

A versão 0.4.0 verifica os quatro formatos de saída, preservação de nils, IDs e horários novos, gates de papel/estado/alvo, cooldowns, correlação de respostas, recusa por escudo e encerramento sem novos comandos. Um teste separado reproduz cem UUIDs variáveis sem encher o arquivo de ações e preserva distinções entre respostas de equipamentos e motivos de veredito. Os testes anteriores de interface, recursos locais e exportação continuam sendo executados. Essas verificações usam APIs simuladas e não medem sucesso contra o servidor real.

A versão 0.3.0 foi verificada com APIs simuladas para continuidade durante lobby/dano/morte/respawn, coleta de remotes e valores tardios, filtros, limites, marcadores e limpeza. A captura de saída preservou argumentos, nils, retornos, erros e o comportamento de espera simulado de InvokeServer; foram verificados restauração, coexistência com um observador posterior e fallback sem APIs. A exportação foi verificada com JSON longo contendo UTF-8, recomposição exata das partes, salvamento, campo selecionável e isolamento de timers de sessões anteriores. Esses testes não executam o motor Roblox nem o Delta.

Foram verificados a sintaxe e os fluxos de controles usando APIs simuladas: construção das oito categorias, navegação, expansão, toque, validação de valores, bloqueio de recursos sem integração, movimento, colisão, câmera, ESP, configurações, restauração, encerramento e reexecução. A versão 0.2 também verifica transparência dos cartões, dimensões da tela, avisos opcionais, migração de configurações, novos membros do personagem, reaproveitamento do preview, interpolação e restauração após respawn. Isso não substitui o teste no Roblox/Delta; não há uma sessão desse jogo disponível neste ambiente.

As opções começam desligadas. O ESP possui frequência de dados e distância configuráveis, com movimento projetado por quadro. Varreduras do cenário são feitas por lote ao ativar recursos ou solicitar o diagnóstico. O X recolhe a janela. Destroy Menu desconecta os eventos, remove objetos locais e tenta restaurar as propriedades alteradas. Executar novamente substitui a instância anterior.

## Referências das APIs do motor

- [LinearVelocity](https://create.roblox.com/docs/reference/engine/classes/LinearVelocity)
- [Highlight](https://create.roblox.com/docs/reference/engine/classes/Highlight)
- [Humanoid](https://create.roblox.com/docs/reference/engine/classes/Humanoid)
- [Animação de interface](https://create.roblox.com/docs/ui/animation)

Referências de entrada utilizadas na integração: [getconnections](https://docs.sunc.io/Signals/getconnections/), [firesignal](https://docs.sunc.io/Signals/firesignal/) e [VirtualInputManager](https://create.roblox.com/docs/reference/engine/classes/VirtualInputManager). A disponibilidade efetiva no Delta é conferida em execução.




