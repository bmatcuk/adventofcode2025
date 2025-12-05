import gleam/int
import gleam/io
import gleam/list
import nibble.{Break, Continue, do, return}
import nibble/lexer
import simplifile

type Mode {
  Start
  Number(Int)
  RangeStart(Int)
}

type Token {
  Range(from: Int, to: Int)
  Ingredient(Int)
}

/// Reduce the list of ranges to a more "simplified" set by combining
/// overlapping ranges. Input is assumed to be sorted by range starts,
/// ascending.
fn simplify_fresh(fresh: List(#(Int, Int))) -> List(#(Int, Int)) {
  case fresh {
    // second is completely part of first
    [first, second, ..rest] if second.1 <= first.1 -> simplify_fresh([first, ..rest])

    // first and second overlap
    [#(start1, end1), #(start2, end2), ..rest] if start2 <= end1 -> simplify_fresh([#(start1, end2), ..rest])

    // no overlap
    [first, second, ..rest] if second.0 > first.1 -> [first, ..simplify_fresh([second, ..rest])]

    // anything else
    rest -> rest
  }
}

/// Find a needle in a sorted haystack of ranges
fn find(needle: Int, haystack: List(#(Int, Int))) -> Bool {
  case haystack {
    [#(start, end), .._] if start <= needle && needle <= end -> True
    [#(start, _), ..rest] if start < needle -> find(needle, rest)
    _ -> False
  }
}

pub fn main() -> Nil {
  let assert Ok(input) = simplifile.read("input.txt")

  let lexer = lexer.advanced(fn(mode) {
    case mode {
      Start -> [
        // look for numbers and switch to Number mode
        lexer.int(Number) |> lexer.then(lexer.Drop(_)),
        lexer.whitespace(Nil) |> lexer.ignore(),
      ]
      Number(ingredient) -> [
        // look for a dash to switch to RangeStart mode, or whitespace which
        // means the number is just an Ingredient and switch back to Start
        lexer.token("-", Nil) |> lexer.then(fn(_) { lexer.Drop(RangeStart(ingredient)) }),
        lexer.whitespace(Nil) |> lexer.then(fn(_) { lexer.Keep(Ingredient(ingredient), Start) }),
      ]
      RangeStart(ingredient) -> [
        // look for a number to finish the range and return to Start mode
        lexer.int(Range(ingredient, _)) |> lexer.then(lexer.Keep(_, Start)),
        lexer.whitespace(Nil) |> lexer.ignore(),
      ]
    }
  })

  // tokenize
  let assert Ok(tokens) = lexer.run_advanced(input, Start, lexer)

  let parser = nibble.loop(
    #([], []),
    fn(acc) {
      nibble.one_of([
        {
          use _ <- do(nibble.eof())
          return(Break(acc))
        },
        {
          use token <- do(nibble.take_if("token", fn(_) { True }))
          case token {
            Range(start, end) -> return(Continue(#([#(start, end), ..acc.0], acc.1)))
            Ingredient(ingredient) -> return(Continue(#(acc.0, [ingredient, ..acc.1])))
          }
        },
      ])
    }
  )

  // parse
  // sort and simplify the "fresh" list
  let assert Ok(#(fresh, ingredients)) = nibble.run(tokens, parser)
  let fresh = list.sort(fresh, fn(a, b) { int.compare(a.0, b.0) }) |> simplify_fresh()

  // PART 1
  let part1_result = list.fold(ingredients, 0, fn(acc, ingredient) {
    case find(ingredient, fresh) {
      True -> acc + 1
      False -> acc
    }
  })
  io.println("Part 1: " <> int.to_string(part1_result))

  // PART 2
  // since we already simplified the "fresh" list,
  // we just count the size of each range
  let part2_result = list.fold(fresh, 0, fn(acc, range) {
    acc + range.1 - range.0 + 1
  })
  io.println("Part 2: " <> int.to_string(part2_result))
}
