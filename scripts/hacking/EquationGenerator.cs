using System;
using System.Collections.Generic;
using System.Linq;

namespace NeonCalculus.Hacking;

/// <summary>Equação gerada. Params usa as mesmas chaves que a UI em GDScript já lê (ParamA, ParamRes...).</summary>
public sealed record Equation(
    int Stage,
    int SubTopic,
    string Topic,
    string Expression,
    int Solution,
    IReadOnlyDictionary<string, int> Params);

/// <summary>
/// Gerador procedural de equações. Sem dependência do Godot (testável com NUnit).
/// Toda equação sai com solução inteira positiva e passa pelo <see cref="EquationValidator"/>.
/// </summary>
public sealed class EquationGenerator
{
    public const int MinStage = 1;
    public const int MaxStage = 4;
    private const int MaxAttempts = 50;

    private readonly Random _rng;

    public EquationGenerator() : this(new Random()) { }

    public EquationGenerator(int seed) : this(new Random(seed)) { }

    public EquationGenerator(Random rng) => _rng = rng;

    /// <summary>Gera uma equação válida. Stage fora de 1..4 é ajustado; subTopic != 0 vira 1.</summary>
    public Equation Generate(int stage, int subTopic)
    {
        stage = Math.Clamp(stage, MinStage, MaxStage);
        subTopic = subTopic == 0 ? 0 : 1;

        for (int i = 0; i < MaxAttempts; i++)
        {
            var eq = Build(stage, subTopic);
            if (EquationValidator.IsValid(eq))
                return eq;
        }
        throw new InvalidOperationException($"Não foi possível gerar equação válida (stage {stage}, sub {subTopic}).");
    }

    private Equation Build(int stage, int sub) => (stage, sub) switch
    {
        (1, 0) => AddSub(),
        (1, _) => Multiplication(),
        (2, _) => FirstDegree(sub),
        (3, 0) => RuleOfThree(),
        (3, _) => RectangleArea(),
        (4, 0) => Distributive(),
        _ => TriangleAngles(),
    };

    private Equation AddSub()
    {
        int a = _rng.Next(-9, 10);
        if (a == 0) a = 3;
        int solution = _rng.Next(1, 12);
        int res = solution + a;
        string termA = a >= 0 ? $"{a}" : $"({a})";
        return new Equation(1, 0, "NÚMEROS INTEIROS (ADIÇÃO E SUBTRAÇÃO)", $"x + {termA} = {res}", solution,
            P(("ParamA", a), ("ParamRes", res)));
    }

    private Equation Multiplication()
    {
        int count = _rng.Next(2, 6);
        int solution = _rng.Next(2, 10);
        int res = count * solution;
        return new Equation(1, 1, "ÁLGEBRA SIMPLES (MULTIPLICAÇÃO)", $"{count}x = {res}", solution,
            P(("ParamA", count), ("ParamRes", res)));
    }

    private Equation FirstDegree(int sub)
    {
        int mult = _rng.Next(2, 5);
        int solution = _rng.Next(2, 10);
        int b = _rng.Next(2, 9);
        if (sub == 1) b = -b; // subtração
        int total = mult * solution + b;
        string sign = b >= 0 ? "+" : "-";
        return new Equation(2, sub, "EQUAÇÃO DO 1º GRAU", $"{mult}x {sign} {Math.Abs(b)} = {total}", solution,
            P(("ParamMult", mult), ("ParamB", b), ("ParamTotal", total)));
    }

    private Equation RuleOfThree()
    {
        // x / b = n / d. Escolhe x múltiplo de b; assim n = d*x/b é sempre inteiro.
        int b = _rng.Next(2, 6);
        int d = _rng.Next(2, 6);
        var options = Enumerable.Range(2, 8).Where(x => x % b == 0).ToArray();
        int solution = options[_rng.Next(options.Length)];
        int n = d * solution / b;
        return new Equation(3, 0, "REGRA DE TRÊS SIMPLES", $"x / {b} = {n} / {d}", solution,
            P(("ParamBase", b), ("ParamRightNum", n), ("ParamRightDen", d)));
    }

    private Equation RectangleArea()
    {
        int height = _rng.Next(3, 8);
        int solution = _rng.Next(4, 12);
        int area = height * solution;
        return new Equation(3, 1, "GEOMETRIA (ÁREA DO RETÂNGULO)", $"Área = {area} | Altura = {height}", solution,
            P(("ParamAltura", height), ("ParamArea", area)));
    }

    private Equation Distributive()
    {
        int k = _rng.Next(2, 5);
        int offset = _rng.Next(2, 6);
        int solution = _rng.Next(2, 10);
        int total = k * (solution + offset);
        return new Equation(4, 0, "PROPRIEDADE DISTRIBUTIVA", $"{k}(x + {offset}) = {total}", solution,
            P(("ParamK", k), ("ParamOffset", offset), ("ParamTotal", total)));
    }

    private Equation TriangleAngles()
    {
        int angA = _rng.Next(30, 70);
        int angB = _rng.Next(30, 70);
        int solution = 180 - (angA + angB);
        return new Equation(4, 1, "ÂNGULOS DO TRIÂNGULO", $"{angA}° + {angB}° + x° = 180°", solution,
            P(("ParamAngA", angA), ("ParamAngB", angB)));
    }

    private static IReadOnlyDictionary<string, int> P(params (string Key, int Value)[] items) =>
        items.ToDictionary(i => i.Key, i => i.Value);
}

/// <summary>Confere a equação de forma independente: recalcula a partir dos parâmetros.</summary>
public static class EquationValidator
{
    public const int MaxSolution = 99;

    public static bool IsValid(Equation eq)
    {
        if (eq.Solution < 1 || eq.Solution > MaxSolution) return false;
        if (string.IsNullOrWhiteSpace(eq.Expression) || string.IsNullOrWhiteSpace(eq.Topic)) return false;

        var p = eq.Params;
        int x = eq.Solution;
        try
        {
            return (eq.Stage, eq.SubTopic) switch
            {
                (1, 0) => p["ParamA"] != 0 && x + p["ParamA"] == p["ParamRes"],
                (1, 1) => p["ParamA"] >= 2 && p["ParamA"] * x == p["ParamRes"],
                (2, _) => p["ParamMult"] >= 2 && p["ParamB"] != 0
                          && p["ParamMult"] * x + p["ParamB"] == p["ParamTotal"] && p["ParamTotal"] > 0,
                (3, 0) => p["ParamBase"] > 0 && p["ParamRightDen"] > 0 && p["ParamRightNum"] > 0
                          && x * p["ParamRightDen"] == p["ParamRightNum"] * p["ParamBase"],
                (3, 1) => p["ParamAltura"] > 0 && p["ParamAltura"] * x == p["ParamArea"],
                (4, 0) => p["ParamK"] >= 2 && p["ParamK"] * (x + p["ParamOffset"]) == p["ParamTotal"],
                (4, 1) => p["ParamAngA"] > 0 && p["ParamAngB"] > 0 && p["ParamAngA"] + p["ParamAngB"] + x == 180,
                _ => false,
            };
        }
        catch (KeyNotFoundException)
        {
            return false;
        }
    }
}