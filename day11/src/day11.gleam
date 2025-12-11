import gleam/deque
import gleam/dict
import gleam/int
import gleam/io
import gleam/list
import gleam/option
import gleam/result
import gleam/set
import nibble.{Break, Continue, do, return}
import nibble/lexer
import simplifile

type Token {
  Colon
  Device(String)
  NewLine
}

type Machine {
  Machine(name: String, outputs: List(String))
}

/// Perform a topological sort on the graph
fn topological_sort(
  sort_queue: deque.Deque(String),
  machines: dict.Dict(String, Machine),
  indegree: dict.Dict(String, Int),
  result_queue: deque.Deque(String)
) -> deque.Deque(String) {
  case deque.pop_front(sort_queue) {
    Ok(#(node, sort_queue)) -> {
      // add this node to the result_queue
      let result_queue = deque.push_back(result_queue, node)

      // then, for each output...
      let machine = result.unwrap(dict.get(machines, node), Machine(node, []))
      let #(sort_queue, indegree) = list.fold(
        machine.outputs,
        #(sort_queue, indegree),
        fn(acc, output) {
          // decrement the indegree of the output node
          // if it is now zero, add it to the sort_queue
          let #(sort_queue, indegree) = acc
          let assert Ok(degree) = dict.get(indegree, output)
          case degree {
            1 -> #(deque.push_back(sort_queue, output), dict.insert(indegree, output, 0))
            _ -> #(sort_queue, dict.insert(indegree, output, degree - 1))
          }
        }
      )
      topological_sort(sort_queue, machines, indegree, result_queue)
    }
    _ -> result_queue
  }
}

/// Compute the number of ways to reach each node. `queue` is assumed to be a
/// topologically sorted list of graph nodes, and `ways` is assumed to be
/// initialized with a `1` for the start node.
fn compute_ways_to_reach_nodes(
  queue: deque.Deque(String),
  machines: dict.Dict(String, Machine),
  ways: dict.Dict(String, Int)
) -> dict.Dict(String, Int) {
  case deque.pop_front(queue) {
    Ok(#(node, queue)) -> {
      let machine = result.unwrap(dict.get(machines, node), Machine(node, []))
      let ways_to_node = result.unwrap(dict.get(ways, node), 0)
      let ways = list.fold(machine.outputs, ways, fn(ways, output) {
        dict.upsert(ways, output, fn(num) {
          option.unwrap(num, 0) + ways_to_node
        })
      })
      compute_ways_to_reach_nodes(queue, machines, ways)
    }
    _ -> ways
  }
}

pub fn main() -> Nil {
  let assert Ok(input) = simplifile.read("input.txt")

  let lexer = lexer.simple([
    lexer.token(":", Colon),
    lexer.identifier("[a-z]", "[a-z]", set.new(), Device),
    lexer.token("\n", NewLine),
    lexer.spaces(Nil) |> lexer.ignore(),
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
          use tokens <- do(nibble.take_until(fn(tok) { tok == NewLine }))
          case tokens {
            [Device(name), Colon, ..outputs] -> {
              let outputs = list.map(outputs, fn(output) {
                let assert Device(output) = output
                output
              })
              return(Continue([Machine(name, outputs), ..acc]))
            }
            _ -> nibble.fail("line didn't match pattern")
          }
        },
      ])
    }
  )

  // parse
  let assert Ok(machines) = nibble.run(tokens, parser)

  // build the graph
  // `indegree` is a Dict of node names to the number of nodes that connect
  // "in" to this node.
  let indegree = list.map(machines, fn(machine) { #(machine.name, 0) }) |> dict.from_list()
  let indegree = list.fold(machines, indegree, fn(indegree, machine) {
    list.fold(machine.outputs, indegree, fn(indegree, output) {
      dict.upsert(indegree, output, fn(cnt) {
        option.unwrap(cnt, 0) + 1
      })
    })
  })

  // convert machines to Dict
  let machines = list.map(machines, fn(machine) { #(machine.name, machine) }) |> dict.from_list()

  // use Kahn's algorithm to perform a topological sort
  // initialize the queue with nodes that have no way "in"
  let queue = dict.to_list(indegree)
  |> list.filter(fn(degree) { degree.1 == 0 })
  |> list.map(fn(degree) { degree.0 })
  |> deque.from_list()

  // sort the nodes
  let topo_queue = topological_sort(queue, machines, indegree, deque.new())

  // compute the number of ways to each node from node "you"
  let ways = compute_ways_to_reach_nodes(topo_queue, machines, dict.from_list([#("you", 1)]))

  // PART 1
  // The answer is the number of ways to the last `out` node.
  let assert Ok(part1_result) = dict.get(ways, "out")
  io.println("Part 1: " <> int.to_string(part1_result))

  // PART 2
  // The product of the number of ways from "svr" to "dac", "dac" to "fft", and
  // "fft" to "out" is the number of ways from "svr" to "out", going through
  // "dac" and then "fft". Add that to the product of the number of ways from
  // "svr" to "fft", "fft" to "dac", and "dac" to "out" gives us the total ways
  // from "svr" to "out", through both "fft" and "dac" in any order.
  let paths = [
    [#("svr", "dac"), #("dac", "fft"), #("fft", "out")],
    [#("svr", "fft"), #("fft", "dac"), #("dac", "out")],
  ]
  let part2_result = list.fold(paths, 0, fn(acc, paths) {
    list.fold(paths, 1, fn(acc, path) {
      let #(source, destination) = path
      let ways = compute_ways_to_reach_nodes(topo_queue, machines, dict.from_list([#(source, 1)]))
      let assert Ok(cnt) = dict.get(ways, destination)
      acc * cnt
    }) + acc
  })
  io.println("Part 2: " <> int.to_string(part2_result))
}
