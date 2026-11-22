#!/usr/bin/env bash
# Roda toda a verificação do projeto — o mesmo roteiro no CI e na máquina local.
#   1. importa o projeto (texturas, classes) em modo headless
#   2. compila o C# do jogo e roda os testes NUnit do gerador de equações
#   3. roda as simulações headless (fases, fluxo entre andares e interface)
#
# Uma simulação passa se: sai com código 0, imprime "TUDO OK" e não teve
# nenhum "SCRIPT ERROR" no log (erros de GDScript não mudam o código de saída).
#
# Uso, na raiz do projeto:  tools/run_tests.sh
# Variáveis: GODOT (binário, padrão "godot"), SIM_TIMEOUT (segundos, padrão 300),
# SIMS (lista de simulações separadas por espaço).
set -u

GODOT="${GODOT:-godot}"
SIM_TIMEOUT="${SIM_TIMEOUT:-300}"
# SIMS="a b" roda só essas simulações (útil para depurar uma fase).
read -r -a SIMS <<< "${SIMS:-stage_sim route_sim flow_sim stage2_sim stage3_sim stage3_live_sim stage4_sim stage4_live_sim duel_sim duel_bot_sim balance_sim ui_sim edge_sim}"
LOG_DIR="$(mktemp -d)"
fail=0

step() { printf '\n== %s\n' "$1"; }

step "import do projeto"
timeout 600 "$GODOT" --headless --import --path . >"$LOG_DIR/import.log" 2>&1
echo "import: código $?"

step "build C# do jogo"
if ! dotnet build "Novo Projeto de Jogo.csproj" -nologo -v q; then
	echo "FALHOU: build C#"
	fail=1
fi

step "testes NUnit (gerador de equações)"
if ! dotnet test tests/NeonCalculus.Tests -nologo; then
	echo "FALHOU: testes NUnit"
	fail=1
fi

for sim in "${SIMS[@]}"; do
	step "simulação $sim"
	log="$LOG_DIR/$sim.log"
	timeout "$SIM_TIMEOUT" "$GODOT" --headless --path . "res://tests/$sim.tscn" >"$log" 2>&1
	code=$?
	grep -E '^(OK|FALHOU) ' "$log" | grep -c '^OK ' | xargs printf '%s checagens OK\n'
	grep -E '^FALHOU ' "$log" || true
	if [ "$code" -ne 0 ]; then
		echo "FALHOU: $sim saiu com código $code$([ "$code" -eq 124 ] && echo ' (tempo esgotado)')"
		fail=1
	elif ! grep -q 'TUDO OK' "$log"; then
		echo "FALHOU: $sim não imprimiu TUDO OK"
		fail=1
	elif grep -q 'SCRIPT ERROR' "$log"; then
		echo "FALHOU: $sim teve SCRIPT ERROR:"
		grep -A2 'SCRIPT ERROR' "$log" | head -20
		fail=1
	else
		echo "ok"
	fi
done

echo
if [ "$fail" -eq 0 ]; then
	echo "TODOS OS TESTES PASSARAM"
else
	echo "HÁ FALHAS — logs em $LOG_DIR"
fi
exit "$fail"
