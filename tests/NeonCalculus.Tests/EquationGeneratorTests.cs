using NeonCalculus.Hacking;
using NUnit.Framework;

namespace NeonCalculus.Tests;

public class EquationGeneratorTests
{
    private static readonly (int Stage, int Sub)[] AllTopics =
    {
        (1, 0), (1, 1), (2, 0), (2, 1), (3, 0), (3, 1), (4, 0), (4, 1),
    };

    private static IEnumerable<TestCaseData> Topics() =>
        AllTopics.Select(t => new TestCaseData(t.Stage, t.Sub).SetName($"Stage{t.Stage}_Sub{t.Sub}"));

    [TestCaseSource(nameof(Topics))]
    public void Generate_AlwaysValidWithPositiveIntegerSolution(int stage, int sub)
    {
        for (int seed = 0; seed < 3000; seed++)
        {
            var eq = new EquationGenerator(seed).Generate(stage, sub);
            Assert.Multiple(() =>
            {
                Assert.That(EquationValidator.IsValid(eq), Is.True, eq.Expression);
                Assert.That(eq.Solution, Is.InRange(1, EquationValidator.MaxSolution), eq.Expression);
                Assert.That(eq.Stage, Is.EqualTo(stage));
                Assert.That(eq.SubTopic, Is.EqualTo(sub));
            });
        }
    }

    [Test]
    public void RuleOfThree_IsExact_RegressionForIntegerDivisionBug()
    {
        // A versão antiga calculava n = (x*d)/b com divisão inteira, gerando x errado.
        var gen = new EquationGenerator(1);
        for (int i = 0; i < 5000; i++)
        {
            var eq = gen.Generate(3, 0);
            Assert.That(eq.Solution * eq.Params["ParamRightDen"],
                Is.EqualTo(eq.Params["ParamRightNum"] * eq.Params["ParamBase"]), eq.Expression);
        }
    }

    [Test]
    public void FirstDegree_TotalIsAlwaysPositive()
    {
        var gen = new EquationGenerator(2);
        for (int i = 0; i < 5000; i++)
            Assert.That(gen.Generate(2, 1).Params["ParamTotal"], Is.GreaterThan(0));
    }

    [Test]
    public void SameSeed_ProducesSameEquation()
    {
        var a = new EquationGenerator(42).Generate(2, 0);
        var b = new EquationGenerator(42).Generate(2, 0);
        Assert.That(a.Expression, Is.EqualTo(b.Expression));
    }

    [Test]
    public void Generate_HasVariety()
    {
        var gen = new EquationGenerator(7);
        var distinct = Enumerable.Range(0, 200).Select(_ => gen.Generate(1, 0).Expression).Distinct().Count();
        Assert.That(distinct, Is.GreaterThan(20));
    }

    [TestCase(0, 1)]
    [TestCase(-3, 0)]
    [TestCase(9, 1)]
    public void OutOfRangeStage_IsClampedInsteadOfFailing(int stage, int sub)
    {
        var eq = new EquationGenerator(1).Generate(stage, sub);
        Assert.That(eq.Stage, Is.InRange(EquationGenerator.MinStage, EquationGenerator.MaxStage));
        Assert.That(EquationValidator.IsValid(eq), Is.True);
    }

    [Test]
    public void Validator_RejectsWrongSolution()
    {
        var eq = new EquationGenerator(5).Generate(2, 0);
        Assert.That(EquationValidator.IsValid(eq with { Solution = eq.Solution + 1 }), Is.False);
    }

    [Test]
    public void Validator_RejectsMissingParams()
    {
        var eq = new EquationGenerator(5).Generate(4, 0);
        Assert.That(EquationValidator.IsValid(eq with { Params = new Dictionary<string, int>() }), Is.False);
    }

    [Test]
    public void Validator_RejectsNonPositiveSolution()
    {
        var eq = new EquationGenerator(5).Generate(1, 0);
        Assert.That(EquationValidator.IsValid(eq with { Solution = 0 }), Is.False);
    }
}