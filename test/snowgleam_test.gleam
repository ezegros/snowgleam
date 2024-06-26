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

  let assert Ok(generator) =
    snowgleam.new_generator()
    |> snowgleam.with_epoch(epoch)
    |> snowgleam.with_worker_id(worker_id)
    |> snowgleam.with_process_id(process_id)
    |> snowgleam.start()

  let id = generator |> snowgleam.generate()

  id |> int.to_string() |> string.length() |> should.equal(19)
  let ts = id |> snowgleam.timestamp(epoch)
  should.be_true(ts <= erlang.system_time(erlang.Millisecond))
  id |> snowgleam.worker_id |> should.equal(worker_id)
  id |> snowgleam.process_id |> should.equal(process_id)

  generator |> snowgleam.stop()
}

pub fn snowgleam_generate_multiple_test() {
  let assert Ok(generator) = snowgleam.new_generator() |> snowgleam.start()

  list.range(1, 5000)
  |> list.map(fn(_) { generator |> snowgleam.generate() })
  |> list.unique()
  |> list.length()
  |> should.equal(5000)

  generator |> snowgleam.stop()
}

pub fn snowgleam_generate_future_epoch_test() {
  let epoch = erlang.system_time(erlang.Millisecond) + 1000

  snowgleam.new_generator()
  |> snowgleam.with_epoch(epoch)
  |> snowgleam.start()
  |> should.be_error()
}

pub fn snowgeam_generate_lazy_test() {
  let assert Ok(generator) = snowgleam.new_generator() |> snowgleam.start()

  let id = generator |> snowgleam.generate_lazy()

  id |> int.to_string() |> string.length() |> should.equal(19)
  let ts = id |> snowgleam.timestamp(snowgleam.default_epoch)
  should.be_true(ts <= erlang.system_time(erlang.Millisecond))

  list.range(1, 5000)
  |> list.map(fn(_) { generator |> snowgleam.generate_lazy() })
  |> list.unique()
  |> list.length()
  |> should.equal(5000)

  generator |> snowgleam.stop()
}

pub fn snowgleam_generate_lazy_with_set_timestamp_test() {
  let assert Ok(generator) =
    snowgleam.new_generator()
    |> snowgleam.with_timestamp(1_719_440_739_000)
    |> snowgleam.start()

  let id = generator |> snowgleam.generate_lazy()

  id |> int.to_string() |> string.length() |> should.equal(19)
  should.equal(id |> int.to_string(), "1806091479806902272")

  generator |> snowgleam.stop()
}

pub fn snowgleam_generate_many_test() {
  let assert Ok(generator) = snowgleam.new_generator() |> snowgleam.start()

  let ids = generator |> snowgleam.generate_many(5000)

  ids |> list.unique() |> list.length() |> should.equal(5000)
  let assert Ok(last_id) = ids |> list.last()

  last_id |> int.to_string() |> string.length() |> should.equal(19)
  should.be_true(
    last_id |> snowgleam.timestamp(snowgleam.default_epoch)
    <= erlang.system_time(erlang.Millisecond),
  )

  generator |> snowgleam.stop()
}

pub fn snowgleam_generate_many_lazy_test() {
  let time = 1_719_440_739_000

  let assert Ok(generator) =
    snowgleam.new_generator()
    |> snowgleam.with_timestamp(time)
    |> snowgleam.with_worker_id(20)
    |> snowgleam.with_process_id(30)
    |> snowgleam.start()

  let ids = generator |> snowgleam.generate_many_lazy(5000)

  ids |> list.unique() |> list.length() |> should.equal(5000)
  let assert Ok(last_id) = ids |> list.last()

  last_id |> int.to_string() |> string.length() |> should.equal(19)
  should.equal(
    last_id |> snowgleam.timestamp(snowgleam.default_epoch),
    time + 1,
  )
  should.equal(last_id |> int.to_string(), "1806091479813841799")

  generator |> snowgleam.stop()
}
