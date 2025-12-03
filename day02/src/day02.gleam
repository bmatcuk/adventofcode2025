import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/order.{Eq, Gt, Lt}
import gleam/result
import gleam/string
import nibble/lexer
import simplifile

type Token {
  Range(String, String)
}

fn calc_invalid_ids(range: Token) -> Int {
  let Range(range_start, range_end) = range
  let start_length = string.length(range_start)
  let start = case int.is_even(start_length) {
    True -> {
      // Ex: 1412 we want 14 because the next invalid id would be 1414
      // Ex 2: 1214 we want 13 because the next invalid id would be 1313
      let assert Ok(left) = int.parse(string.slice(range_start, 0, start_length / 2))
      let assert Ok(right) = int.parse(string.drop_start(range_start, start_length / 2))
      case int.compare(left, right) {
        Eq | Gt -> left
        Lt -> left + 1
      }
    }
    False -> {
      // Ex: 999 has a length of 3, so we want half of the digits of
      // 1000 (10 ^ 3), which would be 10 (10 ^ 1).
      // Ex 2: 99999 has a length of 5, so we want half of the digits of
      // 100000 (10 ^ 5), which would be 100 (10 ^ 2)
      // So, the exponent is the integer division of length / 2
      let assert Ok(num) = int.power(10, int.to_float(start_length / 2))
      float.truncate(num)
    }
  }

  let end_length = string.length(range_end)
  let end = case int.is_even(end_length) {
    True -> {
      // Ex: 1412 we want 13 because the last invalid id would be 1313
      // Ex 2: 1214 we want 12 because the last invalid id would be 1212
      let assert Ok(left) = int.parse(string.slice(range_end, 0, end_length / 2))
      let assert Ok(right) = int.parse(string.drop_start(range_end, end_length / 2))
      case int.compare(left, right) {
        Eq | Lt -> left
        Gt -> left - 1
      }
    }
    False -> {
      // Ex: 999 has a length of 3, so we want half of the digits of
      // 99 (10 ^ 2 - 1), which would be 9 (10 ^ 1 - 1).
      // Ex 2: 99999 has a length of 5, so we want half of the digits of
      // 9999 (10 ^ 4 - 1), which would be 99 (10 ^ 2 - 1)
      // So, the exponent is the integer division of length / 2 again
      let assert Ok(num) = int.power(10, int.to_float(end_length / 2))
      float.truncate(num) - 1
    }
  }

  case end - start + 1 > 0 {
    True ->
      list.range(start, end)
      |> list.map(fn(num) {
        int.to_string(num)
        |> string.repeat(2)
        |> int.parse()
        |> result.unwrap(0)
      })
      |> int.sum()
    False -> 0
  }
}

pub fn main() -> Nil {
  let assert Ok(input) = simplifile.read("input.txt")

  // this lexer also parses the ranges
  let lexer = lexer.simple([
    lexer.token(",", Nil) |> lexer.ignore(),
    lexer.whitespace(Nil) |> lexer.ignore(),
    lexer.keep(fn (lexeme, lookahead) {
      case lookahead {
        "" | "," | "\n" -> {
          let assert Ok(#(start, end)) = string.split_once(lexeme, on: "-")
          Ok(Range(start, end))
        }
        _ -> Error(Nil)
      }
    })
  ])

  // tokenize and "parse" by just mapping the tokens to the ranges
  let assert Ok(tokens) = lexer.run(input, lexer)
  let ranges = list.map(tokens, fn(token) { token.value })

  // calculate
  let part1_result = list.fold(ranges, 0, fn(acc, range) {
    acc + calc_invalid_ids(range)
  })
  io.println("Part 1: " <> int.to_string(part1_result))
}
