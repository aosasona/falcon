import gleam/dict.{type Dict}
import gleam/dynamic.{type Decoder}
import gleam/bool
import gleam/hackney
import gleam/http/request.{type Request, Request}
import gleam/http.{
  type Method, type Scheme, Delete, Get, Patch, Post, Put, scheme_to_string,
}
import gleam/int
import gleam/option.{type Option, Some}
import gleam/result
import gleam/string

pub type FacquestError {
  URLParseError
  RequestError(String)
}

pub type Url {
  Url(String)

  SplitUrl(scheme: Scheme, host: String, path: String, port: Option(Int))
}

pub type Pairs =
  List(#(String, String))

pub type Config {
  Body(String)
  Headers(Pairs)
  Query(Pairs)
}

pub type Opts =
  List(Config)

fn with_leading_slash(path: String) -> String {
  use <- bool.guard(when: string.starts_with(path, "/"), return: path)
  "/" <> path
}

fn without_trailing_slash(path: String) -> String {
  use <- bool.guard(when: !string.ends_with(path, "/"), return: path)
  string.slice(path, 0, string.length(path) - 1)
}

pub fn url_to_string(url: Url) -> String {
  case url {
    Url(url) -> url
    SplitUrl(scheme, raw_host, raw_path, raw_port) -> {
      let host =
        without_trailing_slash(raw_host)
        |> string.trim

      let port = case option.unwrap(raw_port, 80) {
        80 | 443 -> ""
        port -> ":" <> int.to_string(port)
      }
      let path =
        with_leading_slash(raw_path)
        |> string.trim

      // respect port over scheme if explicitly provided
      let normalized_scheme = case raw_port {
        Some(443) -> "https"
        Some(80) -> "http"
        _ -> scheme_to_string(scheme)
      }

      normalized_scheme <> "://" <> host <> port <> path
    }
  }
}

fn send(
  method: Method,
  url: Url,
  target: Decoder(a),
  opts: List(Config),
) -> Result(a, FacquestError) {
  let uri = url_to_string(url)
  use req <- result.try(
    request.to(uri)
    |> result.map_error(fn(_) { URLParseError }),
  )
  todo
}

pub fn opts_to_request(
  opts: List(Config),
  state: Request(String),
) -> Request(String) {
  case opts {
    [Body(body), ..rest] ->
      append_body(body, state)
      |> opts_to_request(rest, _)
    [Headers(headers), ..rest] ->
      append_headers(headers, state)
      |> opts_to_request(rest, _)
    [Query(query), ..rest] ->
      append_queries(query, state)
      |> opts_to_request(rest, _)
    [] -> state
  }
}

fn append_headers(headers: Pairs, state: Request(String)) -> Request(String) {
  case headers {
    [] -> state
    [header, ..rest] -> {
      state
      |> request.set_header(header.0, header.1)
      |> append_headers(rest, _)
    }
  }
}

fn append_queries(queries: Pairs, state: Request(String)) -> Request(String) {
  state
  |> request.set_query(queries)
}

fn append_body(body: String, state: Request(String)) -> Request(String) {
  state
  |> request.set_body(body)
}

pub fn get(to url: Url, expecting target: Decoder(a), options opts: Opts) -> a {
  todo
}

pub fn post(
  to url: Url,
  body body: String,
  expecting target: Decoder(a),
  options opts: Opts,
) -> a {
  todo
}

pub fn put(
  to url: Url,
  body body: String,
  expecting target: Decoder(a),
  options opts: Opts,
) -> a {
  todo
}

pub fn patch(
  to url: Url,
  body body: String,
  expecting target: Decoder(a),
  options opts: Opts,
) -> a {
  todo
}

pub fn delete(
  to url: Url,
  expecting target: Decoder(a),
  options opts: Opts,
) -> a {
  todo
}
