import falcon/core.{
  type Opts, type Pairs, type Target, type Url, ClientOptions, Headers, Url,
}
import gleam/bool
import gleam/list
import gleam/string
import gleam/result
import gleam/http.{type Method, Delete, Get, Patch, Post, Put}
import gleam/option.{type Option, None, Some}
import falcon/hackney.{Timeout}

// Re-export the core types for convenience
pub type FalconResponse(a) =
  core.FalconResponse(a)

pub type FalconError =
  core.FalconError

pub type ResultResponse(a) =
  core.ResultResponse(a)

pub const default_timeout: Option(Int) = Some(15_000)

pub opaque type Client {
  Client(base_url: Url, headers: Pairs, timeout: Option(Int))
}

pub fn new(
  base_url base_url: Url,
  headers headers: Pairs,
  timeout timeout: Option(Int),
) -> Client {
  Client(base_url: base_url, headers: headers, timeout: timeout)
}

fn filter_opts(opts: Opts, keep_headers keep_headers: Bool) -> Opts {
  opts
  |> list.filter(fn(opt) {
    use <- bool.guard(when: keep_headers, return: case opt {
      Headers(_) -> True
      _ -> False
    })

    case opt {
      Headers(_) -> False
      _ -> True
    }
  })
}

pub fn extract_headers(opts: Opts) -> List(#(String, String)) {
  opts
  |> list.map(fn(opt) {
    case opt {
      Headers(headers) -> headers
      _ -> []
    }
  })
  |> list.concat
}

/// This is used internally to merge the client options with the request options, it is only exposed for testing purposes
pub fn merge_opts(client: Client, opts: Opts) -> Opts {
  let new_opts = case client.timeout {
    Some(timeout) -> {
      // If there is a timeout in the client options, we want to ignore it if there is a timeout in the request options
      let has_timeout =
        list.find(opts, fn(opt) {
          case opt {
            ClientOptions([Timeout(_)]) -> True
            _ -> False
          }
        })
        |> result.is_ok

      use <- bool.guard(when: has_timeout, return: opts)
      list.concat([[ClientOptions([Timeout(timeout)])], opts])
    }
    None -> opts
  }

  let headers =
    new_opts
    |> filter_opts(keep_headers: True)
    |> extract_headers
    |> normalise_headers
    |> fn(headers) { list.concat([client.headers, headers]) }

  // Remove all headers from the original list and replace with the merged list
  new_opts
  |> filter_opts(keep_headers: False)
  |> fn(new_opts) { list.concat([[Headers(headers)], new_opts]) }
}

/// A way to send a request with a client, you would normally want to use the convenience functions (get, post, put, patch, delete) instead
pub fn send(
  client client: Client,
  method method: Method,
  path path: String,
  expecting target: Target(a),
  options opts: Opts,
) -> ResultResponse(a) {
  client.base_url
  |> core.append_path(path)
  |> core.send(
    method: method,
    expecting: target,
    options: merge_opts(client, opts),
  )
}

pub fn get(
  client client: Client,
  path path: String,
  expecting target: Target(a),
  options opts: Opts,
) -> ResultResponse(a) {
  client
  |> send(Get, path, target, opts)
}

pub fn post(
  client client: Client,
  path path: String,
  body body: String,
  expecting target: Target(a),
  options opts: Opts,
) -> ResultResponse(a) {
  client
  |> send(Post, path, target, [core.to_body(body), ..opts])
}

pub fn put(
  client client: Client,
  path path: String,
  body body: String,
  expecting target: Target(a),
  options opts: Opts,
) -> ResultResponse(a) {
  client
  |> send(Put, path, target, [core.to_body(body), ..opts])
}

pub fn patch(
  client client: Client,
  path path: String,
  body body: String,
  expecting target: Target(a),
  options opts: Opts,
) -> ResultResponse(a) {
  client
  |> send(Patch, path, target, [core.to_body(body), ..opts])
}

pub fn delete(
  client client: Client,
  path path: String,
  expecting target: Target(a),
  options opts: Opts,
) -> ResultResponse(a) {
  client
  |> send(Delete, path, target, opts)
}
