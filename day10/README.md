# Day 10, Part 2
I did not finish this.

In my mind, AoC is about writing code. The solution to part 2 _requires_ an LP
solver, such as z3. So, I'm left with three choices:
1. Implement my own solver;
2. Use a library; or,
3. Use an external tool.

The problem with option 1 is that I don't have the time to build my own solver.
This is a complex topic. One does not simply write an LP solver.

The problem with option 2 is that my chosen language, Gleam, does not have an
LP library. I could switch to a different language, such as python. But, it's
my goal, every year, to use a specific language to solve all of the problems.
So I don't want to do that.

So, I'm left with option 3. I _could_ write some code to transform the input
into some form that I can feed to an external tool, but that feels like I'm
straying from the spirit of AoC: to write code to solve the problem. So,
because my chosen language doesn't have an LP library, and I don't have the
time or energy to write my own, I cannot solve part 2.

I have written a DFS algo that _will_ solve it. It gives correct results with
the sample data. But, I have no idea how long it will take with my actual input
data.
