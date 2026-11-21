# Neon Calculus — Plano da Fase 4 (Núcleo Quântico / Duelo de Paradoxo)

Plano da quarta e última fase, no mesmo formato por etapas das anteriores. Cada etapa termina com algo testável. Base: GDD/WDD/TDD + `HANDOFF_codigo_claude.md` + o que já existe no código. Branch: `feature/core-stage-4` (criada a partir de `feature/rnd-stage-3`). **Nada vai para o GitHub até a revisão final de todas as fases.**

---

## 1. Ponto de partida

- **Fases 1–3 prontas** e testadas: 8 simulações + NUnit em `tools/run_tests.sh`. A saída da Fase 3 é o elevador executivo, com `NEXT_STAGE = ""` (a placa diz "fase 4 em construção").
- **Sistemas prontos e reaproveitáveis:**
  - Eduardo com hack, esconderijo, Ping Sonar (V) e Variável Oculta (C).
  - Guardas e Unidades Lógicas com ponto cego.
  - Câmeras, drones, lasers, lockdown e Varredura de Rotina.
  - Caixa de diálogo (`Dialogue`), lore com dicas da SINE, marcos da história (`story_flags`, ex.: `vance_rescued`) e Protocolo Vance.
  - Segurança máxima (`Level.max_security_rect`), transição, checkpoint, pausa e "Como jogar".
- **Gerador de equações:** só tem os níveis 1–4. O nível 4 (distributiva e ângulos do triângulo) já aparece na Fase 3 nos ciborgues, na cela e no lockdown. O Núcleo precisa de algo acima disso.
- **Já previsto e sem uso:** a música `assets/Music/The_Axioma_Resolve.mp3` (hoje só no menu), o ícone do icosaedro da Axioma (desenhado em código na tela de transição) e o roteiro de vitória/derrota do GDD §9.

---

## 2. O que a Fase 4 é (docs)

- **Bioma** (GDD §6, WDD §3): ambiente quase abstrato, com geometrias matemáticas perfeitas flutuando, servidores massivos, luzes pulsantes e **pontes de luz**. A Axioma não tem corpo: aparece como geometria pulsante em vermelho/laranja (GDD §3).
- **Narrativa** (GDD §1, §9):
  - Eduardo chega ao **Domo de Controle Neural**.
  - A cutscene mostra o embate filosófico entre Eduardo, SINE e Axioma.
  - Vem o **Duelo de Paradoxo**: "equações de lógica circular de alta pressão" enquanto ele desvia de "ameaças físicas e defesas do servidor".
  - A vitória vem ao inserir o **Paradoxo** (a "Variável Infinita"): a Axioma colapsa, os neons da cidade apagam e as portas da torre se abrem.
  - Na derrota, a tela fica vermelha e a Axioma registra a anulação; a SINE oferece restaurar o checkpoint.
  - O Dr. Vance já disse ao Eduardo onde fica a "variável aberta" do núcleo.
- **Inimigos** (GDD §7): Unidades Lógicas protegem o Núcleo. Ainda há câmeras e varreduras. Agentes humanos só sobem até o P&D (o terminal da Fase 3 diz isso).
- **Dificuldade:** `floor_number = 4`, a equação mais difícil do jogo e o tempo mais curto (GDD §2: "diminui drasticamente").
- **Cronograma** (GDD §10, WDD §11): "Implementação do Duelo de Paradoxo" é um marco próprio (M3: "a batalha final já será jogável").

---

## 3. Desenho da fase

Duas partes. Primeiro a **aproximação**, com furtividade como nas outras fases. Depois a **arena do Duelo**, numa sala de tela única, onde o jogo muda de ritmo.

| # | Trecho | O que ensina / testa | Elementos |
|---|---|---|---|
| A | **Chegada do elevador executivo** | Diálogo de elevador (SINE, Eduardo, a Axioma interrompendo pelos alto-falantes) | terminal de lore, plataforma flutuante, nenhuma ameaça |
| B | **Pontes de luz** | **Ponte de luz**: hackear o emissor a materializa por alguns segundos; abismo abaixo | 3 pontes encadeadas, 1 câmera, plataformas geométricas |
| C | **Galeria dos servidores massivos** | Revisão: Unidades Lógicas em rotas perfeitas e lasers; o sonar e a camuflagem brilham aqui | 2 ciborgues, lasers temporizados, servidores como cobertura, segurança máxima em tudo |
| D | **Antecâmara do Domo** | Checkpoint antes do chefe (o save do andar); terminal de lore final | porta do Domo, diálogo de confronto ao entrar |
| E | **Domo de Controle Neural (Duelo)** | **Duelo de Paradoxo**: 3 nós de vigilância para hackear sob ataque do núcleo | núcleo central, 3 nós em plataformas, ataques em padrões |

### O Duelo de Paradoxo (E)

A arena é uma tela única de ~1920×1080 do mundo, com o núcleo (icosaedro laranja gigante) no centro e três **Nodos de Vigilância** (o nome vem do WDD) em plataformas: esquerda, direita e topo.

1. **Camada 1:** um nó fica ciano (alvo). O núcleo ataca com **Varreduras** horizontais e verticais e **pulsos** em anel, e o jogador desvia (pular, agachar, trocar de plataforma). O hack do nó usa a **equação do nível 5** (abaixo). Sob ataque o mundo desacelera para 5% como sempre, mas o tempo do hack é curto.
2. **Camada 2:** o nó seguinte acende, e o núcleo acrescenta **lasers giratórios** e acelera.
3. **Camada 3:** os ataques se combinam. Hackear o último nó abre a "porta" do Vance. O jogador corre até o núcleo e confirma o **Paradoxo**: uma última equação sem solução, em que a resposta é perceber isso (ver decisão 3).
4. **Erros:** errar ou deixar o tempo acabar não mata; o núcleo "recupera a camada": o nó apaga e reacende depois de alguns segundos, e a variância sobe. O que derruba o Eduardo é a **Defesa Neural** zerar com os ataques (dano como o taser). Game over volta ao checkpoint da antecâmara (D).
5. **Não há esconderijo** na arena e o Esc não aborta (como no lockdown). O sonar mostra o próximo padrão de ataque; a camuflagem não serve contra o núcleo, que não "vê".

### Equação do nível 5: "lógica circular"

O x aparece **dos dois lados** (`5x − 7 = 2x + 8`): a incógnita "se refere a si mesma", uma metáfora da lógica circular do GDD. É conteúdo do 7º e 8º ano e vem logo depois do 1º grau da Fase 2.
- Subtópico 0: `ax + b = cx + d` com solução inteira.
- Subtópico 1: com parênteses dos dois lados (`3(x + 2) = x + 14`), juntando a distributiva da Fase 3.
- O gerador em C# ganha `MaxStage = 5`, com validador e testes NUnit.
- A SINE ganha o passo a passo: "junte os x de um lado, os números do outro".
- O visualizador ganha uma balança de dois pratos.

---

## 4. Mecânicas novas — como implementar

1. **Nível 5 no gerador** (`EquationGenerator.cs`, `MathGenerator`, `hacking_interface.gd`, `math_visualizer.gd`): equações novas, tempo na tabela de `_calculate_dynamic_time_limit`, passo a passo da SINE e testes NUnit (válidas, solução inteira, sem divisão por zero, `a ≠ c`).
2. **Ponte de luz** — `scripts/objects/light_bridge.gd` + `Hackable.Kind.BRIDGE` (no fim do enum). Emissor numa ponta; hackear materializa uma plataforma `StaticBody2D` de mão única por ~10 s, que pisca antes de sumir. Cair no abismo: o Eduardo volta à última plataforma segura e perde um pouco de Defesa Neural (não é game over). Variante: ponte temporizada, que liga e desliga.
3. **Núcleo e Duelo** — `scripts/core/paradox_duel.gd` (máquina de estados: INTRO → CAMADA 1..3 → PARADOXO → VITÓRIA/DERROTA), `scripts/objects/axioma_core.gd` (desenho do icosaedro em código, reaproveitando o da transição, com pulso e glitch) e `scripts/objects/surveillance_node.gd` (nó hackeável que só aceita hack quando é a vez dele).
   - Ataques como cenas pequenas, reutilizando o que existe: a Varredura de Rotina (vertical) ganha a versão horizontal; o pulso em anel é um `Area2D` com raio crescente e uma brecha; o laser giratório reaproveita o desenho do `LaserBarrier`. Cada ataque avisa antes (0,6 s de telegrafia) para ser justo.
   - A Defesa Neural já existe (`take_damage`).
4. **Paradoxo final:** a "equação" `x = x + 1` com o teclado e um botão extra **"Ø SEM SOLUÇÃO"**. A SINE explica: "nenhum número satisfaz; a Axioma vai tentar para sempre". Responder um número conta como erro, com dica.
5. **Cutscenes** (GDD §9, no motor): caixa de diálogo + `AnimationPlayer`/tweens (câmera, luzes, glitch do núcleo). Momentos:
   - elevador (A);
   - a Axioma pelos alto-falantes ao ver o Eduardo pela 1ª vez;
   - confronto ao entrar no Domo (D→E);
   - fala da Axioma a cada camada vencida;
   - colapso na vitória.
6. **Final do jogo:**
   - Sequência de vitória: o núcleo trava, o vermelho e o laranja apagam, branco e silêncio.
   - **Tela de encerramento**: "Nova Gödel livre", estatísticas (tempo, alarmes, hacks, erros, lore lida, Vance resgatado) e **créditos** (os 5 autores, a fonte Exo 2/OFL, a arte PixelLab).
   - Volta ao menu, com o save marcado como "jogo concluído" e "Continuar" desligado ou levando aos créditos (decisão 5).
   - O GameOver dentro do Duelo usa o texto de derrota do GDD.
7. **Música:** o Duelo toca `The_Axioma_Resolve.mp3` (synthwave do GDD §6) e a vitória termina em silêncio. Os SFX ficam como opcional (decisão 6).

---

## 5. Arte necessária

Paleta do Núcleo: preto-azulado profundo, linhas de grade ciano finas, geometria e perigo em vermelho/laranja (a Axioma) e verde digital só no "Paradoxo aceito".

| Prioridade | Asset | Como | Gerações |
|---|---|---|---|
| P1 | **Tileset abstrato** (blocos escuros com arestas de luz) | desenhado por script, como `gen_rnd_tiles.py` | 0 |
| P1 | **Fundo de parallax**: vazio com geometrias flutuantes e colunas de servidor ao longe | `create_image_pixen` 768×340 | 1–2 |
| P1 | **Núcleo da Axioma** (icosaedro gigante, pulsando e com glitch) | código (`_draw`), mesmo traço do ícone da transição | 0 |
| P1 | **Servidores massivos** (cobertura em C) e **nós de vigilância** | `create_image_pixen` (folha) + recorte | 1–2 |
| P2 | **Ponte de luz**, pulsos, lasers giratórios | código | 0 |
| P2 | **Ilustração do final** (cidade com os neons apagando) | `create_image_pixen` | 1 |
| P3 | Retratos para a caixa de diálogo (SINE, Eduardo, Axioma, Vance) | `create_image_pixen` pequenos | 0–4 |

**Orçamento:** ~3–9 gerações (hoje há 15 no bônus diário).

---

## 6. Etapas (ordem de execução)

1. ✅ **Ligação e esqueleto**: `GameManager.LEVELS[4]`, saída da Fase 3 → Fase 4, `tools/build_core_stage.gd` vazio. *Teste:* o elevador executivo leva à Fase 4 com "Acessando... Núcleo Quântico"; "Continuar" volta ao andar 4.
2. ✅ **Equação do nível 5** (C# + validador + NUnit + SINE + visual). *Teste:* NUnit e `ui_sim` (o passo a passo chega na resposta).
3. ✅ **Greybox A–D** com o que já existe + diálogo de elevador. *Teste:* atravessável; capturas.
4. ✅ **Ponte de luz** (hack, mão única, queda no abismo). *Teste:* `stage4_sim`.
5. ✅ **Núcleo, nós e ataques** (arena em cena própria `core_duel.tscn`, checkpoint antes do chefe; ataques: varredura com brecha — lateral só agachado —, pulso em anel com brecha e **grade de lasers** no lugar do laser giratório, que não teria como ser desviado no chão) (cada ataque isolado, com telegrafia e dano). *Teste:* um OK/FALHOU por ataque.
6. ✅ **Duelo de Paradoxo** (camadas 1–3, erros, game over no checkpoint, Paradoxo final). *Teste:* `duel_sim` jogando o Duelo inteiro por código.
7. **Cutscenes e diálogos** (elevador, alto-falantes, confronto, falas por camada, colapso).
8. **Final do jogo** (vitória, encerramento com estatísticas e créditos, save "concluído", derrota do GDD).
9. **Lore** (`data/lore/core.json`): o registro de fundação da Axioma (2115, assinado por Vance), o último log da SINE antes de ser "descartada", o "manifesto" da Axioma sobre a variância, com dica da SINE sobre o nível 5.
10. **Arte** (PixelLab + scripts).
11. **Testes e balanceamento** (`stage4_sim`, `duel_sim`, `balance_sim` com o nível 5 e o dano dos ataques; CI).
12. **Playtest e ajuste** (automatizado + teclado).

Commits pequenos por etapa no branch `feature/core-stage-4`, sem push.

---

## 7. Decisões em aberto (recomendação entre parênteses)

1. **Equação de "lógica circular" = x dos dois lados (nível 5)?** (Sim: é o passo seguinte natural da Fase 2, cabe na faixa etária e a metáfora "a incógnita se refere a si mesma" casa com o GDD. Alternativa mais difícil: sistemas 2×2.)
2. **Errar no Duelo mata?** (Não: o erro só faz o núcleo recuperar a camada e sobe a variância; quem mata é a Defesa Neural zerar com os ataques. Isso mantém o foco em aprender a conta.)
3. **Paradoxo final com resposta "sem solução" (`x = x + 1`)?** (Sim, com um botão próprio e a SINE explicando. É a "Variável Infinita" do GDD e ensina que nem toda equação tem solução.)
4. **Recompensa extra do Dr. Vance no Duelo?** (Sim: com `vance_rescued`, a camada 3 começa com o passo a passo da SINE já aberto e o núcleo mostra uma brecha fixa nos pulsos, a "porta" que ele deixou. Sem o resgate o Duelo continua possível.)
5. **Depois de zerar:** "Continuar" leva aos créditos ou recomeça? (Leva à tela de encerramento; "Iniciar" começa de novo.)
6. **SFX** (blips de voz, cliques do teclado, alarmes): o GDD pede, mas não há arquivos. (Fora desta fase; anotar para o polimento M4/M5.)
7. **Ciclos de Processamento / upgrades do traje** (WDD §10). (Continua fora do escopo.)
