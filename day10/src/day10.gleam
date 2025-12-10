import gleam/deque
import gleam/int
import gleam/io
import gleam/list
import gleam/order.{Eq, Gt, Lt}
import gleam/set
import nibble.{Break, Continue, do, return}
import nibble/lexer
import simplifile

type Token {
  StartLights
  EndLights
  StartButton
  EndButton
  StartJoltages
  EndJoltages
  LightOn
  LightOff
  Number(Int)
}

type Button {
  Button(value: Int)
}

type Joltage {
  Joltage(index: Int, bitmask: Int, value: Int)
}

type Machine {
  Machine(lights: Int, buttons: List(Button), joltages: List(Joltage))
}

/// Find the fewest number of button presses to light the lights.
fn find_fewest_button_presses_for_lights(machine: Machine) -> Result(Int, String) {
  let buttons = list.map(machine.buttons, fn(button) { button.value })
  |> set.from_list()

  // queue elements are `#(presses, lights, buttons)`, where `presses` is the
  // number of total button presses, `lights` is the current state of the
  // lights, and `buttons` are the buttons we haven't tried pushing yet.
  let queue = deque.new() |> deque.push_back(#(0, 0, buttons))
  bfs_button_presses_for_lights(queue, machine)
}

/// Breadth First Search over button presses, but we note that a button can
/// never be pressed more than once because it will essentially "undo" itself.
fn bfs_button_presses_for_lights(queue: deque.Deque(#(Int, Int, set.Set(Int))), machine: Machine) -> Result(Int, String) {
  case deque.pop_front(queue) {
    Ok(#(#(presses, lights, _), _)) if lights == machine.lights -> Ok(presses)
    Ok(#(#(presses, lights, remaining_buttons), queue)) ->
      set.to_list(remaining_buttons)
      |> list.fold(queue, fn(queue, button) {
        let buttons = set.drop(remaining_buttons, [button])
        deque.push_back(queue, #(presses + 1, int.bitwise_exclusive_or(lights, button), buttons))
      })
      |> bfs_button_presses_for_lights(machine)
    _ -> Error("Cannot find solution!")
  }
}

/// Find the fewest number of button presses to get the joltages
fn find_fewest_button_presses_for_joltages(machine: Machine) -> Int {
  let buttons = set.from_list(machine.buttons)
  let joltages = list.map(machine.joltages, fn(joltage) { Joltage(..joltage, value: 0) })
  dfs_button_presses_for_joltages(0, buttons, joltages, 999_999, machine)
}

/// Depth first search.
/// Some things to help improve performance:
/// * On each step, sort the joltages and start with the lowest one. For each
///   button that affects that joltage, try pushing the button exactly enough
///   times to max that joltage and recurse. If that didn't work, backtrack to
///   pushing that button one less time, and so on.
/// * On recurse, remove that button entirely from consideration.
/// * Also remove any button that would increment a joltage above the target.
fn dfs_button_presses_for_joltages(presses: Int, buttons: set.Set(Button), joltages: List(Joltage), min_button_presses: Int, machine: Machine) -> Int {
  case int.compare(presses, min_button_presses), set.size(buttons) {
    // not going to get any better than min_button_presses
    Gt, _ | Eq, _ | _, 0 -> min_button_presses

    Lt, _ -> case compare_joltages(joltages, machine.joltages) {
      // this path produced joltages that are too high - skip
      #(Gt, _, _) -> min_button_presses

      // this path produced the correct joltage
      #(Eq, _, _) -> int.min(min_button_presses, presses)

      // haven't finished yet...
      #(Lt, remaining_joltages, mask) -> {
        // remove any buttons that would increment a finished joltage
        let buttons = filter_buttons_masked(buttons, mask)

        // remove any joltages that are zero, then sort
        list.filter(remaining_joltages, fn(joltage) { joltage.value > 0 })
        |> list.sort(fn(a, b) { int.compare(a.value, b.value) })
        |> list.fold(min_button_presses, fn(min_button_presses, joltage) {
          // starting with the lowest remaining joltage, find buttons that will
          // increment that joltage
          filter_buttons_matching(buttons, joltage.bitmask)
          |> set.fold(min_button_presses, fn(min_button_presses, button) {
            // remove that button from consideration
            let buttons = set.drop(buttons, [button])

            // push that button enough times to max the joltage, and then
            // backtrack down to a single push
            list.range(joltage.value, 1)
            |> list.fold(min_button_presses, fn(min_button_presses, add_presses) {
              dfs_button_presses_for_joltages(add_presses + presses, buttons, increment_joltages(joltages, button, add_presses), min_button_presses, machine)
            })
          })
        })
      }
    }
  }
}

/// Compares two joltages and returns three values. The first is an Order:
/// - Lt if all `joltage` values are less than OR equal to the `target` values;
/// - Eq if all `joltage` values are equal to the `target`; otherwise,
/// - Gt if ANY `joltage` value is greater than the `target`.
///
/// The second is a List of Joltages representing how much joltage is left in
/// each position. Note: if the Order is Gt, this value is meaningless.
///
/// The third value is a bit array where a `1` represents a position where the
/// `joltage` value equaled the `target`, `0` otherwise. Note: if the Order is
/// Gt, this value is meaningless.
fn compare_joltages(joltage: List(Joltage), target: List(Joltage)) -> #(order.Order, List(Joltage), Int) {
  case joltage, target {
    [head1, ..rest1], [head2, ..rest2] -> case int.compare(head1.value, head2.value) {
      Lt -> case compare_joltages(rest1, rest2) {
        #(Gt, _, _) -> #(Gt, [], 0)
        #(_, remaining_joltages, num) -> #(Lt, [Joltage(..head2, value: head2.value - head1.value), ..remaining_joltages], num)
      }
      Eq -> {
        let #(order, remaining_joltages, num) = compare_joltages(rest1, rest2)
        #(order, [Joltage(..head2, value: head2.value - head1.value), ..remaining_joltages], int.bitwise_or(num, head2.bitmask))
      }
      Gt -> #(Gt, [], 0)
    }
    [], [] -> #(Eq, [], 0)
    _, _ -> #(Gt, [], 0)
  }
}

fn increment_joltages(joltages: List(Joltage), button: Button, by: Int) -> List(Joltage) {
  list.map(joltages, fn(joltage) {
    case int.bitwise_and(joltage.bitmask, button.value) != 0 {
      True -> Joltage(..joltage, value: joltage.value + by)
      False -> joltage
    }
  })
}

/// Filters a list of buttons, keeping only the ones that match the mask.
fn filter_buttons_matching(buttons: set.Set(Button), mask: Int) -> set.Set(Button) {
  case mask {
    0 -> set.new()
    _ -> set.filter(buttons, fn(button) {
      int.bitwise_and(button.value, mask) != 0
    })
  }
}

/// Filters a list of buttons, removing any match the mask.
fn filter_buttons_masked(buttons: set.Set(Button), mask: Int) -> set.Set(Button) {
  case mask {
    0 -> buttons
    _ -> set.filter(buttons, fn(button) {
      int.bitwise_and(button.value, mask) == 0
    })
  }
}

pub fn main() -> Nil {
  let assert Ok(input) = simplifile.read("input.txt")

  let lexer = lexer.simple([
    lexer.token("[", StartLights),
    lexer.token("]", EndLights),
    lexer.token("(", StartButton),
    lexer.token(")", EndButton),
    lexer.token("{", StartJoltages),
    lexer.token("}", EndJoltages),
    lexer.token("#", LightOn),
    lexer.token(".", LightOff),
    lexer.int(Number),
    lexer.token(",", Nil) |> lexer.ignore(),
    lexer.whitespace(Nil) |> lexer.ignore(),
  ])

  // tokenize
  let assert Ok(tokens) = lexer.run(input, lexer)

  let parser = nibble.loop(
    #(Machine(0, [], []), []),
    fn(acc) {
      let #(machine, list) = acc
      nibble.one_of([
        {
          use _ <- do(nibble.eof())
          return(Break(acc))
        },
        {
          use _ <- do(nibble.take_if("endjoltages", fn(tok) { tok == EndJoltages }))
          return(Continue(#(Machine(0, [], []), [machine, ..list])))
        },
        {
          use _ <- do(nibble.take_if("garbage", fn(tok) { tok == EndLights || tok == EndButton }))
          return(Continue(acc))
        },
        {
          use _ <- do(nibble.take_if("startlights", fn(tok) { tok == StartLights }))
          use lights <- do(nibble.take_until(fn(tok) { tok == EndLights }))
          let lights = list.index_fold(lights, 0, fn(acc, light, idx) {
            case light {
              LightOn -> int.bitwise_or(acc, int.bitwise_shift_left(1, idx))
              _ -> acc
            }
          })
          return(Continue(#(Machine(lights, machine.buttons, machine.joltages), list)))
        },
        {
          use _ <- do(nibble.take_if("startbutton", fn(tok) { tok == StartButton }))
          use positions <- do(nibble.take_until(fn(tok) { tok == EndButton }))
          let value = list.fold(positions, 0, fn(acc, position) {
            let assert Number(position) = position
            int.bitwise_or(acc, int.bitwise_shift_left(1, position))
          })
          return(Continue(#(Machine(machine.lights, [Button(value), ..machine.buttons], machine.joltages), list)))
        },
        {
          use _ <- do(nibble.take_if("startjoltages", fn(tok) { tok == StartJoltages }))
          use joltages <- do(nibble.take_until(fn(tok) { tok == EndJoltages }))
          let joltages = list.index_map(joltages, fn(joltage, idx) {
            let assert Number(joltage) = joltage
            Joltage(idx, int.bitwise_shift_left(1, idx), joltage)
          })
          return(Continue(#(Machine(machine.lights, machine.buttons, joltages), list)))
        },
      ])
    }
  )

  // parse
  let assert Ok(#(_, machines)) = nibble.run(tokens, parser)

  // PART 1
  // A BFS of button mashing until we find the answer.
  let part1_result = list.fold(machines, 0, fn(acc, machine) {
    let assert Ok(fewest_button_presses) = find_fewest_button_presses_for_lights(machine)
    acc + fewest_button_presses
  })
  io.println("Part 1: " <> int.to_string(part1_result))

  // PART 2
  let part2_result = list.fold(machines, 0, fn(acc, machine) {
    echo acc + find_fewest_button_presses_for_joltages(machine)
  })
  io.println("Part 2: " <> int.to_string(part2_result))

  Nil
}
