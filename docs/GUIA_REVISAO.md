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

O roteiro importa o projeto, compila o C#, roda os 23 testes NUnit e 16 simulações headless. Leva **mais de 10 minutos**. Para rodar só algumas simulações:

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
| `duel_bot_sim` | robô que só desvia não leva golpe parado em cada passarela (todos os padrões) e vence o Duelo em 3 sementes |
| `balance_sim` | tabela de tempos de hack por tipo, lockdown, laser, ciborgue, Duelo |
| `ui_sim` | tela de hack (acerto, erro, abortar, SINE, nível 5, Paradoxo), diálogos, Como jogar, pausa, lore, encerramento |
| `guard_nav_sim` | agentes: atacam colados e recuam atirando, puxam o Eduardo do esconderijo se o viram entrar, sobem/descem escadas, pulam só o que dá para pular, param na beirada, seguram distância sem caminho, rádio chama reforços |
| `tutorial_sim` | guia do hack da SINE na Fase 1 (câmera no agente, avisos Q/E/equação), conversas novas das Fases 1 e 2 |
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
| N | no Paradoxo final, responde "∅ SEM SOLUÇÃO" |

---

## 5. Roteiro de playtest à mão

Nada disto foi jogado com teclado e mouse, só por simulação. Vale passar por cada item.

### Geral (pedidos da professora)
- [ ] Acentos (ã, õ, ç) legíveis em todos os textos (fonte Exo 2).
- [ ] Ao confirmar a resposta: "CORRETO!" em verde ou "INCORRETO: x = … não resolve a equação. -3 s" em vermelho.
- [ ] O passo a passo da SINE abre no 2º erro e monta a conta (ex.: "x = 8 / 4") sem dar o resultado.
- [ ] A fórmula do tipo de equação aparece embaixo da equação.
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
- [ ] O Paradoxo `x = x + 1`: um número é erro; ∅ (ou N) vence.
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
- **Efeitos sonoros provisórios:** os sons (voice blips, taser, alerta, passos, hack…) são sintetizados por `tools/gen_sfx.py`. Para trocar por um som gravado, basta sobrescrever `assets/sfx/<nome>.wav` com o mesmo nome.
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

---

## 9. Correções do primeiro playtest (branch `feature/playtest-fixes`)

| Pedido | O que mudou | Onde |
|---|---|---|
| Aviso por cima da tela de hack | A tela de hack fica na camada 30 (acima do lockdown e da HUD; abaixo do diálogo e da pausa) | `scenes/hacking_ui/hacking_interface.gd` |
| Agente colado não ataca | Encostado no Eduardo conta como "vendo" (o raio começava dentro dele) | `Entities/Enemy/enemy.gd` (`is_player_in_los`) |
| Agentes não pulam / espelham por baixo | Perseguição nova (`chase_move`): pulam obstáculos, sobem e descem escadas, saltam de bordas; sem caminho, sobem o que dá e esperam a ~150 px mirando | `Entities/Enemy/enemy.gd`, estados `State*.gd` |
| Drone só vê na esteira | O sensor aponta 40° para baixo com cone de 70° e testa pés, centro e cabeça | `scripts/enemies/patrol_drone.gd` |
| Piso reto no Setor Industrial | Faixa de piso em profundidade (2.5D) como a das favelas | `tools/gen_floor_band.py industrial`, `tools/build_industrial_stage.gd` |
| Alerta chama os outros | Quem vê o Eduardo chama pelo rádio os agentes a até 700 px (chegam em 0,5 s; quem atende não repassa). Aviso "AGENTE CHAMOU REFORÇOS" e fala da SINE na 1ª vez | `enemy.gd` (`on_max_alert`), `scripts/ui/tutorial.gd` |
| Sons | Autoload `Sfx` (bus SFX). Voice blips por falante, taser, "!" e "?" dos agentes, rádio, passos (andando/correndo; agachado é silencioso), esconder, pulo, queda, dano, hack (abrir, tecla, certo, errado, abortar), sonar, camuflagem, sirene do lockdown | `scripts/core/sfx.gd`, `assets/sfx/`, `tools/gen_sfx.py` |
| Tutorial dentro do jogo | Autoload `Tutorial`. Na Fase 1, antes do 1º agente: a SINE pausa, a câmera vai até ele, e um aviso no alto espera cada passo (segurar Q, mirar e E, resolver x). As teclas saem do InputMap | `scripts/ui/tutorial.gd`, `data/dialogue/tutorial.json`, `_tutorial_trigger` no builder |
| Relação SINE–Eduardo | Conversas novas: abertura, quiosque e telhados (Fase 1); chegada, drones e elevador (Fase 2) | `data/dialogue/slums.json`, `data/dialogue/industrial.json` |

Para rever: o guia e as conversas tocam uma vez por save; use "Novo jogo" para vê-los de novo.

### Segundo playtest

| Pedido | O que mudou | Onde |
|---|---|---|
| Guarda colado | Recua enquanto atira (fica a ~110 px), se houver chão e espaço atrás | `enemy.gd` (`back_off_velocity`), `StateMaxAlert.gd` |
| Esconder-se na frente do guarda | Se ele viu o Eduardo entrar no esconderijo (estava em alerta e vendo), vai até lá e o puxa para fora | `StateMaxAlert.gd`, `eduardo.gd` (`pulled_from_hiding`) |
| Guarda pulando contra a parede | Só pula se a altura do pulo passa do obstáculo e não há teto em cima; senão para | `enemy.gd` (`_can_jump_over`) |
| Guarda caindo de plataformas | Para na beirada (quedas maiores que 72 px); desce só por escada | `enemy.gd` (`_ledge_ahead`) |
| Drone parado ao ver o jogador | Era intencional (parava enquanto a barra enchia). Agora segue o jogador pelo ar, dentro da faixa de patrulha + 160 px | `scripts/enemies/patrol_drone.gd` |
| Portas do lockdown sem apoio | Verga de aço com faixa de perigo da porta até o teto | `_door_header` no builder base |
| 10 virava 100 | O botão 0 da tela estava ligado duas vezes (um clique = "00") | `hacking_interface.gd` |
| Fórmula na tela / SINE sem resposta | Linha "FÓRMULA" com a regra geral de cada tipo; a SINE monta a conta mas termina em "faça a conta" (nunca o número pronto) | `hacking_interface.gd` (`formula_for`) |
| Elevador do Setor 2 | Cabine apoiada na passarela, cabos até a tampa do poço; a saída só vale em pé dentro da cabine (subir a escada por baixo não troca mais de fase) | `build_industrial_stage.gd`, `level_exit.gd` (`require_standing`) |


### Terceiro playtest

| Pedido | O que mudou | Onde |
|---|---|---|
| Guarda recuando sem animação | Ao recuar (anda para um lado olhando para o outro) toca a caminhada ao contrário | `enemy.gd` (`_update_animation`) |
| Raio do taser saindo do meio do corpo | Sai da ponta da arma (`muzzle_offset`, espelha com o lado) | `enemy.gd` (`muzzle_position`) |
| Tempo de hack no guarda | Barra ciano em cima do agente hackeado que esvazia até ele voltar (pisca no fim); vale também para a visão apagada do ciborgue | `enemy.gd` (`hack_time_left`) |
| Quadrados da tela de hack | Trocados por uma balança em equilíbrio: cada prato é um lado da equação, com caixas "x" e pesos com número (vermelho = tirar); k(x + a) vira k bandejas [x a]. Regra de três, retângulo e triângulo continuam com a figura | `scenes/hacking_ui/math_visualizer.gd` |

### Quarto playtest

| Pedido | O que mudou | Onde |
|---|---|---|
| Tempo do hack em tudo | Barra ciano em cima de **todo** alvo com efeito temporário (câmera, drone, válvula, esteira, laser, ponte de luz, letreiro, quiosque), que esvazia e pisca no fim. O componente `Hackable` desenha; cada objeto só informa `hack_time_left()` | `scripts/hacking/hackable.gd` + cada objeto |
| Piso 2D nos Setores 3 e 4 | Faixa de piso em profundidade: porcelanato com friso ciano (P&D) e placa escura com grade de luz (Núcleo e arena do Duelo) | `tools/gen_floor_band.py rnd` / `core`, builders |
| Objetos flutuando | Automático em todas as fases: câmera de parede sem parede atrás ganha haste até o teto (ou poste até o chão); emissor de laser sem teto ganha haste; porta mais baixa que o teto ganha verga de aço com faixa de perigo. Servidores do mezanino de P&D movidos para cima da passarela; câmera da ponte do Núcleo sobre a plataforma | `scripts/core/supports.gd`, `security_camera.gd`, `laser_barrier.gd`, `security_door.gd` |
| Porta "teleportando" por baixo / porta final estranha | Saídas de P&D e do Núcleo só valem em pé dentro (como o elevador do Setor 2). Porta do Domo encostada na parede direita, que agora vai até o chão | `build_rnd_stage.gd`, `build_core_stage.gd` |
| Duelo difícil demais | Golpe tira 15 (antes 25: 7 golpes até cair), intervalos entre ataques 2,4/1,9/1,5 s (antes 1,6/1,2/0,8), brecha do pulso 90° (120° com o Vance). Os nós ("cristais") são hackeáveis a até 900 px e sem linha de visão: dá para mirar do chão, sem subir até eles | `scripts/duel/*`, `hackable.gd` (`hack_range`, `ignore_line_of_sight`) |

### Quinto playtest (relatório do Gemini, validado)

| Pedido | O que mudou | Onde |
|---|---|---|
| Ataques do chefe impossíveis de desviar na passarela | Todo padrão agora tem saída **no piso em que o Eduardo está** (chão ou passarela), ao alcance correndo: o duelo mede o piso com raios (`player_span()`), põe a brecha da varredura e do pulso dentro dele, tira colunas da grade até abrir um vão ali, e a varredura lateral deixa a brecha de agachar rente à passarela (antes só rente ao chão) | `scripts/duel/paradox_duel.gd`, `sweep_attack.gd` |
| Varredura de Rotina dentro do Duelo | Arena sem `RoutineSweep`; hack dos nós não mexe na variância (errar já faz o núcleo recuperar a camada) | `build_duel_stage.gd`, `paradox_duel.gd` |
| Spoilers | "Como jogar" não diz mais onde está o Vance nem a resposta do Paradoxo; a tela do Paradoxo não mostra fórmula (a SINE explica depois do 1º erro) | `how_to_play.gd`, `hacking_interface.gd` |
| Aviso do tutorial preso | O guia do hack desiste se o Eduardo fica a mais de 700 px do agente | `scripts/ui/tutorial.gd` |
| Sonar e Camuflagem sem apresentação | Conversa `slums_suit` (SINE ensina [V] e [C]) logo depois do primeiro agente | `data/dialogue/slums.json`, `build_slums_stage.gd` |
| Escada de D batia a cabeça no duto | Chaminé nas colunas 111–112, como a da escada 79 | `build_rnd_stage.gd` |
| Lasers da galeria soltos sob o mezanino | Emissor encosta no mezanino; a haste não atravessa mais passarela | `build_core_stage.gd`, `laser_barrier.gd` |
| Puxadinho e tigela de ramen flutuando | Pilares sob o puxadinho (o vão de 96 px continua livre); tigela num braço de ferro com correntes | `build_slums_stage.gd` |
| HUD ilegível, slider "Voz" morto, sem Opções na pausa | Textos da Defesa em 18/16 px; "Voz" controla o bus novo `Voice` (blips das falas) e é salvo; botão "Opções" na pausa (Esc volta) | `hud.gd`, `default_bus_layout.tres`, `settings_manager.gd`, `options_menu.gd`, `sfx.gd`, `pause_menu.gd` |
| Estado de game over | Ao cair, o `GameManager` entra em `GAME_OVER` (some o HUD de furtividade) | `eduardo.gd` |
| Guarda congelava com o cone visível | Caixa de "na tela" do guarda cobre corpo e alcance (920×280) | `Entities/Enemy/Enemy.tscn` |
| Lore falava em "nível inferior" | Textos falam em subir a torre | `data/lore/slums.json`, `data/dialogue/slums.json` |

Não reproduzido: cones de visão atravessando o chão (headless e com janela, os cones param no piso). Mantido de propósito: o hack **pausa** o mundo.

### Sexto playtest (segunda rodada do Gemini, validada)

| Pedido | O que mudou | Onde |
|---|---|---|
| Erro "Rect2 size is negative" no Duelo | A varredura não cria o pedaço de barra vazio quando a brecha encosta na borda da arena | `scripts/duel/sweep_attack.gd` |
| Músicas fora do slider "Música" | Trilha do Duelo, do hack e do game over no bus `BGM` | `paradox_duel.gd`, `HackingInterface.tscn`, `GameOver.tscn` |
| Daltonismo simulava em vez de corrigir | Filtro de daltonização: calcula o que a pessoa perde e joga nos canais que ela enxerga. Pesos ajustados para a paleta do jogo (vermelho, verde, laranja, amarelo, ciano, rosa): a menor diferença entre essas cores, vista pela pessoa daltônica, sobe de 0,17→0,29 (protan), 0,02→0,22 (deutan) e 0,07→0,17 (tritan) | `scenes/options/colorblind.gdshader` |
| Descer escada pelo topo | Em pé no patamar do topo, S começa a descida (atravessa a grade de mão única) | `scripts/player/eduardo.gd` (`_ladder_below`) |
| Apoios atravessando passarela | A busca de teto/chão dos apoios também para em passarela de mão única: a porta de lockdown de D ganhou a verga | `scripts/core/supports.gd` |
| Corte reto do escurecimento da saída (Fase 1) | Borda direita em degradê | `build_slums_stage.gd` |
| Fundo vazando sob a parede do Domo | Chão vai até a borda da fase | `build_core_stage.gd` |
| Placas de saída como texto solto | Placa escura com borda neon (Setor 2, P&D, Domo) | `stage_builder_base.gd` (`_exit_sign`) |
| Mancha no retrato da Axioma | Canto superior esquerdo refeito (espelho do canto direito) | `assets/ui/portraits/axioma.png` |
| "Ø" parecido com "O" | Símbolo de conjunto vazio de verdade: "∅ SEM SOLUÇÃO" | `hacking_interface.gd`, `data/lore/core.json` |

