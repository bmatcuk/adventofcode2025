import gleam/int
import gleam/io
import gleam/list
import nibble.{Break, Continue, do, return}
import nibble/lexer
import simplifile

type Token {
  Comma
  NewLine
  Number(Int)
}

type Coordinate {
  Coordinate(x: Int, y: Int)
}

type Square {
  Square(vertex1: Coordinate, vertex2: Coordinate, area: Int)
}

fn intersects_horizontal(square: Square, sides: List(#(Coordinate, Coordinate))) -> Bool {
  case sides {
    // side is above square
    [side, ..rest] if side.0.y <= square.vertex1.y && side.0.y <= square.vertex2.y -> intersects_horizontal(square, rest)

    // side is below square
    [side, .._] if side.0.y >= square.vertex1.y && side.0.y >= square.vertex2.y -> False

    // side is vertically inside the square
    [side, ..rest] -> case int.min(side.0.x, side.1.x), int.max(side.0.x, side.1.x), int.min(square.vertex1.x, square.vertex2.x), int.max(square.vertex1.x, square.vertex2.x) {
      // side is to the left or right of the square
      min_side_x, max_side_x, min_square_x, max_square_x if max_side_x <= min_square_x || min_side_x >= max_square_x -> intersects_horizontal(square, rest)

      // side is inside the square
      _, _, _, _ -> True
    }
    _ -> False
  }
}

fn intersects_vertical(square: Square, sides: List(#(Coordinate, Coordinate))) -> Bool {
  case sides {
    // side is left of square
    [side, ..rest] if side.0.x <= square.vertex1.x && side.0.x <= square.vertex2.x -> intersects_vertical(square, rest)

    // side is right of square
    [side, .._] if side.0.x >= square.vertex1.x && side.0.x >= square.vertex2.x -> False

    // side is horizontally inside the square
    [side, ..rest] -> case int.min(side.0.y, side.1.y), int.max(side.0.y, side.1.y), int.min(square.vertex1.y, square.vertex2.y), int.max(square.vertex1.y, square.vertex2.y) {
      // side is above or below the square
      min_side_y, max_side_y, min_square_y, max_square_y if max_side_y <= min_square_y || min_side_y >= max_square_y -> intersects_vertical(square, rest)

      // side is inside the square
      _, _, _, _ -> True
    }
    _ -> False
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
            [Number(x), Comma, Number(y), .._] -> return(Continue([Coordinate(x, y), ..acc]))
            _ -> nibble.fail("cannot parse coordinate")
          }
        },
      ])
    }
  )

  // parse
  let assert Ok(red_tiles) = nibble.run(tokens, parser)

  // Find all squares by combining all tile coordinates, calculate their areas,
  // and sort by area, descending.
  let sorted_squares = list.combination_pairs(red_tiles)
  |> list.map(fn(pair) {
    let #(a, b) = pair
    Square(a, b, { int.absolute_value(a.x - b.x) + 1 } * { int.absolute_value(a.y - b.y) + 1 })
  })
  |> list.sort(fn(a, b) { int.compare(b.area, a.area) })

  // PART 1
  // Answer is the first square
  let assert Ok(Square(_, _, part1_result)) = list.first(sorted_squares)
  io.println("Part 1: " <> int.to_string(part1_result))

  // PART 2
  // Visualizing the data, it appears like some sort of diamond shape, but with
  // a large cut through most of the center. So, we can simplify our solution,
  // but this solution probably wouldn't work in a general case. We'll generate
  // a list of sides, and then separate those into horizontal and vertical.
  // `window_by_2` gets us most of the sides, but we also need to add the side
  // created by the first and last points. We'll also sort each list to make
  // searching them a _little_ faster. We don't have a binary search method,
  // but we can stop searching when we find a side greater than our test case.
  let assert Ok(first) = list.first(red_tiles)
  let assert Ok(last) = list.last(red_tiles)
  let #(horizontal_sides, vertical_sides) = list.window_by_2(red_tiles)
  |> list.prepend(#(last, first))
  |> list.partition(fn(side) { side.0.y == side.1.y })
  let horizontal_sides = list.sort(horizontal_sides, fn(a, b) { int.compare(a.0.y, b.0.y) })
  let vertical_sides = list.sort(vertical_sides, fn(a, b) { int.compare(a.0.x, b.0.x) })

  // Now, starting with the largest square, we'll search until we find a square
  // that has no sides that are inside the square.
  let assert Ok(Square(_, _, part2_result)) = list.find(sorted_squares, fn(square) {
    !intersects_horizontal(square, horizontal_sides) && !intersects_vertical(square, vertical_sides)
  })
  io.println("Part 2: " <> int.to_string(part2_result))
}
