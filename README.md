# Snowgleam ❄️

Gleam version of the Twitter's [snowflake](https://github.com/twitter-archive/snowflake/tree/snowflake-2010) format for unique IDs.
Although it is more inspired by the Discord [implementation](https://discord.com/developers/docs/reference#snowflakes) of the snowflake format.

They are great for generating unique IDs in a distributed system.

```sh
gleam add snowgleam
```
And then use it in your project like this:
```gleam
import gleam/io
import gleam/int
import snowgleam

pub fn main() {
  let assert Ok(generator) = snowgleam.new_generator() |> snowgleam.start()
  let id = generator |> snowgleam.generate()
  io.println("Generated ID: " <> id |> int.to_string())
}
```

Further documentation can be found at <https://hexdocs.pm/snowgleam>.
