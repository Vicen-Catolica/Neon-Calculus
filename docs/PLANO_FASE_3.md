# Neon Calculus — Plano da Fase 3 (Setor de Administração e P&D)

Plano da terceira fase, no mesmo formato por etapas das fases 1 e 2. Cada etapa termina com algo testável. Base: GDD/WDD/TDD + `HANDOFF_codigo_claude.md` + o que já existe no código. Branch: `feature/rnd-stage-3` (criada a partir de `feature/industrial-stage-2`). **Nada vai para o GitHub até a revisão final de todas as fases.**

---

## 1. Ponto de partida

- **Fases 1 e 2 prontas** e testadas (5 simulações, 162 checagens + 18 NUnit em `tools/run_tests.sh`). A saída da Fase 2 é o elevador de carga com `NEXT_STAGE = ""`, ou seja, a Fase 3 só precisa ser ligada ali.
- **Infra multi-fase pronta:** `Level` genérico, `LevelTransition` ("Acessando..."), `SaveGame` (checkpoint por andar + lore), menu de pausa, "Como jogar", `GameManager.LEVELS`.
- **Builder compartilhado:** `tools/stage_builder_base.gd`; a Fase 3 vira `tools/build_rnd_stage.gd` (mesmo padrão de `build_industrial_stage.gd`).
- **Já existe e só falta usar:**
  - `Enemy.EnemyType.CYBORG` e `Hackable.Kind.CYBORG`: sem ouvido, não se distrai com quiosque, espera menor na patrulha, hack reinicia a rota. Nunca foi testado numa fase nem tem arte.
  - Equações do andar 3 no gerador: **regra de três** (subtópico 0: câmera, luz, quiosque) e **área de retângulo** (subtópico 1: porta, agente, drone). O ciborgue soma +1 andar, então usa **distributiva** (nível 4). O tempo do andar 3 já está na tabela de `_calculate_dynamic_time_limit`.
  - Gancho de lore: `industrial_04_vance` diz que o Dr. Vance foi levado ao **Laboratório 07, P&D**.
- **Não existe ainda:** caixa de diálogo (falas de SINE/Eduardo/Axioma/Vance), barreira a laser, NPC resgatável, habilidades do traje (Variável Oculta e Ping Sonar).

---

## 2. O que a Fase 3 é (docs)

- **Bioma** (GDD §6, WDD §3): áreas de design minimalista, **limpas e muito iluminadas**, clima controlado, **portas de segurança a laser** e vigilância intensa. É o contraste com a sujeira das duas primeiras fases: aqui não há sombra natural, o jogador tem que fabricá-la (hackeando luzes).
- **Narrativa** (GDD §1, §9; WDD §6): "ambientes estéreis e hiper-vigiados". A Axioma percebe a invasão e intensifica as defesas: estreia dos **Ciborgues Algorítmicos**. Side quest do WDD: **resgatar infiltradores presos** → **Dr. Vance**, criador do código-base, que "pode fornecer auxílio em hacks se for resgatado". Diálogo de elevador na entrada (SINE ansiosa, Eduardo sarcástico).
- **Inimigos** (GDD §7): Agentes Modificados ainda aparecem (nível intermediário), **ciborgues** nas zonas de segurança máxima (laboratórios). Drones continuam disponíveis. Ciborgue: patrulha perfeita, reação instantânea, imune a distração sonora; só o hack o altera (rotina ou sistema visual).
- **Dificuldade:** `floor_number = 3`. O GDD/WDD pedem tempo **menor** em áreas de segurança máxima → `time_limit_mult` < 1 nas portas e alvos dos laboratórios.

---

## 3. Desenho da fase

**Entrada:** o elevador de carga da Fase 2 abre na doca de serviço do andar administrativo. **Saída:** elevador executivo / átrio para o Núcleo Quântico (Fase 4; por enquanto `NEXT_STAGE = ""`).

Percurso proposto (~5 500 px de largura, verticalidade parecida com a Fase 2), uma ideia nova por trecho:

| # | Trecho | O que ensina / testa | Elementos |
|---|---|---|---|
| A | **Doca de serviço → recepção** | Luz demais: hackear **painéis de luz** para criar a própria sombra; esconder atrás de balcões | diálogo de elevador (SINE/Eduardo), 1 agente, câmera de parede, balcão/vaso (esconderijo), terminal de lore |
| B | **Escritórios open-space** (dois níveis, passarela de vidro) | Furtividade em espaço aberto: cubículos como cobertura, quiosque/monitor para distrair agentes | 2 agentes, câmera-domo, cubículos, quiosque, duto no forro como rota alternativa |
| C | **Corredor de segurança a laser** | **Barreira a laser**: fixas (hackear o emissor desliga por X s) e temporizadas (ritmo liga/desliga) | 3–4 lasers, painel de controle, câmera; duto alternativo agachado |
| D | **Laboratórios de P&D / Lab 07** | **Ciborgue**: rota perfeita, não ouve, não cai em distração; o hack é a única saída. **Resgate do Dr. Vance** (opcional) | 2 ciborgues, câmera, cela com campo de força (hack nível 4), lockdown na ala dos laboratórios |
| E | **Átrio do elevador executivo** | Subida vertical sob vigilância máxima + Varredura de Rotina se a variância estourar | escadas/passarelas, 1 ciborgue + 1 agente, porta final com tempo reduzido → Fase 4 |

O greybox (etapa 3) vale como prova do layout; números se ajustam lá.

---

## 4. Mecânicas novas — como implementar

1. **Caixa de diálogo** (GDD §8: centro inferior; §9: voice blips) — `scripts/ui/dialogue_box.gd`, autoload ou CanvasLayer por fase. Recebe uma lista de falas `{quem, texto}`, escreve letra a letra em **tempo real** (mesma lição do cronômetro), avança com E/Enter/clique, trava o controle do jogador enquanto aberta (estado `CUTSCENE` no `GameManager` ou `PROCESS_MODE`). Cores por falante: SINE ciano, Eduardo branco, Axioma vermelho/laranja, Vance verde. Roteiros em `data/dialogue/rnd.json`. Gatilho por `Area2D` (`DialogueTrigger`, uma vez por save). Serve também para a fala da Axioma no lockdown (hoje é só um label). Blip sonoro fica para quando houver áudio.
2. **Barreira a laser** — `scripts/objects/laser_barrier.gd` + `Hackable.Kind.LASER` ("BARREIRA LASER", adicionado **no fim** do enum). Feixe vertical (`Line2D`/sprite esticado) + `Area2D`. Tocar no feixe ativo = alarme imediato (`GameManager.raise_alarm`) + variância; **não mata** (o perigo é o alarme/lockdown). Modos: `ALWAYS` (hack desliga por ~8 s, com aviso piscando antes de religar) e `TIMED` (liga X s / desliga Y s, hack congela desligado). Bloqueia visão? Não: o feixe é fino. Dificuldade: subtópico 0 (regra de três).
3. **Ciborgue (Unidade Lógica)** — cena `tools/build_objects.gd` → `scenes/enemies/cyborg.tscn`, reaproveitando `Enemy` com `enemy_type = CYBORG`. Ajustes:
   - patrulha sem espera aleatória (já existe a espera menor; tornar fixa);
   - barra de detecção enche bem mais rápido (reação "instantânea");
   - imune a quiosque e ruído (já existe);
   - **hack = ponto cego**: cone desligado por ~6 s (o GDD fala em "hackear seus sistemas visuais"), além de reiniciar a rota (comportamento atual). Escolher um dos dois em playtest; recomendação: ponto cego, mais legível;
   - taser igual ao agente (Defesa Neural).
4. **Dr. Vance (resgate opcional)** — `scripts/objects/holding_cell.gd`: cela com campo de força (`Hackable.Kind.DOOR` com `difficulty_bonus = 1` → distributiva). Ao abrir: diálogo com o Vance (revelação sobre o código-base e o "ponto cego no núcleo"), ele se teleporta/sai pela porta de serviço (sem escolta, para não virar missão de escolta). Recompensa salva no `SaveGame` (`vance_rescued = true`): **a SINE passa a abrir o passo a passo já no 1º erro e os hacks ganham +15% de tempo** (o WDD: "auxílio em hacks"). Aparece no HUD/Como jogar como "Protocolo Vance".
5. **Luzes em toda parte** — nada novo de código: `LIGHT` + esconderijos já existem. O desafio é de level design (pouquíssima sombra natural) e de arte (cones vermelhos precisam ler bem sobre fundo claro → contorno escuro no cone).
6. **Segurança máxima** — `time_limit_mult` 0.8 nos alvos da ala dos laboratórios e do átrio; lockdown (já existe) na ala do Lab 07.
7. **Ligar fases** — `GameManager.LEVELS[3] = {"scene": "res://scenes/levels/rnd/rnd_stage3.tscn", "title": "Setor de P&D"}` e `NEXT_STAGE` da Fase 2 apontando para ela.

---

## 5. Arte necessária

Regras do `GUIA_DE_ARTE_gemini.md` valem igual (tiles 32×32, personagens 128×128 com pés em y = 126, olhando para a direita, contorno ~`#0C0A0A`, sem anti-aliasing). Paleta do P&D: branco-gelo, cinza claro, vidro azulado, linhas de luz ciano; vermelho/laranja só para a Axioma e perigo. Para a leitura do jogo, **o tileset não pode ser branco puro**: tons médios (cinza-azulado) com detalhes claros, senão o personagem escuro e os cones somem.

| Prioridade | Asset | Como | Gerações |
|---|---|---|---|
| P1 | **Tileset limpo** (piso polido, paredes de painel, vidro), terreno "Corners" como os anteriores | imagem + recorte/script, como `gen_industrial_tiles.py` | 1–2 |
| P1 | **Fundo de parallax** (andar corporativo com janelas para a cidade de noite) | `create_image_pixen` | 1–2 |
| P1 | **Folha de props**: mesas, cubículos, balcão de recepção, vasos, bebedouro, monitores, racks brancos, bancadas de laboratório, tubos de amostra | `create_image_pixen` + recorte | 2 |
| P1 | **Ciborgue**: idle, patrol, alert, shoot, stunned/reboot (128×128) | personagem PixelLab + animações (ou edição dos sprites de guarda v2 se faltar orçamento) | 5–8 |
| P2 | **Dr. Vance**: idle na cela, falando | personagem + 1–2 animações | 2–3 |
| P2 | **Emissor de laser** (on/off) e feixe | `pixelart_workbench` (grátis) + feixe desenhado em código | 0 |
| P2 | **Cela / campo de força**, porta de laboratório, elevador executivo | `pixelart_workbench` / variação de `gen_door_art.py` | 0–1 |
| P3 | Retratos para a caixa de diálogo (SINE, Eduardo, Axioma, Vance) | `create_image_pixen` pequenos ou ícones desenhados | 0–2 |

**Orçamento:** ~12–20 gerações. Conta hoje (17/11): 1 do plano + 20 do bônus diário (+5 por noite, até 20). Ordem: tileset e fundo primeiro (definem a legibilidade com o fundo claro), conferir montado numa cena, depois ciborgue, depois o resto.

Enquanto a arte não chega: greybox com os tiles industriais clareados e retângulos coloridos; ciborgue = guarda v2 tingido.

---

## 6. Etapas (ordem de execução)

1. ✅ **Ligação e esqueleto** — `GameManager.LEVELS[3]`, saída da Fase 2 → Fase 3, `build_rnd_stage.gd` vazio (chão + player + saída). *Teste:* terminar a Fase 2 leva à Fase 3 com a transição "Acessando... Setor de P&D"; "Continuar" volta ao andar 3.
2. ✅ **Caixa de diálogo** + `DialogueTrigger` + diálogo de elevador. *Teste:* texto em tempo real com o mundo pausado, avança com Enter, não reabre após recarregar o checkpoint.
3. ✅ **Greybox da Fase 3** — layout A–E só com o que já existe (agentes, câmeras, luzes, esconderijos, quiosque, escadas, passarelas, dutos, terminais, porta, lockdown, saída). *Teste:* atravessável do início ao fim; screenshots de cada trecho.
4. ✅ **Barreira a laser** (fixa e temporizada, hack, alarme). *Teste:* tocar no feixe dispara alarme; hackeado, passa; religa depois do tempo.
5. ✅ **Ciborgue** (cena, ajustes de FSM, hack = ponto cego). *Teste:* não reage a quiosque/ruído; detecta mais rápido que o agente; hackeado, não vê por ~6 s.
6. **Dr. Vance** (cela, diálogo, recompensa salva e aplicada nos hacks). *Teste:* resgatar → `vance_rescued` no save; SINE abre no 1º erro; tempo +15%; sem resgate, nada muda.
7. **Lore** — `data/lore/rnd.json`: SINE na doca; e-mail corporativo sobre as "Atualizações Mandatórias"; relatório de testes do Projeto Determinismo (cobaias); diário da Dra. Kessler (continuação do terminal da Fase 2); registro da conversão de humanos em Unidades Lógicas; gancho para o Núcleo.
8. **Arte** — PixelLab conforme §5 e troca dos placeholders.
9. **Testes** — `tests/stage3_sim.gd` (um OK/FALHOU por mecânica, como `stage2_sim`) + `ui_sim` cobrindo a caixa de diálogo; entra no `run_tests.sh`.
10. **Playtest e ajuste** — tempos de laser/ciborgue, quantidade de luz, dificuldade do andar 3 (regra de três e área), bônus do Vance.

Commits pequenos por etapa no branch `feature/rnd-stage-3`, sem push.

---

## 7. Decisões em aberto (recomendação entre parênteses)

1. **Habilidades do traje (GDD: Variável Oculta Q, Ping Sonar V).** O Q hoje é a visão hacker. (Fazer **só o Ping Sonar (V)** nesta fase: o andar é aberto e cheio de ciborgues, revelar cones através de paredes ajuda muito e não conflita com nenhuma tecla. A camuflagem fica para a Fase 4, na tecla C, se houver tempo.)
2. ✅ **Hack no ciborgue:** ponto cego de 6 s (cone apagado, piscando no fim) + rota reiniciada. A barra enche ~2× mais rápido que a do agente e pula a suspeita.
3. **Vance opcional ou obrigatório?** (Opcional, com recompensa clara; o WDD trata como side quest e o GDD diz "se for resgatado".)
4. **Laser mata ou só dispara alarme?** (Só alarme + variância; a morte continua sendo pelo taser, como no GDD.)
5. ✅ **Abortar hack com Esc** (GDD §4). Não existia: implementado na etapa 3. Esc fecha o hack como falha; chance de alarme = 60% × fração do tempo que restava; sob lockdown o Esc só avisa (`Hackable.abortable`).
6. **Ciclos de Processamento / upgrades do traje** (WDD §10). (Fora do escopo desta fase; anotar para depois da Fase 4.)
