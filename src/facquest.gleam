import gleam/dynamic.{type Decoder, type Dynamic}
import gleam/bool
import gleam/hackney
import gleam/http/request.{type Request, Request}
import gleam/http.{
  type Method, type Scheme, Delete, Get, Patch, Post, Put, scheme_to_string,
}
import gleam/int
import gleam/io
import gleam/option.{type Option, Some}
import gleam/result
import gleam/string

pub type FacquestResponse(a) {
  FacquestResponse(status: Int, headers: Pairs, body: a)
}

pub type FacquestError {
  URLParseError
  InvalidUtf8Response
  HackneyError(Dynamic)
  DecodingError(dynamic.DecodeErrors)
}

type ResultResponse(a) =
  Result(FacquestResponse(a), FacquestError)

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

pub fn error_to_string(err: FacquestError) -> String {
  case err {
    URLParseError -> "Invalid URL provided, unable to parse."
    InvalidUtf8Response -> "Received invalid UTF-8 response."
    HackneyError(e) -> {
      io.debug(e)
      "Something really went wrong, see logs for more info"
    }
    DecodingError(e) -> {
      io.debug(e)
      "Failed to decode response, ensure your decoder is correct. You can also use a map if you are unsure of the response structure, see the logs for more info."
    }
  }
}

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

pub fn opts_to_request(
  opts: List(Config),
  state: Request(String),
) -> Request(String) {
  case opts {
    [Body(body), ..rest] ->
      append_body(body, state)
      |> opts_to_request(rest, _)
    [Headers(headers), ..rest] ->
      prepend_headers(headers, state)
      |> opts_to_request(rest, _)
    [Query(query), ..rest] ->
      append_queries(query, state)
      |> opts_to_request(rest, _)
    [] -> state
  }
}

fn prepend_headers(headers: Pairs, state: Request(String)) -> Request(String) {
  case headers {
    [] -> state
    [header, ..rest] -> {
      state
      |> request.prepend_header(header.0, header.1)
      |> prepend_headers(rest, _)
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

fn send(
  method: Method,
  url: Url,
  decode: Decoder(a),
  opts: List(Config),
) -> Result(FacquestResponse(a), FacquestError) {
  let uri = url_to_string(url)
  use req <- result.try(
    request.to(uri)
    |> result.map_error(fn(_) { URLParseError }),
  )

  use resp <- result.try(
    req
    |> request.set_method(method)
    |> opts_to_request(opts, _)
    |> hackney.send
    |> result.map_error(fn(err) {
      case err {
        hackney.InvalidUtf8Response -> InvalidUtf8Response
        hackney.Other(e) -> HackneyError(e)
      }
    }),
  )

  use body <- result.try(
    resp.body
    |> dynamic.from
    |> decode
    |> result.map_error(fn(err) { DecodingError(err) }),
  )

  Ok(FacquestResponse(status: resp.status, headers: resp.headers, body: body))
}

pub fn get(
  to url: Url,
  expecting target: Decoder(a),
  options opts: Opts,
) -> ResultResponse(a) {
  send(Get, url, target, opts)
}

pub fn post(
  to url: Url,
  body body: String,
  expecting target: Decoder(a),
  options opts: Opts,
) -> ResultResponse(a) {
  send(Post, url, target, [Body(body), ..opts])
}

pub fn put(
  to url: Url,
  body body: String,
  expecting target: Decoder(a),
  options opts: Opts,
) -> ResultResponse(a) {
  send(Put, url, target, [Body(body), ..opts])
}

pub fn patch(
  to url: Url,
  body body: String,
  expecting target: Decoder(a),
  options opts: Opts,
) -> ResultResponse(a) {
  send(Patch, url, target, [Body(body), ..opts])
}

pub fn delete(
  to url: Url,
  expecting target: Decoder(a),
  options opts: Opts,
) -> ResultResponse(a) {
  send(Delete, url, target, opts)
}
