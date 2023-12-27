import facquest/core.{
  type Opts, type Pairs, type ResultResponse, type Url, ClientOptions, Headers,
  Url,
}
import gleam/dynamic.{type Decoder}
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

// TODO: test
fn merge_opts(client: Client, opts: Opts) -> Opts {
  case client.timeout {
    Some(timeout) -> list.concat([opts, [ClientOptions([Timeout(timeout)])]])
    None -> opts
  }
  |> fn(new_opts) { list.concat([[Headers(client.headers)], new_opts]) }
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
