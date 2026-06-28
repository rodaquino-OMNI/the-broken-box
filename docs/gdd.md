---
title: "The broken box"
game_type: horror
platforms:
  - Roblox
created: 2026-06-27
updated: 2026-06-28
author: familia
status: draft
version: 2.0
benchmark: "Pwned by 14:00"
---

# The broken box — Game Design Document

**Autor:** familia
**Tipo de Jogo:** Terror Assimétrico (Horror — PvP Multijogador)
**Plataforma:** Roblox (exclusivo)
**Benchmark criativo:** *Pwned by 14:00*
**Data:** 28 de Junho de 2026

---

## Resumo Executivo

### Conceito Central

The broken box é um jogo multijogador assimétrico de terror e sobrevivência para Roblox. Em cada partida, **1 jogador assume o papel de um Caçador** — uma criatura sobrenatural com habilidades únicas e aterradoras — enquanto **de 1 a 7 jogadores cooperam como Sobreviventes**, com um objetivo central diferente do gênero de fuga-por-objetivo: **resistir vivos até o Ciclo (cronômetro da partida) se esgotar e, quando ele zera, escapar por um dos portões numa corrida final coletiva.**

A partida tem duas fases. Na **Resistência**, o Caçador caça enquanto os Sobreviventes fogem e, opcionalmente, completam **missões** espalhadas pelo mapa. Cada missão concluída encurta o Ciclo (antecipa a fuga), rende moedas e neutraliza um perigo que, caso contrário, atrapalhará a corrida final. Na **Fuga**, disparada quando o Ciclo zera, os **3 portões abrem** e todos os vivos precisam atravessar dentro de uma janela finita, enfrentando os perigos deixados pelas missões que ninguém terminou.

Cada lado joga um jogo completamente diferente: o Caçador é forte, solitário e implacável; os Sobreviventes são frágeis individualmente mas capazes de virar o jogo através de cooperação, comunicação e uso inteligente de habilidades de classe.

Inspirado primariamente por *Pwned by 14:00* — referência de survival horror assimétrico "retraux" em que os Sobreviventes vencem pela resistência ao tempo, não pelo conserto de objetivos — e secundariamente por *Dead by Daylight* e *Flee the Facility* (cujo minigame clássico de hackeamento sobrevive aqui na Máquina de Petróleo). O jogo entrega a fantasia central de ser o predador implacável ou a presa que precisa usar tudo que tem para sobreviver, com a acessibilidade e o ritmo rápido que o público do Roblox espera.

### Público-Alvo

- **Primário:** Jogadores de Roblox entre 12 e 18 anos que curtem jogos competitivos, experiências multiplayer sociais e terror leve/acessível (sem gore, sem jumpscares excessivos).
- **Secundário:** Jogadores mais velhos (18+) familiarizados com o gênero assimétrico que buscam uma versão casual e rápida dentro do ecossistema Roblox.

### Diferenciais (USPs)

1. **Estética retraux Roblox-first:** Visual e som deliberadamente "Roblox antigo" (corpos R6 em bloco, studs, animações simples, áudio bitcrushed). Nostalgia de plataforma como identidade, não um port de outra plataforma.
2. **Terror moderado:** Atmosfera sombria e tensão sem sangue, gore ou jumpscares gratuitos. Adequado para 12+.
3. **Loop de resistência-e-fuga, não de conserto-e-escape:** O tempo é o relógio do jogo. Missões são opcionais e estratégicas (aceleram a fuga, removem perigos e rendem moedas), não um gate de vitória. Mantém a partida em perseguição constante, mais perto de *Pwned by 14:00* do que de *Flee the Facility*.
4. **Imprevisibilidade por partida:** Quantidade, tipo e posição das 10 missões variam a cada partida dentro de locais planejados, garantindo rejogabilidade sem dezenas de mapas.
5. **MVP enxuto e realista:** Escopo controlado para um desenvolvedor iniciante — 1 Caçador, 1 Mapa, 4 Sobreviventes, loja básica e lobby. Documentação completa que serve como aprendizado.

---

## Objetivos e Contexto

### Objetivos do Projeto

1. **Validar a dinâmica assimétrica de resistência no Roblox:** Provar que jogadores se divertem com Caçador vs Sobreviventes num loop de resistir-ao-tempo-e-fugir, em partidas de poucos minutos.
2. **Entregar um MVP jogável e polido em 3-4 semanas:** Foco em um Caçador, um Mapa e o loop principal funcional (Resistência + Fuga, 3 variáveis de missão, 3 portões) com as 4 classes de Sobreviventes.
3. **Servir como plataforma de aprendizado:** O desenvolvedor (iniciante em Roblox Studio e Luau) aprende fazendo — cada sistema documentado, cada decisão justificada.
4. **Base para expansão:** O design do MVP é modular — novos Caçadores, mapas, classes, skins e o aprofundamento da loja são planejados para fases posteriores.

### Contexto e Justificativa

O gênero assimétrico tem bases sólidas no Roblox (*Pwned by 14:00*, *Flee the Facility*) e fora dele (*Dead by Daylight*). Muitos títulos do gênero no Roblox são complexos demais ou rasos demais. The broken box ocupa o espaço do "assimétrico acessível mas com profundidade estratégica": adota o modelo de resistência-e-fuga de *Pwned by 14:00*, porém adiciona uma camada de missões opcionais que dão agência tática à equipe sem reintroduzir o ritmo lento do conserto-e-escape de *Flee the Facility*.

O projeto é desenvolvido por um único desenvolvedor iniciante (`familia`), aprendendo Roblox Studio e Luau durante o processo. O GDD é a fonte canônica de verdade para todas as decisões de design, alimentando as fases de arquitetura (`gds-game-architecture`) e criação de épicos e histórias (`gds-create-epics-and-stories`).

---

## Gameplay Principal

### Pilares do Jogo

| Pilar | Descrição |
|-------|-----------|
| **P1 — Poder Assimétrico** | Cada lado joga um jogo diferente. O Caçador é forte, solitário e implacável; sua presença domina o mapa. Os Sobreviventes são frágeis individualmente mas fortes em equipe. A assimetria está na experiência: ambos jogam em 3ª pessoa por padrão (com troca livre para 1ª). Ambos os lados correm e **pulam**, consumindo a mesma stamina, tornando o pulo ferramenta de navegação e esquiva. |
| **P2 — Tensão e Gato-e-Rato** | Silêncio tenso e furtividade interrompidos por perseguições frenéticas. A proximidade do Caçador é sentida por áudio (batimentos, passos) e distorção visual. Há um relógio: quando o Ciclo zera, a tensão difusa vira pânico concentrado na corrida pelos portões. A fuga final é o pico. |
| **P3 — Cooperação Estratégica** | Sobreviventes precisam se comunicar, dividir tarefas e calcular risco. Completar missões juntos encurta o Ciclo e desarma os perigos da Fuga, mas expõe. Jogar sozinho raramente compensa. As classes têm sinergia: o Médico cura e controla, o Soldado controla à distância, o Robô absorve e se sacrifica, o Sackboy atrapalha o Caçador. |
| **P4 — Variedade e Rejogabilidade** | Múltiplos Caçadores com habilidades radicalmente diferentes, classes de Sobreviventes com identidades próprias, distribuição aleatória de missões (quantidade, tipo e posição) a cada partida, 3 portões de fuga e um mapa com rotas e estruturas variadas. Nenhuma partida é igual. |

### Loop Principal de Gameplay

\`\`\`
┌──────────────────────────────────────────────────────────┐
│ 1. PREPARAÇÃO                                            │
│    Sobreviventes spawnam em posições aleatórias.         │
│    Caçador spawna em local fixo.                         │
│    Timer de 5s antes do início da caçada.                │
│    O Ciclo (cronômetro da partida) começa a contar.      │
├──────────────────────────────────────────────────────────┤
│ 2. RESISTÊNCIA                                           │
│    Caçador patrulha usando sentidos e habilidades.       │
│    Sobreviventes fogem, pulam para esquivar e,           │
│    opcionalmente, completam MISSÕES.                     │
│    Cada missão concluída: -10s no Ciclo + moedas +       │
│    desarma o perigo daquela missão na Fuga.              │
├──────────────────────────────────────────────────────────┤
│ 3. PERSEGUIÇÃO                                           │
│    Encontro Caçador-Sobrevivente → perseguição.          │
│    Sobrevivente usa obstáculos, pulo-esquiva,            │
│    habilidades e looping; pode stunar o Caçador.         │
│    Caçador stunado: trava por T s, depois 2s de i-frames.│
│    HP do Sobrevivente a 0 → MORTE → espectar ou lobby.   │
├──────────────────────────────────────────────────────────┤
│ 4. FUGA                                                  │
│    O Ciclo zera → os 3 PORTÕES abrem.                    │
│    O cenário começa a queimar (estético, sem dano).      │
│    Todos os vivos correm para um portão na janela.       │
│    Missões pendentes deixam perigos ativos na rota.      │
│    Ninguém escapa → Caçador vence; mapa desmorona.       │
└──────────────────────────────────────────────────────────┘
\`\`\`

### Condições de Vitória e Derrota

| Condição | Vencedor | Gatilho |
|----------|----------|---------|
| **Fuga Total** | Sobreviventes | Todos os vivos atravessam um dos 3 portões antes de a janela de Fuga fechar. |
| **Fuga Parcial** | Sobreviventes | Ao menos 1 Sobrevivente atravessa um portão. Apenas quem fugiu ganha moedas de fuga. |
| **Contenção Total** | Caçador | A janela de Fuga fecha e ninguém escapou: todos mortos ou presos. O mapa é destruído. |
| **Caçada** *(pós-protótipo)* | Sobreviventes | HP do Caçador chega a 0. Encerra a rodada na hora; todos os vivos vencem. Realista só contra o Amaldiçoado (500 HP). |

**Regra de fuga parcial:** se ao menos 1 Sobrevivente escapar, a vitória é de equipe. Como só quem atravessa o portão ganha moedas de fuga, há incentivo individual para correr o risco da corrida final.

**Sobre o tempo:** diferente de *Flee the Facility* e do GDD v1.0, esgotar o Ciclo **não** é derrota dos Sobreviventes — é o **gatilho da Fuga**. Missões não são pré-requisito de vitória: apenas tornam a Fuga mais curta (-10s/missão no Ciclo) e mais segura (cada missão pendente vira perigo na rota).

---

## Mecânicas do Jogo

### Mecânicas Primárias

#### M1 — Missões (V1, V2, V3)

As missões substituem o sistema de geradores do gênero conserto-e-escape. **Não são obrigatórias para vencer.** Servem para três fins: encurtar o Ciclo (antecipar a Fuga), desarmar perigos da Fuga e render moedas.

- **Quantidade:** 10 missões (instâncias) por partida.
- **Distribuição:** quantidade, tipo e posição **aleatórios a cada partida**, dentro de locais planejados, com **mínimo de 1 de cada variável**. Ex.: 5 V1 / 3 V2 / 2 V3 numa partida; 1 V1 / 1 V2 / 8 V3 em outra.
- **Recompensa ao concluir (qualquer variável):** **-10s no Ciclo** + moedas (COIN_MISSAO = 15) + **desarma o perigo daquela missão na Fuga**.
- **Regra de ouro:** as **penalidades só se manifestam na fase de Fuga**. Durante a Resistência, missão pendente não pune.
- **Vulnerabilidade atencional (não posicional):** executar uma missão **abre a UI do minigame na tela** (ocupa atenção e visão), mas **não trava o jogador nem o revela** ao Caçador. **Mover-se cancela/encerra a missão** a qualquer momento. O risco é ficar "de cabeça baixa", vulnerável a ser surpreendido.

| Var | Missão | Minigame | Repetições | Perigo se pendente (só na Fuga) |
|-----|--------|----------|:---:|---|
| **V1** | Disjuntor de Energia | Colocar todas as alavancas para a direita; ao completar, o minigame reinicia | **4x** | As luzes da área próxima ao disjuntor **apagam** (escuridão localizada). |
| **V2** | Gerador | Conectar **5 cabos** | **4x** | **Barreira elétrica** na passagem próxima: **10 de dano por travessia**. |
| **V3** | Máquina de Petróleo | Minigame idêntico ao do PC de *Flee the Facility* (ponteiro/zona de acerto) | **1x** | **Poça grande**: **35% de lentidão** em quem pisar. |

**Detalhe da Barreira Elétrica (V2):** dano por travessia, com **janela de imunidade de 5s** — se o mesmo jogador atravessa 2+ vezes em menos de 5s, só o dano da primeira conta. Não pode ser destruída na Fuga: a única forma de neutralizá-la é concluir a missão durante a Resistência.

**Nota de design (mapa):** como os perigos nascem onde as missões estavam, os locais planejados ficam **sobre ou perto das rotas de fuga aos 3 portões**, para que a penalidade crie pressão real na corrida final.

#### M2 — Portões e Fuga

- **Quantidade:** **3 portões** em posições fixas, um dentro de cada estrutura principal (Caverna, Castelo, centro do Estoque).
- **Ativação:** os 3 abrem automaticamente quando o **Ciclo zera**, dando início à Fuga. Sem alavanca nem pré-requisito de missões.
- **Janela de Fuga:** base **60s**, reduzida em **5s por missão não concluída** (piso de **10s**). **Mortes não estendem a Fuga.**
- **Perigos na rota:** cada missão pendente mantém dois efeitos na Fuga — o **-5s** na janela **e** o perigo específico da sua variável (escuridão / barreira elétrica / poça).
- **Incêndio estético:** ao iniciar a Fuga, o cenário começa a queimar. O fogo **não causa dano** — serve para sinalizar o colapso e criar urgência.
- **Encerramento:** ao fim da janela, **o mapa é destruído** (consumido pelo fogo); quem não atravessou um portão morre. Apenas quem escapou ganha moedas de fuga (COIN_FUGA = 40).

#### M3 — Morte e Pós-Morte

Não há estado Derrubado, captura, jaula nem resgate.

- **Morte:** HP a 0 → **morte imediata**, eliminado da partida. Sem segunda chance no chão.
- **Cura antes da morte:** HP recupera enquanto acima de 0 (só via Médico e Block do Robô; sem regen passiva). Em 0, está morto.
- **Extensão do Ciclo por morte:** **cada morte de Sobrevivente (qualquer causa) adiciona +20s ao Ciclo** durante a Resistência. Mecânica de catch-up. Mortes na Fuga não estendem nada.
- **Pós-morte (escolha do jogador):**
  - **Espectar:** câmera que segue um Sobrevivente vivo, ciclável entre os restantes; ou
  - **Lobby:** sair para a Caixa e fazer o que quiser (navegar, comprar na loja, customizar). Pode voltar a espectar até a partida acabar.

#### M4 — Stamina e Pulo (ambos os lados)

A stamina cobre **correr e pular**, e **os dois lados têm stamina** (fiel a *Pwned by 14:00*).

- **Gasto ao correr:** 7/s. **Regeneração:** 9/s. A stamina **regenera quando não se está correndo** — andar em velocidade normal **não impede** a regeneração; só correr gasta.
- **Esgotamento:** ao chegar a 0, **0,5s de atraso** antes de a regeneração recomeçar.
- **Pulo:** custo **10 de stamina**, **cooldown de 2s**. O pulo é alto o suficiente para **saltar por cima da hitbox do M1** — é a janela de esquiva do ataque básico. O cooldown de 2s impede spam e torna o timing uma decisão real.
- **Dash e stamina:** durante qualquer dash, a regeneração de stamina fica **pausada** (sem consumo adicional, mas sem recuperar). Vale para todo dash (Soldado, Médico e futuros).

| Personagem | Stamina | Corrida (~14,3s/100) | Velocidade |
|---|---:|---:|---:|
| Caçadores (Distorcido etc.) | 110 | ~15,7s | 26 (base) |
| Soldado | 110 | ~15,7s | 20 |
| Robô | 110 | ~15,7s | 18 |
| Médico | 100 | ~14,3s | 22 |
| Sackboy | 70 | ~10s | 26 |
| Alma (pós-MVP) | 100 | ~14,3s | 22 |

### Mecânicas do Caçador

#### M5 — Fúria e Rage (exclusiva d'O Distorcido)

- **Medidor de Fúria:** 0 a 100+ (acumula acima do limiar).
- **Ganho de Fúria:**
  - **+10** ao ser atacado/atordoado.
  - **+1/s** após **20s contínuos** a ≤40 studs de algum Sobrevivente (pode **trocar de alvo** sem zerar; sair do raio zera a contagem).
  - **+10 por morte feita durante o Rage**, creditado ao sair do Rage.
- **Ativação:** medidor **≥80 E fora da fase de Fuga**. **Sem limite de usos.** Windup de **5s** (transformação comprometida e vulnerável, não cancelável). Ao completar, **causa 20 de dano em área (raio 30 studs)**.
- **Durante o Rage:** o **Ciclo pausa**; M1 **+5** (→25); velocidade **+2** (→28); o Grito passa a causar **10 de dano**; **O Distorcido muda de forma** (a criatura). **Duração: 30s + 10s por morte feita durante o Rage** (extensão por-Rage, reinicia a cada ativação).
- **Ao sair:** o Ciclo volta; forma e stats normalizam; medidor vai a **0 + 10 por morte feita no Rage**.

> Exemplo: 2 mortes no Rage → dura 30 + 20 = 50s; ao sair, medidor inicia em 20; a extensão de 20s não conta no próximo Rage.

#### M6 — Stun e I-frames (regra universal)

- **Stun:** trava movimento e habilidades do Caçador por T segundos (definido em cada habilidade).
- **I-frames:** ao se recuperar de qualquer stun, o Caçador ganha **2s de invencibilidade** (não pode ser atacado nem stunado de novo). Evita stun-lock encadeado.

#### M7 — Câmera e Visão do Caçador

- **Perspectiva livre (3ª pessoa padrão, toggle 1ª)** para Caçador e Sobreviventes, ao estilo *Forsaken* / *Pwned by 14:00*. FOV padrão Roblox (~70°).
- **Assimetria de informação:** o Caçador **não vê os Sobreviventes pela UI** — nada de lista, **classe** ou **barra de HP**. Vê apenas o **número de vivos** (para a condição de vitória). Os Sobreviventes, cooperativos, continuam vendo aliados e o HP da equipe. A ignorância força o Caçador a descobrir a composição na perseguição.
- **Indicadores:** marcador direcional no HUD apenas para casts conspícuos (ex.: Bazuca). Correr, mover-se e executar missão **não** alertam (corrida é cosmética; missão abre só a UI do minigame).

### Controles e Input

#### Sobreviventes (3ª pessoa padrão)

| Ação | Input (PC) | Input (Mobile) |
|------|-----------|----------------|
| Mover | WASD | Joystick virtual esquerdo |
| Olhar / Câmera | Mouse | Toque/arrastar |
| Pular | Espaço | Botão de pulo |
| Correr | Shift (segurar) | Botão dedicado (segurar) |
| Interagir (missão, portão) | E | Botão contextual |
| Trocar perspectiva (1ª/3ª) | (livre) | (livre) |
| Habilidade 1 | (remapeável) | Botão 1 |
| Habilidade 2 | (remapeável) | Botão 2 |
| Habilidade 3 (Robô) | (remapeável) | Botão 3 |

#### Caçador (3ª pessoa padrão)

| Ação | Input (PC) | Input (Mobile) |
|------|-----------|----------------|
| Mover | WASD | Joystick virtual esquerdo |
| Olhar / Câmera | Mouse | Toque/arrastar |
| Pular | Espaço | Botão de pulo |
| M1 (Ataque Básico) | Clique Esquerdo | Botão de ataque |
| Braço Esticado | (remapeável) | Botão 1 |
| Grito | (remapeável) | Botão 2 |
| Rage | (remapeável) | Botão 3 |

> **Notas:** não há agachar. Todos os binds de habilidade são **remapeáveis**. A perspectiva (1ª/3ª) é livre para os dois papéis; ninguém é obrigado a jogar em 1ª pessoa.

### Mecânicas Específicas do Gênero (Horror)

O núcleo de terror vive em três sistemas: o **relógio de pressão** (Ciclo + Fuga), a **morte sem volta** (HP a 0 = espectador/lobby, sem resgate) e a **leitura de proximidade** (áudio e distorção). A ausência de captura/resgate torna cada perseguição mais letal e cada decisão de fazer uma missão mais arriscada.

---

## Design Específico de Terror

### Atmosfera e Construção de Tensão

#### Design Visual de Atmosfera (Retraux)

- **Linguagem visual:** estética **retraux** — Roblox antigo. Corpos **R6 em bloco**, **studs** aparentes, baixa poligonização, animações simples e "duras". O terror vem do estranhamento nostálgico: brinquedos e cenários familiares renderizados de um jeito velho e errado.
- **Paleta:** cores primárias de brinquedo **desbotadas/desaturadas** (o desbotado é a "criatividade morta"); preto e sombra profunda nas zonas de horror; o Caçador em preto com fragmentações e âmbar.
- **Iluminação:** alto contraste, sombras densas. A penalidade da missão V1 (Disjuntor) conversa diretamente com isto: áreas não estabilizadas apagam na Fuga, transformando rotas conhecidas em corredores cegos.
- **Tom (alegre-sinistro / liminal):** um playset de criança fofo por fora, abandonado e errado por dentro. Sem gore, sem sustos baratos: o desconforto vem da familiaridade deformada.

#### Design de Áudio de Tensão (Bitcrushed)

- **Textura geral:** áudio **bitcrushed / lo-fi**, como gravação antiga.
- **Trilha dinâmica em 3 camadas (stems)**, crossfade de 2s por distância do Caçador: Calma → Alerta (60 studs) → Perseguição (30 studs).
- **Efeitos de tensão:** batimentos do Sobrevivente (sobem com a proximidade), rangidos de papelão, sussurros abafados, passos pesados e distorcidos do Caçador.
- **Pico da Fuga:** som global de colapso/incêndio ao zerar o Ciclo, virando a trilha para um clímax bitcrushed agressivo.

#### Ritmo de Tensão (Ciclo de 4:00 + Fuga)

- **Estrutura em 3 atos** (Ciclo base 240s, esticado por mortes):
  - **Ato 1 — Dispersão (~0:00 a 1:30):** tensão baixa. Sobreviventes se espalham; primeiras missões; o Caçador se posiciona e constrói Fúria por proximidade.
  - **Ato 2 — Pressão (1:30 até o Ciclo zerar):** tensão alta. Perseguições, primeiras mortes (+20s cada), provável janela de Rage. A equipe decide entre arriscar missões ou só sobreviver.
  - **Ato 3 — Fuga:** tensão máxima. O mapa expira e queima, os 3 portões abrem, os perigos pendentes acendem. Decisões de vida ou morte numa janela que encurta 5s por missão não feita.
- **Sem jumpscares programados:** o medo vem da antecipação e da corrida final.

### Mecânicas de Medo

#### Visibilidade e Escuridão
- Iluminação variável por área (zonas de horror quase sem luz). Sem lanterna no MVP: a escuridão é ameaça ambiental.
- **Escuridão dinâmica (V1):** Disjuntores pendentes apagam suas áreas na Fuga, criando trechos cegos quando a velocidade importa.
- **Silhueta do Caçador:** sempre um tom mais escuro que o ambiente.

#### Vulnerabilidade
- **Sobreviventes causam dano ao Caçador** (ver fichas) e, em teoria, podem matá-lo (Caçada; realista só vs Amaldiçoado). A defesa principal é posicionamento, **pulo-esquiva**, quebra de linha de visão e habilidades.
- **Sem bloqueio passivo, sem agachar, sem esconderijo.** Sobreviver é movimento ativo e leitura do Caçador.
- **Stamina finita:** correr e pular saem do mesmo medidor.
- **Missão ocupa atenção, não posição.**
- **Morte permanente:** sem Derrubado, sem resgate.

#### Indicadores de Proximidade
- **Batimentos cardíacos:** audíveis a 40 studs, sobem com a proximidade.
- **Distorção de borda:** a tela escurece/distorce nas bordas a 20 studs.

### Design de Inimigo/Ameaça

#### O Distorcido (Caçador MVP)

| Atributo | Valor |
|----------|-------|
| HP | 2000 |
| Velocidade base | 26 studs/s |
| Velocidade em Rage | 28 studs/s |
| Stamina | 110 |
| Limiar de Rage | 80 |
| Aparência base | Um boneco com **partes pretas saindo** e **fragmentações/rachaduras**, sinais da criatura presa dentro de si. |
| Aparência em Rage | O boneco **se torna a criatura** — grande demais para o invólucro, com **mãos e torso rasgados**, pretos e expostos. |
| Som de passos | Pesados, com eco distorcido e deslocado da posição real (bitcrushed). |

**Lore:** Um cientista criou uma entidade instável — a "coisa preta" — que, por acidente, entrou em um boneco, fundindo-se a ele, deixando-o instável e fragmentado, com partes escuras vazando pelas rachaduras. No processo, a criatura **matou o próprio criador**. A alma do cientista ficou presa neste lugar (e habitará um Sobrevivente futuro).

**Habilidades** (ver tabela-mestra para tempos exatos):
1. **M1 — Tapa:** 20 de dano (25 em Rage), 5 hitboxes em 0,5s, empurra 3 studs.
2. **Braço Esticado (Pull):** projétil de hitbox móvel, **15 studs/s × 2s = 30 studs**, puxa o Sobrevivente e atordoa 0,5s. Esquivável com pulo.
3. **Grito:** slow 40%/3s + tela borrada (raio 60), revelação por 4s (raio 100). **10 de dano em Rage.** Hitbox de área radial.
4. **Rage:** transformação com windup de 5s que termina num pulso de **20 de dano em área (raio 30)**; ver M5.

#### Estratégia de Patrulha do Caçador
- **Início:** ocupar o centro e acumular Fúria mantendo pressão de proximidade (≤40 studs) sobre quem dispersou.
- **Meio:** Grito para revelar/isolar; Braço Esticado para punir posicionamento; decidir entre forçar mortes (esticam o Ciclo, mas alimentam o próximo Rage) e guardar a Fúria.
- **Fim (rumo à Fuga):** posicionar-se entre os 3 portões e os perigos das missões pendentes. **Rage não pode ser usado na Fuga** — convém gastá-lo antes.
- **Contra classes:** Médico é prioridade (cura/controle); Robô é resistente mas lento (cercar); Sackboy controla muito (cuidado com stun).

### Escassez de Recursos
- **HP limitado:** cura só via Médico (Poção, 25) e Robô (Block, 10). Sem regen passiva. HP a 0 = morte definitiva.
- **Stamina finita:** correr e pular competem pelo mesmo recurso.
- **Tempo de dois gumes:** missões encurtam o Ciclo (boa antecipação) mas expõem; mortes esticam o Ciclo (fôlego) mas reduzem a equipe.
- **Sem recursos de luz.**

### Quebra de Linha de Visão e Rotas
Com esconderijos e pós-resgate removidos, o respiro vem do mapa: as 3 estruturas têm funções de perseguição distintas — **Caverna (esconder)**, **Estoque/labirinto (despistar)** e **Castelo (loopar)**. Zonas mortas são armadilhas se o Caçador está perto, mas servem para despistar com timing. Na Fuga, evitar zonas mortas é vital.

### Integração de Puzzles
- **Minigames de missão como puzzles:** V1 (execução repetida de alavancas), V2 (conexão de 5 cabos), V3 (timing de ponteiro, à la Flee). Todos prendem a UI sem travar o movimento.
- **Conhecimento do mapa como puzzle:** sem minimapa; missões sem seta direcional (achadas por exploração/som). Como posição e quantidade variam, é preciso ler o mapa daquela rodada e priorizar missões perto das rotas de portão.

---

## Personagens — Elenco Completo

### Caçadores

Todos os Caçadores podem ser **mortos** pelos Sobreviventes (HP a 0 → **Caçada**, vitória dos Sobreviventes). Na prática, só o **Amaldiçoado** (500 HP) é alvo realista; os demais têm HP alto e só caem com coordenação extrema. O Caçador só é imune durante janelas de invencibilidade (i-frames de 2s pós-stun e os 8s do Agarrar do Robô).

#### 1. O DISTORCIDO (MVP)
- **HP:** 2000 · **Velocidade:** 26 (28 Rage) · **Stamina:** 110 · **Limiar de Rage:** 80
- Aparência, lore e habilidades: ver Design de Inimigo/Ameaça.
- **Skin planejada (pós-MVP):** "Flowers" — Fase 1: robloxiano com flores crescendo de dentro; Fase 2 (Rage): a criatura preta. *Validar originalidade/direito de uso antes de publicar (referencia um ARG de terceiro).*

#### 2. AMALDIÇOADO (Pós-MVP) — *renomeado de "Boneco de Pano"*
- **HP:** 500 (glass killer, o único realisticamente matável) · **Velocidade:** 26
- **Aparência:** boneco de pano amaldiçoado, rasgado, com uma pedra brilhante no peito. A cor da pedra muda com o modo do laser: VERMELHO = ataque, VERDE = cura, AZUL = lentidão.
- **Lore:** um boneco de pano comum, até ser amaldiçoado pela pedra que hoje o controla. Frágil como todo boneco de pano, movido por uma maldição que não é dele. **É o mesmo boneco/alma do Sackboy Sobrevivente** — um livre, o outro sob controle da pedra.

| Habilidade | Descrição | Números |
|-----------|-----------|---------|
| M1 | Ataque corpo a corpo. | 20, alcance 5 |
| Dash | Após windup, voa na direção do olhar (hitbox móvel, para em alvo/parede). | Dano 30 + slow 3s |
| Laser (3 modos, cicla) | Ativa por 10s; movimento muito lento. | CD 20s |
| — Vermelho | Autocura. | 20 HP/s |
| — Verde | Dano contínuo. | 5/s |
| — Azul | Lentidão + revelação. | Slow 40%, revela 15s |

#### 3. SOLDADO FUNDIDO (Pós-MVP) — *renomeado de "Soldado" Caçador*
- **HP:** 1500 · **Velocidade:** 24
- **Aparência:** aberração de soldadinhos derretidos e fundidos num único soldado grande.
- **Lore:** era o **capitão** de uma tropa de soldadinhos. Quando algo os derreteu e fundiu, foi absorvido e tornou-se a criatura feita de todos eles. Antes da fusão final, **salvou um único soldado** (o Soldado Sobrevivente) — e agora, incompleto, caça justamente essa peça que falta para se completar.

| Habilidade | Descrição | Números |
|-----------|-----------|---------|
| M1 | Ataque pesado. | 30, alcance 5 |
| Sentinela | Soldado fixo que atira: lentidão, revelação e BLOQUEIO de habilidades (sem dano). | Máx. 5 |
| Míssil Bazuca | Para 2s, dispara míssil. Direto 35 + explosão (5 + slow). | CD 18s |
| Marca + Teleporte | Deixa marca; teleporta para ela (chegada: 20 em área + boost). | CD 30s |

#### 4. COMPASSO (Pós-MVP)
- **HP:** 1000 · **Velocidade:** 28
- **Aparência:** materiais escolares fundidos — compasso gigante como braço, lápis no torso, réguas e borrachas incrustadas.
- **Lore:** foi o **primeiro protótipo do Construtor**. O protótipo se revoltou e **matou o criador**. Sem carcaça de robô, cobriu-se com o que havia na sala de aula até virar esta aberração escolar.

| Habilidade | Descrição | Números |
|-----------|-----------|---------|
| M1 | Corte com sangramento. | 15 + 10 em 4s |
| Dash (Colossus) | Avança com curva; empala até 3 e arremessa. | até 3 alvos |
| Lápis | Arremessa (hitbox móvel). Acerto: 10 + ragdoll 3s + "cravado" 20s (+5 dano recebido, revelado). | — |
| Recall | Chama o lápis de volta; 10 ao portador; dá velocidade + invencibilidade ao Caçador. | — |

### Sobreviventes

Todos compartilham **velocidade base 22** (correndo gasta stamina; stamina cobre o pulo). **Sem agachar e sem esconderijos.** **HP a 0 = morte definitiva** (espectar ou lobby).

**Dano dos Sobreviventes ao Caçador é aplicado 1 vez por alvo colidido com a hitbox** (não por hitbox individual; o mesmo alvo nunca empilha).

#### 1. SOLDADO SOBREVIVENTE
- **HP:** 120 · **Velocidade:** 20 · **Stamina:** 110
- **Lore:** o soldado que o capitão salvou antes da fusão. Escapou com a bazuca do arsenal, mas a criatura que seu capitão virou nunca parou de procurá-lo — é dele que o Soldado Fundido precisa para se completar.
- **LMS (condicional, vs Soldado Fundido):** velocidade → 22, +30% dano de Bazuca. *(Heroico: o confronto de destino.)*

| Habilidade | Descrição | Hitbox | Dano ao Caçador |
|-----------|-----------|--------|:---:|
| Dash Tático | Avança (hitbox móvel, dura até 15s, para em Caçador/parede; sem regen de stamina no dash). Empurra 10 + silêncio 3s. | Móvel | 20 |
| Bazuca | Modo de mira (limite 10s); hitbox fina **3×3×100 studs** instantânea (para na parede). | Linha 3×3×100 | 40 |

#### 2. SACKBOY SOBREVIVENTE
- **HP:** 110 · **Velocidade:** 26 · **Stamina:** 70
- **Lore:** um boneco de pano intacto — sem rasgos, sem pedra. Escapou antes que a maldição encontrasse hospedeiro. **A mesma alma habita os dois Sackboys**: este, livre; o Amaldiçoado, controlado pela pedra.
- **LMS (condicional, vs Amaldiçoado):** velocidade → 28, stamina → 80. *(A alma livre enfrenta a si mesma sob a maldição.)*

| Habilidade | Descrição | Hitbox | Dano ao Caçador |
|-----------|-----------|--------|:---:|
| Arma de Tinta (carga 1/2/3) | Hitbox fina **3×3×100 studs** (para na parede); segura para carregar (3 cargas). C1 slow 30%; C2 slow 40% + silêncio 4s; C3 stun 2s + blur. | Linha 3×3×100 | 5 / 10 / 15 |
| Surto | +6 velocidade + pulo mais alto por 5s. | — | — |

#### 3. ROBÔ — *exatamente 3 habilidades*
- **HP:** 150 (maior entre Sobreviventes) · **Velocidade:** 18 (o mais lento, tanque) · **Stamina:** 110
- **Lore:** um robô de brinquedo que nunca deveria ter sido ligado. Resistente, com um protocolo final que nenhum brinquedo deveria ter.
- **Restrição de cura:** só pode se curar pelo próprio Block.
- **LMS (incondicional):** buff de sobrevivência. *(Trágico: ele deveria ter explodido pelos outros, não sobrado.)*

| Habilidade | Descrição | Hitbox | Dano ao Caçador |
|-----------|-----------|--------|:---:|
| Agarrar | Projétil móvel (viaja 2s, ~30 studs); puxa o Caçador até o Robô. O Robô fica **imóvel até o braço voltar** (fim dos 2s ou colisão com alvo/parede/chão). Dá **8s de invencibilidade** ao Caçador + desabilita habilidades dele (+1s após). Não atravessa parede. | Projétil | 0 |
| Block | Postura de contra-ataque (janela 1,5s). Se atingido: silêncio 3s no Caçador + autocura 10. | Área reativa | 10 |
| Autodestruição | Para 3s → boost de velocidade 5s → explode. Auto-dano 40 + slow 8s. Explosão no Caçador: arremessa 100 + stun 6s. | Área | 100 |

> **Anti-sinergia proposital:** o Agarrar dá invencibilidade ao Caçador por 8s — usá-lo antes de uma Autodestruição **desperdiça** o dano (o killer fica imune). Coordenar os dois é um erro a ser respeitado no balanceamento.

#### 4. MÉDICO — *novo, substitui a Enfermeira*
- **HP:** 80 · **Velocidade:** 22 · **Stamina:** 100
- **Papel:** suporte/cura de equipe + controle.
- **Lore:** o brinquedo que cuidava dos outros quando ninguém olhava. Segue curando, protegendo e mantendo os amigos de pé.
- **LMS (incondicional):** buff. *(Trágico: sua missão era salvar todos; estar sozinho significa que falhou.)*

| Habilidade | Descrição | Hitbox | Dano ao Caçador |
|-----------|-----------|--------|:---:|
| Poção em Área (A1) | Cura aliados próximos (cura 25, raio 12). Cada curado **acumula** no contador da A2. | Área (aliados) | — |
| Investida Medicinal (A2) | Golpe de área: **cubo único de 10 studs ao redor do Médico**. Efeito escala com curados; **contador zera só ao acertar o Caçador**. | Cubo (10) | 0 / 10 / 20 / 30 |
| — 0 curados | Apenas empurra. | | 0 |
| — 1 curado | Empurra + desabilita habilidades 3s. | | 10 |
| — 2 curados | Empurra mais longe + desabilita habilidades 5s. | | 20 |
| — 3+ curados | Stun 3s + velocidade ao Médico + autocura 20. | | 30 |

#### 5. ALMA — *novo, substitui o Campeão (Pós-MVP; "starter grátis" futuro)*
- **HP:** 100 · **Velocidade:** 22 · **Stamina:** 100
- **Papel:** furtividade, controle e mobilidade.
- **Lore:** uma alma sem corpo, que não encontrou um boneco para se hospedar. Vaga como um vulto espectral, despistando a criatura e abrindo caminho.

| Habilidade | Descrição | Hitbox | Dano ao Caçador |
|-----------|-----------|--------|:---:|
| A1 — Desvanecer | Levemente invisível e irrastreável por 4s. | — | — |
| A2 — Grito Dilacerante | Projétil maior que o do Soldado. Acerto: tela borrada + lentidão 5s. | Móvel | 0 |
| A3 — Lampejo (Dash) | Dash curto. Custo 10 de stamina. | Móvel | — |

### Backlog de Roster — Fichas Completas (Pós-MVP)

#### CIENTISTA (classe única — futuro Sobrevivente)
A alma do criador da coisa preta, presa na mansão. Kit de poções com efeito em aliados e no Caçador. **4 habilidades.**

| # | Habilidade | Descrição |
|---|-----------|-----------|
| 1 | Poção (arremesso) | Arremessa; efeito depende do tipo ativo e de quem acerta. Consome 1. |
| 2 | Criação | Senta 6s e cria 1 poção. Estoque máx. 3. |
| 3 | Beber | Bebe 1 poção, efeito reduzido. |
| 4 | Trocar | Alterna o tipo ativo entre os 3. |

| Tipo | Acerta Sobrevivente | Acerta Caçador | Ao Beber |
|---|---|---|---|
| 1 | Resistência 5s | Lentidão 5s | Resistência pequena 5s |
| 2 | Cura 20 em 10s | Empurra + ragdoll 3s | +Velocidade 3s |
| 3 | +Velocidade 5s | Sem habilidade + fraqueza 5s | +10 HP instantâneo |

#### CONSTRUTOR (classe — lado a definir; criador morto pelo Compasso)
**3 habilidades.**

| # | Habilidade | Descrição |
|---|-----------|-----------|
| 1 | Eficiência | Faz missões 2x mais rápido (conta como 2; Petróleo enche 2x). Passiva. |
| 2 | Armadilha (mina) | Máx. 8. Caçador pisa → alerta → após 3s explode, stunando se ainda estiver nela. |
| 3 | Rastreador | Revela todos para si; o Caçador é revelado para Sobreviventes próximos a ele. |

**Ganchos narrativos do universo:** Alma do Cientista (criou a coisa preta, morto pelo Distorcido) e Construtor (construiu o Compasso, morto por ele) são dois "criadores mortos pela própria criação", a manter distintos. Eco temático possível entre o Construtor ("sem carcaça de robô") e o Robô Sobrevivente.

---

## Design do Mapa — Criatividade Morta (Protótipo)

### Visão Geral

| Atributo | Valor |
|----------|-------|
| Nome | Criatividade Morta |
| Tamanho | Médio |
| Topografia | **Plano**, com relevos suaves, pontuado por **3 estruturas principais** e por pequenos obstáculos (props propositais ou peças derrubadas) |
| Estilo | Mundo de brinquedos feito à mão em papelão, **retraux** (R6/studs, baixo poli), inspiração de tom em LBP com **assets originais**. Áudio bitcrushed. |
| Lore | O mundo de brinquedos que o Sackboy habitava, abandonado. O nome é o motivo temático: a criatividade da criança que montou tudo morreu, e o que sobrou é alegre por fora e apodrecido por dentro. |
| Tempo de travessia | ~25s de ponta a ponta (correndo) |
| Início da Fuga | O cenário **começa a queimar** (sem dano, estético): sinaliza o colapso e cria urgência. |
| Fim de partida | Ao fechar a janela de Fuga, a caixa **desmorona** (consumida pelo fogo); quem não escapou morre. |

### Lobby — A Caixa
A caixa de brinquedos fechada é o **lobby** (hub fora da partida): ponto de partida das rodadas, espaço social e **loja**. Contém **O Vendedor** (loja estilo Noli) e pequenas distrações interativas. Tom de "criatividade morta": aconchegante por fora, abandonada por dentro. Dela, os brinquedos "saem" para o mapa.

### As 3 Estruturas Principais (função de perseguição)

| Estrutura | Característica | Função de design | Portão |
|---|---|---|---|
| **O Castelo** | Alto, escalável por fora e percorrível por dentro | **Loopar** (looping spot — circular obstáculos e ganhar distância) | P2 (interno + subida) |
| **A Caverna** | Mais escura e rebaixada | **Esconder** (sumir da linha de visão, respirar) | P1 |
| **O Estoque de Materiais** | Labirinto de corredores/prateleiras | **Despistar** (juke/mind-game; o Caçador perde o rastro nas curvas) | P3 (no centro) |

O "chão" entre as estruturas é plano com relevos, povoado por obstáculos propositais e **peças derrubadas** (cobertura, quebra de linha de visão, plataformas baixas para pulo).

### Camada de Atmosfera de Terror
Por baixo da estética de brinquedo, o mapa esconde horror ambiental (**sem gore, pouquíssimo sangue**):
- **Caverna:** locais sombrios e corpos de brinquedo.
- **Salas do Castelo:** cantos escuros e corpos internos.
- **Estoque (labirinto):** **bonecos fundidos aos materiais** (eco da lore de fusão — Soldado Fundido, Compasso).

### Pontos de Interesse

| Tipo | Quantidade | Posicionamento |
|------|-----------|----------------|
| Locais planejados de missão | ~14 candidatos (10 ativos por partida) | Distribuídos entre as 3 estruturas e o campo aberto; densidade maior nas aproximações das 3 rotas de fuga. |
| Portões de Saída | 3 fixos | P1 Caverna, P2 Castelo (interno + subida), P3 centro do Estoque. |

### Posicionamento de Missões e Perigos
- **V1 Disjuntor → escuridão:** Caverna e aproximações (já escuras; pendentes, ficam cegas na Fuga).
- **V2 Gerador → barreira elétrica:** gargalos do Estoque e entradas do Castelo.
- **V3 Petróleo → poça (35% slow):** campo aberto e rampas largas.

### Fluxo de Navegação
- **Campo aberto + relevos:** favorece perseguições de leitura, equilibrado por obstáculos que dão cobertura e pulo-esquiva.
- **Verticalidade concentrada no Castelo** (subir = decisão tática).
- **Densidade no Estoque** (quebra perseguição, arriscado na Fuga).
- **Caverna como aposta** (boa para sumir, perigosa sem Disjuntores feitos).
- **3 rotas de Fuga:** Caverna (P1), Castelo (P2, interno + topo), centro do Estoque (P3). Na Fuga, evitar zonas mortas é vital.

### Variação por Partida

| Elemento | Variação |
|----------|----------|
| Missões | 10 instâncias sorteadas entre ~14 locais; tipo sorteado por local, ≥1 de cada; quantidade por tipo varia livremente. |
| Obstáculos derrubados | Podem variar de posição por partida (opcional). |
| Perigos na Fuga | Determinados pelas missões pendentes. |
| Portões | Sempre os mesmos 3. Abrem juntos no fim do Ciclo. |

---

## Progressão e Balanceamento

### Progressão de Jogador (Fora de Partida)

O protótipo inclui **economia de moedas persistente e a loja da Caixa** (DataStore no escopo do MVP), porque são o gancho de retenção que valida o ciclo jogar → ganhar → desbloquear.

#### MVP — Loja da Caixa e Moedas
- **Onde:** lobby (A Caixa), com **O Vendedor** (estilo Noli).
- **Moeda:** persistente por conta, via **DataStore**.
- **Ganho:** missão concluída = **15** (COIN_MISSAO); fuga bem-sucedida = **40** (COIN_FUGA, só para quem atravessou um portão).
- **Gasto:** desbloqueio de personagens; skins no backlog (incl. "Flowers").
- **Roster grátis vs pago no protótipo:**

| Personagem | Status |
|---|---|
| O Distorcido | Grátis (único Caçador) |
| Sackboy | Grátis |
| Médico | Grátis |
| Soldado | Pago (moedas) |
| Robô | Pago (moedas) |

*(Backlog: quando a Alma entrar, assume o papel de Sobrevivente "starter grátis".)*

#### Pós-MVP — Progressão Planejada
- Nível de Conta / XP; skins cosméticas (incl. "Flowers"); expansão do roster na loja (Amaldiçoado, Alma, Cientista, Construtor); conquistas.

### Curva de Dificuldade
- **Caçador (Distorcido):** médio-difícil. Habilidades diretas com teto de domínio (timing do pull, posicionamento do Grito, quando estourar o Rage no limiar 80).
- **Sobreviventes:** Fácil — Soldado; Médio — Sackboy, Médico; Difícil — Robô.
- **Curva da partida:** dispersão → pressão (mortes esticam o Ciclo) → pico na Fuga (dificuldade definida pelas missões pendentes).

### Economia e Recursos

| Recurso | Tipo | Descrição |
|---------|------|-----------|
| HP | Renovável (limitado) | Cura só via Médico (Poção 25) e Robô (Block 10). Sem regen passiva. HP a 0 = morte definitiva. |
| Stamina | Renovável (automático) | Cobre correr e pular, ambos os lados. 7/s gasto, 9/s regen, 0,5s atraso pós-zero; andar regenera. |
| Fúria (Caçador) | Acumulativa | +10 ao ser atacado; +1/s após 20s a ≤40 studs; +10/morte no Rage. Zera ao usar Rage. |
| Cooldowns | Tempo real | Por habilidade. I-frames de 2s pós-stun. |
| Moedas | Persistente (DataStore) | 15/missão, 40/fuga (só quem escapou). Gastas na loja. |
| Tempo / Ciclo | De dois gumes | Missão -10s; morte +20s. Janela de Fuga -5s/missão pendente; não estendida por mortes. |

### Tabela-Mestra de Balanceamento (Protótipo)

Tempos em segundos, dano em HP, distâncias em studs.

**Caçador — O Distorcido**

| Habilidade | Windup | Cooldown | Dano | Notas |
|---|:--:|:--:|:--:|---|
| M1 Tapa | 0.6 | 0.8 | 20 (25 Rage) | 5 hitboxes em 0,5s; empurra 3 |
| Braço Esticado | 1 | 12 | 0 | hitbox móvel 15 studs/s × 2s (30 alcance); puxa + stun 0,5 |
| Grito | 2 | 25 | 0 (10 em Rage) | área radial; slow 40%/3s (r60); revela 4s (r100) |
| Rage | 5 (windup) | 0 (medidor ≥80) | 20 em área (raio 30) | comprometido nos 5s; +5 M1, +2 vel; dura 30 +10/morte; pausa Ciclo |

**Médico**

| Habilidade | Windup | Cooldown | Efeito |
|---|:--:|:--:|---|
| Poção em Área (A1) | 2 | 15 | cura 25 (raio 12) |
| Investida (A2) | 1 | 10 | dano 0/10/20/30; dash 15 studs com hitboxes contínuas; zera contador ao acertar |

**Soldado**

| Habilidade | Windup | Cooldown | Dano | Notas |
|---|:--:|:--:|:--:|---|
| Dash Tático | 0.5 | 20 | 20 | hitbox móvel; dura até 15s, para em Caçador/parede; sem regen de stamina; empurra 10 + silêncio 3 |
| Bazuca | 2 | 30 (cancela 15) | 40 | mira até 10s; feixe instantâneo (hitscan) |

**Sackboy**

| Habilidade | Windup | Carga máx. | Cooldown | Dano | Notas |
|---|:--:|:--:|:--:|:--:|---|
| Tinta carga 1 | 1 | 10 | 30 | 5 | projétil; slow 30%/2s |
| Tinta carga 2 | 2 | 10 | 30 | 10 | slow 40%/2s + silêncio 4 |
| Tinta carga 3 | 3 | 10 | 30 | 15 | stun 2 + blur |
| Surto | 0 | — | 20 | — | +6 vel + pulo alto, 5s |

**Robô**

| Habilidade | Windup | Janela ativa | Cooldown | Dano | Notas |
|---|:--:|:--:|:--:|:--:|---|
| Agarrar | 1 | — | 22 | 0 | hitbox móvel 15 studs/s × 2s (30); dá 8s invenc. ao Caçador + desabilita hab. dele (+1s após) |
| Block | 0 | 1.5 | 14 | 10 | se atingido: silêncio 3 + autocura 10 |
| Autodestruição | 3 | — | 60 | 100 | auto-dano 40; boost vel 5s; arremesso 100 + stun 6 |

**Sistemas globais:** Stamina 7/s gasto · 9/s regen · 0,5s atraso · Pulo 10 custo / 2s cd (salta hitbox do M1) · i-frames 2s pós-stun · Ciclo 240 base / +20 morte / -10 missão · Fuga 60 / -5 missão pendente / piso 10 · Preparação 5s.

**HP e dano-ao-Caçador (resumo):**

| Caçador | HP | Matável na prática? |
|---|---:|---|
| O Distorcido | 2000 | Não (Caçada é pós-protótipo) |
| Amaldiçoado | 500 | Sim (glass killer) |
| Soldado Fundido | 1500 | Teórico |
| Compasso | 1000 | Teórico |

| Sobrevivente | HP | Vel. | Stamina | Maior dano ao Caçador |
|---|---:|---:|---:|---:|
| Soldado | 120 | 20 | 110 | 40 (Bazuca) |
| Sackboy | 110 | 26 | 70 | 15 (Tinta c3) |
| Robô | 150 | 18 | 110 | 100 (Autodestruição) |
| Médico | 80 | 22 | 100 | 30 (Investida 3+) |
| Alma (pós) | 100 | 22 | 100 | 0 |

---

## Especificações Técnicas

### Sistema de Hitboxes e Layers

O jogo é **baseado em hitboxes**: Sobreviventes e Caçador têm uma **hitbox de corpo** que determina se um ataque os atingiu, e cada ataque define a forma e o comportamento da sua própria hitbox. **Regra de dano: aplicado 1 vez por alvo colidido**, nunca empilhando no mesmo alvo (um M1 que pega 2 Sobreviventes dá 20 a cada um, não 40 a um).

**Formas de hitbox por ataque:**

| Ataque | Forma | Atravessa parede? |
|---|---|---|
| M1 Distorcido | 5 hitboxes de detecção em 0,5s | Sim (se facilitar) |
| Braço Esticado / Agarrar (Robô) | **Projétil móvel**: viaja 2s, puxa o alvo até o atirador; o atirador fica **imóvel até o braço voltar** (fim dos 2s ou colisão) | **Não** — para em alvo/parede/chão |
| Bazuca (Soldado) | **Linha fina 3×3×100 studs**, instantânea | **Não** — para na parede |
| Arma de Tinta (Sackboy) | **Linha fina 3×3×100 studs** (mantém 3 cargas) | **Não** — para na parede |
| Grito (Distorcido) | **Cubo único grande** (60 slow / 100 revelação) | **Sim** — atravessa |
| Rage, pulso de ativação (Distorcido) | **Cubo único**, raio 30 | **Sim** — atravessa |
| Cura — Poção em Área (Médico A1) | **Cubo único**, 10 ao redor de si | **Sim** — atravessa |
| Investida (Médico A2) | **Cubo único**, 10 ao redor de si | **Sim** — atravessa |
| Block (Robô) | **Cubo maior que o corpo do Robô** (mais fácil de acertar) | Sim (se facilitar) |
| Corpos (todos) | Hitbox de corpo (registra acerto) | — |

**Regra-resumo de parede:** apenas **projéteis/mísseis** (Bazuca, Tinta, agarrões, Lápis) param na parede/chão. **Todo o resto, incluindo os pulsos de cubo grande (Grito, Rage, Cura, Investida), atravessa parede.**

**Layers de colisão:**
- **Layer do Caçador vs Sobreviventes:** cada ataque filtra por layer de alvo (Braço Esticado só pega Sobreviventes; Agarrar só pega o Caçador).
- **Layer de invencibilidade:** durante i-frames (2s pós-stun) e a invencibilidade de 8s do Agarrar, o Caçador sai da layer "atingível" — hitboxes que o tocariam são ignoradas.
- **Layer de ambiente:** projéteis colidem com paredes/chão (param); cubos grandes ignoram o ambiente.
- **Validação server-side:** colisões e dano resolvidos no servidor (anti-exploit).

### Requisitos de Desempenho

| Métrica | Alvo | Método |
|---------|------|--------|
| FPS | 60 (PC), 30 (mobile) | Medir na Fuga (fogo + perigos + até 8 jogadores) |
| Latência | <100ms de ping | Host local e amigos remotos |
| Memória | <500 MB (mobile) | Developer Console |
| Carregamento | <15s (mobile) | Do "Iniciar" ao spawn |

### Detalhes de Plataforma (Roblox)
- **Motor:** Roblox Engine. **Linguagem:** Luau.
- **Networking:** cliente-servidor. No MVP, host = servidor (partidas com amigos). Servidores dedicados são pós-MVP.
- **Lotação:** **1 Caçador + 1 a 7 Sobreviventes** (máx. **8 jogadores/servidor**; mín. 2). Validar carga de replicação na Fuga.
- **DataStore:** **no escopo do MVP** (moedas + personagens desbloqueados), com retry e tratamento de falha.
- **Assimetria de informação server-side:** o servidor **não envia** ao cliente do Caçador identidade/classe/HP dos Sobreviventes (só a contagem de vivos), para a regra de HUD não ser contornada por exploit.

### Restrições Técnicas
- Replicação cliente-servidor; inputs validados no servidor.
- Segurança: anti speed-hack/teleporte/modificação de HP/stamina e **anti-fraude de moedas/DataStore**.
- Mobile: ~200 partículas simultâneas (atenção ao fogo da Fuga — efeito otimizado); light baking; ~2000 tris/modelo.
- Áudio: trilha em **stems** (3 camadas) + SFX mono; bitcrushed pré-renderizado no asset.

### Requisitos de Assets

| Categoria | MVP | Estilo | Fonte |
|-----------|-----|--------|-------|
| Caçador | 1 (Distorcido: base + Rage) | Retraux R6, ~1500 tris | Studio/Blender |
| Sobreviventes | 4 (Médico, Soldado, Sackboy, Robô) | Retraux R6, ~1000 tris | Studio/Blender |
| Mapa (Criatividade Morta) | 1 (campo + 3 estruturas + obstáculos + corpos/fusões) | Papelão, baixo poli | Partes Roblox + originais |
| Lobby (A Caixa) | 1 (caixa + Vendedor + distrações) | Retraux | Studio |
| Animações | ~35 (incl. pulo, habilidades, morte) | Roblox | Built-in + custom |
| SFX | ~30 (minigames, fogo, moeda) | Terror bitcrushed | Biblioteca gratuita |
| Música | 3 camadas (stems) | Lo-fi/bitcrushed | Gratuita no MVP; OST original pós-MVP |
| UI | ~14 elementos | Minimalista | ScreenGui |

---

## Épicos de Desenvolvimento

| Épico | Nome | Escopo | Ordem |
|-------|------|--------|-------|
| **E1** | Fundação — Movimento, Câmera e Stamina | Movimento, câmera 3ª pessoa com toggle 1ª (ambos), **pulo** (10 stamina, cd 2s, esquiva de M1), **stamina** (7/9/0,5; andar regenera), **sistema de hitboxes e layers** | 1 |
| **E2** | O Caçador — O Distorcido | HP 2000, M1, Braço Esticado, Grito, **Rage** (limiar 80, windup 5s, pulso 20 área, troca de forma, 30+10/morte, pausa Ciclo), **Fúria**, **Stun + i-frames (2s)** | 2 |
| **E3** | Os Sobreviventes — 4 Classes | Stats e habilidades de Médico/Soldado/Sackboy/Robô, **dano ao Caçador**, vínculos **LMS** | 3 |
| **E4** | O Mundo — Criatividade Morta + A Caixa | Mapa plano + 3 estruturas (loop/esconder/despistar), obstáculos, camada de horror, lobby A Caixa | 4 |
| **E5** | Missões e Ciclo | 10 missões V1/V2/V3, distribuição aleatória ≥1 de cada, -10s + moedas, **Ciclo** (240/+20/-10), perigos armados (só na Fuga) | 5 |
| **E6** | Fuga e Resolução | Gatilho no zero do Ciclo, 3 portões, janela 60s -5s/pendente, fogo estético + desmoronamento, matriz de vitória, morte → espectar/lobby | 6 |
| **E7** | Lobby, Loja e Persistência | A Caixa, O Vendedor, **moedas via DataStore**, desbloqueios (grátis: Distorcido/Sackboy/Médico; pago: Soldado/Robô) | 7 |
| **E8** | Áudio e Atmosfera | Trilha em stems bitcrushed (3 camadas), batimentos/distorção, SFX de missões e do fogo | 8 |
| **E9** | Polimento e Balanceamento | Ajuste fino dos números da tabela-mestra, teste com amigos, correções | 9 |

Detalhamento completo em \`epics.md\`.

---

## Métricas de Sucesso

### Técnicas

| Métrica | Alvo | Quando |
|---------|------|--------|
| FPS médio (PC) | ≥55 | Na Fuga |
| FPS médio (Mobile) | ≥28 | Na Fuga |
| Carregamento (Mobile) | <18s | Lobby → spawn |
| Desconexões/partida | <10% | 20 partidas |
| Crash rate | <5% | 20 partidas |
| Integridade DataStore | 0 perdas | 20 partidas |

### Gameplay

| Métrica | Alvo | Como |
|---------|------|------|
| Duração média | 5-9 min | Timestamps |
| Vitória do Caçador (Contenção) | 45-55% | 20 partidas |
| Missões concluídas/partida | 4-8 de 10 | Log de conclusões |
| Fuga Parcial vs Total | acompanhar | Equipe escapa junta? |
| Uso de habilidades | ≥3 por habilidade | Log |
| Tempo até 1ª morte | 1,5-4 min | Log |
| Frequência de Rage | ~30%+ das partidas | Valida limiar 80 |
| Satisfação | ≥7/10 | Pesquisa informal |

---

## Fora do Escopo

### MVP — Deliberadamente Excluído

| Item | Justificativa | Para |
|------|---------------|------|
| Caçadores adicionais (Amaldiçoado, Soldado Fundido, Compasso) | MVP valida com 1 Caçador. Designs prontos. | Pós-MVP |
| Sobreviventes/classes (Alma, Cientista, Construtor) | 4 classes cobrem os papéis. Kits desenhados. | Pós-MVP |
| Condição "Caçada" (matar o Caçador) | Testável com Distorcido AFK; raríssima com 2000 HP. Vira core com o Amaldiçoado. | Pós-protótipo |
| Mapas adicionais (Laboratório, Porão, Set de Guerra) | 1 mapa valida o loop; missões aleatórias dão rejogabilidade. | Pós-MVP |
| Mansão Abandonada | Preservada. Provável especial de Halloween. | Pós-MVP |
| Skins (incl. "Flowers") | A loja vende só personagens no MVP. | Pós-MVP |
| XP / Nível de Conta | Persistência do MVP é só moedas + desbloqueios. | Pós-MVP |
| Monetização | Não necessária para validar. | Pós-MVP |
| Matchmaking / Servidores dedicados | MVP usa host = servidor. | Pós-MVP |
| Modo Juggernaut / LMS dos Caçadores futuros | Dependem de Caçadores pós-MVP. | Pós-MVP |
| Lanternas | Escuridão é ameaça ambiental. | Pós-MVP |
| Tutorial interativo | Design intuitivo + dicas contextuais. | Futuro |
| Bots | Desnecessário com lobby local. | Pós-MVP |
| Leaderboard / conquistas | Dependem de mais persistência. | Pós-MVP |

### Pós-MVP — Roadmap (Backlog Acumulado)
- **Caçadores:** Amaldiçoado (500), Soldado Fundido (1500), Compasso (1000).
- **Sobreviventes/classes:** Alma (starter grátis, 3 habs), Cientista (4 habs), Construtor (3 habs).
- **Mapas:** Laboratório Tecnológico, Porão de Armazenamento, Set de Guerra Destruído, Mansão (Halloween).
- **Lore conectada:** Alma do Cientista; Construtor; os dois Sackboys como a mesma alma.
- **Caçada** ativada como rota real; possível modo Juggernaut.
- **OST original instrumental** (chase → fuga → lobby) em stems, via rev-share/comissão barata, com licença comercial.
- XP, níveis, skins, conquistas, monetização cosmética, matchmaking, servidores dedicados.

---

## Premissas e Dependências

### Premissas

| ID | Premissa | Impacto se Incorreta |
|----|----------|----------------------|
| A1 | O dev aprende Roblox Studio/Luau o suficiente para o MVP em 3-4 semanas. | Atraso; reduzir escopo (corte: 3 Sobreviventes). |
| A2 | Host = servidor basta para testar e validar o loop. | Antecipar servidor dedicado. |
| A3 | A biblioteca gratuita do Roblox tem sons para terror bitcrushed. | Criar/comissionar áudio. |
| A4 | Mobile roda Criatividade Morta a 30 FPS, incl. o fogo da Fuga. | Reduzir partículas/densidade. |
| A5 | Os números da tabela-mestra são ponto de partida, ajustados em teste. | Esperado (função do E9). |
| A6 | Até 7 Sobreviventes (8 jogadores) é adequado ao mapa. | Ajustar a lotação. |
| A7 | DataStore confiável o bastante para moedas/desbloqueios. | Reforçar retry/cache. |
| A8 | O gênero de horror assimétrico retraux segue atraente no Roblox. | Pivotar tema mantendo mecânicas. |

### Dependências

| ID | Dependência | Resolução |
|----|-------------|-----------|
| D1 | Roblox Studio atualizado. | Site oficial. |
| D2 | Conta com permissão para publicar. | Conta de dev gratuita. |
| D3 | 3-4 amigos para testar (até 8 jogadores). | Sessões regulares. |
| D4 | Áudio gratuito com qualidade suficiente. | Catalogar antes. |
| D5 | Assets de papelão. | Toolbox + originais (evitar IP de Sackboy/LBP). |
| D6 | Acesso/teste de DataStore (exige publicar). | Publicar cedo para testar persistência. |

---

## Registro de Alterações

| Versão | Data | Alteração | Autor |
|--------|------|-----------|-------|
| 1.0 | 2026-06-28 | Criação. Caçador MVP O Distorcido, 5 classes, 1 mapa (Mansão), loop conserto-e-escape (Flee the Facility). | familia |
| 2.0 | 2026-06-28 | **Reescrita completa com benchmark Pwned by 14:00.** Loop → resistência-ao-Ciclo + Fuga por 3 portões. Geradores → 10 missões (V1/V2/V3), perigos só na Fuga. Captura/jaula/Derrubado removidos (morte direta + espectador/lobby). Pulo + stamina compartilhada e Stun+i-frames. Fúria reescrita (limiar 80). Caçador matável (pós-protótipo) com HP recalibrado. Elenco: Enfermeira→Médico, Campeão→Alma; Caçadores renomeados (Boneco de Pano→Amaldiçoado, Soldado→Soldado Fundido). Mapa → Criatividade Morta (lobby A Caixa). Loja persistente (DataStore), câmera 3ª pessoa. Estética retraux/papelão, áudio bitcrushed em stems. **Sistema de hitboxes e layers** detalhado. Lotação 1 Caçador + 1-7 Sobreviventes (máx. 8). Tabela-mestra de balanceamento com windups/cooldowns/dano. | familia + reescrita assistida |

---

*Fim do documento — The broken box GDD v2.0*
