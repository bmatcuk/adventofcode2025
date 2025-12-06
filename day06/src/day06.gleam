import gleam/int
import gleam/io
import gleam/list
import gleam/result
import gleam/string
import nibble.{Break, Continue, do, return}
import nibble/lexer
import simplifile

type Token {
  Number(Int)
  NewLine
  Addition
  Multiplication
}

type OperatorAndOperands {
  Operand(Int)
  Add
  Multiply
}

pub fn main() -> Nil {
  let assert Ok(input) = simplifile.read("input.txt")

  let lexer = lexer.simple([
    lexer.int(Number),
    lexer.token("\n", NewLine),
    lexer.token("+", Addition),
    lexer.token("*", Multiplication),
    lexer.spaces(Nil) |> lexer.ignore(),
  ])

  // tokenize
  let assert Ok(tokens) = lexer.run(input, lexer)

  let parser = nibble.loop(
    #([], []),
    fn(acc) {
      nibble.one_of([
        {
          use _ <- do(nibble.eof())
          case acc.0 {
            [_, .._] -> return(Break(#([], [acc.0, ..acc.1])))
            _ -> return(Break(acc))
          }
        },
        {
          use token <- do(nibble.take_if("token", fn(_) { True }))
          case token {
            NewLine -> return(Continue(#([], [acc.0, ..acc.1])))
            Number(num) -> return(Continue(#([Operand(num), ..acc.0], acc.1)))
            Addition -> return(Continue(#([Add, ..acc.0], acc.1)))
            Multiplication -> return(Continue(#([Multiply, ..acc.0], acc.1)))
          }
        },
      ])
    }
  )

  // parse
  // transpose the data so we have a list of columns
  let assert Ok(#(_, rows)) = nibble.run(tokens, parser)
  let columns = list.transpose(rows)

  // PART 1
  let part1_result = list.fold(columns, 0, fn(acc, column) {
    // for each column, find the operator (list.sum or list.product) and the
    // list of operands
    let #(func, nums) = list.fold(column, #(int.sum, []), fn(acc, operand) {
      case operand {
        Operand(num) -> #(acc.0, [num, ..acc.1])
        Add -> #(int.sum, acc.1)
        Multiply -> #(int.product, acc.1)
      }
    })

    // then perform the operation
    func(nums) + acc
  })
  io.println("Part 1: " <> int.to_string(part1_result))

  // PART 2
  // Part 2 is very different from part 1, so I'm going to basically start over
  // from parsing...
  let part2_result = string.split(input, "\n")      // split on newlines
  |> list.map(string.to_graphemes(_))               // convert to list of graphemes
  |> list.transpose()                               // transpose to columns
  |> list.map(fn(graphemes) {
    // move the last column (where the operators are)
    // to the front, then convert back to a string
    let cnt = list.length(graphemes)
    let #(digits, operator) = list.split(graphemes, cnt - 1)
    list.append(operator, digits)
    |> string.join("")
  })
  |> list.fold(#(int.sum, [], 0), fn(acc, line) {
    // If the line starts with an operator, run the function in acc.0 (int.sum
    // or int.product) on the list in acc.1 and add it to acc.2. Then update
    // the function in acc.0 and start a new list in acc.1 with the number on
    // this line.
    //
    // Otherwise, just add the number on this line to the list in acc.1,
    // skipping blank lines.
    case line {
      "+" <> rest -> #(int.sum, [result.unwrap(int.parse(string.trim(rest)), 0)], acc.2 + acc.0(acc.1))
      "*" <> rest -> #(int.product, [result.unwrap(int.parse(string.trim(rest)), 0)], acc.2 + acc.0(acc.1))
      _ -> {
        // int.parse will return Error on blank lines - ignore them
        case int.parse(string.trim(line)) {
          Ok(num) -> #(acc.0, [num, ..acc.1], acc.2)
          Error(_) -> acc
        }
      }
    }
  })
  |> fn(acc) { acc.0(acc.1) + acc.2 }               // one final calculation
  io.println("Part 2: " <> int.to_string(part2_result))
}
