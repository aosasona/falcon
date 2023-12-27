import facquest/core.{
  type Opts, type Pairs, type ResultResponse, type Url, ClientOptions, Headers,
  Url,
}
import gleam/dynamic.{type Decoder}
import gleam/bool
import gleam/list
import gleam/http.{type Method, Delete, Get, Patch, Post, Put}
import gleam/option.{type Option, None, Some}
import facquest/hackney.{Timeout}

pub const default_timeout: Option(Int) = Some(10_000)

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

pub fn merge_opts(client: Client, opts: Opts) -> Opts {
  // There is a chance this will cause problems if you pass in a timeout in the client and another timeout in the options simply because we are not filtering out duplicates at the moment seeing as it might be too expensive to do that with every single request (it is nested - we'd have to look into opts and then filter out timeout from every single client options before putting them back together)
  let new_opts = case client.timeout {
    Some(timeout) -> list.concat([[ClientOptions([Timeout(timeout)])], opts])
    None -> opts
  }

  // Merge all headers into one list
  let headers =
    new_opts
    |> filter_opts(keep_headers: True)
    |> extract_headers
    |> fn(headers) { list.concat([client.headers, headers]) }

  // Remove all headers from the original list and replace with the merged list
  new_opts
  |> filter_opts(keep_headers: False)
  |> fn(new_opts) { list.concat([[Headers(headers)], new_opts]) }
}

pub fn send(
  client: Client,
  method: Method,
  path: String,
  target: Decoder(a),
  opts: Opts,
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
  expecting target: Decoder(a),
  options opts: Opts,
) -> ResultResponse(a) {
  client
  |> send(Get, path, target, opts)
}

pub fn post(
  client client: Client,
  path path: String,
  body body: String,
  expecting target: Decoder(a),
  options opts: Opts,
) -> ResultResponse(a) {
  client
  |> send(Post, path, target, [core.to_body(body), ..opts])
}

pub fn put(
  client client: Client,
  path path: String,
  body body: String,
  expecting target: Decoder(a),
  options opts: Opts,
) -> ResultResponse(a) {
  client
  |> send(Put, path, target, [core.to_body(body), ..opts])
}

pub fn patch(
  client client: Client,
  path path: String,
  body body: String,
  expecting target: Decoder(a),
  options opts: Opts,
) -> ResultResponse(a) {
  client
  |> send(Patch, path, target, [core.to_body(body), ..opts])
}

pub fn delete(
  client client: Client,
  path path: String,
  expecting target: Decoder(a),
  options opts: Opts,
) -> ResultResponse(a) {
  client
  |> send(Delete, path, target, opts)
}
