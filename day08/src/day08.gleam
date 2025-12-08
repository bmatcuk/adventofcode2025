import gleam/float
import gleam/dict
import gleam/int
import gleam/io
import gleam/list
import gleam/option
import nibble.{Break, Continue, do, return}
import nibble/lexer
import simplifile

type Token {
  Comma
  NewLine
  Number(Int)
}

type Coordinate {
  Coordinate(x: Int, y: Int, z: Int)
}

/// This function is used with list.fold to calculate the answers. The
/// accumulator is `#(id, id_to_boxes, boxes_to_id)`, where `id` is the next
/// available circuit id, `id_to_boxes` maps circuit ids to the junction boxes
/// that exist in that circuit, and `boxes_to_id` maps junction boxes to their
/// circuit.
fn calculate(
  acc: #(Int, dict.Dict(Int, List(Coordinate)), dict.Dict(Coordinate, Int)),
  pair: #(Coordinate, Coordinate, Float)
) -> #(Int, dict.Dict(Int, List(Coordinate)), dict.Dict(Coordinate, Int)) {
  let #(next_id, id_to_boxes, boxes_to_id) = acc
  let #(box_a, box_b, _) = pair
  case dict.get(boxes_to_id, box_a), dict.get(boxes_to_id, box_b) {
    Error(_), Error(_) -> #(
      next_id + 1,
      dict.insert(id_to_boxes, next_id, [box_a, box_b]),
      dict.insert(dict.insert(boxes_to_id, box_a, next_id), box_b, next_id)
    )
    Ok(circuit), Error(_) -> #(
      next_id,
      dict.upsert(id_to_boxes, circuit, fn(boxes) { [box_b, ..option.unwrap(boxes, [])] }),
      dict.insert(boxes_to_id, box_b, circuit)
    )
    Error(_), Ok(circuit) -> #(
      next_id,
      dict.upsert(id_to_boxes, circuit, fn(boxes) { [box_a, ..option.unwrap(boxes, [])] }),
      dict.insert(boxes_to_id, box_a, circuit)
    )
    Ok(circuit1), Ok(circuit2) -> {
      let assert Ok(circuit2_boxes) = dict.get(id_to_boxes, circuit2)
      #(
        next_id,
        dict.upsert(dict.drop(id_to_boxes, [circuit2]), circuit1, fn(boxes) { list.append(option.unwrap(boxes, []), circuit2_boxes) }),
        list.fold(circuit2_boxes, boxes_to_id, fn(boxes_to_id, circuit2_box) {
          dict.insert(boxes_to_id, circuit2_box, circuit1)
        })
      )
    }
  }
}

pub fn main() -> Nil {
  let assert Ok(input) = simplifile.read("input.txt")

  let lexer = lexer.simple([
    lexer.token(",", Comma),
    lexer.token("\n", NewLine),
    lexer.int(Number),
  ])

  // tokenize
  let assert Ok(tokens) = lexer.run(input, lexer)

  let parser = nibble.loop(
    [],
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
          use row <- do(nibble.take_until(fn(tok) { tok == NewLine }))
          case row {
            [Number(x), Comma, Number(y), Comma, Number(z), .._] -> return(Continue([Coordinate(x, y, z), ..acc]))
            _ -> nibble.fail("cannot parse coordinate")
          }
        },
      ])
    }
  )

  // parse
  let assert Ok(junction_boxes) = nibble.run(tokens, parser)

  // PART 1
  // Find all unique combinations, calculate their distance, and sort. There
  // are 499500 combinations - that's not too bad.
  let pairs_by_distance = list.combinations(junction_boxes, 2)
  |> list.map(fn(junction_boxes) {
    let assert [a, b] = junction_boxes
    let assert Ok(x) = int.power(a.x - b.x, 2.0)
    let assert Ok(y) = int.power(a.y - b.y, 2.0)
    let assert Ok(z) = int.power(a.z - b.z, 2.0)
    let assert Ok(distance) = float.square_root(x +. y +. z)
    #(a, b, distance)
  })
  |> list.sort(fn(a, b) { float.compare(a.2, b.2) })

  // Next, combine the first 1000 and keep track of the circuits they belong to
  let #(first_1000_pairs, remaining_pairs) = list.split(pairs_by_distance, 1000)
  let #(next_id, circuits, boxes_to_id) = list.fold(first_1000_pairs, #(0, dict.new(), dict.new()), calculate)

  // Now, find the three largest circuits and multiply their size
  let part1_result = dict.values(circuits)
  |> list.map(fn(boxes) { list.length(boxes) })
  |> list.sort(fn(a, b) { int.compare(b, a) })
  |> list.take(3)
  |> int.product()
  io.println("Part 1: " <> int.to_string(part1_result))

  // PART 2
  // Continue the calculation until all 1000 junction boxes are part of one
  // large circuit. Keep track of the final pair that made this happen.
  let #(_, final_pair) = list.fold_until(
    remaining_pairs,
    #(#(next_id, circuits, boxes_to_id), #(Coordinate(0, 0, 0), Coordinate(0, 0, 0), 0.0)),
    fn(acc, pair) {
      let #(acc, _) = acc
      let next_acc = calculate(acc, pair)
      case dict.values(next_acc.1) {
        // exactly one circuit...
        [circuit] -> case list.length(circuit) {
          // with all 1000 junction boxes
          1000 -> list.Stop(#(next_acc, pair))
          _ -> list.Continue(#(next_acc, pair))
        }
        _ -> list.Continue(#(next_acc, pair))
      }
    }
  )
  let part2_result = final_pair.0.x * final_pair.1.x
  io.println("Part 2: " <> int.to_string(part2_result))
}
