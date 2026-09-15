using Godot;
using Godot.Collections; // OBRIGATÓRIO para compatibilidade com GDScript
using System;

public partial class MathGenerator : RefCounted
{
    private Random _random = new Random();

    public Dictionary GenerateValidEquation(int stage, int subTopic)
    {
        var dict = new Dictionary();

        switch (stage)
        {
            case 1:
                if (subTopic == 0)
                {
                    dict["Topic"] = "NÚMEROS INTEIROS (ADIÇÃO E SUBTRAÇÃO)";
                    int a = _random.Next(-9, 10);
                    if (a == 0) a = 3;
                    int solution = _random.Next(1, 12);
                    int res = solution + a;
                    
                    string termA = a >= 0 ? $"{a}" : $"({a})";
                    dict["Expression"] = $"x + {termA} = {res}";
                    dict["Solution"] = solution;
                    dict["ParamA"] = a;
                    dict["ParamRes"] = res;
                }
                else
                {
                    dict["Topic"] = "ÁLGEBRA SIMPLES (MULTIPLICAÇÃO)";
                    int count = _random.Next(2, 6);
                    int solution = _random.Next(2, 10);
                    int res = count * solution;

                    dict["Expression"] = $"{count}x = {res}";
                    dict["Solution"] = solution;
                    dict["ParamA"] = count;
                    dict["ParamRes"] = res;
                }
                break;

            case 2:
                dict["Topic"] = "EQUAÇÃO DO 1º GRAU";
                int mult = _random.Next(2, 5);
                int sol2 = _random.Next(2, 10);
                int bVal = _random.Next(2, 9);
                if (subTopic == 1) bVal = -bVal; // Trata equações com subtração
                
                int totalC = (mult * sol2) + bVal;
                string signStr = bVal >= 0 ? "+" : "-";
                dict["Expression"] = $"{mult}x {signStr} {Math.Abs(bVal)} = {totalC}";
                dict["Solution"] = sol2;
                dict["ParamMult"] = mult;
                dict["ParamB"] = bVal;
                dict["ParamTotal"] = totalC;
                break;

            case 3:
                if (subTopic == 0)
                {
                    dict["Topic"] = "REGRA DE TRÊS SIMPLES";
                    int baseVal = _random.Next(2, 6);
                    int den = _random.Next(2, 6);
                    int sol3 = _random.Next(2, 10);
                    int num = (sol3 * den) / baseVal;

                    dict["Expression"] = $"x / {baseVal} = {num} / {den}";
                    dict["Solution"] = sol3;
                    dict["ParamBase"] = baseVal;
                    dict["ParamRightNum"] = num;
                    dict["ParamRightDen"] = den;
                }
                else
                {
                    dict["Topic"] = "GEOMETRIA (ÁREA DO RETÂNGULO)";
                    int alt = _random.Next(3, 8);
                    int solArea = _random.Next(4, 12);
                    int area = alt * solArea;

                    dict["Expression"] = $"Área = {area} | Altura = {alt}";
                    dict["Solution"] = solArea;
                    dict["ParamAltura"] = alt;
                    dict["ParamArea"] = area;
                }
                break;

            case 4:
                if (subTopic == 0)
                {
                    dict["Topic"] = "PROPRIEDADE DISTRIBUTIVA";
                    int k = _random.Next(2, 5);
                    int offset = _random.Next(2, 6);
                    int solDist = _random.Next(2, 10);
                    int totalDist = k * (solDist + offset);

                    dict["Expression"] = $"{k}(x + {offset}) = {totalDist}";
                    dict["Solution"] = solDist;
                    dict["ParamK"] = k;
                    dict["ParamOffset"] = offset;
                    dict["ParamTotal"] = totalDist;
                }
                else
                {
                    dict["Topic"] = "ÂNGULOS DO TRIÂNGULO";
                    int angA = _random.Next(30, 70);
                    int angB = _random.Next(30, 70);
                    int solTri = 180 - (angA + angB);

                    dict["Expression"] = $"{angA}° + {angB}° + x° = 180°";
                    dict["Solution"] = solTri;
                    dict["ParamAngA"] = angA;
                    dict["ParamAngB"] = angB;
                }
                break;
        }

        return dict;
    }
}