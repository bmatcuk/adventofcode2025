import gleam/dict
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{None, Some}
import nibble.{Break, Continue, do, return}
import nibble/lexer
import simplifile

type Token {
  Blank
  NewLine
  Splitter
  Start
}

/// Upserts the beam count in the beams Dict. If the key (x) exists, beam_cnt
/// is added to it. Otherwise, it is set to beam_cnt.
fn update_beams(beams: dict.Dict(Int, Int), x: Int, beam_cnt: Int) -> dict.Dict(Int, Int) {
  dict.upsert(beams, x, fn(v) {
    case v {
      Some(cnt) -> cnt + beam_cnt
      None -> beam_cnt
    }
  })
}

pub fn main() -> Nil {
  let assert Ok(input) = simplifile.read("input.txt")

  let lexer = lexer.simple([
    lexer.token(".", Blank),
    lexer.token("\n", NewLine),
    lexer.token("^", Splitter),
    lexer.token("S", Start),
  ])

  // tokenize
  let assert Ok(tokens) = lexer.run(input, lexer)

  // parser
  // Returns a tuple where .0 is a count of the number of splits the beam hits,
  // and .1 is a Dict of beams where the keys are the x positions, and the
  // values are the number of ways the beam got there.
  let parser = nibble.loop(
    #(0, dict.new()),
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
          let #(cnt, original_beams) = acc
          use row <- do(nibble.take_until(fn(tok) { tok == NewLine }))
          list.index_fold(row, #(cnt, dict.new()), fn(acc, tok, x) {
            let #(cnt, beams) = acc
            case tok {
              // Blanks pass beams from above, if any
              Blank -> case dict.get(original_beams, x) {
                Ok(beam_cnt) -> #(cnt, update_beams(beams, x, beam_cnt))
                Error(_) -> acc
              }
              NewLine -> acc

              // Splitters create two beams at x-1 and x+1
              Splitter -> case dict.get(original_beams, x) {
                Ok(beam_cnt) -> #(cnt + 1, update_beams(update_beams(beams, x + 1, beam_cnt), x - 1, beam_cnt))
                Error(_) -> acc
              }

              // Start creates a beam.
              Start -> #(cnt, update_beams(beams, x, 1))
            }
          })
          |> Continue()
          |> return()
        },
      ])
    }
  )

  // parse
  let assert Ok(#(split_cnt, beams)) = nibble.run(tokens, parser)

  // PART 1
  // Just a count of the number of splitters that we hit.
  let part1_result = split_cnt
  io.println("Part 1: " <> int.to_string(part1_result))

  // PART 2
  // Just sum the number of ways we reached the bottom.
  let part2_result = dict.values(beams) |> int.sum()
  io.println("Part 2: " <> int.to_string(part2_result))
}
