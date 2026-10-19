# Neon Calculus — Handoff para a sessão de código

Este documento resume tudo o que foi decidido e produzido antes de começarmos o código. Leia inteiro antes da primeira alteração. O trabalho será feito **por partes**, uma etapa por vez, validando cada uma antes da próxima.

---

## 1. Contexto

- **Jogo:** Neon Calculus — plataforma 2D de furtividade, visão lateral, cyberpunk (Nova Gödel, 2142). O protagonista, Eduardo, invade a mega-torre da OmniCorp e "hackeia" o mundo resolvendo equações sob limite de tempo. **Sem combate.**
- **Equipe:** projeto acadêmico (Católica de SC, Engenharia de Software), 5 autores. Cronograma de 18 semanas com milestones M1 (protótipo) → M2 (vertical slice) → M3 (alpha, greybox) → M4 (beta, arte final) → M5 (release).
- **Documentos originais** (estão em `C:\Users\vicen\Downloads\`; vale copiar para `docs/` do projeto):
  - `PAC 3 - GDD_ Neon Calculus.pdf` (design)
  - `PAC 3 - TDD_ Neon Calculus.pdf` (técnico)
  - `PAC 3 - WDD_ Neon Calculus.pdf` (mundo)
- **Decisão de processo:** fazer primeiro o **esqueleto jogável com placeholders**; a arte final entra depois, trocando texturas. A arte está sendo produzida em paralelo (no Gemini, com o guia `docs/GUIA_DE_ARTE_gemini.md`).

---

## 2. Stack técnica (do TDD)

- **Godot 4.x, versão .NET** (C# + GDScript).
  - **C#**: lógica pesada — gerador procedural de equações (com validador), FSM da IA, grafos/pathfinding.
  - **GDScript**: UI, transições de cena, chamadas de animação.
- Física: `CharacterBody2D` para jogador e guardas; `RayCast2D` e `Area2D` para visão e audição.
- IA: FSM com padrão **State** (Patrulha → Suspeita → Busca → Alerta Máximo); `NavigationRegion2D`/`NavigationAgent2D`; recalcular rota só ao mudar de estado.
- Pausa do hack (**decisão atualizada**): o mundo fica **desacelerado** via `Engine.time_scale` (visão hacker ~25%, equação ~5%), não pausado. A `HackingInterface` e o cronômetro do hack usam **tempo real** (ignoram `time_scale`, ex.: `Time.get_ticks_msec()` ou dividir delta por `Engine.time_scale`). A pausa total de acessibilidade usa `get_tree().paused = true` com a `HackingInterface` em `PROCESS_MODE_ALWAYS` (já ligada no `GameManager` via `pause_on_hacking`).
- Resolução (**decisão**): manter 1920×1080 com stretch `canvas_items` (menu/HUD intactos). A `Camera2D` de gameplay usa zoom (2,2) ≈ enquadramento 960×540; snap 2D e filtro Nearest ligados. Se tremer em resoluções não múltiplas de 1080p, migrar o mundo para um SubViewport 960×540 depois.
- Inputs (**decisão**): o Eduardo novo usa só as ações novas (`move_left`, `move_right`, `run`, `crouch`, `jump`, `climb_*`, `hack_*`, `interact_world`), nunca `ui_*`. `Interact` é mantida. O player antigo e o `Terminal.gd` serão removidos no fim da etapa 3.
- Addon `godot_ai`: autoload e plugin removidos do `project.godot` (projeto precisa abrir sem erros para a CI headless).
- Comunicação: **Signals** (padrão Observer). `GameManager` como autoload/singleton.
- Testes: **GUT** (GDScript) e **NUnit** (C#), com foco no gerador de equações (sempre solução inteira e plausível).
- Git + GitHub, GitFlow, CI com GitHub Actions (build headless).
- Importação de texturas: filtro **Nearest** (preset 2D Pixel).
- Persistência: `FileAccess`/`ConfigFile`; dados de lore e dificuldade em `.json`.

**Estado da máquina:** o Godot **não estava instalado** no PC quando este documento foi escrito. Para C# é preciso o **Godot 4 .NET** e o **.NET SDK**. Confirmar a instalação antes de começar.

---

## 3. Decisões de design tomadas depois dos documentos (substituem o GDD onde houver conflito)

1. **Visão hacker no lugar de terminais de equação** (estilo Watch Dogs):
   - Segurar um botão → entra em "visão hacker" (mundo em câmera lenta, alvos hackeáveis destacados em ciano, zonas da Axioma em vermelho).
   - Mirar/selecionar um alvo → aparece uma linha do Eduardo até o alvo.
   - Confirmar → abre a interface de equação (mundo bem desacelerado, ~5–10%; pausa total como opção de acessibilidade).
   - Requisitos: **linha de visão** (raycast) e **alcance máximo**.
   - Dificuldade por tipo de alvo (câmera fácil < porta < guarda < ciborgue), somada ao escalonamento por andar do TDD.
   - Combina com o `HackingRaycast` que já está no diagrama de arquitetura do TDD.
2. **Alvos hackeáveis**:
   - Câmera de vigilância → desliga a visão por X segundos.
   - Porta biométrica → destranca.
   - Guarda humano → distração sonora (implante/comunicador toca).
   - Ciborgue → altera a rota de patrulha.
   - Letreiro/luz neon → apaga (cria sombra para se esconder).
   - Quiosque público da Axioma → alarme/propaganda (distração).
3. **Limite de hacks = "Score de Variância"** (lore do WDD): cada hack aumenta a variância (falhar aumenta mais); passando do limite, a Axioma dispara as **"Varreduras de Rotina"** (scanners a laser descem do teto). Sem barra de mana artificial.
4. **Esconderijos**: certos props (caixotes, caçamba, sacos de lixo) permitem se esconder; não funciona sob luz neon. O jogador pode hackear escondido.
5. **Lore — um único sistema de dados** (`LogEntry` em JSON) com várias fontes:
   - terminais de dados (CRT da resistência nas favelas; terminal limpo nos andares corporativos);
   - tablets sobre mesas;
   - conversas de NPCs ouvidas **escondido**, disparadas por flags de progresso (não por simulação de tempo);
   - (opcional, prioridade baixa) "sobrecarregar implante" de um guarda com uma equação difícil → ele desmaia → pegar o tablet. Guardas com tablet são fixos e marcados na visão hacker (não aleatório). Exige tratar "guarda desacordado encontrado → alerta".
6. **Prioridade de escopo**: (1) visão hacker + câmera, porta, distração, luz → (2) esconderijos → (3) terminais e tablets → (4) conversas ouvidas → (5) sobrecarga de implante.
7. **Lockdown** (GDD): continua — alarme prende o jogador numa sala e exige um desafio rápido para sair.

---

## 4. Arte disponível (para usar já no protótipo)

Pasta: `C:\Users\vicen\OneDrive\Documentos\Krita\Neon Calculus\nobg\`
Convenção: uma pasta por animação com `frame 1.png … frame N.png`; tiras horizontais em `nobg\spritesheets\<nome>.png`. Pastas com ` - old` são versões antigas — **ignorar**.

### Eduardo — quadro 128 × 128, olhando para a direita
- **Pés na linha y = 126** (2 px acima da borda de baixo). Centro horizontal do corpo ≈ x 66.
- Altura de pé ≈ 123 px (y 3–126). Agachado ≈ 91 px (y 35–126).
- Sugestão de colisão: de pé cápsula ~28 × 118; agachado ~44 × 86 (ajustar no teste).

| Pasta | Frames | Uso | FPS sugerido |
|---|---|---|---|
| `idle - visor` | 6 | parado | 8 |
| `walking` | 8 | andar | 10 |
| `running` | 8 | correr | 12 |
| `crouching` | 6 | transição em pé → agachado (tocar 1x; ao levantar, tocar ao contrário) | 14 |
| `crouch idle` | 4 | agachado parado (loop) | 6 |
| `crouch walking` | 8 | andar agachado (loop) | 9 |
| `hacking - start` | 4 | leva a mão ao visor (1x) | 12 |
| `hacking` | 4 | hackeando (loop) | 6 |
| `hacking - fx only` | 4 | partículas matemáticas (camada separada, mesmo quadro 128) | 6 |

Faltam (pedidos ao Gemini): `jump`, `fall`, `land`, `crouch hacking`, `hide`, `ladder climb`, `caught`.

### Favelas (slums)
- **Tiles de 32 × 32.**
- `slums - tileset\slums_ground.png` + `slums_ground.tres`: TileSet com **terrain set em modo Corners** (terrain "Slum Ground"), colisão por tile, variações com probabilidade. **O `.tres` nunca foi aberto no Godot** — validar logo na primeira etapa. Ele aponta para `res://assets/tilesets/slums/slums_ground.png`.
  - O topo visual do chão fica exatamente no centro do tile (y = 16). Nas laterais e embaixo, a colisão fica até ~3 px para dentro do desenho.
- `slums - tileset\slums_structures.png` + `slums_structures.tres`: passarelas (esquerda, meio, direita, avulsa) com **colisão de mão única** no topo (y = 16 a 23); escadas e vigas sem colisão (escada deve ser uma `Area2D`).
- `slums - props\`: caçamba, sacos de lixo, caixotes, tambor, ar-condicionado, caixa de papelão, pneu, canos com cabo — sprites soltos, base = chão.
- `slums - neon signs\`: letreiros com texto (`neon_RAMEN`, `neon_BAR`, `neon_REPAIR`, `neon_HOTEL_vertical`, `neon_OPEN_24H`), cada um com `_flicker_2f` (2 frames lado a lado) + letreiros decorativos. Bons candidatos a "luz hackeável".
- `slums - background\bg_favela_dark_seamless.png` (1536 × 340): camada de parallax emendável. `bg_favela_dark.png` (768 × 340) e `bg_favela_original.png` também.
- Referência visual de como montar: `slums - tileset\slums_reference_scene_x2.png` e `slums_reference_scene_terminals_x2.png`.

### Terminais
- `terminal data - idle` (2f), `terminal data - reading` (4f, tocar 1x e segurar o último) — 64 × 80. Fonte de lore.
- `terminal equation - locked/hacking/solved` — 64 × 96. **Não é mais usado como terminal**; reaproveitar como "quiosque da Axioma" hackeável (distração). As cores dos estados (vermelho/ciano/verde) servem de referência para a UI de hack.

### Scripts de arte
`C:\Users\vicen\OneDrive\Documentos\Krita\Neon Calculus\tools\`: scripts Python usados para gerar/limpar a arte (sujar o tileset, exportar `.tres`, letreiros, estados dos terminais, partículas). São referência; os caminhos dentro deles são relativos à pasta de trabalho original.

---

## 5. Pontos em aberto (decidir cedo)

1. **Resolução interna.** O personagem tem ~123 px de altura. Em 640 × 360 ele ocuparia 1/3 da tela (grande demais para stealth). Sugestão: **viewport 960 × 540** com escala inteira ×2 para 1920 × 1080 (stretch mode `viewport`, `snap 2D` ligado). Consequência: o fundo de 340 px de altura não cobre 540 — ancorar embaixo com céu escuro acima ou pedir um fundo mais alto.
2. **Câmera:** seguir o Eduardo com suavização e limites por sala; dar um pouco mais de visão para frente.
3. **Controles** (teclado e mouse, pelo TDD): ex. A/D andar, Shift correr, Ctrl/S agachar, Espaço pular, **segurar Q/botão direito = visão hacker**, mouse/Tab para escolher o alvo, E/clique para hackear, F para interagir (ler terminal, esconder).
4. Onde os dados de lore e dificuldade ficam (`res://data/*.json`).

---

## 6. Plano por partes (M1 → início do M2)

Cada etapa termina com algo testável no editor.

1. **Setup**: projeto Godot 4 .NET, estrutura de pastas, `.gitignore` do Godot/.NET, `GameManager` autoload, configuração de pixel art (Nearest, viewport, snap), Input Map.
   - Estrutura sugerida: `res://assets/{characters/eduardo, tilesets/slums, props/slums, neon/slums, backgrounds/slums, terminals}`, `res://scenes/{player, enemies, levels, ui, objects}`, `res://scripts/{core, player, ai, hacking, lore}`, `res://data/`, `res://tests/`.
2. **Importar a arte** existente para `res://assets/...` e criar o `SpriteFrames` do Eduardo. **Validar os dois `.tres`** de TileSet (abrir, pintar com o terreno, testar colisão).
3. **Eduardo** (`CharacterBody2D`): andar, correr, pular, agachar (com troca de colisão), andar agachado, escada. Máquina de estados de movimento + troca de animação. Placeholders para pulo/queda.
4. **Nível de teste das favelas**: TileMapLayer com o chão e as passarelas, parallax, props, letreiros, câmera seguindo.
5. **Gerador de equações (C#)** com validador (solução inteira, dentro da dificuldade) + testes NUnit. Desacoplado da física; emite sucesso/falha.
6. **Visão hacker**: segurar botão, slow-motion, destacar alvos (`Hackable` como componente/grupo), raycast de linha de visão + alcance, linha até o alvo, abrir a `HackingInterface`, aplicar o efeito no alvo via signal.
7. **Câmera de vigilância** (primeiro alvo): varredura, cone de visão (`RayCast2D`/polígono), detecção, efeito do hack (desliga X s).
8. **Guarda humano** com FSM: patrulha entre waypoints → suspeita → busca → alerta; cone de visão e audição; reação à distração por hack. Placeholder retangular até a arte chegar.
9. **Esconderijos** + regra de luz (neon expõe; neon hackeado apaga).
10. **Score de Variância** + Varredura de Rotina.
11. **Lore**: `LogEntry` JSON, terminal de dados e tablet, tela de leitura.
12. HUD mínimo, game over (pego pelo taser), checkpoint no início do andar.

---

## 7. Regras de trabalho para a sessão de código

- Trabalhar etapa por etapa; ao fim de cada uma, dizer o que testar no editor.
- Não editar nada dentro de `Neon Calculus\nobg\` (é a pasta de arte, mantida pelo Gemini). Copiar os assets para dentro do projeto.
- Commits pequenos, por etapa.
