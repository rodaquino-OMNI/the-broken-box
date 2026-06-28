# The broken box — Guia de Assets

**Versao:** 1.0 — MVP / Prototipo
**Estilo visual:** Retraux (Roblox antigo — R6, studs, baixo poli, papelao)
**Estilo de audio:** Bitcrushed / lo-fi

---

## 1. Modelos de Personagem (R6 Retraux)

Todos usam rig R6 padrao do Roblox. Tris alvo: ~1000-1500.

| Personagem | Papel | Estilo | Status MVP | Tris |
|-----------|-------|--------|:---:|---:|
| O Distorcido | Cacador | Boneco R6 preto com fragmentacoes/rachaduras, partes escuras vazando | Gratis | ~1500 |
| O Distorcido (Rage) | Cacador (Rage) | Criatura preta grande, maos e torso rasgados | Gratis | ~1500 |
| Medico | Sobrevivente | Boneco R6 com detalhes medicos (cruz, maleta) | Gratis | ~1000 |
| Soldado | Sobrevivente | Soldadinho de brinquedo R6, bazuca nas costas | Pago (150 moedas) | ~1000 |
| Sackboy | Sobrevivente | Boneco de pano R6, intacto | Gratis | ~1000 |
| Robo | Sobrevivente | Robo de brinquedo R6, aspecto resistente | Pago (200 moedas) | ~1000 |

### Criacao (Roblox Studio + Blender):

1. **R6 rig:** Usar o rig R6 padrao do Roblox (Model > Rig Builder > R6).
2. **Texturizacao:** Cores solidas, sem PBR. Paleta desbotada/desaturada.
3. **Distorcido base:** Partir de um boneco R6. Adicionar partes pretas extrudadas e rachaduras nos membros. A cabeca pode ter um fragmento faltando com preto vazando.
4. **Distorcido Rage:** Escalar 1.3x. Remover textura do torso e maos, substituir por preto solido. Adicionar garras/dedos alongados.
5. **Soldado:** Verde militar desbotado. Adicionar cilindro da bazuca nas costas.
6. **Robo:** Cinza metalico, juntas visiveis, olhos com glow fraco (ambar).
7. **Exportar:** .fbx do Blender > importar no Roblox Studio.

### Toolbox search terms:

- `R6 soldier toy` (Soldado)
- `R6 robot toy` (Robo)
- `R6 ragdoll` (Sackboy)
- `R6 doctor toy` (Medico)
- `dark creature R6` (Distorcido)

---

## 2. Mapa — Criatividade Morta

### Estruturas Principais (3D parts em estilo papelao)

| Estrutura | Funcao de Design | Descricao |
|-----------|-----------------|-----------|
| O Castelo | Loopar | Alto (~40 studs), escalavel por fora, percorrivel por dentro. Torres, muralhas, ponte levadica. |
| A Caverna | Esconder | Rebaixada, escura. Entrada tipo gruta. Corpos de brinquedo no interior. |
| O Estoque de Materiais | Despistar | Labirinto de corredores/prateleiras. Bonecos fundidos aos materiais. |

### Caracteristicas do terreno:

- **Chao plano** com relevos suaves (usar Terrain ou Parts largas).
- **Obstaculos propositais:** caixas de papelao, pecas derrubadas, plataformas baixas.
- **Tamanho do mapa:** travessia de ~25s correndo (ponta a ponta).
- **Estilo visual:** tudo em **papelao** — textura CraftPaper ou cor marrom-claro (#C4A882). Bordas com fita crepe visivel.
- **Paleta:** cores primarias de brinquedo desbotadas.

### Portoes (3, fixos):

| Portao | Localizacao |
|--------|-------------|
| P1 | Dentro/saida da Caverna |
| P2 | Interior do Castelo (subida + topo) |
| P3 | Centro do Estoque |

Cada portao: um arco de papelao com glow (ambar/vermelho na Fuga).

### Camada de Horror (sem gore):

- **Caverna:** corpos de brinquedo (bonecos R6 deitados, imoveis).
- **Castelo:** salas escuras com corpos internos.
- **Estoque:** bonecos parcialmente fundidos com prateleiras/materiais (inspirado na lore do Soldado Fundido/Compasso).

### Construcao no Roblox Studio:

1. Criar **base plana** com Part (500x500 studs, cor marrom-claro).
2. Construir as 3 estruturas usando **Parts** (caixas, cilindros, wedges) com textura de papelao.
3. Adicionar obstaculos menores: Parts de varios tamanhos como "caixas de papelao".
4. Adicionar **14 locais de missao** (marcadores visuais ou props):
   - ~5 na Caverna e aproximacoes (V1 Disjuntor)
   - ~5 no Estoque e entradas do Castelo (V2 Gerador)
   - ~4 no campo aberto e rampas (V3 Petroleo)
5. Adicionar os **3 portoes** nos locais designados.
6. Adicionar **corpos de brinquedo** na Caverna e Castelo.
7. Adicionar **fusoes** (bonecos + prateleiras) no Estoque.

### Toolbox search terms:

- `cardboard box` (caixas de papelao)
- `cardboard castle` (partes do castelo)
- `cardboard wall` (muralhas)
- `cave entrance cardboard` (entrada da caverna)
- `warehouse shelf cardboard` (prateleiras do estoque)
- `toy parts` (obstaculos/pecas)
- `cardboard arch` (portoes)

---

## 3. Audio

### Trilha Dinamica (3 stems, bitcrushed)

| Camada | Distancia do Cacador | Descricao | Duracao (loop) |
|--------|:---:|-----------|:---:|
| Calma | > 60 studs | Ambiente leve, toy-like, levemente detuned | ~30s |
| Alerta | 30-60 studs | Tensao crescente, batimentos sutis, cordas distorcidas | ~30s |
| Perseguicao | < 30 studs | Agressivo, percussao distorcida, drone grave | ~30s |

**Crossfade:** 2 segundos entre camadas.

### SFX (~15, bitcrushed)

| SFX | Contexto | Descricao |
|-----|----------|-----------|
| hunter_footstep | Passos do Cacador | Pesado, eco distorcido, deslocado |
| survivor_footstep | Passos do Sobrevivente | Leve, plastico/brinquedo |
| hunter_m1 | M1 (Tapa) | Impacto seco + distorcao |
| hunter_pull | Braco Esticado | Whoosh + estalo |
| hunter_roar | Grito | Distorcao vocal grave, reverberacao |
| hunter_rage_activate | Rage ativacao | Pulso grave + rachaduras/estalos |
| survivor_damage | Sobrevivente atingido | Impacto + gemido abafado |
| survivor_death | Morte de Sobrevivente | Quebra + silencio |
| mission_complete | Missao concluida | Click + power-up 8-bit |
| mission_interact | Interacao com missao | Beep mecanico |
| portal_open | Portao abre | Rangido metalico + whoosh |
| escape_success | Fuga bem-sucedida | Power-down + fade |
| fire_ambient | Incendio da Fuga | Crackle bitcrushed (loop) |
| coin_collect | Moeda ganha | Coin 8-bit |
| heartbeat | Batimento cardiaco | Sub grave, cresce com proximidade |

### Toolbox search terms:

- `8-bit horror ambient` (trilha)
- `bitcrushed drone` (drone)
- `8-bit footsteps` (passos)
- `lo-fi impact` (impactos)
- `8-bit coin collect` (moeda)
- `pixel fire crackle` (fogo)
- `8-bit heartbeat` (batimento)

### Dica de producao:

Se nao encontrar sons bitcrushed prontos, pegar sons normais e aplicar:
- **Roblox Studio:** inserir no SoundService, reduzir `PlaybackSpeed` (~0.8x), aumentar `Volume` e usar `RollOffMaxDistance`.
- **Audacity (externo):** Effects > Distortion > Clip, depois reduzir sample rate para 11025 Hz.

---

## 4. UI Assets

| Elemento | Descricao | Tipo |
|----------|-----------|------|
| HUD Survivor | HP, stamina, habilidades, minimapa | ScreenGui (codigo) |
| HUD Hunter | Furia, vivos restantes, habilidades | ScreenGui (codigo) |
| Mission UI | Minigames V1/V2/V3 | ScreenGui (codigo) |
| Character Select UI | Grid de personagens, lock/unlock | ScreenGui (codigo) |
| Shop UI | Loja com O Vendedor, precos | ScreenGui (codigo) |
| Game Over UI | Resultado, espectar/lobby | ScreenGui (codigo) |
| Heartbeat overlay | Distorcao de borda (20 studs) | ScreenGui (codigo) |

**Icones necessarios (Toolbox):**

- `skull icon pixel` — icone de morte/vivos
- `lightning bolt pixel` — icone de stamina
- `heart pixel` — icone de HP
- `coin pixel` — icone de moeda
- `lock pixel` — icone de personagem bloqueado
- `fire pixel` — icone de fogo/Fuga
- `hourglass pixel` — icone do Ciclo
- `cross pixel` — icone de cura (Medico)

---

## 5. Animacoes

| Animacao | Personagem | Prioridade |
|----------|-----------|:---:|
| Idle | Todos | Alta |
| Walk | Todos | Alta |
| Run | Todos | Alta |
| Jump | Todos | Alta |
| M1 (Tapa) | Distorcido | Alta |
| Pull (Braco Esticado) | Distorcido | Alta |
| Roar (Grito) | Distorcido | Alta |
| Rage transform | Distorcido | Alta |
| Death | Todos | Alta |
| Survivor A1 (Dash) | Soldado | Media |
| Survivor A2 (Bazuca) | Soldado | Media |
| Survivor A1 (Ink) | Sackboy | Media |
| Survivor A2 (Surge) | Sackboy | Media |
| Survivor A1 (Grab) | Robo | Media |
| Survivor A2 (Block) | Robo | Media |
| Survivor A3 (Selfdestruct) | Robo | Media |
| Survivor A1 (Potion) | Medico | Media |
| Survivor A2 (Charge) | Medico | Media |
| Stun | Distorcido | Media |

Prioridade Alta = necessario para testar o loop basico.
Prioridade Media = necessario para validar personagens individuais.

---

## 6. Lobby — A Caixa

- **Ambiente:** caixa de brinquedos fechada, estilo retraux.
- **O Vendedor:** NPC boneco R6 parado, com dialogo em ScreenGui.
- **Decoracao:** papeis de parede de crianca, estantes vazias, po em cantos.
- **Iluminacao:** quente/aconchegante porem desbotada.

---

## 7. Checklist de Build no Roblox Studio

1. [ ] Importar 5 personagens R6 no StarterPack
2. [ ] Construir mapa base (chao + 3 estruturas)
3. [ ] Posicionar 14 locais de missao
4. [ ] Posicionar 3 portoes
5. [ ] Adicionar obstaculos/caixas de papelao
6. [ ] Adicionar camada de horror (corpos/fusoes)
7. [ ] Construir Lobby (A Caixa)
8. [ ] Importar 3 stems de musica no SoundService
9. [ ] Importar ~15 SFX no SoundService
10. [ ] Configurar ScreenGuis no StarterGui
11. [ ] Importar icones (ImageLabels)
12. [ ] Configurar animacoes no Animator
13. [ ] Publicar para testar DataStore
14. [ ] Testar com 3-8 jogadores

---

*Guia atualizado em: 28 Jun 2026 — MVP E9 Polimento*
