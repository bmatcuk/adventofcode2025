import gleam/int
import gleam/io
import gleam/list
import gleam/result
import gleam/string
import nibble/lexer
import simplifile

type Token {
  Batteries(List(Int))
}

fn find_largest_joltage(bank: List(Int), batteries_to_turn_on: Int) -> Int {
  // Idea is pretty simple: in the case where we only turn on two batteries, we
  // want to find the highest joltage, and then the next highest joltage that
  // comes after it. The only edge case is if the highest joltage is the last
  // number, then we need to take what _was_ the highest joltage before that as
  // the first digit, and the last number as the second digit.
  //
  // More generally, if we want to turn on X batteries, we need to find the
  // largest joltage in the first `batteries_per_bank - (X - 1)` batteries, to
  // ensure we have enough remaining batteries to turn on X - 1 more, and then
  // recurse on the remaining batteries to turn on the remaining X - 1
  // batteries.
  //
  // This function first zips the battery bank with a decreasing index,
  // representing how many batteries are left after that, ie:
  //   [#(B1, 99), #(B2, 98), ..., #(B99, 1), #(B100, 0)]
  //
  // This is passed to find_largest_joltage_impl which returns a list of the
  // joltages we turn on. That is then summed, with ever-increasing powers of
  // 10, to produce the result.
  let len = list.length(bank)
  let bank_with_remaining = list.zip(bank, list.range(len - 1, 0))
  find_largest_joltage_impl(bank_with_remaining, batteries_to_turn_on)
  |> list.fold(0, fn(acc, joltage) {
    acc * 10 + joltage
  })
}

fn find_largest_joltage_impl(bank: List(#(Int, Int)), batteries_to_turn_on: Int) -> List(Int) {
  // This implements the main recursive loop: find the largest joltage in the
  // beginning of the list, leaving enough batteries to ensure we can turn on
  // `batteries_to_turn_on - 1` more.
  case batteries_to_turn_on - 1 {
    remaining if remaining >= 0 -> {
      let #(joltage, rest) = find_largest_until(bank, remaining)
      [joltage, ..find_largest_joltage_impl(rest, remaining)]
    }
    _ -> []
  }
}

fn find_largest_until(bank: List(#(Int, Int)), remaining: Int) -> #(Int, List(#(Int, Int))) {
  // And this function actually finds the largest joltage, leaving at least
  // `remaining` batteries left, and returns the largest plus the list of
  // remaining batteries.
  case bank {
    [#(_, remains), .._] if remains < remaining -> #(-1, [])
    [#(joltage, _), ..rest] -> case find_largest_until(rest, remaining) {
      max_joltage if max_joltage.0 > joltage -> max_joltage
      _ -> #(joltage, rest)
    }
    _ -> #(-1, [])
  }
}

pub fn main() -> Nil {
  let assert Ok(input) = simplifile.read("input.txt")

  // this lexer also parses
  let lexer = lexer.simple([
    lexer.whitespace(Nil) |> lexer.ignore(),
    lexer.keep(fn (lexeme, lookahead) {
      case lookahead {
        "" | "\n" -> Ok(
          Batteries(
            string.to_graphemes(lexeme)
            |> list.map(int.parse)
            |> list.map(result.unwrap(_, 0))
          )
        )
        _ -> Error(Nil)
      }
    })
  ])

  // tokenize and parse
  let assert Ok(tokens) = lexer.run(input, lexer)
  let banks = list.map(tokens, fn(token) { token.value })

  // part 1
  let part1_result = list.fold(banks, 0, fn(acc, batteries) {
    let Batteries(bank) = batteries
    acc + find_largest_joltage(bank, 2)
  })
  io.println("Part 1: " <> int.to_string(part1_result))

  // part 2
  let part2_result = list.fold(banks, 0, fn(acc, batteries) {
    let Batteries(bank) = batteries
    acc + find_largest_joltage(bank, 12)
  })
  io.println("Part 2: " <> int.to_string(part2_result))
}
