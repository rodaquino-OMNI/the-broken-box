---
project: The broken box
document: Epics & Stories
version: 1.0
created: 2026-06-28
author: familia
source_gdd: docs/gdd.md (v2.0)
stepsCompleted: []
---

# The broken box — Documento de Épicos e Histórias

**Idioma:** PT-BR
**Projeto:** the-broken-box
**Fonte de verdade:** [GDD v2.0](gdd.md) — todos os valores numéricos, mecânicas e dados de balanceamento são extraídos do GDD.

---

## Visão Geral

Este documento decompõe os requisitos do GDD em **9 épicas (E1–E9)** e **histórias de usuário detalhadas**, cada uma com:
- ID da história (ex.: E1-S1)
- Descrição no formato "Como [tipo de jogador], quero [funcionalidade] para [benefício]"
- Arquivos a criar/modificar
- Critérios de aceitação testáveis
- Dependências
- Prioridade (P0–Crítica, P1–Alta, P2–Média)

---

## Inventário de Requisitos

### Requisitos Funcionais (extraídos do GDD v2.0)

| ID | Requisito | Épico |
|----|-----------|-------|
| RF01 | Movimento WASD/joystick + corrida (Shift) com stamina | E1 |
| RF02 | Câmera 3ª pessoa padrão com toggle livre para 1ª pessoa (ambos os lados) | E1 |
| RF03 | Pulo: custo 10 stamina, cooldown 2s, esquiva da hitbox do M1 | E1 |
| RF04 | Sistema de stamina: 7/s gasto ao correr, 9/s regen, 0,5s atraso pós-zero, andar regenera | E1 |
| RF05 | Sistema de hitboxes (corpo + formas de ataque) e layers de colisão | E1 |
| RF06 | O Distorcido: HP 2000, M1 (5 hitboxes, 20 dmg), Braço Esticado, Grito, Rage | E2 |
| RF07 | Sistema de Fúria: +10 ao ser atacado, +1/s após 20s ≤40 studs, +10/morte no Rage | E2 |
| RF08 | Stun + i-frames de 2s pós-stun (regra universal) | E2 |
| RF09 | Médico: HP 80, Vel 22, Stam 100, Poção (A1), Investida (A2) | E3 |
| RF10 | Soldado: HP 120, Vel 20, Stam 110, Dash Tático, Bazuca | E3 |
| RF11 | Sackboy: HP 110, Vel 26, Stam 70, Tinta (3 cargas), Surto | E3 |
| RF12 | Robô: HP 150, Vel 18, Stam 110, Agarrar, Block, Autodestruição | E3 |
| RF13 | Bônus LMS condicionais e incondicionais | E3 |
| RF14 | Mapa Criatividade Morta: terreno plano + 3 estruturas + obstáculos | E4 |
| RF15 | Estética retraux/papelão + camada de horror (corpos, fusões) | E4 |
| RF16 | Lobby A Caixa com O Vendedor | E4 |
| RF17 | 10 missões/partida (V1 Disjuntor, V2 Gerador, V3 Petróleo), distribuição aleatória ≥1 de cada | E5 |
| RF18 | Ciclo: 240s base, +20s/morte, -10s/missão concluída | E5 |
| RF19 | Perigos de missão pendente armados (só manifestam na Fuga) | E5 |
| RF20 | 3 portões abrem quando Ciclo zera; janela de Fuga 60s -5s/missão pendente (piso 10s) | E6 |
| RF21 | Incêndio estético (sem dano) + desmoronamento do mapa ao fim da janela | E6 |
| RF22 | Matriz de vitória: Fuga Total, Fuga Parcial, Contenção Total | E6 |
| RF23 | Morte → espectar (câmera cíclica) ou voltar ao lobby | E6 |
| RF24 | Moedas via DataStore: 15/missão, 40/fuga (só quem escapou) | E7 |
| RF25 | Loja d'O Vendedor: desbloqueio de personagens (grátis/pago) | E7 |
| RF26 | Trilha dinâmica em 3 camadas (stems): Calma → Alerta (60s) → Perseguição (30s) | E8 |
| RF27 | Batimentos cardíacos (40 studs) + distorção de borda (20 studs) | E8 |
| RF28 | SFX bitcrushed para missões, Rage, portão e fogo | E8 |
| RF29 | Ajuste fino da tabela-mestra de balanceamento | E9 |
| RF30 | Teste com amigos (1–7 Sobreviventes), correções de bugs e edge cases | E9 |

### Requisitos Não-Funcionais

| ID | Requisito | Épico |
|----|-----------|-------|
| RNF01 | FPS ≥55 (PC), ≥28 (mobile) na Fuga | E9 |
| RNF02 | Latência <100ms | E9 |
| RNF03 | Carregamento <15s (mobile) | E9 |
| RNF04 | Validação server-side de colisões e dano (anti-exploit) | E1, E2 |
| RNF05 | Inputs validados no servidor; anti speed-hack/teleporte | E1 |
| RNF06 | Assimetria de informação: servidor não envia classe/HP ao Caçador | E2 |
| RNF07 | Mobile: ~200 partículas simultâneas; ~2000 tris/modelo | E4, E9 |
| RNF08 | Áudio bitcrushed pré-renderizado; trilha em stems mono | E8 |

---

## Lista de Épicas

| Épico | Nome | Escopo | Ordem | Dependências |
|-------|------|--------|:-----:|-------------|
| **E1** | Fundação — Movimento, Câmera e Stamina | Movimento, câmera 3ª/1ª, pulo, stamina, hitboxes e layers | 1 | Nenhuma |
| **E2** | O Caçador — O Distorcido | HP, M1, Braço Esticado, Grito, Rage, Fúria, Stun/i-frames | 2 | E1 |
| **E3** | Os Sobreviventes — 4 Classes | Stats + habilidades de Médico/Soldado/Sackboy/Robô, dano ao Caçador, LMS | 3 | E1, E2 |
| **E4** | O Mundo — Criatividade Morta + A Caixa | Mapa, 3 estruturas, obstáculos, horror, lobby | 4 | E1 |
| **E5** | Missões e Ciclo | 10 missões V1/V2/V3, distribuição aleatória, Ciclo, perigos | 5 | E1, E4 |
| **E6** | Fuga e Resolução | Portões, janela, fogo, matriz de vitória, espectar/lobby | 6 | E1, E4, E5 |
| **E7** | Lobby, Loja e Persistência | DataStore de moedas, O Vendedor, desbloqueios | 7 | E4 |
| **E8** | Áudio e Atmosfera | Trilha em stems, batimentos, distorção, SFX bitcrushed | 8 | E1, E2, E4 |
| **E9** | Polimento e Balanceamento | Ajuste de números, playtest, bugs, otimização | 9 | E1–E8 |

---

## Grafo de Dependências

```
E1 (Fundação)
 ├──► E2 (O Caçador)
 │     └──► E3 (Sobreviventes)
 ├──► E4 (O Mundo)
 │     ├──► E5 (Missões e Ciclo)
 │     │     └──► E6 (Fuga e Resolução)
 │     └──► E7 (Lobby, Loja e Persistência)
 └──► E8 (Áudio e Atmosfera) ─── pode iniciar junto com E2/E4
                                    (requer apenas E1 completo)

LEGENDA:
──►  = depende de (sequencial)
 ⇢   = pode rodar em paralelo

PARALELISMO POSSÍVEL:
- E2 e E4 podem rodar em paralelo (ambos só dependem de E1)
- E8 pode iniciar assim que E1 estiver pronto (precisa do sistema de proximidade)
- E3 só depois de E2 (precisa do Caçador para dano e i-frames)
- E7 pode rodar em paralelo com E5/E6 (só depende de E4)
```

### Caminho Crítico Estimado

```
E1 → E4 → E5 → E6
E1 → E2 → E3
E1 → E8
E4 → E7
```

**Resumo:** O caminho mais longo é E1 → E4 → E5 → E6 (4 épicas sequenciais). E2→E3 e E7 e E8 correm em paralelo. Com 1 desenvolvedor, a ordem sugerida é E1 → E2 → E4 → E3 → E5 → E8 → E6 → E7 → E9.

---

---

## Épico E1: Fundação — Movimento, Câmera e Stamina

**Objetivo:** Estabelecer a base de movimento, câmera e o sistema de stamina compartilhado entre Caçador e Sobreviventes, além do sistema de hitboxes e layers de colisão que regem todo o combate.

**Prioridade:** P0 — Crítica (tudo depende disto)

**Dependências:** Nenhuma

---

### E1-S1: Sistema de Movimento e Corrida

**Como** jogador (Caçador ou Sobrevivente),
**Quero** me movimentar pelo mapa com WASD/joystick e correr segurando Shift,
**Para** navegar pelo ambiente e gerenciar stamina durante perseguições.

**Arquivos a criar/modificar:**
- `src/server/PlayerManager.server.lua` — gerenciamento de conexão e spawn
- `src/server/MovementController.server.lua` — validação server-side de inputs de movimento
- `src/client/MovementHandler.client.lua` — input local e envio ao servidor
- `src/shared/InputConfig.lua` — binds padrão (WASD, Shift, Espaço, E)

**Critérios de Aceitação:**
- Jogador move-se com WASD (PC) e joystick virtual (mobile)
- Segurar Shift ativa corrida (velocidade base 22 studs/s; valores por classe aplicados depois)
- Correr consome stamina a 7/s (ver E1-S4)
- Movimento é validado no servidor (anti speed-hack/teleporte)
- Colisão com o ambiente funcional (paredes, chão, obstáculos)

**Dependências:** Nenhuma

**Prioridade:** P0

---

### E1-S2: Câmera 3ª Pessoa com Toggle para 1ª Pessoa

**Como** jogador (ambos os lados),
**Quero** jogar em 3ª pessoa por padrão e poder alternar livremente para 1ª pessoa,
**Para** escolher a perspectiva que me dá melhor visibilidade situacional.

**Arquivos a criar/modificar:**
- `src/client/CameraController.client.lua` — controle de perspectiva e FOV
- `src/shared/CameraConfig.lua` — FOV padrão (~70°), distâncias, sensibilidade
- `src/client/InputHandler.client.lua` — bind de toggle de perspectiva

**Critérios de Aceitação:**
- Câmera inicia em 3ª pessoa (padrão para ambos os papéis)
- Toggle entre 3ª e 1ª funciona com input dedicado (livre, sem trava)
- FOV padrão Roblox (~70°) mantido em ambas perspectivas
- Transição suave (sem snap brusco)
- Funciona tanto para Caçador quanto para Sobrevivente (testar ambos)

**Dependências:** E1-S1 (precisa do personagem spawnado)

**Prioridade:** P0

---

### E1-S3: Sistema de Pulo com Esquiva de Hitbox

**Como** jogador (ambos os lados),
**Quero** pular consumindo 10 de stamina com cooldown de 2 segundos,
**Para** esquivar da hitbox do ataque básico (M1) do Caçador e navegar obstáculos.

**Arquivos a criar/modificar:**
- `src/server/JumpController.server.lua` — validação de pulo, custo de stamina, cooldown
- `src/client/JumpHandler.client.lua` — input de pulo (Espaço / botão mobile)
- `src/shared/MovementConfig.lua` — constantes: JUMP_STAMINA_COST=10, JUMP_COOLDOWN=2
- Modificar `src/server/MovementController.server.lua` — integrar pulo

**Critérios de Aceitação:**
- Pressionar Espaço executa pulo (altura suficiente para saltar a hitbox do M1)
- Custa 10 de stamina por pulo (verificado no servidor)
- Cooldown de 2s entre pulos (tentativa de spam ignorada)
- Pulo não funciona se stamina < 10
- Ambos os lados (Caçador e Sobrevivente) podem pular
- Durante o pulo, hitboxes do M1 não atingem o jogador (verificar com E2)

**Dependências:** E1-S1 (movimento), E1-S4 (stamina)

**Prioridade:** P0

---

### E1-S4: Sistema de Stamina Compartilhado

**Como** jogador (ambos os lados),
**Quero** um medidor de stamina que gaste 7/s ao correr, regenere 9/s ao andar/parar, com 0,5s de atraso ao zerar,
**Para** gerenciar meu fôlego durante perseguições e fugas.

**Arquivos a criar/modificar:**
- `src/server/StaminaController.server.lua` — lógica de gasto/regen autoritativa
- `src/client/StaminaUI.client.lua` — barra de stamina no HUD
- `src/shared/StaminaConfig.lua` — constantes: DRAIN_RATE=7, REGEN_RATE=9, EMPTY_DELAY=0.5, PULOCUSTO=10
- `src/shared/ClassStats.lua` — tabela de stamina por classe (Distorcido 110, Soldado 110, Robô 110, Médico 100, Sackboy 70)

**Critérios de Aceitação:**
- Correr consome 7 de stamina por segundo
- Andar ou ficar parado regenera 9 de stamina por segundo
- Ao chegar a 0, há atraso de 0,5s antes de começar a regenerar
- Andar NÃO interrompe a regeneração (só correr gasta)
- Dash pausa regeneração (sem consumo extra; validar com E3)
- Barra de stamina visível no HUD, atualizada em tempo real
- Valores de stamina máxima por classe respeitados (conforme ClassStats)
- Validação server-side (anti-stamina hack)

**Dependências:** E1-S1 (movimento)

**Prioridade:** P0

---

### E1-S5: Sistema de Hitboxes e Layers de Colisão

**Como** sistema de jogo,
**Quero** um framework de hitboxes com formas variadas (cubo, linha, projétil móvel) e layers de colisão (Caçador, Sobrevivente, Ambiente, Invencibilidade),
**Para** que todo dano e interação sejam resolvidos de forma consistente e server-side.

**Arquivos a criar/modificar:**
- `src/server/HitboxSystem.server.lua` — motor de hitboxes: detecção de colisão, filtra por layer, aplica dano 1x/ alvo
- `src/shared/HitboxTypes.lua` — enum de formas: CUBO, LINHA, PROJETIL_MOVEL, CORPO
- `src/shared/CollisionLayers.lua` — definição de layers: HUNTER, SURVIVOR, ENVIRONMENT, INVINCIBLE
- `src/server/DamageController.server.lua` — aplicação de dano, regra de 1x por alvo, filtro de i-frames

**Critérios de Aceitação:**
- Cada personagem tem hitbox de corpo que registra acertos
- Ataques definem forma da hitbox: cubo (Grito, Rage, Cura), linha (Bazuca, Tinta), projétil móvel (Braço, Agarrar)
- Dano aplicado 1 vez por alvo colidido, sem empilhamento no mesmo alvo
- Projéteis param em paredes/chão; cubos grandes ignoram ambiente
- Layer de invencibilidade: durante i-frames (2s pós-stun) e Agarrar (8s), Caçador não é atingível
- Braço Esticado só atinge Sobreviventes; Agarrar só atinge o Caçador
- Toda colisão e dano resolvidos no servidor (anti-exploit)
- Log de acertos para debug

**Dependências:** E1-S1 (personagens spawnados precisam de hitboxes)

**Prioridade:** P0

---

### E1-S6: Preparação da Partida e Spawn

**Como** sistema de jogo,
**Quero** que os Sobreviventes spawnem em posições aleatórias e o Caçador em local fixo, com timer de 5s antes do início,
**Para** criar uma abertura justa para dispersão antes da caçada começar.

**Arquivos a criar/modificar:**
- `src/server/MatchManager.server.lua` — controle de estado da partida (Preparação → Resistência → Fuga → Encerramento)
- `src/server/SpawnController.server.lua` — lógica de spawn aleatório (Sobreviventes) e fixo (Caçador)
- `src/shared/MatchConfig.lua` — PREP_TIME=5, MAX_PLAYERS=8, MIN_PLAYERS=2
- `src/client/MatchUI.client.lua` — contagem regressiva de 5s no HUD

**Critérios de Aceitação:**
- Sobreviventes spawnam em posições aleatórias (mín. 20 studs entre si e do Caçador)
- Caçador spawna em posição fixa (centro ou ponto designado do mapa)
- Timer de 5s visível para todos antes do Ciclo começar
- Durante a preparação, jogadores podem se mover mas habilidades estão bloqueadas
- Suporta 1 Caçador + 1 a 7 Sobreviventes (mín. 2, máx. 8 jogadores)

**Dependências:** E1-S1 (movimento), E1-S2 (câmera), E4 (mapa para definir spawns)

**Prioridade:** P1

---

---

## Épico E2: O Caçador — O Distorcido

**Objetivo:** Implementar O Distorcido completo: HP 2000, aparência base e Rage, habilidades (M1 Tapa, Braço Esticado, Grito, Rage), sistema de Fúria, e a mecânica universal de Stun + i-frames.

**Prioridade:** P0 — Crítica (sem Caçador não há jogo assimétrico)

**Dependências:** E1 (Fundação completa)

---

### E2-S1: O Distorcido — Aparência, HP e Estatísticas Base

**Como** jogador Caçador,
**Quero** controlar O Distorcido com HP 2000, velocidade 26, stamina 110 e aparência retraux fragmentada,
**Para** incorporar a ameaça central do jogo assimétrico.

**Arquivos a criar/modificar:**
- `src/server/HunterController.server.lua` — estado do Caçador, HP, stats base
- `src/shared/HunterStats.lua` — constantes: HP=2000, SPEED=26, STAMINA=110
- `src/client/HunterModel.client.lua` — carregar modelo R6 base (boneco com partes pretas e rachaduras)
- Assets: `assets/models/distorted_base.rbxm` — modelo base do Distorcido (~1500 tris)
- Assets: `assets/models/distorted_rage.rbxm` — modelo da criatura em Rage
- Modificar `src/server/DamageController.server.lua` — receber dano ao Caçador

**Critérios de Aceitação:**
- O Distorcido aparece como boneco R6 com partes pretas saindo e fragmentações/rachaduras
- HP inicial = 2000, visível apenas para o Caçador (HUD próprio)
- Velocidade base = 26 studs/s (correndo)
- Stamina máxima = 110 (usa o sistema de E1-S4)
- Passos pesados com eco distorcido (placeholder até E8)
- Sobreviventes podem causar dano ao Caçador (validar com ataques do E3)
- O Caçador não vê classe/HP dos Sobreviventes — só o número de vivos

**Dependências:** E1-S1 (movimento), E1-S4 (stamina), E1-S5 (hitboxes)

**Prioridade:** P0

---

### E2-S2: M1 — Tapa (Ataque Básico)

**Como** jogador Caçador,
**Quero** usar o ataque básico M1 (Tapa) que gera 5 hitboxes em 0,5s causando 20 de dano e empurrando 3 studs,
**Para** atacar Sobreviventes em curta distância.

**Arquivos a criar/modificar:**
- `src/server/HunterM1.server.lua` — lógica do M1: 5 hitboxes sequenciais, dano, empurrão
- `src/client/HunterM1.client.lua` — input (clique esquerdo / botão), animação, efeitos
- `src/shared/HunterAbilityConfig.lua` — M1: WINDUP=0.6, COOLDOWN=0.8, DAMAGE=20, RAGE_DAMAGE=25, PUSH=3
- Assets: `assets/animations/hunter_m1.rbxm` — animação do Tapa

**Critérios de Aceitação:**
- Clique esquerdo (PC) / botão de ataque (mobile) dispara o M1
- Windup de 0,6s antes das hitboxes ativarem
- 5 hitboxes de detecção geradas em 0,5s
- Cada Sobrevivente atingido toma 20 de dano (25 em Rage)
- Empurra 3 studs ao acertar
- Cooldown de 0,8s entre M1s
- M1 pode ser esquivado com pulo (hitbox não atinge no ar — validar com E1-S3)
- Cooldown e dano validados server-side

**Dependências:** E2-S1 (Distorcido), E1-S5 (hitboxes), E1-S3 (pulo-esquiva)

**Prioridade:** P0

---

### E2-S3: Braço Esticado (Pull)

**Como** jogador Caçador,
**Quero** lançar o Braço Esticado como projétil que viaja 15 studs/s por 2s, puxa o Sobrevivente e atordoa por 0,5s,
**Para** punir Sobreviventes mal posicionados e encurtar distâncias.

**Arquivos a criar/modificar:**
- `src/server/HunterPull.server.lua` — lógica do projétil: trajetória, colisão, pull + stun
- `src/client/HunterPull.client.lua` — input, efeito visual do braço, feedback de acerto
- Modificar `src/shared/HunterAbilityConfig.lua` — PULL: WINDUP=1, CD=12, SPEED=15, DURATION=2, STUN=0.5
- Modificar `src/server/HitboxSystem.server.lua` — suporte a projétil móvel que puxa o alvo

**Critérios de Aceitação:**
- Ao ativar, após windup de 1s, projétil viaja a 15 studs/s por até 2s (alcance 30 studs)
- Ao colidir com Sobrevivente: puxa-o até o Caçador + stun de 0,5s
- Projétil para em paredes/chão (não atravessa ambiente)
- Caçador fica imóvel até o braço voltar (fim dos 2s ou colisão)
- Cooldown de 12s
- Esquivável com pulo (validar interação com hitbox de corpo)
- Stun de 0,5s trava movimento e habilidades do Sobrevivente

**Dependências:** E2-S1 (Distorcido), E1-S5 (hitboxes, projétil móvel)

**Prioridade:** P0

---

### E2-S4: Grito (Revelação + Slow)

**Como** jogador Caçador,
**Quero** usar o Grito para aplicar slow de 40% por 3s em raio 60 e revelar Sobreviventes por 4s em raio 100,
**Para** isolar alvos e ganhar informação tática.

**Arquivos a criar/modificar:**
- `src/server/HunterScream.server.lua` — hitbox de cubo: slow (r60), revelação (r100)
- `src/client/HunterScream.client.lua` — input, efeito visual/sonoro do grito, tela borrada
- Modificar `src/shared/HunterAbilityConfig.lua` — SCREAM: WINDUP=2, CD=25, SLOW_RADIUS=60, REVEAL_RADIUS=100, SLOW=40%, SLOW_DUR=3, REVEAL_DUR=4
- `src/client/RevealEffect.client.lua` — highlight/outline nos Sobreviventes revelados
- `src/client/ScreenBlur.client.lua` — efeito de tela borrada para Sobreviventes afetados

**Critérios de Aceitação:**
- Windup de 2s antes do Grito ativar
- Raio 60: Sobreviventes recebem slow 40% por 3s + tela borrada
- Raio 100: Sobreviventes são revelados (highlight/outline) por 4s
- Cubo de área atravessa paredes (não bloqueado por ambiente)
- Cooldown de 25s
- Em Rage: Grito causa 10 de dano adicional (validar com E2-S5)
- Efeito de tela borrada visível apenas para Sobreviventes afetados

**Dependências:** E2-S1 (Distorcido), E1-S5 (hitbox cubo)

**Prioridade:** P0

---

### E2-S5: Rage — Transformação e Fúria

**Como** jogador Caçador,
**Quero** acumular Fúria e, ao atingir ≥80, ativar o Rage com windup de 5s que termina em pulso de 20 de dano (r30), transforma o modelo, pausa o Ciclo e buffa M1 e velocidade,
**Para** virar o jogo em momentos críticos com poder avassalador.

**Arquivos a criar/modificar:**
- `src/server/FurySystem.server.lua` — acúmulo de Fúria, condições de ganho, ativação do Rage
- `src/server/RageController.server.lua` — windup, pulso de dano, buffs, pausa do Ciclo, duração, saída
- `src/client/RageUI.client.lua` — barra de Fúria no HUD do Caçador (0–100+)
- `src/client/RageEffects.client.lua` — transformação visual, pulso, distorção
- Modificar `src/shared/HunterAbilityConfig.lua` — RAGE: THRESHOLD=80, WINDUP=5, PULSE_DMG=20, PULSE_RADIUS=30, DURATION=30, EXTRA_PER_KILL=10, M1_BONUS=5, SPEED_BONUS=2
- Modificar `src/server/MatchManager.server.lua` — suporte a pausar/retomar Ciclo
- Modificar `src/server/HunterM1.server.lua` — dano 25 durante Rage
- Modificar `src/server/HunterScream.server.lua` — dano 10 durante Rage

**Critérios de Aceitação:**
- **Ganho de Fúria:** +10 ao ser atacado/atordoado; +1/s após 20s contínuos a ≤40 studs de algum Sobrevivente (pode trocar alvo; sair do raio zera a contagem); +10 por morte feita durante o Rage (creditado ao sair)
- Medidor visível no HUD: 0 a 100+ (acumula acima do limiar)
- Ativação disponível com medidor ≥80 E fora da Fuga; sem limite de usos por partida
- Windup de 5s: transformação comprometida e vulnerável (não cancelável; Caçador pode ser atacado)
- Ao completar windup: pulso de 20 de dano em raio 30 studs
- Durante o Rage: Ciclo pausa; M1 causa 25 (+5); velocidade sobe para 28 (+2); Grito causa 10 de dano; modelo muda para a criatura (mãos e torso rasgados, pretos)
- Duração: 30s base + 10s por morte feita durante o Rage
- Ao sair: Ciclo retoma; forma e stats normalizam; medidor vai a 0 + 10 por morte feita no Rage
- Barra de Fúria no HUD reflete o valor pós-Rage

**Dependências:** E2-S1 (base), E2-S2 (M1), E2-S4 (Grito), E5 (Ciclo)

**Prioridade:** P0

---

### E2-S6: Stun e I-Frames (Regra Universal)

**Como** sistema de jogo,
**Quero** que todo stun no Caçador trave movimento/habilidades por T segundos e conceda 2s de i-frames (invencibilidade) ao se recuperar,
**Para** evitar stun-lock encadeado e garantir janelas de contra-ataque justas.

**Arquivos a criar/modificar:**
- `src/server/StunController.server.lua` — aplicação de stun, duração, i-frames pós-stun
- `src/server/InvincibilityLayer.server.lua` — gerencia entrada/saída da layer de invencibilidade
- `src/shared/StunConfig.lua` — IFRAMES_DURATION=2
- Modificar `src/server/HitboxSystem.server.lua` — filtrar hitboxes durante i-frames

**Critérios de Aceitação:**
- Qualquer habilidade que aplique stun trava movimento e habilidades do Caçador por T segundos (T definido por habilidade)
- Ao se recuperar de qualquer stun, Caçador ganha 2s de invencibilidade
- Durante i-frames, hitboxes que tocariam o Caçador são ignoradas (layer INVINCIBLE)
- Stun não pode ser reaplicado durante i-frames (proteção anti-stun-lock)
- Funciona com stuns de qualquer fonte (Braço Esticado, Tinta c3, Autodestruição, Investida 3+)

**Dependências:** E2-S1 (Caçador existe), E1-S5 (layers de colisão)

**Prioridade:** P0

---

---

## Épico E3: Os Sobreviventes — 4 Classes

**Objetivo:** Implementar as 4 classes de Sobreviventes do MVP com stats, habilidades completas, dano ao Caçador e bônus LMS (Last Man Standing).

**Prioridade:** P0 — Crítica (sem Sobreviventes não há jogo assimétrico)

**Dependências:** E1 (Fundação), E2 (Caçador — para dano, i-frames e interação)

---

### E3-S1: Médico — Poção em Área e Investida Medicinal

**Como** jogador Médico (HP 80, Vel 22, Stam 100),
**Quero** curar aliados em área (25 HP, raio 12) com minha Poção (A1) e usar a Investida Medicinal (A2) que escala dano com número de aliados curados,
**Para** manter a equipe viva e punir o Caçador com dano crescente.

**Arquivos a criar/modificar:**
- `src/server/MedicController.server.lua` — A1 (cura), A2 (investida com contador de curados)
- `src/client/MedicUI.client.lua` — HUD do Médico, contador de curados, cooldowns
- `src/shared/SurvivorStats.lua` — MEDIC: HP=80, SPEED=22, STAMINA=100
- `src/shared/MedicConfig.lua` — A1: WINDUP=2, CD=15, HEAL=25, RADIUS=12; A2: WINDUP=1, CD=10, DASH=15, DAMAGE=[0,10,20,30]
- Assets: `assets/models/medic.rbxm` — modelo R6 do Médico (~1000 tris)
- Assets: `assets/animations/medic_a1.rbxm`, `assets/animations/medic_a2.rbxm`
- Modificar `src/server/HealingController.server.lua` — sistema de cura (única fonte: Médico e Block do Robô)

**Critérios de Aceitação:**
- **Poção em Área (A1):** windup 2s, cura 25 HP em raio 12 studs (aliados apenas); cooldown 15s
- Cura não excede HP máximo
- **Investida Medicinal (A2):** windup 1s, dash de 15 studs com hitbox cúbica (10 studs ao redor)
- Efeito escala com número de aliados curados desde o último acerto no Caçador:
  - 0 curados: apenas empurra (dano 0)
  - 1 curado: empurra + desabilita habilidades 3s (dano 10)
  - 2 curados: empurra mais longe + desabilita habilidades 5s (dano 20)
  - 3+ curados: stun 3s + velocidade ao Médico + autocura 20 (dano 30)
- Contador de curados zera ao acertar o Caçador com A2; cooldown 10s
- LMS (incondicional): buff aplicado quando Médico é o último vivo

**Dependências:** E1-S4 (stamina), E1-S5 (hitboxes), E2-S6 (stun/i-frames), E3 (HealingController base)

**Prioridade:** P0

---

### E3-S2: Soldado — Dash Tático e Bazuca

**Como** jogador Soldado (HP 120, Vel 20, Stam 110),
**Quero** avançar com Dash Tático que empurra e silencia o Caçador, e disparar a Bazuca com feixe de 40 de dano,
**Para** controlar o Caçador à distância e proteger a equipe.

**Arquivos a criar/modificar:**
- `src/server/SoldierController.server.lua` — Dash Tático, Bazuca (mira + disparo)
- `src/client/SoldierUI.client.lua` — HUD, modo de mira da Bazuca, cooldowns
- Modificar `src/shared/SurvivorStats.lua` — SOLDIER: HP=120, SPEED=20, STAMINA=110
- `src/shared/SoldierConfig.lua` — DASH: WINDUP=0.5, CD=20, DAMAGE=20, PUSH=10, SILENCE=3, MAX_DUR=15; BAZUCA: WINDUP=2, CD=30(CANCEL=15), DAMAGE=40, BEAM=3×3×100
- Assets: `assets/models/soldier.rbxm` — modelo R6 (~1000 tris)
- Assets: `assets/animations/soldier_dash.rbxm`, `assets/animations/soldier_bazooka.rbxm`
- `src/client/HunterIndicator.client.lua` — marcador direcional no HUD do Caçador quando Bazuca é usada

**Critérios de Aceitação:**
- **Dash Tático:** windup 0,5s, hitbox móvel, avança por até 15s, para ao colidir com Caçador ou parede
  - Sem regeneração de stamina durante o dash
  - Ao acertar Caçador: 20 de dano + empurra 10 studs + silêncio 3s (habilidades desabilitadas)
  - Cooldown 20s
- **Bazuca:** modo de mira por até 10s; disparo após windup de 2s
  - Feixe instantâneo (hitscan) 3×3×100 studs; para na parede (não atravessa)
  - Dano 40 ao Caçador
  - Cooldown 30s (cancela sem disparo: 15s)
- Marcador direcional aparece no HUD do Caçador durante o modo de mira
- LMS condicional (vs Soldado Fundido): Vel 22, +30% dano de Bazuca

**Dependências:** E1-S5 (hitbox linha), E2-S1 (Caçador como alvo), E2-S6 (stun/silêncio)

**Prioridade:** P0

---

### E3-S3: Sackboy — Arma de Tinta e Surto

**Como** jogador Sackboy (HP 110, Vel 26, Stam 70),
**Quero** atirar tinta com 3 níveis de carga (slow/silêncio/stun) e ativar Surto para ganhar velocidade e pulo alto,
**Para** ser ágil e atrapalhar o Caçador com controle.

**Arquivos a criar/modificar:**
- `src/server/SackboyController.server.lua` — Tinta (carga 1/2/3), Surto
- `src/client/SackboyUI.client.lua` — indicador de carga, cooldowns
- Modificar `src/shared/SurvivorStats.lua` — SACKBOY: HP=110, SPEED=26, STAMINA=70
- `src/shared/SackboyConfig.lua` — TINTA: CHARGE_TIMES=[1,2,3], MAX_CHARGES=10, CD=30; C1: DMG=5, SLOW=30%/2s; C2: DMG=10, SLOW=40%/2s, SILENCE=4; C3: DMG=15, STUN=2, BLUR; SURTO: CD=20, SPEED_BONUS=6, DUR=5
- Assets: `assets/models/sackboy.rbxm` — modelo R6 (~1000 tris)
- Assets: `assets/animations/sackboy_ink.rbxm`, `assets/animations/sackboy_surge.rbxm`

**Critérios de Aceitação:**
- **Arma de Tinta:** segurar para carregar (1s/2s/3s); máx. 10 cargas; hitbox linha 3×3×100 (para na parede)
  - Carga 1 (1s): 5 dano + slow 30% por 2s
  - Carga 2 (2s): 10 dano + slow 40% por 2s + silêncio 4s
  - Carga 3 (3s): 15 dano + stun 2s + blur (tela borrada)
  - Cooldown 30s para todos os níveis
- **Surto:** ativação instantânea, +6 velocidade + pulo mais alto por 5s; cooldown 20s
- LMS condicional (vs Amaldiçoado): Vel 28, Stam 80

**Dependências:** E1-S5 (hitbox linha), E2-S6 (stun/i-frames)

**Prioridade:** P0

---

### E3-S4: Robô — Agarrar, Block e Autodestruição

**Como** jogador Robô (HP 150, Vel 18, Stam 110),
**Quero** agarrar o Caçador para dar invencibilidade a ele (com risco), usar Block para contra-atacar e me curar, e ativar Autodestruição como sacrifício extremo,
**Para** ser o tanque da equipe com alto risco e recompensa.

**Arquivos a criar/modificar:**
- `src/server/RobotController.server.lua` — Agarrar, Block, Autodestruição
- `src/client/RobotUI.client.lua` — HUD, indicadores de janela do Block, cooldowns
- Modificar `src/shared/SurvivorStats.lua` — ROBOT: HP=150, SPEED=18, STAMINA=110
- `src/shared/RobotConfig.lua` — AGARRAR: WINDUP=1, CD=22, SPEED=15, DUR=2, INVINCIBILITY=8; BLOCK: WINDUP=0, WINDOW=1.5, CD=14, SILENCE=3, SELFHEAL=10; AUTODESTRUICAO: WINDUP=3, CD=60, DMG=100, SELFDMG=40, BOOST=5, STUN=6, SLOW=8
- Assets: `assets/models/robot.rbxm` — modelo R6 (~1000 tris)
- Assets: `assets/animations/robot_grab.rbxm`, `assets/animations/robot_block.rbxm`, `assets/animations/robot_selfdestruct.rbxm`

**Critérios de Aceitação:**
- **Agarrar:** windup 1s, projétil móvel viaja 15 studs/s × 2s (30 studs de alcance); puxa Caçador até o Robô
  - Robô fica imóvel até o braço voltar (fim dos 2s ou colisão)
  - Não atravessa parede (para em alvo/parede/chão)
  - Dá 8s de invencibilidade ao Caçador + desabilita habilidades dele (+1s após os 8s)
  - Cooldown 22s
- **Block:** postura de contra-ataque, janela ativa de 1,5s
  - Se atingido durante a janela: silêncio 3s no Caçador + autocura 10 HP
  - Hitbox maior que o corpo do Robô (mais fácil de acertar)
  - Cooldown 14s
- **Autodestruição:** windup 3s → boost de velocidade 5s → explode
  - Auto-dano 40 + slow 8s no Robô
  - No Caçador: arremesso 100 + stun 6s
  - Cooldown 60s
- **Anti-sinergia:** se Agarrar for usado antes da Autodestruição, Caçador fica imune durante a explosão (validar que dano não se aplica)
- Robô só pode se curar pelo próprio Block (sem cura do Médico)
- LMS incondicional: buff de sobrevivência

**Dependências:** E1-S5 (hitboxes), E2-S6 (stun/i-frames), E3-S1 (HealingController — restrição de cura)

**Prioridade:** P0

---

### E3-S5: Dano ao Caçador e Registro de Acertos

**Como** sistema de jogo,
**Quero** que o dano dos Sobreviventes ao Caçador seja aplicado 1 vez por alvo colidido e registrado para o sistema de Fúria,
**Para** manter o balanceamento e alimentar a mecânica de Fúria do Caçador.

**Arquivos a criar/modificar:**
- `src/server/SurvivorDamage.server.lua` — unificação de dano ao Caçador, regra 1x/alvo
- Modificar `src/server/DamageController.server.lua` — integrar dano ao Caçador
- Modificar `src/server/FurySystem.server.lua` — receber notificação de dano (+10 Fúria)
- `src/shared/DamageConfig.lua` — tabela de dano máximo por Sobrevivente: Soldado 40, Sackboy 15, Robô 100, Médico 30

**Critérios de Aceitação:**
- Dano aplicado 1 vez por alvo colidido (não empilha no mesmo alvo)
- Cada acerto no Caçador notifica o sistema de Fúria (+10)
- HP do Caçador atualizado corretamente no servidor
- Log de dano para debug
- Validação server-side (anti-dano hack)

**Dependências:** E2-S1 (Caçador), E3-S1 a E3-S4 (habilidades de dano)

**Prioridade:** P0

---

### E3-S6: Bônus LMS (Last Man Standing)

**Como** sistema de jogo,
**Quero** aplicar bônus de LMS quando um Sobrevivente é o último vivo da equipe,
**Para** dar uma chance heroica ao último sobrevivente conforme as condições de cada classe.

**Arquivos a criar/modificar:**
- `src/server/LMSController.server.lua` — detecção de último vivo, aplicação de bônus por classe
- `src/shared/LMSConfig.lua` — bônus por classe:
  - Soldado (condicional vs Soldado Fundido): Vel 22, +30% dano Bazuca
  - Sackboy (condicional vs Amaldiçoado): Vel 28, Stam 80
  - Robô (incondicional): buff de sobrevivência
  - Médico (incondicional): buff trágico

**Critérios de Aceitação:**
- Sistema detecta quando resta apenas 1 Sobrevivente vivo
- Bônus condicionais: aplicados apenas se o Caçador for o oponente específico (Soldado vs Soldado Fundido, Sackboy vs Amaldiçoado)
- Bônus incondicionais: aplicados sempre (Robô, Médico)
- Bônus removidos se o Sobrevivente deixar de ser o último (ex.: outro revive — não aplicável no MVP pois não há revive, mas arquitetura preparada)
- Stats retornam ao normal se LMS deixar de valer
- Notificação visual/sonora ao ativar LMS (placeholder até E8)

**Dependências:** E3-S2 (Soldado), E3-S3 (Sackboy), E3-S4 (Robô), E3-S1 (Médico), E6 (morte)

**Prioridade:** P1

---

---

## Épico E4: O Mundo — Criatividade Morta + A Caixa

**Objetivo:** Construir o mapa Criatividade Morta com terreno plano, 3 estruturas (Castelo, Caverna, Estoque), obstáculos, camada de horror ambiental e o lobby A Caixa.

**Prioridade:** P0 — Crítica (sem mapa não há partida)

**Dependências:** E1 (Fundação)

---

### E4-S1: Terreno Base e Estruturas Principais

**Como** jogador,
**Quero** um mapa plano com 3 estruturas distintas (Castelo, Caverna, Estoque) conectadas por campo aberto,
**Para** ter variedade tática de perseguição: loopar, esconder e despistar.

**Arquivos a criar/modificar:**
- `src/server/MapController.server.lua` — carregamento do mapa, spawns, limites
- `src/shared/MapConfig.lua` — dimensões, posições das estruturas, waypoints
- Assets: `assets/maps/creative_death.rbxl` — mapa completo (terreno + 3 estruturas + obstáculos)
- Assets: `assets/maps/castle.rbxm` — O Castelo (alto, escalável, looping)
- Assets: `assets/maps/cave.rbxm` — A Caverna (escura, rebaixada, esconderijo)
- Assets: `assets/maps/warehouse.rbxm` — O Estoque (labirinto de corredores/prateleiras)

**Critérios de Aceitação:**
- Terreno plano com relevos suaves; travessia de ~25s correndo de ponta a ponta
- **Castelo:** alto, escalável por fora, percorrível por dentro — função de looping
- **Caverna:** mais escura, rebaixada — função de esconder (quebra de linha de visão)
- **Estoque:** labirinto de corredores e prateleiras — função de despistar (juke/mind-game)
- Obstáculos propositais e peças derrubadas entre estruturas (cobertura, plataformas)
- Colisão funcional em todas as estruturas
- Iluminação básica (placeholder até layer de horror em E4-S3)

**Dependências:** E1-S1 (movimento), E1-S5 (colisão)

**Prioridade:** P0

---

### E4-S2: Estética Retraux e Papelão

**Como** jogador,
**Quero** um mundo visual com estética retraux (Roblox antigo, R6, studs, baixo poli, papelão),
**Para** sentir a identidade nostálgica e "criatividade morta" do jogo.

**Arquivos a criar/modificar:**
- `src/client/RetrauxRenderer.client.lua` — configurações visuais: paleta desbotada, sombras densas
- `src/shared/VisualConfig.lua` — paleta de cores, configurações de iluminação
- Assets: texturas de papelão para estruturas
- Assets: props de brinquedo (blocos, peças, studs aparentes)
- Modificar assets das estruturas — aplicar textura de papelão e baixo poli

**Critérios de Aceitação:**
- Todos os modelos usam corpos R6 em bloco com studs aparentes
- Baixa poligonização (~2000 tris máx. por modelo)
- Paleta: cores primárias de brinquedo desbotadas/desaturadas
- Iluminação de alto contraste com sombras densas
- Textura de papelão nos elementos estruturais
- Tom "alegre-sinistro / liminal": playset fofo por fora, abandonado e errado por dentro
- Sem gore, sem sangue excessivo

**Dependências:** E4-S1 (mapa base)

**Prioridade:** P1

---

### E4-S3: Camada de Horror Ambiental

**Como** jogador,
**Quero** encontrar corpos de brinquedo, bonecos fundidos a materiais e zonas escuras no mapa,
**Para** sentir o horror ambiental sutil que reforça a lore e a atmosfera.

**Arquivos a criar/modificar:**
- Assets: `assets/maps/horror_props.rbxm` — corpos de brinquedo, bonecos fundidos, peças derrubadas
- `src/client/AtmosphereController.client.lua` — iluminação por zona, névoa, partículas
- `src/shared/ZoneConfig.lua` — definição de zonas: claro, sombrio, horror

**Critérios de Aceitação:**
- Caverna: corpos de brinquedo em locais sombrios
- Salas do Castelo: cantos escuros e corpos internos
- Estoque: bonecos fundidos aos materiais (papelão, prateleiras)
- Iluminação variável por área (zonas de horror quase sem luz)
- Silhueta do Caçador sempre um tom mais escuro que o ambiente
- Sem gore explícito — horror por estranhamento e familiaridade deformada

**Dependências:** E4-S1 (mapa base), E4-S2 (estética)

**Prioridade:** P1

---

### E4-S4: Lobby — A Caixa

**Como** jogador,
**Quero** um lobby imersivo (A Caixa) onde eu spawno antes das partidas, encontro O Vendedor e interajo com distrações,
**Para** ter um hub social fora de partida que reforça o tema.

**Arquivos a criar/modificar:**
- `src/server/LobbyController.server.lua` — estado do lobby, transição para partida
- `src/client/LobbyUI.client.lua` — interface do lobby (pronto, loja, espectar)
- Assets: `assets/maps/the_box.rbxm` — modelo da Caixa (lobby)
- Assets: `assets/models/vendor.rbxm` — modelo d'O Vendedor

**Critérios de Aceitação:**
- Lobby é uma caixa de brinquedos fechada com estética retraux
- O Vendedor está presente (modelo placeholder, funcionalidade na E7)
- Pequenas distrações interativas (props clicáveis)
- Tom "aconchegante por fora, abandonada por dentro"
- Transição lobby → partida funcional (via E1-S6)
- Jogadores podem navegar livremente no lobby entre partidas

**Dependências:** E4-S1 (construção de mapas), E4-S2 (estética)

**Prioridade:** P1

---

### E4-S5: Posicionamento de Portões e Locais de Missão

**Como** designer de níveis,
**Quero** 3 portões fixos (P1 Caverna, P2 Castelo, P3 centro do Estoque) e ~14 locais candidatos a missão posicionados estrategicamente,
**Para** que o fluxo de Fuga e a distribuição de missões façam sentido tático.

**Arquivos a criar/modificar:**
- `src/shared/GateConfig.lua` — posições fixas dos 3 portões
- `src/shared/MissionSpawns.lua` — ~14 locais candidatos com coordenadas e tipo preferencial
- Modificar `src/shared/MapConfig.lua` — integrar portões e locais de missão
- Assets: modelos de portão (3), modelos de estação de missão (Disjuntor, Gerador, Petróleo)

**Critérios de Aceitação:**
- P1 na Caverna, P2 no Castelo (interno + subida), P3 no centro do Estoque
- Portões fechados durante a Resistência, abertos na Fuga (lógica na E6)
- ~14 locais de missão distribuídos entre as 3 estruturas e campo aberto
- Densidade maior de locais nas aproximações das 3 rotas de fuga
- V1 (Disjuntor) preferencialmente na Caverna e aproximações (já escuras)
- V2 (Gerador) preferencialmente nos gargalos do Estoque e entradas do Castelo
- V3 (Petróleo) preferencialmente no campo aberto e rampas largas

**Dependências:** E4-S1 (mapa), E5 (missões — para referência), E6 (portões)

**Prioridade:** P0

---

---

## Épico E5: Missões e Ciclo

**Objetivo:** Implementar o sistema de 10 missões por partida (V1 Disjuntor, V2 Gerador, V3 Máquina de Petróleo) com distribuição aleatória, o Ciclo (240s base) e os perigos de missão pendente.

**Prioridade:** P0 — Crítica (missões e Ciclo são o núcleo da Resistência)

**Dependências:** E1 (Fundação), E4 (Mundo — locais de missão)

---

### E5-S1: Sistema de Missões Base — Distribuição Aleatória

**Como** sistema de jogo,
**Quero** que a cada partida 10 missões sejam sorteadas de ~14 locais com ≥1 de cada variável (V1/V2/V3),
**Para** que nenhuma partida seja igual e sempre haja variedade tática.

**Arquivos a criar/modificar:**
- `src/server/MissionManager.server.lua` — sorteio, ativação, conclusão de missões
- `src/shared/MissionConfig.lua` — total=10, min_per_type=1, locais=14
- Modificar `src/shared/MissionSpawns.lua` — integrar com MissionManager

**Critérios de Aceitação:**
- 10 instâncias de missão ativas por partida
- Sorteadas aleatoriamente entre ~14 locais candidatos
- Garantia de ≥1 de cada variável (V1, V2, V3) por partida
- Tipos sorteados por local (pode variar: 5V1/3V2/2V3 ou 1V1/1V2/8V3 etc.)
- Posições marcadas no mapa (sem seta direcional — encontradas por exploração)
- Distribuição validada em 20 partidas de teste

**Dependências:** E4-S5 (locais de missão)

**Prioridade:** P0

---

### E5-S2: V1 — Disjuntor de Energia

**Como** jogador Sobrevivente,
**Quero** interagir com o Disjuntor e colocar todas as alavancas para a direita (repetindo 4x),
**Para** concluir a missão, ganhar -10s no Ciclo, 15 moedas e desarmar a escuridão na Fuga.

**Arquivos a criar/modificar:**
- `src/server/MissionV1.server.lua` — lógica do minigame: alavancas, 4 repetições, conclusão
- `src/client/MissionV1UI.client.lua` — UI do minigame (alavancas), indicador de progresso
- `src/client/MissionInteraction.client.lua` — input E / botão contextual para iniciar missão
- `src/shared/MissionV1Config.lua` — repetições=4, recompensa padrão
- Assets: `assets/models/mission_breaker.rbxm` — modelo do Disjuntor
- Assets: `assets/sfx/breaker_sfx.rbxk` — sons bitcrushed do disjuntor (placeholder até E8)

**Critérios de Aceitação:**
- Jogador pressiona E (PC) / botão contextual (mobile) próximo ao Disjuntor
- UI do minigame abre na tela (ocupa atenção mas NÃO trava movimento)
- Mover-se cancela/encerra a missão a qualquer momento
- Minigame: colocar todas as alavancas para a direita
- Ao completar: minigame reinicia (total de 4 repetições para concluir)
- Conclusão das 4 repetições: -10s no Ciclo + 15 moedas + flag de perigo desarmado
- Progresso não é perdido se o jogador cancelar (retoma de onde parou na mesma missão)
- UI fecha ao cancelar ou concluir

**Dependências:** E5-S1 (sistema de missões), E1 (interação)

**Prioridade:** P0

---

### E5-S3: V2 — Gerador

**Como** jogador Sobrevivente,
**Quero** interagir com o Gerador e conectar 5 cabos (repetindo 4x),
**Para** concluir a missão, ganhar -10s no Ciclo, 15 moedas e desarmar a barreira elétrica na Fuga.

**Arquivos a criar/modificar:**
- `src/server/MissionV2.server.lua` — lógica: conectar 5 cabos, 4 repetições, conclusão
- `src/client/MissionV2UI.client.lua` — UI de conexão de cabos, indicador de progresso
- `src/shared/MissionV2Config.lua` — cabos=5, repetições=4
- Assets: `assets/models/mission_generator.rbxm` — modelo do Gerador
- Assets: `assets/sfx/generator_sfx.rbxk` — sons bitcrushed

**Critérios de Aceitação:**
- Interação igual V1 (E / botão contextual)
- UI do minigame abre na tela; mover cancela
- Conectar 5 cabos corretamente (ordem ou pares — definir na UI)
- 4 repetições para concluir (reinicia ao completar cada ciclo)
- Conclusão: -10s Ciclo + 15 moedas + perigo desarmado
- Progresso preservado ao cancelar (por missão)

**Dependências:** E5-S1 (sistema de missões)

**Prioridade:** P0

---

### E5-S4: V3 — Máquina de Petróleo

**Como** jogador Sobrevivente,
**Quero** interagir com a Máquina de Petróleo e completar o minigame de ponteiro/zona de acerto (estilo Flee the Facility),
**Para** concluir a missão em 1 etapa, ganhar -10s no Ciclo, 15 moedas e desarmar a poça de lentidão na Fuga.

**Arquivos a criar/modificar:**
- `src/server/MissionV3.server.lua` — lógica: ponteiro, zona de acerto, 1 repetição
- `src/client/MissionV3UI.client.lua` — UI do ponteiro giratório e zona de acerto
- `src/shared/MissionV3Config.lua` — repetições=1
- Assets: `assets/models/mission_oil.rbxm` — modelo da Máquina de Petróleo
- Assets: `assets/sfx/oil_sfx.rbxk` — sons bitcrushed

**Critérios de Aceitação:**
- Interação igual V1/V2
- Minigame: ponteiro giratório, jogador pressiona no momento certo na zona de acerto
- Apenas 1 repetição (mais rápido, mas requer timing)
- Conclusão: -10s Ciclo + 15 moedas + perigo desarmado
- Mover cancela

**Dependências:** E5-S1 (sistema de missões)

**Prioridade:** P0

---

### E5-S5: O Ciclo — Cronômetro da Partida

**Como** sistema de jogo,
**Quero** um Ciclo base de 240s que é reduzido em 10s por missão concluída e estendido em 20s por morte de Sobrevivente,
**Para** criar o relógio de pressão que define o ritmo da partida.

**Arquivos a criar/modificar:**
- `src/server/CycleController.server.lua` — cronômetro autoritativo, modificações por missão/morte
- `src/client/CycleUI.client.lua` — HUD do Ciclo (timer visível para todos)
- `src/shared/CycleConfig.lua` — BASE=240, DEATH_EXTENSION=20, MISSION_REDUCTION=10
- Modificar `src/server/MatchManager.server.lua` — integrar Ciclo com estados da partida

**Critérios de Aceitação:**
- Ciclo inicia em 240s após a Preparação (5s)
- Cada missão concluída: -10s no Ciclo
- Cada morte de Sobrevivente: +20s no Ciclo (durante a Resistência; mortes na Fuga não estendem)
- Ciclo visível no HUD de todos os jogadores (timer regressivo)
- Quando Ciclo chega a 0: transição automática para fase de Fuga (via E6)
- Ciclo pausa durante Rage do Caçador (validar com E2-S5)
- Validação server-side (anti-manipulação de tempo)

**Dependências:** E5-S1 a E5-S4 (missões), E6 (Fuga — para transição)

**Prioridade:** P0

---

### E5-S6: Perigos de Missão Pendente (Armados)

**Como** sistema de jogo,
**Quero** que missões não concluídas armem perigos (escuridão V1, barreira elétrica V2, poça V3) que só se manifestam na Fuga,
**Para** que a decisão de pular missões tenha consequência real na corrida final.

**Arquivos a criar/modificar:**
- `src/server/HazardController.server.lua` — ativação de perigos na transição para Fuga
- `src/shared/HazardConfig.lua` — V1: escuridão localizada; V2: barreira elétrica 10 dmg + imunidade 5s; V3: poça 35% slow
- `src/client/HazardEffects.client.lua` — efeitos visuais: escuridão, barreira faiscante, poça de óleo
- Modificar `src/server/MissionManager.server.lua` — rastrear pendentes e acionar HazardController

**Critérios de Aceitação:**
- **V1 Disjuntor pendente:** área ao redor do disjuntor fica em escuridão total na Fuga
- **V2 Gerador pendente:** barreira elétrica na passagem próxima; 10 de dano por travessia; janela de imunidade de 5s (travessias repetidas em <5s só causam dano 1 vez)
- **V3 Petróleo pendente:** poça grande com 35% de lentidão em quem pisar
- Perigos NÃO se manifestam durante a Resistência (apenas na Fuga)
- Perigos são removidos se a missão correspondente for concluída
- Efeitos visuais claros para cada perigo

**Dependências:** E5-S1 (missões), E4-S5 (posicionamento), E6 (Fuga)

**Prioridade:** P1

---

---

## Épico E6: Fuga e Resolução

**Objetivo:** Implementar a fase de Fuga: ativação dos 3 portões quando o Ciclo zera, janela de 60s (-5s por missão pendente), incêndio estético, matriz de vitória e fluxo de pós-morte.

**Prioridade:** P0 — Crítica (define o fim da partida)

**Dependências:** E1 (Fundação), E4 (Mundo — portões), E5 (Ciclo e missões)

---

### E6-S1: Abertura dos Portões e Janela de Fuga

**Como** sistema de jogo,
**Quero** que os 3 portões abram automaticamente quando o Ciclo zerar, com janela base de 60s (-5s por missão pendente, piso de 10s),
**Para** iniciar a corrida final dos Sobreviventes.

**Arquivos a criar/modificar:**
- `src/server/EscapeController.server.lua` — abertura de portões, temporizador da janela, fechamento
- `src/client/EscapeUI.client.lua` — HUD da Fuga (timer da janela, indicadores de portão)
- `src/shared/EscapeConfig.lua` — BASE_WINDOW=60, PENALTY_PER_MISSION=5, FLOOR=10
- Modificar `src/server/MatchManager.server.lua` — transição Resistência → Fuga → Encerramento
- Modificar `src/shared/GateConfig.lua` — estados: fechado, abrindo, aberto, fechando

**Critérios de Aceitação:**
- Ciclo zera → 3 portões abrem simultaneamente
- Janela de Fuga = 60s - (5s × número de missões pendentes), mínimo de 10s
- Mortes na Fuga NÃO estendem a janela
- Timer da janela visível no HUD de todos
- Ao fim da janela: portões fecham e mapa desmorona (E6-S2)
- Portões são atravessáveis: jogador que passa por um portão é considerado "escapou"
- Caçador NÃO pode atravessar portões

**Dependências:** E5-S5 (Ciclo), E4-S5 (portões), E5 (missões — para contagem de pendentes)

**Prioridade:** P0

---

### E6-S2: Incêndio Estético e Desmoronamento

**Como** sistema de jogo,
**Quero** que o cenário comece a queimar ao iniciar a Fuga (sem dano, apenas estético) e desmorone ao fim da janela,
**Para** criar urgência visual e encerrar a partida de forma impactante.

**Arquivos a criar/modificar:**
- `src/server/FireController.server.lua` — propagação do fogo (estético), desmoronamento
- `src/client/FireEffects.client.lua` — partículas de fogo, fumaça, colapso de estruturas
- `src/shared/FireConfig.lua` — sem dano, propagação visual, timing do desmoronamento
- Assets: `assets/particles/fire_particles.rbxm` — partículas de fogo otimizadas (~200 simultâneas máx.)
- Assets: `assets/sfx/fire_sfx.rbxk` — som de colapso/incêndio (placeholder até E8)

**Critérios de Aceitação:**
- Fogo inicia assim que os portões abrem (fase de Fuga)
- Fogo é puramente estético: NÃO causa dano
- Fogo se espalha progressivamente pelo mapa (sinaliza o colapso)
- Partículas otimizadas: ≤200 simultâneas (compatível com mobile)
- Ao fim da janela de Fuga: mapa desmorona (consumido pelo fogo)
- Quem não escapou até o desmoronamento: morte automática
- Som de colapso/incêndio ao zerar o Ciclo (placeholder → E8)

**Dependências:** E6-S1 (portões/janela), E4-S1 (mapa)

**Prioridade:** P1

---

### E6-S3: Matriz de Vitória e Derrota

**Como** sistema de jogo,
**Quero** resolver as condições de vitória: Fuga Total (todos escapam), Fuga Parcial (≥1 escapa) e Contenção Total (ninguém escapa),
**Para** declarar um vencedor ao fim de cada partida.

**Arquivos a criar/modificar:**
- `src/server/VictoryController.server.lua` — avaliação de condição de vitória ao fim da janela
- `src/client/VictoryUI.client.lua` — tela de resultado (vitória/derrota, stats da partida)
- `src/shared/VictoryConfig.lua` — moedas de fuga: COIN_FUGA=40 (só quem escapou)

**Critérios de Aceitação:**
- **Fuga Total:** todos os Sobreviventes vivos atravessam um portão → vitória dos Sobreviventes
- **Fuga Parcial:** ao menos 1 Sobrevivente escapa → vitória da equipe; apenas quem escapou ganha 40 moedas
- **Contenção Total:** ninguém escapa (todos mortos ou presos) → vitória do Caçador; mapa destruído
- Tela de resultado exibe: condição, quem escapou, moedas ganhas, stats
- Caçador vê apenas o resultado (vitória/derrota) e número de fugitivos
- Transição para lobby ou nova partida após resultado

**Dependências:** E6-S1 (portões), E6-S2 (desmoronamento), E7 (moedas — para creditar)

**Prioridade:** P0

---

### E6-S4: Morte e Pós-Morte (Espectar / Lobby)

**Como** jogador Sobrevivente morto,
**Quero** poder escolher entre espectar aliados vivos (câmera cíclica) ou voltar ao lobby A Caixa,
**Para** continuar acompanhando a partida ou fazer outras atividades.

**Arquivos a criar/modificar:**
- `src/server/DeathController.server.lua` — morte (HP=0), remoção do jogo, notificação
- `src/client/DeathUI.client.lua` — tela de morte com opções: Espectar / Lobby
- `src/client/SpectateController.client.lua` — câmera de espectador, ciclo entre alvos
- Modificar `src/server/MatchManager.server.lua` — rastrear vivos e permitir espectar

**Critérios de Aceitação:**
- HP chega a 0 → morte imediata (sem estado Derrubado, sem resgate)
- Tela de morte oferece: "Espectar" (câmera segue Sobrevivente vivo) e "Lobby" (sair para A Caixa)
- Espectar: câmera cíclica entre Sobreviventes vivos (troca com input)
- Jogador no lobby pode voltar a espectar até a partida acabar
- Morte notificada ao MatchManager para rastreamento de vivos
- Morte de Sobrevivente durante a Resistência: +20s no Ciclo (validar com E5-S5)
- Morte de Sobrevivente durante a Fuga: NÃO estende a janela

**Dependências:** E5-S5 (Ciclo — para +20s), E6-S3 (matriz de vitória), E4-S4 (lobby)

**Prioridade:** P0

---

### E6-S5: Perigos Ativos na Rota de Fuga

**Como** sistema de jogo,
**Quero** que os perigos de missões pendentes estejam ativos durante a Fuga e interajam com a jogabilidade de travessia,
**Para** que a decisão de pular missões cobre seu preço na corrida final.

**Arquivos a criar/modificar:**
- Modificar `src/server/HazardController.server.lua` — ciclo de vida na Fuga: ativação, interação com jogadores
- Modificar `src/client/HazardEffects.client.lua` — visibilidade na Fuga (escuridão pior com fogo, barreira brilha)
- Integrar com `src/server/EscapeController.server.lua` — perigos afetam travessia dos portões

**Critérios de Aceitação:**
- **V1 Escuridão:** área do disjuntor fica totalmente escura; Sobreviventes precisam navegar às cegas ou por memória
- **V2 Barreira Elétrica:** 10 de dano ao atravessar; imunidade de 5s após tomar dano (não acumula)
- **V3 Poça de Óleo:** 35% de lentidão contínua enquanto pisa na poça
- Perigos posicionados sobre ou perto das rotas de fuga aos 3 portões
- Caçador NÃO é afetado pelos perigos (só os Sobreviventes)
- Interação entre perigos: múltiplos perigos próximos acumulam efeitos
- Efeitos visuais/sonoros claros para cada perigo ativo

**Dependências:** E5-S6 (perigos definidos), E6-S1 (Fuga ativada)

**Prioridade:** P1

---

---

## Épico E7: Lobby, Loja e Persistência

**Objetivo:** Implementar a economia persistente com DataStore: moedas ganhas em partida (15/missão, 40/fuga), loja d'O Vendedor e sistema de desbloqueio de personagens (grátis e pagos).

**Prioridade:** P1 — Alta (valida retenção, mas partida funciona sem)

**Dependências:** E4 (Mundo — lobby A Caixa)

---

### E7-S1: DataStore de Moedas

**Como** sistema de persistência,
**Quero** salvar e carregar moedas do jogador via Roblox DataStore com retry e tratamento de falha,
**Para** que o progresso econômico sobreviva entre sessões.

**Arquivos a criar/modificar:**
- `src/server/DataStoreController.server.lua` — get/set com retry (3 tentativas), fallback
- `src/server/CoinController.server.lua` — crédito de moedas (missão=15, fuga=40), débito (loja)
- `src/shared/EconomyConfig.lua` — COIN_MISSAO=15, COIN_FUGA=40, preços: Soldado=500, Robô=500
- `src/client/CoinUI.client.lua` — exibição de moedas no HUD e no lobby

**Critérios de Aceitação:**
- Moedas salvas no DataStore por UserId
- Get: 3 tentativas com backoff; fallback para 0 em caso de falha total
- Set: 3 tentativas com backoff; log de falha se todas falharem
- Ao concluir missão: +15 moedas creditadas e salvas
- Ao escapar na Fuga: +40 moedas creditadas apenas para quem atravessou o portão
- Moedas NÃO são creditadas para quem morreu ou não escapou (na Fuga)
- Integridade validada: 0 perdas em 20 partidas de teste
- Anti-fraude: validação server-side de ganhos

**Dependências:** E4-S4 (lobby), E5 (missões — para crédito), E6 (Fuga — para crédito)

**Prioridade:** P1

---

### E7-S2: O Vendedor — Loja da Caixa

**Como** jogador no lobby,
**Quero** interagir com O Vendedor (estilo Noli) para comprar personagens com minhas moedas,
**Para** desbloquear novas classes e expandir minhas opções de jogo.

**Arquivos a criar/modificar:**
- `src/server/ShopController.server.lua` — lógica de compra, verificação de saldo, desbloqueio
- `src/client/ShopUI.client.lua` — interface da loja: grid de personagens, preços, status
- `src/client/VendorInteraction.client.lua` — interação com O Vendedor (E / toque)
- `src/shared/UnlockConfig.lua` — status de cada personagem (grátis/pago/preço)

**Critérios de Aceitação:**
- O Vendedor está presente no lobby A Caixa
- Interagir (E / toque) abre a UI da loja
- Loja exibe personagens com status: "Grátis" (Distorcido, Sackboy, Médico), preço (Soldado 500, Robô 500), ou "Desbloqueado"
- Comprar: verifica saldo, deduz moedas, desbloqueia personagem, salva no DataStore
- Personagens desbloqueados disponíveis para seleção na próxima partida
- Tentativa de compra sem saldo mostra mensagem de erro
- UI responsiva e temática (retraux)

**Dependências:** E7-S1 (DataStore, moedas), E4-S4 (lobby)

**Prioridade:** P1

---

### E7-S3: Seleção de Personagem e Desbloqueio

**Como** jogador,
**Quero** selecionar meu personagem antes da partida (entre os que desbloqueei) e ver quais estão bloqueados,
**Para** jogar com a classe que escolhi.

**Arquivos a criar/modificar:**
- `src/server/CharacterSelectController.server.lua` — validação de desbloqueio, atribuição de classe
- `src/client/CharacterSelectUI.client.lua` — tela de seleção: grid, lock/unlock, stats
- Modificar `src/server/LobbyController.server.lua` — fluxo lobby → seleção → partida
- Modificar `src/server/DataStoreController.server.lua` — salvar desbloqueios

**Critérios de Aceitação:**
- Tela de seleção antes de cada partida (após lobby)
- Personagens exibidos com card: nome, stats resumidos, status (bloqueado/desbloqueado/selecionado)
- Grátis sempre desbloqueados: O Distorcido (Caçador), Sackboy, Médico
- Pagos exigem compra prévia: Soldado (500), Robô (500)
- Seleção validada no servidor (anti-burlar desbloqueio)
- Caçador: apenas 1 por partida (se múltiplos querem, seleção aleatória ou rodízio)
- Seleção persiste entre partidas (último escolhido pré-selecionado)

**Dependências:** E7-S1 (DataStore), E7-S2 (loja), E3 (classes implementadas)

**Prioridade:** P1

---

---

## Épico E8: Áudio e Atmosfera

**Objetivo:** Implementar a trilha sonora dinâmica em 3 camadas (stems), efeitos de proximidade (batimentos e distorção), e SFX bitcrushed para missões, Rage, portão e fogo.

**Prioridade:** P1 — Alta (define a atmosfera, mas o jogo funciona sem)

**Dependências:** E1 (Fundação — precisa de personagens para proximidade), E2 (Caçador), E4 (Mundo)

---

### E8-S1: Trilha Dinâmica em 3 Camadas (Stems)

**Como** sistema de áudio,
**Quero** tocar uma trilha em 3 camadas (Calma → Alerta → Perseguição) com crossfade de 2s baseado na distância do Sobrevivente ao Caçador,
**Para** que a música reflita a tensão do momento.

**Arquivos a criar/modificar:**
- `src/server/MusicController.server.lua` — calcula distância, determina camada, sincroniza clientes
- `src/client/MusicPlayer.client.lua` — toca stems, crossfade de 2s entre camadas
- `src/shared/AudioConfig.lua` — distâncias: ALERTA=60, PERSEGUICAO=30, crossfade=2s
- Assets: `assets/audio/stems/calm.ogg` — camada Calma (lo-fi)
- Assets: `assets/audio/stems/alert.ogg` — camada Alerta
- Assets: `assets/audio/stems/chase.ogg` — camada Perseguição
- Assets: `assets/audio/stems/climax.ogg` — clímax da Fuga (bitcrushed agressivo)

**Critérios de Aceitação:**
- 3 camadas (stems) carregadas em loop
- Distância do Sobrevivente mais próximo ao Caçador define camada ativa:
  - >60 studs: Calma
  - 30–60 studs: Alerta
  - <30 studs: Perseguição
- Crossfade de 2s entre camadas (sem corte brusco)
- Na Fuga: transição para clímax bitcrushed agressivo (ignora distância)
- Áudio mono, bitcrushed, pré-renderizado no asset
- Sincronização via servidor para todos os clientes

**Dependências:** E1-S1 (movimento — para calcular distância), E2-S1 (Caçador), E6 (Fuga)

**Prioridade:** P1

---

### E8-S2: Batimentos Cardíacos e Distorção de Borda

**Como** sistema de atmosfera,
**Quero** que Sobreviventes ouçam batimentos cardíacos (a 40 studs do Caçador) e vejam distorção de borda na tela (a 20 studs),
**Para** sentir fisicamente a proximidade da ameaça.

**Arquivos a criar/modificar:**
- `src/client/HeartbeatController.client.lua` — áudio de batimentos, volume por distância
- `src/client/EdgeDistortion.client.lua` — efeito visual de distorção/escurecimento nas bordas
- `src/shared/ProximityConfig.lua` — HEARTBEAT_RADIUS=40, DISTORTION_RADIUS=20
- Assets: `assets/audio/heartbeat.ogg` — som de batimentos (bitcrushed, lo-fi)

**Critérios de Aceitação:**
- Batimentos audíveis quando Caçador está a ≤40 studs do Sobrevivente
- Volume/intensidade dos batimentos aumenta com a proximidade
- Tela escurece/distorce nas bordas quando Caçador está a ≤20 studs
- Ambos os efeitos são aplicados por Sobrevivente (individual, baseado na distância ao Caçador)
- Efeitos suaves (transição gradual, sem liga/desliga abrupto)
- Caçador NÃO recebe esses efeitos

**Dependências:** E1-S1 (movimento), E2-S1 (Caçador)

**Prioridade:** P1

---

### E8-S3: SFX Bitcrushed para Eventos de Jogo

**Como** sistema de áudio,
**Quero** sons bitcrushed para missões (Disjuntor, Gerador, Petróleo), Rage (windup + pulso), abertura de portão e fogo,
**Para** reforçar a identidade sonora lo-fi e dar feedback auditivo claro aos eventos.

**Arquivos a criar/modificar:**
- `src/client/SFXController.client.lua` — gerenciador central de SFX, fila, prioridade
- `src/shared/SFXConfig.lua` — mapeamento evento→som, volume, alcance
- Assets: `assets/sfx/` — todos os sons:
  - `rage_windup.ogg`, `rage_pulse.ogg`
  - `gate_open.ogg`, `gate_close.ogg`
  - `fire_start.ogg`, `fire_loop.ogg`
  - `mission_complete.ogg`
  - `coin_earn.ogg`
  - `death_survivor.ogg`
  - `stun_hunter.ogg`
  - `hit_m1.ogg`, `hit_pull.ogg`, `hit_scream.ogg`

**Critérios de Aceitação:**
- Todos os SFX com textura bitcrushed/lo-fi
- SFX para: início do Rage (windup) e pulso de ativação
- SFX para: abertura e fechamento dos portões
- SFX para: início do fogo e loop de incêndio
- SFX para: conclusão de missão (qualquer variável)
- SFX para: ganho de moedas
- SFX para: morte de Sobrevivente, stun do Caçador
- SFX para: acerto de M1, Braço Esticado, Grito
- Volume e alcance configuráveis por som
- Áudio mono, pré-renderizado

**Dependências:** E2 (Caçador — Rage, ataques), E5 (missões), E6 (portão, fogo)

**Prioridade:** P1

---

### E8-S4: Passos e Som Ambiente

**Como** sistema de áudio,
**Quero** passos distintos para Caçador (pesados, eco distorcido) e Sobreviventes, além de som ambiente (rangidos de papelão, sussurros),
**Para** enriquecer a imersão e dar pistas auditivas de posicionamento.

**Arquivos a criar/modificar:**
- `src/client/FootstepController.client.lua` — som de passos por tipo de personagem e terreno
- `src/client/AmbientController.client.lua` — sons ambientes: rangidos, sussurros
- Assets: `assets/sfx/footsteps/` — passos do Distorcido, Sobreviventes (genérico)
- Assets: `assets/sfx/ambient/` — rangidos, sussurros abafados

**Critérios de Aceitação:**
- Passos do Distorcido: pesados, eco distorcido e deslocado da posição real (bitcrushed)
- Passos dos Sobreviventes: mais leves
- Volume dos passos do Caçador audível a distância (alerta de proximidade)
- Som ambiente: rangidos de papelão, sussurros abafados em zonas de horror
- Som ambiente varia por zona (Caverna: mais sussurros; Castelo: mais rangidos)
- Todos os sons mono, bitcrushed

**Dependências:** E2-S1 (Caçador — passos), E4 (mapa — zonas)

**Prioridade:** P2

---

---

## Épico E9: Polimento e Balanceamento

**Objetivo:** Ajustar números da tabela-mestra, realizar playtest com amigos (1–7 Sobreviventes), corrigir bugs e edge cases, e otimizar desempenho para a Fuga.

**Prioridade:** P1 — Alta (define qualidade final)

**Dependências:** E1–E8 (todas as épicas anteriores completas)

---

### E9-S1: Ajuste Fino da Tabela-Mestra

**Como** designer,
**Quero** revisar e ajustar todos os valores da tabela-mestra de balanceamento com base em dados de playtest,
**Para** alcançar as métricas de sucesso: vitória do Caçador 45-55%, 4-8 missões/partida, Rage em ~30%+ das partidas.

**Arquivos a criar/modificar:**
- `src/shared/BalanceTuning.lua` — valores ajustáveis em um só lugar (substitui constantes dispersas)
- Modificar todos os `*Config.lua` — referenciar BalanceTuning

**Critérios de Aceitação:**
- Todos os valores numéricos consolidados em um arquivo de tuning
- Parâmetros a ajustar: danos, cooldowns, windups, velocidades, HP, stamina, durações, raios
- Cada valor documentado com justificativa (por que este número?)
- Primeira rodada de ajuste após 5 partidas de playtest
- Segunda rodada após 15 partidas
- Métricas-alvo monitoradas:
  - Vitória do Caçador (Contenção): 45–55%
  - Missões concluídas/partida: 4–8 de 10
  - Tempo até 1ª morte: 1,5–4 min
  - Frequência de Rage: ~30%+ das partidas
  - Duração média da partida: 5–9 min

**Dependências:** E1–E8 (tudo implementado)

**Prioridade:** P0

---

### E9-S2: Playtest com Amigos (1–7 Sobreviventes)

**Como** desenvolvedor,
**Quero** conduzir playtests com 3-4 amigos (até 8 jogadores) em sessões regulares,
**Para** validar o loop de gameplay, balanceamento e encontrar bugs.

**Arquivos a criar/modificar:**
- `docs/playtest-log.md` — registro de sessões de playtest
- `docs/playtest-feedback.md` — feedback coletado, bugs encontrados
- `src/server/DebugController.server.lua` — comandos de debug para playtest (ex.: set HP, spawn missão, zerar Ciclo)

**Critérios de Aceitação:**
- Mínimo de 3 sessões de playtest com ≥4 jogadores
- Cada sessão documentada: data, participantes, duração, resultado, bugs, feedback
- Comandos de debug disponíveis (apenas em modo teste/estúdio):
  - Zerar Ciclo (testar Fuga)
  - Spawnar missão específica
  - Setar HP do Caçador/Sobrevivente
  - Ativar/desativar Rage
  - Resetar partida
- Satisfação dos jogadores: ≥7/10 em pesquisa informal
- Logs de partida coletados: timestamps, mortes, missões, uso de habilidades

**Dependências:** E1–E8 (jogo jogável)

**Prioridade:** P0

---

### E9-S3: Correção de Bugs e Edge Cases

**Como** desenvolvedor,
**Quero** corrigir todos os bugs encontrados no playtest e tratar edge cases,
**Para** garantir uma experiência estável e sem exploits.

**Arquivos a criar/modificar:**
- `docs/bug-tracker.md` — lista de bugs, severidade, status
- Correções nos arquivos de sistema conforme bugs encontrados

**Critérios de Aceitação:**
- Todos os bugs P0 e P1 corrigidos
- Edge cases tratados:
  - Kill-death looping (jogador morrendo repetidamente sem chance de jogar)
  - Verificar todos os bônus LMS (condicionais e incondicionais)
  - Concorrência de habilidades (ex.: dois stuns simultâneos)
  - Limite de partículas na Fuga
  - Desconexão de jogador (Caçador ou Sobrevivente)
  - Timeout de DataStore
  - Troca de perspectiva durante animações
  - Pulo durante stun/silêncio
- Crash rate <5% em 20 partidas
- Desconexões <10% em 20 partidas

**Dependências:** E9-S2 (playtest — para encontrar bugs)

**Prioridade:** P0

---

### E9-S4: Otimização de Desempenho para a Fuga

**Como** desenvolvedor,
**Quero** otimizar a fase de Fuga (fogo + perigos + até 8 jogadores) para manter ≥55 FPS no PC e ≥28 FPS no mobile,
**Para** cumprir as metas de desempenho no pior caso.

**Arquivos a criar/modificar:**
- `src/client/PerformanceController.client.lua` — LOD, culling, limite de partículas
- Modificar `src/client/FireEffects.client.lua` — otimizar partículas de fogo
- Modificar `src/client/HazardEffects.client.lua` — otimizar efeitos de perigo

**Critérios de Aceitação:**
- FPS médio na Fuga (pior caso): ≥55 (PC), ≥28 (mobile)
- Partículas de fogo: ≤200 simultâneas (com mobile ativo)
- Memória: <500 MB (mobile) — verificado no Developer Console
- Carregamento: <15s do lobby ao spawn (mobile)
- Latência: <100ms (host local + amigos remotos)
- Light baking aplicado (iluminação pré-calculada para mobile)
- LOD para modelos distantes (>100 studs)
- Teste de estresse: 8 jogadores + Fuga com todos os perigos ativos

**Dependências:** E6 (Fuga — fogo e perigos), E9-S2 (playtest — para medir)

**Prioridade:** P1

---

### E9-S5: Validação Anti-Cheat e Segurança

**Como** desenvolvedor,
**Quero** validar que as proteções anti-exploit funcionam (speed-hack, teleporte, HP/stamina hack, fraude de moedas),
**Para** garantir uma experiência justa para todos os jogadores.

**Arquivos a criar/modificar:**
- `src/server/AntiCheatController.server.lua` — validações server-side
- Modificar `src/server/MovementController.server.lua` — reforçar validação
- Modificar `src/server/StaminaController.server.lua` — reforçar validação
- Modificar `src/server/DataStoreController.server.lua` — reforçar validação de ganhos

**Critérios de Aceitação:**
- Speed-hack detectado e corrigido (velocidade validada no servidor)
- Teleporte detectado e revertido (posição validada no servidor)
- HP/stamina não modificáveis pelo cliente (valores autoritativos no servidor)
- Moedas validadas: ganhos só por eventos reais de jogo
- DataStore: operações autenticadas, sem injeção
- Assimetria de informação mantida: cliente do Caçador não recebe classe/HP dos Sobreviventes
- Log de tentativas de exploração para análise

**Dependências:** E1–E8 (todos os sistemas implementados)

**Prioridade:** P1

---

### E9-S6: Revisão Final de Todas as Interações

**Como** designer,
**Quero** uma revisão sistemática de todas as interações entre sistemas (Caçador vs Sobreviventes, habilidades vs habilidades, missões vs perigos vs Fuga),
**Para** garantir que nada quebre em casos de borda.

**Arquivos a criar/modificar:**
- `docs/interaction-matrix.md` — matriz de interações testadas

**Critérios de Aceitação:**
- Matriz de interações preenchida e validada:
  - Cada habilidade de Sobrevivente vs cada habilidade do Caçador
  - Pulo vs cada hitbox de ataque
  - Stun + i-frames vs ataques durante i-frames
  - Rage vs Ciclo (pausa/retoma)
  - Rage vs dano de Sobreviventes
  - Missão vs movimento (cancelamento)
  - Múltiplos Sobreviventes na mesma missão
  - Morte durante missão
  - Morte durante Rage do Caçador
  - Autodestruição vs Agarrar (anti-sinergia)
  - LMS vs condições de vitória
  - Desconexão do Caçador (partida inválida)
  - Desconexão de Sobrevivente (recalcular vivos)
- Todas as interações produzem resultado esperado
- Sem soft-locks ou estados inválidos

**Dependências:** E1–E8 (todos os sistemas)

**Prioridade:** P1

---

---

## Resumo de Arquivos

### Arquivos a Criar por Épico

| Épico | Arquivos Server (.lua) | Arquivos Client (.lua) | Shared (.lua) | Assets |
|-------|----------------------|----------------------|--------------|--------|
| E1 | 5 | 4 | 5 | 0 |
| E2 | 8 | 6 | 3 | 4 |
| E3 | 5 | 4 | 8 | 12 |
| E4 | 2 | 3 | 4 | 10+ |
| E5 | 5 | 4 | 5 | 6 |
| E6 | 4 | 5 | 3 | 2 |
| E7 | 3 | 4 | 2 | 0 |
| E8 | 1 | 6 | 3 | ~20 |
| E9 | 3 | 1 | 1 | 0 |
| **Total** | **36** | **37** | **34** | **~54** |

### Total de Histórias por Épico

| Épico | Nome | Histórias |
|-------|------|:---------:|
| E1 | Fundação | 6 |
| E2 | O Caçador | 6 |
| E3 | Sobreviventes | 6 |
| E4 | O Mundo | 5 |
| E5 | Missões e Ciclo | 6 |
| E6 | Fuga e Resolução | 5 |
| E7 | Lobby, Loja e Persistência | 3 |
| E8 | Áudio e Atmosfera | 4 |
| E9 | Polimento e Balanceamento | 6 |
| **Total** | | **47 histórias** |

---

## Ordem de Implementação Recomendada (MVP ~3-4 semanas)

### Semana 1: Fundação + Caçador
- E1 (Fundação) completo: S1→S2→S4→S3→S5→S6
- Iniciar E2 (Caçador): S1→S2→S6 (stun/i-frames) em paralelo

### Semana 2: Sobreviventes + Mundo
- E2 restante: S3→S4→S5 (Braço, Grito, Rage)
- E4 (Mundo): S1→S4→S5 (terreno + lobby + portões) em paralelo
- Iniciar E3 (Sobreviventes): S1→S2 (Médico + Soldado)

### Semana 3: Sobreviventes + Missões + Fuga
- E3 restante: S3→S4→S5→S6 (Sackboy + Robô + dano + LMS)
- E5 (Missões e Ciclo): S1→S5→S2→S3→S4→S6
- E6 (Fuga): S1→S4→S2→S3→S5

### Semana 4: Persistência + Áudio + Polimento
- E7 (Loja e Persistência): S1→S2→S3
- E8 (Áudio): S1→S2→S3→S4
- E9 (Polimento): S1→S2→S3→S4→S5→S6

---

*Fim do documento — The broken box Epics & Stories v1.0*
