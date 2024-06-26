//// A module for generating unique IDs using the Twitter Snowflake algorithm.

import gleam/erlang
import gleam/erlang/process
import gleam/int
import gleam/otp/actor
import gleam/result
import gleam/string

/// The default epoch for the generator. Corresponds to the Unix epoch.
pub const default_epoch: Int = 1_288_834_974_657

/// The maximum number of IDs that can be generated in a single millisecond.
const max_index: Int = 4096

/// Type alias for the genarator message subject. It is the actual
/// public interface for the generator and should be used to interact with it.
///
/// # Examples
/// ```gleam
/// import gleam/snowgleam
///
/// pub type Context {
///   Context(generator: snowgleam.Generator)
/// }
///
/// let assert Ok(generator) = snowgleam.new_generator() |> snowgleam.start()
/// let context = Context(generator: generator)
/// let id = context.generator |> snowgleam.generate()
/// ```
pub type Generator =
  process.Subject(Message)

/// The messages that the generator can receive.
pub opaque type Message {
  Generate(reply_with: process.Subject(Int))
}

/// The Snowflake ID generator state.
/// It handles the internal state of the generator and should not be used directly.
pub opaque type State {
  State(epoch: Int, worker_id: Int, process_id: Int, last_ts: Int, index: Int)
}

/// Creates a new Snowflake ID generator with default settings.
pub fn new_generator() -> State {
  State(
    epoch: default_epoch,
    worker_id: 0,
    process_id: 0,
    last_ts: 0,
    index: -1,
  )
}

/// Sets the epoch for the generator.
pub fn with_epoch(state: State, epoch: Int) -> State {
  State(..state, epoch: epoch)
}

/// Sets the worker ID for the generator.
pub fn with_worker_id(state: State, worker_id: Int) -> State {
  State(..state, worker_id: worker_id)
}

/// Sets the process ID for the generator.
pub fn with_process_id(state: State, process_id: Int) -> State {
  State(..state, process_id: process_id)
}

/// Starts the generator.
pub fn start(state: State) -> Result(Generator, String) {
  case state.epoch > erlang.system_time(erlang.Millisecond) {
    True -> Error("epoch must be in the past")
    False -> {
      let state = State(..state, last_ts: state |> get_timestamp)

      state
      |> actor.start(handle_message)
      |> result.map_error(fn(e) {
        "could not start actor: " <> e |> string.inspect()
      })
    }
  }
}

/// Generates a new Snowflake ID.
///
/// # Examples
/// ```gleam
/// import gleam/snowgleam
///
/// let epoch = 1_420_070_400_000
/// let worker_id = 12
/// let process_id = 1
///
/// let assert Ok(generator) =
///   snowgleam.new_generator()
///   |> snowgleam.with_epoch(epoch)
///   |> snowgleam.with_worker_id(worker_id)
///   |> snowgleam.with_process_id(process_id)
///   |> snowgleam.start()
///
/// let id = snowgleam.generate(generator)
/// ```
pub fn generate(state: Generator) -> Int {
  actor.call(state, Generate, 10)
}

/// Extracts the timestamp from a Snowflake ID using the provided epoch.
pub fn timestamp(id: Int, epoch: Int) -> Int {
  id |> int.bitwise_shift_right(22) |> int.add(epoch)
}

/// Extracts the worker ID from a Snowflake ID.
pub fn worker_id(id: Int) -> Int {
  id |> int.bitwise_and(0x3E0000) |> int.bitwise_shift_right(17)
}

/// Extracts the process ID from a Snowflake ID.
pub fn process_id(id: Int) -> Int {
  id |> int.bitwise_and(0x1F000) |> int.bitwise_shift_right(12)
}

/// Actor message handler.
fn handle_message(message: Message, state: State) -> actor.Next(Message, State) {
  case message {
    Generate(reply) -> {
      let state = state |> setup
      let id = state |> generate_id
      actor.send(reply, id)
      actor.continue(state)
    }
  }
}

/// Generates a new Snowflake ID.
fn generate_id(state: State) -> Int {
  int.bitwise_shift_left(state.last_ts, 22)
  |> int.bitwise_or(int.bitwise_shift_left(state.worker_id, 17))
  |> int.bitwise_or(int.bitwise_shift_left(state.process_id, 12))
  |> int.bitwise_or(state.index)
}

/// Sets up the state before generating a new ID.
/// Handles the case where multiple IDs are generated in the same millisecond.  
/// It wait for the next millisecond if the 4096 were already generated.
fn setup(state: State) -> State {
  let timestamp = state |> get_timestamp
  case state {
    State(last_ts: lts, index: i, ..) if lts == timestamp && i < max_index -> {
      State(..state, index: i + 1)
    }
    State(last_ts: lts, ..) if lts == timestamp -> state |> setup
    _ -> State(..state, index: 0, last_ts: timestamp)
  }
}

/// Gets the current timestamp using erlang os:system_time/1.
fn get_timestamp(state: State) -> Int {
  erlang.system_time(erlang.Millisecond) |> int.subtract(state.epoch)
}
