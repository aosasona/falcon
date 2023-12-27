import gleeunit
import gleeunit/should
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import facquest.{extract_headers, merge_opts, new}
import facquest/core.{type Opts, ClientOptions, Headers, Url}
import facquest/hackney.{Timeout}

pub fn main() {
  gleeunit.main()
}

fn extract_timeout(
  opts: List(hackney.HackneyOption),
  state: List(Option(Int)),
) -> List(Option(Int)) {
  case opts {
    [Timeout(t), ..rest] -> {
      extract_timeout(rest, list.concat([state, [Some(t)]]))
    }
    _ -> state
  }
}

fn extract_timeouts(opts: Opts) -> List(Option(Int)) {
  opts
  |> list.filter(fn(opt) {
    // Extract all client options
    case opt {
      ClientOptions(_) -> True
      _ -> False
    }
  })
  |> list.map(fn(opt) {
    case opt {
      ClientOptions(client_options) -> extract_timeout(client_options, [])
      _ -> []
    }
  })
  |> list.flatten
}

pub fn merge_opts_test() {
  let new_opts =
    new(
      Url("http://example.com"),
      [#("x-client-default", "default")],
      Some(15_000),
    )
    |> merge_opts([Headers([#("x-test", "test")])])

  new_opts
  |> extract_headers
  |> should.equal([#("x-client-default", "default"), #("x-test", "test")])

  new_opts
  |> extract_timeouts
  |> list.first
  |> should.equal(Ok(Some(15_000)))

  // Test that all headers are merged even if timeout is not set
  let new_opts =
    new(Url("http://example.com"), [#("a", "b"), #("c", "d")], None)
    |> merge_opts([Headers([#("e", "f")]), Headers([#("g", "h")])])

  new_opts
  |> extract_headers
  |> should.equal([#("a", "b"), #("c", "d"), #("e", "f"), #("g", "h")])

  new_opts
  |> extract_timeouts
  |> list.first
  |> result.unwrap(None)
  |> should.equal(None)

  // Test that all timeouts are kept if set
  let new_opts =
    new(Url("http://example.com"), [], Some(15_000))
    |> merge_opts([ClientOptions([Timeout(30_000)])])

  new_opts
  |> extract_headers
  |> should.equal([])

  new_opts
  |> extract_timeouts
  |> should.equal([Some(15_000), Some(30_000)])

  // Test that the last timeout provided by the user in the request itself is used instead of the default
  new(Url("http://example.com"), [], Some(15_000))
  |> merge_opts([ClientOptions([Timeout(30_000), Timeout(10_000)])])
  |> extract_timeouts
  |> list.last
  |> should.equal(Ok(Some(10_000)))
}
