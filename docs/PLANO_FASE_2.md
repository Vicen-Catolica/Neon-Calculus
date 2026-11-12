# Neon Calculus — Plano da Fase 2 (Setor Industrial e de Manutenção)

Plano de trabalho para a segunda fase, no mesmo formato por etapas usado na Fase 1. Cada etapa termina com algo testável. Base: GDD/WDD/TDD + decisões do `HANDOFF_codigo_claude.md` (o HANDOFF vence onde houver conflito).

---

## 1. Ponto de partida

- **Fase 1 (favelas) pronta** no branch `feature/slums-stage-1` (11 commits à frente do `master`; ainda não foi para o `develop`). A saída dela leva ao antigo `scenes/Stage2/stage2.tscn`, um placeholder da equipe.
- As fases são **geradas por script**: `tools/build_slums_stage.gd` e `tools/build_industrial_stage.gd` herdam de `tools/stage_builder_base.gd` (terreno, passarelas, escadas, props, neon, terminais, câmeras, guardas, saída, player/UI). As cenas de objetos compartilhadas vêm de `tools/build_objects.gd` (rodar só quando um objeto mudar). A regeração é determinística, exceto os `unique_id` dos nós.
- Sistemas prontos e reaproveitáveis: Eduardo completo, visão hacker + `Hackable`, interface de equação (C#, com validador e testes), guardas com FSM, câmeras (parede/domo), porta biométrica, quiosque, esconderijos + luz, terminais de lore, Score de Variância + Varredura de Rotina, HUD, game over.
- Já previsto no código, mas sem uso: `Enemy.EnemyType.CYBORG` e `Hackable.Kind.CYBORG`.
- Ambiente (Linux/distrobox): `godot` 4.7.2 .NET, `dotnet` 8, `git`. Verificações: `dotnet test tests/NeonCalculus.Tests` e `godot --headless --path . res://tests/stage_sim.tscn`. Screenshots: `LIBGL_ALWAYS_SOFTWARE=1 godot --path . --windowed --resolution 1920x1080 res://tests/stage_shots.tscn -- <cena> "<x:y;...>" <pasta>`.

---

## 2. O que a Fase 2 é (docs)

- **Bioma** (GDD §6, WDD §3): dutos de ventilação enferrujados, esteiras automatizadas, servidores antigos de refrigeração, muito vapor e fumaça. Primeiro andar **dentro** da torre: a sujeira da favela começa a dar lugar à máquina.
- **Narrativa** (GDD §1, §9): Eduardo já sabe do Projeto Determinismo e abandona o contrato; começa a "escalada furtiva" e a confrontar o código que ele mesmo ajudou a escrever. Side quest do WDD: **sabotar fábricas de drones de patrulha**. Primeira pista do Dr. Vance (o resgate fica para a Fase 3).
- **Inimigos** (GDD §7): Agentes Modificados continuam (níveis baixos e intermediários). **Drones de patrulha** (WDD: "pombos foram substituídos por drones") entram aqui. Ciborgues são do P&D e do Núcleo → ficam para a Fase 3.
- **Dificuldade**: `floor_number = 2` → equações um nível acima; tempo limite menor.
- **Eventos**: Lockdown (GDD/WDD) — alarme prende o jogador numa sala e exige um hack rápido antes dos "guardas pesados". Ainda não existe; a Fase 2 é o lugar natural para estreá-lo.

---

## 3. Desenho da fase

**Entrada:** a escada no escuro do fim da Fase 1 desemboca num duto de manutenção na base da torre. **Saída:** elevador de carga para o P&D (gancho para o "diálogo de elevador" do GDD).

Percurso proposto (≈ mesmo tamanho da Fase 1, ~5 300 px de largura, com mais verticalidade), uma mecânica nova por trecho:

| # | Trecho | O que ensina / testa | Elementos |
|---|---|---|---|
| A | **Duto de entrada** | Rastejar em dutos (agachado), sair por uma grade | duto baixo, grade, 1º terminal (SINE apresenta o setor) |
| B | **Casa de caldeiras** | **Válvula de vapor hackeável**: o vapor bloqueia a visão por X s e cria cobertura | 2 guardas, câmera de parede, válvulas, armários (esconderijo) |
| C | **Linha de montagem de drones** | **Esteiras** (hackear para parar/inverter) e **drone de patrulha** (hackear = reinicia, fica X s parado) | esteiras sobre um fosso, 2 drones, passarelas, quiosque/painel |
| D | **Sala dos servidores de refrigeração** | **Lockdown**: área com câmeras-domo; se o alarme disparar ali, portas fecham e começa o desafio rápido | servidores (cobertura escura), terminal de lore (diário de cientista + pista do Dr. Vance), porta de saída hackeável |
| E | **Poço do elevador de carga** | Subida vertical com escadas/passarelas + Varredura de Rotina se a variância estourar | elevador → Fase 3 |

O greybox (etapa 3) vale como prova do layout; ajustar números lá, não aqui.

---

## 4. Mecânicas novas — como implementar

1. **Duto de ventilação** — só geometria: vão de 96 px (já é a regra do túnel da Fase 1: só passa agachado) + sprite de grade na entrada/saída. Sem código novo.
2. **Válvula de vapor** — `Hackable.Kind.VALVE` ("VÁLVULA"), dificuldade de câmera/luz. Ao hackear: `Area2D` de vapor ativa por ~6 s, com partículas. `Enemy.has_line_of_sight_to()` e o cone da `SecurityCamera` passam a ignorar o jogador quando a linha atravessa uma área do grupo `vision_blocker` (teste de segmento × retângulo, sem física extra). Opcional: vapor periódico que não depende de hack (timing).
3. **Esteira** — `StaticBody2D` com `constant_linear_velocity` (o `CharacterBody2D` herda a velocidade do chão) + sprite animado. `Hackable.Kind.CONVEYOR`: alterna rodando ↔ parada (ou inverte). Uma esteira empurrando para dentro do fosso = morte/queda → reposicionar no último ponto seguro (não game over).
4. **Drone de patrulha** — `scenes/enemies/drone.tscn`, `CharacterBody2D` sem gravidade que voa entre `Marker2D`s. Reaproveita a barra de detecção e o cone do `Enemy` (cone apontando para baixo/frente). Não atira: ao ver o jogador chama `GameManager.raise_alarm()` (guardas vêm). `Hackable.Kind.DRONE`: reinicia, fica ~8 s parado e "cego". Avaliar se dá para ser uma subclasse do `Enemy` com estados próprios (Patrol/Alert/Rebooting) em vez de herdar a FSM de guarda.
5. **Lockdown** — `scripts/core/lockdown_zone.gd` (`Area2D` + lista de portas). Se `alarm_raised` ocorrer com o jogador dentro: portas fecham, a Axioma "fala" (caixa de texto), contador de ~20 s; a porta de saída vira alvo de hack com dificuldade +1 e **não pode ser abortada** (GDD §4). Fim do tempo = guardas pesados entram (game over na prática). Sucesso = portas abrem, variância sobe.
6. **Infra de várias fases** (necessário agora que existem duas):
   - `slums_level.gd` → `level.gd` genérico (nome da fase, andar, limites de câmera, ponto de checkpoint).
   - **Transição/loading** (GDD §8): tela preta com o icosaedro laranja da Axioma e "Acessando... Setor Industrial" (< 2 s).
   - **Checkpoint/save** (TDD): `user://save.cfg` com andar atual e `lore_read`; escrita atômica (grava em temporário e renomeia). Game over → "Carregar checkpoint" reinicia o andar. Main menu → "Continuar".
7. **Builder compartilhado** — extrair de `build_slums_stage.gd` os utilitários (`_own`, `_save`, `_rect_shape`, `_frames`, `_hackable`, montagem de guarda/câmera/porta, terreno por retângulos, superfícies, escadas, player+UI) para `tools/stage_builder_base.gd`. As duas fases herdam dele. Regerar a Fase 1 depois e rodar `stage_sim` para garantir que nada mudou.

---

## 5. Arte necessária

Regras do `GUIA_DE_ARTE_gemini.md` valem igual: tiles 32×32, personagens 128×128 com pés em y = 126, olhando para a direita, contorno ~`#0C0A0A`, sem anti-aliasing, entrega em `nobg/<objeto - estado>/frame N.png` + spritesheet. Paleta do industrial: ferrugem, marrom/laranja queimado, cinza-aço; ciano/vermelho continuam com o mesmo significado.

### Já existe e só falta importar (0 gerações)
- Eduardo: `caught` (game over pelo taser), `hide`, `crouch hacking` (+ fx). A Fase 1 ainda não usa — importar na etapa 1.

### A produzir

| Prioridade | Asset | Como (PixelLab / outro) | Gerações |
|---|---|---|---|
| P1 | **Tileset industrial** (chão de chapa/grade, paredes de concreto com ferrugem), terreno "Corners" como o das favelas | `create_tiles_pro` ou imagem + degradar com `tools/grunge.py`; `.tres` exportado com `tools/export_godot.py` (evitar `create_sidescroller_tileset`, ver guia §8) | 1–2 |
| P1 | **Fundo de parallax** (salão industrial: tubulações, chaminés, esteiras ao longe), escuro e de baixo contraste | `create_image_pixen`/`pro` | 1–2 |
| P1 | **Folha de props**: canos, válvula, tambores, armário de vestiário (esconderijo), caixotes de metal, painel elétrico, rack de servidor antigo, gerador, carrinho | `create_image_pixen` "sprite sheet of separate props" e recortar | 1–2 |
| P1 | **Drone de patrulha**: `drone - patrol` (4f flutuando), `drone - alert` (2–4f, luz vermelha), `drone - disabled` (2f, faíscas/caindo) | `create_object` 1 direção + `animate_object` | 3 |
| P1 | **Esteira** (segmento repetível 32 ou 64 px, 4f) | imagem + `pixelart_workbench` para o loop | 1 |
| P2 | **Vapor** (jato 6f) e **faísca** (4f) | `vfx_workbench` (grátis) | 0 |
| P2 | **Grade de duto**, **válvula** nos estados fechada/aberta | `pixelart_workbench` (grátis) | 0 |
| P2 | **Porta industrial / blast door** (trancada vermelha → destrancando ciano → aberta verde) | variação do `tools/gen_door_art.py` | 0 |
| P2 | **Elevador de carga** (plataforma + gaiola) | `create_object` ou desenho | 1 |
| P3 | Luzes de alarme giratórias (Lockdown), placas de perigo da OmniCorp | `pixelart_workbench` | 0 |

**Orçamento:** ~9–12 gerações. Conta atual (12/11): plano trial, 9 gerações restantes + bônus diário (+5 por noite, até 20), 1 geração por vez. Dá, mas sem margem para muitas repetições: gerar primeiro **tileset e fundo** (definem o visual) e conferir montados numa cena antes de gerar o resto.

Enquanto a arte não chega: greybox com os tiles das favelas tingidos de laranja/cinza e retângulos coloridos.

---

## 6. Etapas (ordem de execução)

1. ✅ **Infra multi-fase** — `level.gd` genérico, transição/loading, checkpoint/save, "Continuar" no menu, importar `caught`/`hide`/`crouch hacking` e usar `caught` no game over. *Teste:* terminar a Fase 1 leva a uma Fase 2 vazia com a tela de transição; fechar e "Continuar" volta ao andar 2.
2. ✅ **Builder compartilhado** — `stage_builder_base.gd`; regerar a Fase 1. *Teste:* `stage_sim` continua 100% OK.
3. ✅ **Greybox da Fase 2** — layout A–E só com mecânicas que já existem (guardas, câmeras, escadas, passarelas, dutos, esconderijos, terminal, porta, saída). *Teste:* fase atravessável do início ao fim; screenshots de cada trecho.
4. ✅ **Válvula de vapor + bloqueio de visão.** *Teste:* guarda/câmera não detectam através do vapor; detectam depois que ele some.
5. **Esteira** (andar sobre, parar/inverter por hack, queda no fosso).
6. **Drone de patrulha** (voo, cone, alarme, hack de reinício).
7. **Lockdown** (sala dos servidores).
8. **Lore** — `data/lore/industrial.json`: SINE no duto de entrada; diário de um cientista da OmniCorp sobre as "Atualizações Mandatórias"; registro de um engenheiro de manutenção sobre a fábrica de drones; mensagem que cita o Dr. Vance (gancho da Fase 3).
9. **Arte final** — trocar placeholders conforme os assets chegam.
10. **Testes e CI** — `tests/stage2_sim.gd` (um OK/FALHOU por mecânica, como o da Fase 1); CI do GitHub passa a usar Godot .NET e roda `dotnet test` e as simulações headless (hoje o job de testes é só um `echo`).
11. **Playtest e ajuste** — tempos de vapor/drone/lockdown, dificuldade das equações do andar 2.

Commits pequenos por etapa, no branch `feature/industrial-stage-2`.

---

## 7. Decisões em aberto (recomendação entre parênteses)

1. **Ciborgue na Fase 2?** (Não — o GDD põe no P&D; no máximo um aparecendo de longe no fim, como prenúncio.)
2. **Lockdown nesta fase ou na 3?** (Nesta: é sistema do jogo inteiro e quanto antes entrar, mais playtest recebe.)
3. **Dr. Vance**: resgate na Fase 3, só pista aqui. (Sim.)
4. **Habilidades Variável Oculta (Q) e Ping Sonar (V)** do GDD: o Q hoje é a visão hacker. (Adiar; quando entrarem, mover a camuflagem para outra tecla — sugestão C — e rever o GDD.)
5. **Cenas antigas** `scenes/Stage2..4`, `Terminal.gd`, `MathGenerator.cs`, `.csproj.old*`: apagar quando a Fase 2 substituir o Stage2? (Sim, na etapa 1, depois de conferir que nada mais as referencia.)
6. **Merge da Fase 1**: abrir PR `feature/slums-stage-1` → `develop` antes de começar? (Sim, ou a Fase 2 vai crescer em cima de um branch que ninguém mais tem.)
