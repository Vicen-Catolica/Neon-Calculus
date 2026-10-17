using Godot;
using Godot.Collections; // OBRIGATÓRIO para compatibilidade com GDScript
using NeonCalculus.Hacking;

/// <summary>
/// Ponte fina entre o GDScript (hacking_interface.gd) e o gerador puro em
/// scripts/hacking/EquationGenerator.cs. A lógica fica lá, onde é testada com NUnit.
/// </summary>
public partial class MathGenerator : RefCounted
{
    private readonly EquationGenerator _generator = new();

    public Dictionary GenerateValidEquation(int stage, int subTopic)
    {
        var eq = _generator.Generate(stage, subTopic);
        var dict = new Dictionary
        {
            ["Topic"] = eq.Topic,
            ["Expression"] = eq.Expression,
            ["Solution"] = eq.Solution,
        };
        foreach (var (key, value) in eq.Params)
            dict[key] = value;
        return dict;
    }
}