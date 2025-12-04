import gleam/dict
import gleam/int
import gleam/io
import gleam/list
import nibble.{Break, Continue, do, return}
import nibble/lexer
import simplifile

type Token {
  Paper
  Empty
  NewLine
}

fn remove_rolls(rolls: dict.Dict(#(Int, Int), Int)) -> Int {
  // split into rolls to remove (<4 neighbors) and remaining rolls
  let #(rolls_to_remove, remaining_rolls) = dict.to_list(rolls)
  |> list.partition(fn(roll) { roll.1 < 4 })

  // if there are no more rolls to remove, we're done.
  case rolls_to_remove {
    [] -> 0
    _ -> {
      // otherwise, decrement neighbors and recurse
      let remaining_rolls = dict.from_list(remaining_rolls)
      let cnt = list.fold(rolls_to_remove, remaining_rolls, fn(rolls, pos) {
        let #(x, y) = pos.0
        list.range(x - 1, x + 1)
        |> list.fold(rolls, fn(rolls, x) {
          list.range(y - 1, y + 1)
          |> list.fold(rolls, fn(rolls, y) {
            let key = #(x, y)
            case dict.get(rolls, key) {
              Ok(value) -> dict.insert(rolls, key, value - 1)
              Error(_) -> rolls
            }
          })
        })
      })
      |> remove_rolls()

      list.length(rolls_to_remove) + cnt
    }
  }
}

pub fn main() -> Nil {
  let assert Ok(input) = simplifile.read("input.txt")

  let lexer = lexer.simple([
    lexer.token("@", Paper),
    lexer.token(".", Empty),
    lexer.token("\n", NewLine),
  ])

  // tokenize
  let assert Ok(tokens) = lexer.run(input, lexer)

  // parser returns a List(#(x,y)) of all the positions that have a paper roll
  let parser = nibble.loop(
    #(0, []),
    fn(acc) {
      nibble.one_of([
        {
          use _ <- do(nibble.eof())
          return(Break(acc))
        },
        {
          use _ <- do(nibble.take_if("newline", fn(tok) { tok == NewLine }))
          return(Continue(acc))
        },
        {
          let #(y, list) = acc
          use row <- do(nibble.take_until(fn(tok) { tok == NewLine }))
          list.index_fold(row, list, fn(list, tok, x) {
            case tok {
              NewLine -> list
              Empty -> list
              Paper -> [#(x, y), ..list]
            }
          })
          |> fn(list) { Continue(#(y + 1, list)) }
          |> return()
        },
      ])
    }
  )

  // parse
  let assert Ok(#(_, list)) = nibble.run(tokens, parser)

  // now we'll create a dict where keys are #(x,y) of positions with rolls of
  // paper, and values are how many neighboring rolls there are
  let rolls = list.length(list)
  |> list.repeat(0, _)
  |> list.zip(list, _)
  |> dict.from_list()
  |> list.fold(list, _, fn(rolls, pos) {
    dict.upsert(rolls, pos, fn(_) {
      // start cnt at -1 because we'll end up counting ourselves
      let #(x, y) = pos
      list.range(x - 1, x + 1)
      |> list.fold(-1, fn(cnt, x) {
        list.range(y - 1, y + 1)
        |> list.fold(cnt, fn(cnt, y) {
          case dict.has_key(rolls, #(x, y)) {
            True -> cnt + 1
            False -> cnt
          }
        })
      })
    })
  })

  // PART 1
  // Just count any roll with <4 neighbors
  let part1_result = dict.values(rolls)
  |> list.count(fn(cnt) { cnt < 4 })
  io.println("Part 1: " <> int.to_string(part1_result))

  // PART 2
  let part2_result = remove_rolls(rolls)
  io.println("Part 2: " <> int.to_string(part2_result))
}
