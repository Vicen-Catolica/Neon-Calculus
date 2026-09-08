using Godot;
using System;

public partial class MathGenerator : Node
{
    private Random _random = new Random();

    public Godot.Collections.Dictionary GenerateValidEquation(int stage, int subTopic = 0)
    {
        string expression = "";
        int solution = 0;
        string topic = "";
        var dict = new Godot.Collections.Dictionary();

        switch (stage)
        {
            case 1:
                if (subTopic == 0)
                {
                    topic = "NÚMEROS INTEIROS (ADIÇÃO E SUBTRAÇÃO)";
                    int a = _random.Next(-9, 10);
                    if (a == 0) a = 3;
                    solution = _random.Next(1, 12);
                    int res = solution + a;
                    expression = $"x + ({a}) = {res}";

                    dict["ParamA"] = a;
                    dict["ParamRes"] = res;
                }
                else
                {
                    topic = "ÁLGEBRA SIMPLES (MULTIPLICAÇÃO)";
                    int a = _random.Next(2, 5);
                    solution = _random.Next(2, 10);
                    int res = a * solution;
                    expression = $"{a}x = {res}";

                    dict["ParamA"] = a;
                    dict["ParamRes"] = res;
                }
                break;

            case 2:
                if (subTopic == 0)
                {
                    topic = "EQUAÇÕES DO 1º GRAU (POSITIVOS)";
                    int mult = _random.Next(2, 5);
                    solution = _random.Next(2, 10);
                    int bVal = _random.Next(2, 9);
                    int totalC = (mult * solution) + bVal;
                    expression = $"{mult}x + {bVal} = {totalC}";

                    dict["ParamMult"] = mult;
                    dict["ParamB"] = bVal;
                    dict["ParamTotal"] = totalC;
                }
                else
                {
                    topic = "NÚMEROS RACIONAIS & INTEIROS NEGATIVOS";
                    int mult = _random.Next(2, 5);
                    solution = _random.Next(2, 10);
                    int bVal = _random.Next(2, 9);
                    int totalC = (mult * solution) - bVal;
                    expression = $"{mult}x - {bVal} = {totalC}";

                    dict["ParamMult"] = mult;
                    dict["ParamB"] = -bVal;
                    dict["ParamTotal"] = totalC;
                }
                break;

            case 3:
                if (subTopic == 0)
                {
                    topic = "RAZÃO E PROPORÇÃO (REGRA DE TRÊS)";
                    int baseVal = _random.Next(2, 6);
                    int factor = _random.Next(2, 5);
                    solution = _random.Next(2, 10);
                    int rightNum = solution * factor;
                    int rightDen = baseVal * factor;
                    expression = $"x / {baseVal} = {rightNum} / {rightDen}";

                    dict["ParamBase"] = baseVal;
                    dict["ParamRightNum"] = rightNum;
                    dict["ParamRightDen"] = rightDen;
                }
                else
                {
                    topic = "GEOMETRIA (ÁREA DE RETÂNGULO)";
                    int altura = _random.Next(3, 8);
                    solution = _random.Next(3, 10);
                    int area = solution * altura;
                    expression = $"Área = {area} | Altura = {altura} | Base x = ?";

                    dict["ParamAltura"] = altura;
                    dict["ParamArea"] = area;
                }
                break;

            case 4:
                if (subTopic == 0)
                {
                    topic = "ÁLGEBRA (PROPRIEDADE DISTRIBUTIVA)";
                    int k = _random.Next(2, 5);
                    solution = _random.Next(2, 8);
                    int offset = _random.Next(2, 6);
                    int total = k * (solution + offset);
                    expression = $"{k}(x + {offset}) = {total}";

                    dict["ParamK"] = k;
                    dict["ParamOffset"] = offset;
                    dict["ParamTotal"] = total;
                }
                else
                {
                    topic = "GEOMETRIA (ÂNGULOS DO TRIÂNGULO)";
                    int angA = _random.Next(35, 70);
                    int angB = _random.Next(35, 70);
                    solution = 180 - (angA + angB);
                    expression = $"Triângulo: {angA}°, {angB}° e x°";

                    dict["ParamAngA"] = angA;
                    dict["ParamAngB"] = angB;
                }
                break;
        }

        dict["Expression"] = expression;
        dict["Solution"] = solution;
        dict["Topic"] = topic;

        return dict;
    }
}