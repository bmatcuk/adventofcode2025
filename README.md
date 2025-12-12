# Advent of Code, 2025 :christmas_tree:
My solutions to the [Advent of Code 2025] in [gleam].

I like to use the Advent of Code as a learning opportunity. This year, I
decided on learning [gleam]. I have zero experience with the language.

## Retrospective :santa:
Gleam is alright. I found it fairly easy to write code in gleam. Because it's a
tight, functional language, types are guaranteed and can be reasoned,
implicitly, as you write, allowing the language server to easily alert you to
mistakes. Syntax was straightforward, though a little clumsy at times. For
example, really felt weird to have to write a `case` statement with paths for
`True` and `False`, and annoying that "guards" cannot contain function calls.

But, it also left much to be desired. The standard library has very limited
functionality. Some stuff has been moved out into their own libraries, sowing
confusion because some documentation and examples haven't been updated. And,
for example, neither gleam, nor the standard gleam library, have a way to read
from a file! Had to reach for a third party library just for that.

Anyway, I think all I could say is: I wouldn't be sad if I _had_ to use gleam,
but I wouldn't reach for it otherwise.

## Notable Algorithms and Data Structures :snowflake:
* Gaussian Elimination - [day 10], part 2, was painful. It required solving a
  linear programming problem, to which most people reached for an existing LP
  solver such as z3. Sadly, Gleam doesn't have bindings to any of these
  libraries, and I lack the knowledge and time to implement one. It's a
  difficult topic. Fortunately, I did find someone on reddit that used Gaussian
  Elimination to solve the problem, and whose code had just enough
  self-documentation for me to understand. Porting to Gleam was difficult, but
  I made it work with only a single typo, that took an hour or two of hand
  solving matricies to find, lol. I did not enjoy this.
* Kahn's - [day 11] required finding all of the paths through a directed graph.
  By creating a topological sort, using Kahn's algorithm, it's easy to compute
  the number of ways from one node to another.
* Packing Problem - [day 12] is a packing problem, which is NP Complete.
  Fortunately, we were not expected to actually solve this.

:snowman_with_snow:

[Advent of Code 2025]: https://adventofcode.com/2025
[gleam]: https://gleam.run/
[day 10]: https://github.com/bmatcuk/adventofcode2025/blob/9930279e2d415dd985910176e0e1e4c9d87ce1c6/day10/src/day10.gleam
[day 11]: https://github.com/bmatcuk/adventofcode2025/blob/04abd24c0b66e5d39b2d77a0c5c1d6fea7f7c113/day11/src/day11.gleam
[day 12]: https://github.com/bmatcuk/adventofcode2025/blob/main/day12/src/day12.gleam
