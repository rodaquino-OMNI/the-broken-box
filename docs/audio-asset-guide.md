# Guia de Assets de Áudio — The broken box

**Versão:** 1.0
**Data:** 28 de Junho de 2026
**Referência:** GDD Design de Áudio de Tensão (Bitcrushed)

> **IMPORTANTE:** Todos os arquivos de áudio devem ser bitcrushed / lo-fi para
> manter a estética retraux. Busque por sons com textura de "gravação antiga",
> "8-bit", "16-bit", ou com distorção digital leve.

---

## 1. Trilha Musical Dinâmica (4 Camadas)

A trilha usa um sistema de 3+1 camadas com crossfade de 2s:
- **Calma** → padrão, Cacador a mais de 60 studs
- **Alerta** → Cacador entre 30 e 60 studs
- **Perseguição** → Cacador a menos de 30 studs (ou durante Rage)
- **Climax** → fase de Fuga

### BUSCAR NO TOOLBOX ROBLOX:

| Camada | Termos de Busca | Descrição Desejada |
|--------|-----------------|-------------------|
| **Calma** | `ambient`, `dark ambient`, `creepy lullaby`, `music box`, `abandoned`, `empty room` | Ambiente sombrio mas contido. Tom de brinquedo abandonado. Sem percussão. 60-90 BPM. |
| **Alerta** | `tension`, `suspense`, `buildup`, `ominous drone`, `heartbeat ambient`, `approaching danger` | Tensão crescente. Drone grave, texturas ásperas. 80-110 BPM. |
| **Perseguição** | `chase`, `pursuit`, `frantic`, `distorted percussion`, `industrial horror`, `panic` | Percussão distorcida, ritmo acelerado. 120-160 BPM. Baixo pesado e saturado. |
| **Climax** | `apocalyptic`, `collapse`, `fire`, `destruction`, `world ending`, `chaos` | Colapso total. Camadas densas, distorção máxima. Sensação de urgência e fim. |

### IDs Placeholder (substituir no código):

Localização: `src/client/Audio/AudioManager.lua` → tabela `AUDIO_IDS`

```lua
MUSIC_CALMA       = "rbxassetid://0"  -- Substituir
MUSIC_ALERTA      = "rbxassetid://0"  -- Substituir
MUSIC_PERSEGUICAO = "rbxassetid://0"  -- Substituir
MUSIC_CLIMAX      = "rbxassetid://0"  -- Substituir
```

---

## 2. Batimentos Cardíacos

Batimentos em loop que aceleram com a proximidade do Cacador.
Audíveis a até 40 studs (GameConstants.Audio.HEARTBEAT_RADIUS).
PlaybackSpeed varia de 1.0 (longe) a 2.5 (muito perto).

### BUSCAR NO TOOLBOX ROBLOX:

| Termos de Busca | Descrição Desejada |
|-----------------|-------------------|
| `heartbeat`, `heart beat loop`, `anxious heartbeat`, `racing pulse`, `cardiac`, `thump` | Batimento cardíaco em loop limpo (sem música de fundo). De preferência com variação de intensidade ou que permita pitch shift sem artefatos. |

### ID Placeholder:

```lua
HEARTBEAT = "rbxassetid://0"  -- Substituir
```

---

## 3. SFX — Efeitos Sonoros

### BUSCAR NO TOOLBOX ROBLOX:

| Evento | Termos de Busca | Descrição Desejada | Duração |
|--------|-----------------|-------------------|---------|
| **Missão Concluída** | `quest complete`, `success chime`, `achievement`, `reward`, `coin collect` | Som positivo mas contido. Tom metálico ou de "caixa registradora de brinquedo". | 1-3s |
| **Jogador Ferido** | `hurt`, `damage`, `hit impact`, `pain grunt`, `flesh hit` | Som de impacto corporal. Sem gore explícito — mais "pancada seca" que sangrento. | 0.5-1s |
| **Jogador Morto** | `death`, `game over`, `failure`, `life lost`, `elimination` | Som de derrota/fim. Pode ser um "estouro" ou "quebra" distorcido. | 1-3s |
| **Rage Ativado** | `transformation`, `monster roar`, `power up evil`, `dark awakening`, `demon` | Transformação monstruosa. Rugido distorcido + impacto. Sensação de poder liberado. | 2-5s |
| **Portão Abrindo** | `gate open`, `door open heavy`, `mechanism`, `grinding metal`, `escape door` | Portão pesado abrindo. Metal rangendo, mecanismo antigo. | 2-4s |
| **Incêndio/Colapso** | `fire loop`, `burning`, `crackling fire`, `building collapse`, `rumbling` | Fogo crepitando + estrutura desmoronando. Pode ser loop para a fase de Fuga. | 5-30s (loop) |
| **Início da Fuga** | `alarm`, `siren`, `emergency`, `evacuation`, `warning horn` | Alarme de emergência. Sirene ou buzina distorcida. Urgência máxima. | 3-6s |

### IDs Placeholder:

```lua
SFX_MISSION_COMPLETE = "rbxassetid://0"  -- Substituir
SFX_PLAYER_DAMAGED   = "rbxassetid://0"  -- Substituir
SFX_PLAYER_DIED      = "rbxassetid://0"  -- Substituir
SFX_RAGE_ACTIVATE    = "rbxassetid://0"  -- Substituir
SFX_GATE_OPEN        = "rbxassetid://0"  -- Substituir
SFX_FIRE             = "rbxassetid://0"  -- Substituir
SFX_ESCAPE_START     = "rbxassetid://0"  -- Substituir
```

---

## 4. Passos do Caçador (Futuro)

Para implementação futura (E8-S5 ou além):
- **Termos:** `heavy footsteps`, `distorted steps`, `giant walk`, `monster stomp`
- **Estilo:** Passos pesados com eco deslocado da posição real (bitcrushed)
- **ID Placeholder:** Não incluso no MVP — som de passos é cosmético avançado

---

## 5. Dicas de Edição de Áudio

Para manter a estética bitcrushed/retraux:

1. **Bitcrusher:** Reduza a resolução para 8-bit ou 12-bit
2. **Sample Rate:** Diminua para 11025 Hz ou 22050 Hz
3. **Distorção:** Adicione saturação leve (não exagere — ainda precisa ser audível)
4. **EQ:** Corte agudos acima de 8 kHz e graves abaixo de 80 Hz
5. **Vinyl Crackle:** Opcional — adicione ruído de vinyl para textura "antiga"
6. **Ferramentas gratuitas:** Audacity (bitcrusher, EQ, distorção), LMMS, sfxr/bfxr

---

## 6. Verificação de Conformidade

- [ ] Todos os sons são bitcrushed/lo-fi
- [ ] Nenhum som tem gore, jumpscare ou conteúdo inadequado para 12+
- [ ] Todos os IDs no `AUDIO_IDS` foram substituídos
- [ ] Sons são mono (não estéreo) para performance no Roblox
- [ ] Duração total de assets < 50 MB (limite Roblox)
- [ ] Formatos: .ogg ou .mp3 (Roblox converte automaticamente)

---

## 7. Procedimento de Substituição

1. Encontre sons no **Toolbox Roblox** ou faça upload dos seus próprios
2. Copie o ID do asset (ex.: `rbxassetid://123456789`)
3. Substitua em `src/client/Audio/AudioManager.lua` na tabela `AUDIO_IDS`
4. Teste no Roblox Studio com o jogo rodando
5. Ajuste volumes em `playSfx()` se necessário (padrão: 0.6-1.0)

---

**Referências:**
- GDD v2.0 — Design de Áudio de Tensão (Bitcrushed)
- GameConstants.Audio (valores numéricos)
- AudioService.lua (servidor, orquestração)
- AudioManager.lua (cliente, reprodução)
