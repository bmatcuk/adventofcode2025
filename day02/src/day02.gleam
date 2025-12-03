import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/result
import gleam/set
import gleam/string
import nibble/lexer
import simplifile

type Token {
  Range(String, String)
}

fn calc_invalid_ids_part1(range: Token) -> Int {
  // for part 1, the set isn't really necessary...
  let Range(range_start, range_end) = range
  calc_invalid_ids_impl(range_start, range_end, 2, set.new())
  |> set.to_list()
  |> int.sum()
}

fn calc_invalid_ids_part2(range: Token) -> Int {
  // ...but, for part 2, the set is necessary. Take, for example, the number
  // 24242424. This could be represented as 2424 twice, or 24 four times. It's
  // the same result, though, so we need to avoid double counting it. There's
  // probably some other way to remove the duplicates, but a set is super easy.
  //
  // We run the same algo as before, but now multiple times: first with 2
  // repeats, then 3, then 4, etc, until we reach the length of the range end
  // (at which point we'd be repeating a single digit that many times).
  let Range(range_start, range_end) = range
  case string.length(range_end) {
    length if length >= 2 ->
      calc_invalid_ids_rec(range_start, range_end, list.range(2, length), set.new())
      |> set.to_list()
      |> list.sort(int.compare)
      |> int.sum()
    _ -> 0
  }
}

fn calc_invalid_ids_rec(range_start: String, range_end: String, repeats: List(Int), set: set.Set(Int)) -> set.Set(Int) {
  case repeats {
    [repeated, ..remaining] ->
      calc_invalid_ids_rec(
        range_start,
        range_end,
        remaining,
        calc_invalid_ids_impl(range_start, range_end, repeated, set)
      )
    [] -> set
  }
}

fn calc_invalid_ids_impl(range_start: String, range_end: String, repeated: Int, set: set.Set(Int)) -> set.Set(Int) {
  let start_length = string.length(range_start)
  let assert Ok(start) = case start_length % repeated == 0 {
    True -> {
      // If repeated is 2:
      // Ex: 1412 we want 14 because the next invalid id would be 1414
      // Ex 2: 1214 we want 13 because the next invalid id would be 1313
      // If repeated is 3:
      // Ex: 161412 we want 16 because the next invalid id would be 161616
      // Ex: 121416 we want 13 because the next invalid id would be 131313
      // Ex: 141612 we want 15 because the next invalid id would be 151515
      // Ex: 141216 we want 14 because the next invalid id would be 141414
      // So, generally, we want the first tuple if it is greater than the first
      // non-equal tuple; otherwise, we want the first tuple + 1. If all tuples
      // are the equal, we want the first tuple as well.
      let tuples = string.to_graphemes(range_start)
      |> list.sized_chunk(start_length / repeated)
      |> list.map(fn(chunk) {
        string.join(chunk, "")
        |> int.parse()
        |> result.unwrap(0)
      })
      case tuples {
        [first, ..rest] -> case list.drop_while(rest, fn(i) { i == first }) {
          [] -> Ok(first)
          [second, .._] if first >= second -> Ok(first)
          _ -> Ok(first + 1)
        }
        _ -> Error("No chunks in start?")
      }
    }
    False -> {
      // If repeated is 2:
      // Ex: 999 has a length of 3, so we want half of the digits of
      // 1000 (10 ^ 3), which would be 10 (10 ^ 1).
      // Ex 2: 99999 has a length of 5, so we want half of the digits of
      // 100000 (10 ^ 5), which would be 100 (10 ^ 2)
      // So, the exponent is the integer division of length / 2
      // If repeated is 3:
      // Ex: 9999 has a length of 4, so we want a third of the digits of
      // 100000 (10 ^ 5), which would be 10 (10 ^ 1)
      // Ex: 99999 has a length of 5, so we want a third of the digits of
      // 100000 again.
      // So, generally, the exponent is the integer division of
      // length / repeated
      let assert Ok(num) = int.power(10, int.to_float(start_length / repeated))
      Ok(float.truncate(num))
    }
  }

  let end_length = string.length(range_end)
  let assert Ok(end) = case end_length % repeated == 0 {
    True -> {
      // If repeated is 2:
      // Ex: 1412 we want 13 because the last invalid id would be 1313
      // Ex 2: 1214 we want 12 because the last invalid id would be 1212
      // If repeated is 3:
      // Ex: 161412 we want 15 because the last invalid id would be 151515
      // Ex: 121416 we want 12 because the last invalid id would be 121212
      // Ex: 141612 we want 14 because the last invalid id would be 141414
      // So, generally, we want the first tuple if it is lower than the first
      // non-equal tuple; otherwise, we want the first tuple - 1. If all tuples
      // are equal, we want the first tuple as well.
      let tuples = string.to_graphemes(range_end)
      |> list.sized_chunk(end_length / repeated)
      |> list.map(fn(chunk) {
        string.join(chunk, "")
        |> int.parse()
        |> result.unwrap(0)
      })
      case tuples {
        [first, ..rest] -> case list.drop_while(rest, fn(i) { i == first }) {
          [] -> Ok(first)
          [second, .._] if first <= second -> Ok(first)
          _ -> Ok(first - 1)
        }
        _ -> Error("Not enough chunks in end?")
      }
    }
    False -> {
      // If repeated is 2:
      // Ex: 999 has a length of 3, so we want half of the digits of
      // 99 (10 ^ 2 - 1), which would be 9 (10 ^ 1 - 1).
      // Ex 2: 99999 has a length of 5, so we want half of the digits of
      // 9999 (10 ^ 4 - 1), which would be 99 (10 ^ 2 - 1)
      // So, the exponent is the integer division of length / 2 again
      // If repeated is 3:
      // Ex: 9999 has a length of 4, so we want a third of the digits of
      // 999 (10 ^ 3 - 1), which would be 9 (10 ^ 1 - 1).
      // Ex: 99999 has a length of 5, so we want a third of the digits of
      // 999 again.
      // So, generally, the exponent is the integer division of
      // length / repeated again.
      let assert Ok(num) = int.power(10, int.to_float(end_length / repeated))
      Ok(float.truncate(num) - 1)
    }
  }

  case end >= start {
    True ->
      list.range(start, end)
      |> list.fold(
        set,
        fn(set, num) {
          int.to_string(num)
          |> string.repeat(repeated)
          |> int.parse()
          |> result.unwrap(0)
          |> set.insert(set, _)
        })
    False -> set
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

  // calculate part 1
  let part1_result = list.fold(ranges, 0, fn(acc, range) {
    acc + calc_invalid_ids_part1(range)
  })
  io.println("Part 1: " <> int.to_string(part1_result))

  // calculate part 2
  let part2_result = list.fold(ranges, 0, fn(acc, range) {
    acc + calc_invalid_ids_part2(range)
  })
  io.println("Part 2: " <> int.to_string(part2_result))
}
