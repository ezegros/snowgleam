import gleam/erlang
import gleam/int
import gleam/list
import gleam/string
import gleeunit
import gleeunit/should
import snowgleam

pub fn main() {
  gleeunit.main()
}

// gleeunit test functions end in `_test`
pub fn snowgleam_generate_test() {
  let epoch = 1_420_070_400_000
  let worker_id = 20
  let process_id = 30

  let assert Ok(channel) =
    snowgleam.new_generator()
    |> snowgleam.with_epoch(epoch)
    |> snowgleam.with_worker_id(worker_id)
    |> snowgleam.with_process_id(process_id)
    |> snowgleam.start()

  let id = channel |> snowgleam.generate()

  id |> int.to_string() |> string.length() |> should.equal(19)
  let ts = id |> snowgleam.timestamp(epoch)
  should.be_true(ts <= erlang.system_time(erlang.Millisecond))
  id |> snowgleam.worker_id |> should.equal(worker_id)
  id |> snowgleam.process_id |> should.equal(process_id)
}

pub fn snowgleam_generate_multiple_test() {
  let assert Ok(channel) = snowgleam.new_generator() |> snowgleam.start()

  list.range(1, 5000)
  |> list.map(fn(_) { channel |> snowgleam.generate() })
  |> list.unique()
  |> list.length()
  |> should.equal(5000)
}
