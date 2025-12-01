import gleam/list
import gleam/int
import gleam/io
import gleam/option.{Some}
import gleam/result
import gleam/set
import gleam/string
import nibble.{Break, Continue, do, return}
import nibble/lexer
import simplifile

type Token {
  Left(String)
  Right(String)
}

/// Compute modulo the way python does, at least,
/// assuming the dividend is positive.
fn positive_modulo(dividend: Int, by divisor: Int) -> Int {
  case dividend % divisor {
    result if result < 0 -> divisor + result
    result -> result
  }
}

pub fn main() -> Nil {
  let assert Ok(input) = simplifile.read("input.txt")

  // lexer to tokenize input
  let lexer = lexer.simple([
    lexer.identifier("L", "\\d", set.new(), Left),
    lexer.identifier("R", "\\d", set.new(), Right),
    lexer.whitespace(Nil) |> lexer.ignore()
  ])

  // tokenize
  let assert Ok(tokens) = lexer.run(input, lexer)

  // parse LX to -X, and RX to X
  let parse_token = {
    use token <- nibble.take_map("expected token")
    case token {
      Left(s) -> Some(int.parse(string.drop_start(s, 1)) |> result.map(int.subtract(0, _)))
      Right(s) -> Some(int.parse(string.drop_start(s, 1)))
    }
  }

  // parse input tokens until EOF
  let parser = nibble.loop(
    [],
    fn(list) {
      nibble.one_of([
        {
          use _ <- do(nibble.eof())
          return(Break(list))
        },
        {
          use result <- nibble.do(parse_token)
          case result {
            Ok(move) -> return(Continue([move, ..list]))
            Error(_) -> nibble.fail("failed to parse token")
          }
        },
      ])
    }
  )

  // parse tokens
  let assert Ok(moves) = nibble.run(tokens, parser) |> result.map(list.reverse)

  // PART 1
  let #(_, part1_result) = list.fold(
    over: moves,
    from: #(50, 0),
    with: fn(acc, move) {
      let #(position, cnt) = acc
      let new_position = positive_modulo(position + move, 100)
      case new_position {
        0 -> #(new_position, cnt + 1)
        _ -> #(new_position, cnt)
      }
    }
  )
  io.println("Part 1: " <> int.to_string(part1_result))

  // PART 2
  let #(_, part2_result) = list.fold(
    over: moves,
    from: #(50, 0),
    with: fn(acc, move) {
      let #(position, cnt) = acc
      case position + move {
        new_position if new_position >= 100 -> #(positive_modulo(new_position, 100), cnt + new_position / 100)
        new_position if new_position <= 0 -> case position {
          0 -> #(positive_modulo(new_position, 100), cnt + new_position / -100)
          _ -> #(positive_modulo(new_position, 100), cnt + new_position / -100 + 1)
        }
        new_position -> #(positive_modulo(new_position, 100), cnt)
      }
    }
  )
  io.println("Part 2: " <> int.to_string(part2_result))
}
