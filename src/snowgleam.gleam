//// A module for generating unique IDs using the Twitter Snowflake algorithm.

import gleam/erlang
import gleam/erlang/process
import gleam/int
import gleam/otp/actor
import gleam/result
import gleam/string

/// The default epoch for the generator. Corresponds to the Unix epoch.
pub const default_epoch: Int = 31_546_800

/// The maximum number of IDs that can be generated in a single millisecond.
const max_index: Int = 4096

/// The messages that the generator actor can receive.
pub opaque type Message {
  Generate(reply_with: process.Subject(Int))
}

/// The Snowflake ID generator.
/// This is not meant to be used directly but with the provided builder functions.
pub opaque type Generator {
  Generator(
    epoch: Int,
    worker_id: Int,
    process_id: Int,
    last_ts: Int,
    index: Int,
  )
}

/// Creates a new Snowflake ID generator with default settings.
pub fn new_generator() -> Generator {
  Generator(
    epoch: default_epoch,
    worker_id: 0,
    process_id: 0,
    last_ts: 0,
    index: -1,
  )
}

/// Sets the epoch for the generator.
pub fn with_epoch(generator: Generator, epoch: Int) -> Generator {
  Generator(..generator, epoch: epoch)
}

/// Sets the worker ID for the generator.
pub fn with_worker_id(generator: Generator, worker_id: Int) -> Generator {
  Generator(..generator, worker_id: worker_id)
}

/// Sets the process ID for the generator.
pub fn with_process_id(generator: Generator, process_id: Int) -> Generator {
  Generator(..generator, process_id: process_id)
}

/// Starts the generator.
pub fn start(generator: Generator) -> Result(process.Subject(Message), String) {
  case generator.epoch > erlang.system_time(erlang.Millisecond) {
    True -> Error("epoch must be in the past")
    False -> {
      let generator =
        Generator(..generator, last_ts: generator |> get_timestamp)

      generator
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
///
/// let assert Ok(generator) =
///   snowgleam.new_generator()
///   |> snowgleam.with_epoch(epoch)
///   |> snowgleam.with_worker_id(worker_id)
///   |> snowgleam.start()
///
/// let id = snowgleam.generate(generator)
/// ```
pub fn generate(channel: process.Subject(Message)) -> Int {
  actor.call(channel, Generate, 10)
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
fn handle_message(
  message: Message,
  generator: Generator,
) -> actor.Next(Message, Generator) {
  case message {
    Generate(reply) -> {
      let generator = generator |> setup
      let id = generator |> generate_id
      actor.send(reply, id)
      actor.continue(generator)
    }
  }
}

/// Generates a new Snowflake ID.
fn generate_id(generator: Generator) -> Int {
  int.bitwise_shift_left(generator.last_ts, 22)
  |> int.bitwise_or(int.bitwise_shift_left(generator.worker_id, 17))
  |> int.bitwise_or(int.bitwise_shift_left(generator.process_id, 12))
  |> int.bitwise_or(generator.index)
}

/// Sets up the generator before generating a new ID.
/// Handles the case where multiple IDs are generated in the same millisecond.  
/// It wait for the next millisecond if the 4096 were already generated.
fn setup(generator: Generator) -> Generator {
  let timestamp = generator |> get_timestamp
  case generator {
    Generator(last_ts: lts, index: i, ..) if lts == timestamp && i < max_index -> {
      Generator(..generator, index: i + 1)
    }
    Generator(last_ts: lts, ..) if lts == timestamp -> generator |> setup
    _ -> Generator(..generator, index: 0, last_ts: timestamp)
  }
}

/// Gets the current timestamp using erlang os:system_time/1.
fn get_timestamp(generator: Generator) -> Int {
  erlang.system_time(erlang.Millisecond) |> int.subtract(generator.epoch)
}
