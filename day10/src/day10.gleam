import gleam/deque
import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/result
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
  Button(bitmask: Int, positions: List(Int))
}

type Joltage {
  Joltage(index: Int, bitmask: Int, value: Int)
}

type Machine {
  Machine(lights: Int, buttons: List(Button), joltages: List(Joltage))
}

/// Find the fewest number of button presses to light the lights.
fn find_fewest_button_presses_for_lights(machine: Machine) -> Result(Int, String) {
  let buttons = list.map(machine.buttons, fn(button) { button.bitmask })
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

/// A "fudge" factor to account for floating point inaccuracies
const epsilon = 1.0e-6
const nepsilon = -1.0e-6

/// Represents a linear expression in vector form
type LinearExpression {
  LinearExpression(coefficients: List(Float), constant: Float)
}

/// Each button is a variable
type Variable {
  Variable(free: Bool, expression: LinearExpression, value: Int, max_value: Int)
}

/// Find the fewest number of button presses to get the joltages. Based on:
/// https://codeberg.org/siddfinch/aoc2025/src/branch/trunk/src/day10/Factory.pas
fn find_fewest_button_presses_for_joltages(machine: Machine) -> Int {
  let button_len = list.length(machine.buttons)

  // Each button is a variable initialized with a vector of 0's
  let variables = list.map(machine.buttons, fn(button) {
    // The `max_value` of a variable cannot exceed the minimum joltage that the
    // button affects.
    let max_value = list.fold(machine.joltages, 999_999, fn(acc, joltage) {
      case int.bitwise_and(button.bitmask, joltage.bitmask) != 0 {
        True -> int.min(acc, joltage.value)
        False -> acc
      }
    })
    let expression = LinearExpression(list.repeat(0.0, button_len), 0.0)
    Variable(True, expression, 0, max_value)
  })

  // Each joltage has an equation where coefficients correspond to buttons: a 1
  // if the button affects that joltage, or a 0 otherwise.
  let equations = list.map(machine.joltages, fn(joltage) {
    let coefficients = list.map(machine.buttons, fn(button) {
      case int.bitwise_and(button.bitmask, joltage.bitmask) != 0 {
        True -> 1.0
        False -> 0.0
      }
    })
    LinearExpression(coefficients, int.to_float(0 - joltage.value))
  })

  // Gaussian Elimination
  // The algo will reduce the above equations into row-echelon form, reducing
  // the number of "free" variables, and, thus, the size of the search space
  // that we need to consider to find the answer.
  let #(_equations, variables) = list.zip(variables, list.range(0, list.length(variables)))
  |> list.map_fold(equations, fn(equations, variable_with_idx) {
    let #(variable, idx) = variable_with_idx
    let equation = list.find(equations, fn(equation) {
      case list.drop(equation.coefficients, idx) {
        [coefficient, .._] if coefficient >. epsilon || coefficient <. nepsilon -> True
        _ -> False
      }
    })
    case equation {
      Ok(equation) -> {
        let expression = extract_variable(equation, idx)
        let new_equations = list.map(equations, substitute_variable(_, idx, expression))
        let new_variable = Variable(..variable, free: False, expression: expression)
        #(new_equations, new_variable)
      }
      _ -> #(equations, variable)
    }
  })

  // Evaluate variables in reverse. Technically, gaussian elimination can fail
  // to find a solution. Luckily, it works for all of our input.
  let assert Ok(result) = evaluate_variables(list.reverse(variables), [], button_len, 0)
  result
}

/// Extract a variable from the given LinearExpression
fn extract_variable(expression: LinearExpression, idx: Int) -> LinearExpression {
  // A is the negated coefficient at the index
  let assert Ok(a) = list.first(list.drop(expression.coefficients, idx))
  |> result.map(float.negate)

  // Update each coefficient by dividing by A - also update the constant
  list.index_map(expression.coefficients, fn(coefficient, coeff_idx) {
    case coeff_idx == idx {
      True -> 0.0
      False -> coefficient /. a
    }
  })
  |> LinearExpression(expression.constant /. a)
}

/// Substitute a variable into a LinearExpression by basically multiplying the
/// equation with the Variable's vector.
fn substitute_variable(equation: LinearExpression, idx: Int, expression: LinearExpression) -> LinearExpression {
  let assert Ok(a) = list.first(list.drop(equation.coefficients, idx))
  list.zip(equation.coefficients, expression.coefficients)
  |> list.index_map(fn(coefficients, coeff_idx) {
    case coeff_idx == idx {
      True -> 0.0
      False -> coefficients.0 +. a *. coefficients.1
    }
  })
  |> LinearExpression(equation.constant +. a *. expression.constant)
}

/// Evaluate variables to minimize button presses
fn evaluate_variables(variables: List(Variable), values: List(Float), remaining_vals: Int, presses: Int) -> Result(Int, Nil) {
  case variables {
    // for free variables, try all values from 0 to max_value inclusive
    [variable, ..variables] if variable.free -> list.fold(list.range(0, variable.max_value), Error(Nil), fn(minimum, value) {
      case minimum, check_evaluation(variables, int.to_float(value), values, remaining_vals, presses) {
        Ok(minimum), Ok(presses) -> Ok(int.min(minimum, presses))   // have a value, and got a new value: take minimum
        Ok(_), Error(_) -> minimum                                  // have a value, but failed to find a new one: keep value
        Error(_), Ok(presses) -> Ok(presses)                        // don't have value, found a new one: take new one
        err, _ -> err                                               // don't have value, and no new one: return error
      }
    })

    // for bound variables, multiply the coefficients by values
    [variable, ..variables] -> {
      // pad the beginning of values with zeros so it's the same length as the
      // coefficient list
      let padded_values = list.append(list.repeat(0.0, remaining_vals), values)

      // multiply the `values` vector with the variable's expression
      let value = list.fold(list.zip(padded_values, variable.expression.coefficients), variable.expression.constant, fn(acc, coefficients) {
        acc +. coefficients.0 *. coefficients.1
      })
      check_evaluation(variables, value, values, remaining_vals, presses)
    }

    // no more variables to evaluate, so return presses
    _ -> Ok(presses)
  }
}

/// Checks if the value we calculated is valid. If it is, continue the
/// recursion. Otherwise, return an error to end the recursion.
fn check_evaluation(variables: List(Variable), value: Float, values: List(Float), remaining_vals: Int, presses: Int) -> Result(Int, Nil) {
  let rounded_value = float.round(value)
  case float.absolute_value(value -. int.to_float(rounded_value)) {
    // if any of these conditions are true, we can quit this evaluation
    diff if value <. nepsilon || diff >. epsilon || rounded_value < 0 -> Error(Nil)

    // otherwise, continue with the recursion
    _ -> evaluate_variables(variables, [value, ..values], remaining_vals - 1, presses + rounded_value)
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
          let positions = list.map(positions, fn(position) {
            let assert Number(position) = position
            position
          })
          let bitmask = list.fold(positions, 0, fn(acc, position) {
            int.bitwise_or(acc, int.bitwise_shift_left(1, position))
          })
          return(Continue(#(Machine(machine.lights, [Button(bitmask, positions), ..machine.buttons], machine.joltages), list)))
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
    acc + find_fewest_button_presses_for_joltages(machine)
  })
  io.println("Part 2: " <> int.to_string(part2_result))
}
