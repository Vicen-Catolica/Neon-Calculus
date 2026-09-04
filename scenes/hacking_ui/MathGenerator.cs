using Godot;
using System;

public partial class MathGenerator : Node
{
    private Random _random = new Random();

    public Godot.Collections.Dictionary GenerateValidEquation(int currentFloor)
    {
        bool isValid = false;
        string expression = "";
        int xTarget = 0;

        do
        {
            int a = _random.Next(1, 3 + currentFloor);
            int b = _random.Next(1, 10 * currentFloor);
            xTarget = _random.Next(1, 10 + currentFloor);

            int c = (a * xTarget) + b;

            expression = $"{a}x + {b} = {c}";

            if ((c - b) % a == 0 && xTarget > 0)
            {
                isValid = true;
            }
        } while (!isValid);

        return new Godot.Collections.Dictionary
        {
            { "Expression", expression },
            { "Solution", xTarget }
        };
    }
}