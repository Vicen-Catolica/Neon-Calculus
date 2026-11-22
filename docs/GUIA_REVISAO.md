# Neon Calculus — Guia para a revisão final

O que foi feito nas Fases 2, 3 e 4, como conferir cada uma e o que ficou em aberto. Os planos detalhados estão em `docs/PLANO_FASE_2.md`, `docs/PLANO_FASE_3.md` e `docs/PLANO_FASE_4.md`.

---

## 1. Onde está cada coisa

**Nada foi enviado ao GitHub.** As branches são locais e empilhadas: cada fase foi criada a partir da anterior.

| Fase | Branch | Base | Commits | Arquivos |
|---|---|---|---|---|
| 1 — Submundo de Neon | `feature/slums-stage-1` | — | já mergeada no `develop` | — |
| 2 — Setor Industrial | `feature/industrial-stage-2` | `origin/develop` | 11 | 191 |
| 3 — Setor de P&D | `feature/rnd-stage-3` | Fase 2 | 12 | 174 |
| 4 — Núcleo Quântico + Duelo | `feature/core-stage-4` | Fase 3 | 13 | 104 |

`feature/core-stage-4` contém o jogo inteiro. Para ver só o que uma fase acrescentou:

```bash
git diff --stat feature/rnd-stage-3...feature/core-stage-4
```

**Sugestão de merge:** abrir os PRs na ordem 2 → 3 → 4 para o `develop`. Cada PR mostra só o diff da sua fase, e é mais fácil revisar em partes. Antes do PR da Fase 3, a base dela já precisa ter a Fase 2 no `develop`, e o mesmo vale para a 4. O CI (`.github/workflows/blank.yml`) roda o roteiro de testes completo em cada push.

---

## 2. Testes automáticos

```bash
tools/run_tests.sh
```

O roteiro importa o projeto, compila o C#, roda os 23 testes NUnit e 13 simulações headless. Leva **mais de 10 minutos**. Para rodar só algumas simulações:

```bash
SIMS="duel_sim duel_bot_sim" tools/run_tests.sh
```

| Simulação | O que confere |
|---|---|
| `stage_sim`, `route_sim` | Fase 1 (rota completa, mecânicas) |
| `flow_sim` | o jogo inteiro: transições, checkpoint, Continuar, game over, Fase 1 → Duelo |
| `stage2_sim` | Fase 2: duto, vapor, esteira, drones, lockdown |
| `stage3_sim`, `stage3_live_sim` | Fase 3: luzes, lasers, ciborgues, Vance, sonar, camuflagem; esconderijos com tudo ligado |
| `stage4_sim`, `stage4_live_sim` | Fase 4: pontes de luz, abismo, galeria, lore, alarme; esconderijos com tudo ligado |
| `duel_sim` | peças do Duelo e o Duelo inteiro por código, até a vitória |
| `duel_bot_sim` | robô que só desvia vence o Duelo em 3 sementes (os padrões são justos) |
| `balance_sim` | tabela de tempos de hack por tipo, lockdown, laser, ciborgue, Duelo |
| `ui_sim` | tela de hack (acerto, erro, abortar, SINE, nível 5, Paradoxo), diálogos, Como jogar, pausa, lore, encerramento |
| `edge_sim` | casos-limite do playtest automatizado: hack pendurado na escada, Esc no quadro em que o hack abre, pausa na visão hacker, Esc repetido, hack escondido, abismo com pouca defesa, reiniciar andar com o Vance resgatado, pausa bloqueada depois de vencer o Duelo |

Fora do roteiro (não entram no CI):

- `tests/chaos_sim.tscn`: robô que aperta teclas ao acaso em cada fase (andar, pular, escadas, esconder, visão hacker, hack certo/errado/abortado/sem tempo, sonar, camuflagem, pausa, reiniciar, game over) e vigia travas de estado a cada quadro (jogo pausado sem tela, câmera lenta presa, duas telas abertas, mundo rodando atrás do game over, Eduardo fora do mapa…). `CHAOS_SECS=100 CHAOS_SEED=1 godot --headless --path . res://tests/chaos_sim.tscn`; `CHAOS_LEVELS=4,5` limita as fases.
- `tests/ui_shots.tscn`: fotos das telas sobrepostas (hack nível 5 com SINE, Paradoxo, pausa, Como jogar, diálogos, game over, encerramento). Precisa de janela: `LIBGL_ALWAYS_SOFTWARE=1 godot --path . --windowed --resolution 1920x1080 res://tests/ui_shots.tscn -- <pasta>`.

> O import do Godot reformata `MathGenerator.cs`, `math_visualizer.gd` e `EquationGenerator.cs` (tabs/CRLF). Se aparecerem como modificados depois de rodar os testes sem você ter mexido neles: `git restore` nos três.

---

## 3. Como pular direto para uma fase

- **Do começo:** menu → INICIAR (apaga o save).
- **Direto numa fase:** no editor do Godot, abra a cena e aperte **F6** (rodar cena atual):

| Cena | Fase |
|---|---|
| `scenes/levels/slums/slums_stage1.tscn` | 1 |
| `scenes/levels/industrial/industrial_stage2.tscn` | 2 |
| `scenes/levels/rnd/rnd_stage3.tscn` | 3 |
| `scenes/levels/core/core_stage4.tscn` | 4 (aproximação) |
| `scenes/levels/core/core_duel.tscn` | 4 (Duelo de Paradoxo) |

Rodar uma fase direto grava o checkpoint nela, então depois o "Continuar" do menu volta para lá. Assim o Dr. Vance não está resgatado; para testar o Duelo com o Protocolo Vance, jogue a Fase 3 resgatando-o e siga pelo elevador.

O save fica em `user://save.cfg` (no Linux, `~/.local/share/godot/app_userdata/<nome do projeto>/`).

---

## 4. Controles

| Tecla | Ação |
|---|---|
| A / D, Shift | andar, correr (faz barulho) |
| S ou Ctrl | agachar (dutos de 96 px, brecha da varredura) |
| Espaço, W / S | pular, escadas |
| F | esconder-se, ler terminal, avançar diálogo |
| Q ou botão direito (segurar) | visão hacker |
| Mouse / Tab, E / clique | escolher alvo, hackear |
| **V** | Ping Sonar (novo) |
| **C** | Variável Oculta, camuflagem (nova) |
| Esc | pausa; durante o hack, aborta (não no lockdown nem no Duelo) |
| N | no Paradoxo final, responde "Ø SEM SOLUÇÃO" |

---

## 5. Roteiro de playtest à mão

Nada disto foi jogado com teclado e mouse, só por simulação. Vale passar por cada item.

### Geral (pedidos da professora)
- [ ] Acentos (ã, õ, ç) legíveis em todos os textos (fonte Exo 2).
- [ ] Ao confirmar a resposta: "CORRETO!" em verde ou "INCORRETO: x = … não resolve a equação. -3 s" em vermelho.
- [ ] O passo a passo da SINE abre no 2º erro e chega na resposta certa.
- [ ] "Como jogar" no menu e na pausa, com o objetivo do jogo.
- [ ] Cronômetro e SINE em tempo real durante a câmera lenta.

### Fase 2 — Setor Industrial
- [ ] Duto só agachado; válvula de vapor tapa guarda e câmera.
- [ ] Esteira para com o hack; drone reinicia.
- [ ] Lockdown nos servidores: portas fecham, 25 s, saída mais difícil.
- [ ] Etapa 11 do plano da Fase 2 (ajuste fino de tempos) nunca teve playtest à mão.

### Fase 3 — Setor de P&D
- [ ] Diálogo de elevador abre ao chegar e não repete depois de morrer.
- [ ] Balcão e cubículos iluminados só escondem depois de apagar a luz do teto.
- [ ] Lasers: o fixo desliga com o hack; os temporizados dão para passar no ritmo; o duto passa por cima.
- [ ] Unidade Lógica: não ouve, não cai no quiosque, detecta rápido; o hack a deixa cega por 6 s.
- [ ] Lab 07: resgatar o Vance (equação de ângulos), diálogo, e depois +15% de tempo e SINE no 1º erro.
- [ ] Sonar (V) e camuflagem (C) fazem sentido aqui.
- [ ] Terminais mostram a "DICA DA SINE" depois do texto.

### Fase 4 — Núcleo Quântico
- [ ] Pontes de luz: hackear o emissor, atravessar, a ponte pisca antes de sumir. A do meio liga e desliga sozinha.
- [ ] Cair no vazio volta à plataforma com −20 de defesa.
- [ ] Primeiro alarme: a Axioma fala pelos alto-falantes (tela com interferência vermelha).
- [ ] Equações do nível 5 (x dos dois lados): a balança e o passo a passo.

### Duelo de Paradoxo
- [ ] Confronto com a Axioma antes de começar; não se repete após game over.
- [ ] Cada ataque avisa antes. A brecha da varredura é alcançável; a varredura lateral passa agachado; o pulso tem um setor livre; a grade tem vãos.
- [ ] Errar a equação de um nó só apaga o nó por 4 s.
- [ ] O Paradoxo `x = x + 1`: um número é erro; Ø (ou N) vence.
- [ ] Vitória: falas finais, tela branca e encerramento com estatísticas e créditos.
- [ ] Depois de zerar, "Continuar" leva ao encerramento.
- [ ] **Dificuldade:** o Duelo está justo para quem joga de verdade? (O robô vence sem levar golpe porque reage no primeiro quadro do aviso.)

---

## 6. Decisões que se afastam do GDD (validar com a equipe)

1. **Camuflagem na tecla C**, não Q: o Q já era a visão hacker. O "Como jogar" e a tabela acima usam C.
2. **Laser giratório do Duelo trocado por grade de lasers**: um feixe girando a partir do núcleo, que fica no alto, não teria como ser desviado no chão.
3. **Equação de "lógica circular" = x dos dois lados (nível 5)**, mais acessível que sistemas 2×2. O Paradoxo final é `x = x + 1`, com resposta "sem solução".
4. **Errar no Duelo não mata**: o que derruba é a Defesa Neural zerar com os ataques.
5. **Lockdown estreia na Fase 2** (o GDD não fixa o andar); volta nos laboratórios da Fase 3.
6. **Dr. Vance é opcional**, com recompensa (Protocolo Vance) e falas que mudam no Duelo.
7. **Esc aborta o hack** com chance de alarme proporcional ao tempo restante (GDD §4); isso não existia antes da Fase 3.
8. **Segurança máxima** (−20% de tempo) nos laboratórios, no átrio e no Núcleo inteiro (GDD §2 e WDD §10).
9. **Arena do Duelo é uma cena própria**, para o checkpoint ficar logo antes do chefe.

---

## 7. Pendências conhecidas

- **Playtest com teclado e mouse** (seção 5).
- **Créditos das músicas:** a tela final lista só os títulos das três faixas; falta o autor.
- **Efeitos sonoros e "Voice Blips"** do GDD §9: não há arquivos de som para eles.
- **"Configurações" no menu de pausa** (GDD §8): a pausa tem Retomar, Como jogar, Reiniciar andar e Menu principal; as opções só estão no menu principal.
- **Ciclos de Processamento / upgrades do traje** (WDD §10): fora do escopo.
- **Build de Windows** (M5 do cronograma): não foi gerada nem testada.
- **Dicas de tecla fixas no texto:** a HUD ("[F] ESCONDER", "SONAR [V]"…), a visão hacker ("[E] HACKEAR") e o "Como jogar" mostram as teclas padrão; se o jogador remapear nas Opções, essas dicas não acompanham.
- **Arte ainda desenhada em código:** emissor de laser, cela, ponte de luz, núcleo e nós (funcionam e combinam com o estilo, mas não são pixel art desenhada).

---

## 8. Mapa rápido do código novo

| Área | Arquivos |
|---|---|
| Fases (geradas por script, não editar as `.tscn`) | `tools/build_*_stage.gd`, `tools/stage_builder_base.gd`, `tools/build_objects.gd` |
| Arte (scripts que processam o PixelLab) | `tools/gen_industrial_*.py`, `tools/gen_rnd_*.py`, `tools/gen_core_art.py`; originais em `tools/art_src/` |
| Infra | `scripts/core/` (level, save, transição, lockdown, abismo, gatilhos de diálogo) |
| Hack e equações | `scenes/hacking_ui/`, `scripts/hacking/` (gerador C# com níveis 1–5) |
| Objetos | `scripts/objects/` (válvula, esteira, laser, cela, ponte de luz…) |
| Inimigos | `Entities/Enemy/` (agente e Unidade Lógica), `scripts/enemies/` (drone) |
| Duelo | `scripts/duel/` (controlador, núcleo, nós, ataques) |
| Interface | `scripts/ui/` (diálogo, pausa, Como jogar, encerramento) e `scripts/player/` (sonar, camuflagem) |
| Textos | `data/lore/*.json`, `data/dialogue/*.json` |
