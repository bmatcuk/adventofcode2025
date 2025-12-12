import gleam/int
import gleam/io
import gleam/list
import gleam/option.{None, Some}
import nibble.{Break, Continue, do, return}
import nibble/lexer
import simplifile

type Token {
  Colon
  Empty
  NewLine
  Number(Int)
  Occupied
  X
}

type Present {
  Present(shape: List(List(Bool)), area: Int)
}

type Space {
  Space(w: Int, h: Int, presents: List(Int))
}

pub fn main() -> Nil {
  let assert Ok(input) = simplifile.read("input.txt")

  let lexer = lexer.simple([
    lexer.token(":", Colon),
    lexer.token(".", Empty),
    lexer.token("\n", NewLine),
    lexer.int(Number),
    lexer.token("#", Occupied),
    lexer.token("x", X),
    lexer.spaces(Nil) |> lexer.ignore(),
  ])

  // tokenize
  let assert Ok(tokens) = lexer.run(input, lexer)

  let parser = nibble.loop(
    #([], []),
    fn(acc) {
      let #(presents, spaces) = acc
      nibble.one_of([
        {
          use _ <- do(nibble.eof())
          return(Break(#(list.reverse(presents), list.reverse(spaces))))
        },
        {
          use _ <- do(nibble.take_if("newline", fn(tok) { tok == NewLine }))
          return(Continue(acc))
        },
        {
          use tokens <- do(nibble.take_until(fn(tok) { tok == NewLine }))
          case tokens {
            [Number(_), Colon] -> {
              use shape <- do(
                nibble.take_exactly(
                  {
                    use _ <- do(nibble.take_if("newline", fn(tok) { tok == NewLine }))
                    nibble.take_map_while(fn(tok) {
                      case tok {
                        Occupied -> Some(True)
                        Empty -> Some(False)
                        _ -> None
                      }
                    })
                  },
                  3
                )
              )
              let area = list.fold(shape, 0, fn(acc, line) {
                acc + list.count(line, fn(a) { a })
              })
              return(Continue(#([Present(shape, area), ..presents], spaces)))
            }
            [Number(w), X, Number(h), Colon, ..present_cnt] -> {
              let present_cnt = list.map(present_cnt, fn(present) {
                let assert Number(present) = present
                present
              })
              return(Continue(#(presents, [Space(w, h, present_cnt), ..spaces])))
            }
            _ -> nibble.fail("could not parse")
          }
        },
      ])
    }
  )

  // parse
  let assert Ok(#(_presents, spaces)) = nibble.run(tokens, parser)

  // PART 1
  // In general, this problem is NP Complete with no generalized solution. AoC
  // can be mean at times, but not that mean. So, we're going to treat each
  // present as a 3x3 grid and count the spaces that can fit those.
  let part1_result = list.fold(spaces, 0, fn(acc, space) {
    let total_squares = { space.w / 3 } * { space.h / 3 }
    let cnt_presents = int.sum(space.presents)
    case cnt_presents <= total_squares {
      True -> acc + 1
      False -> acc
    }
  })
  io.println("Part 1: " <> int.to_string(part1_result))

  Nil
}
