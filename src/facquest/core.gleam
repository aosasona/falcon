import gleam/dynamic.{type Decoder, type Dynamic}
import gleam/bool
import facquest/hackney
import gleam/http/request.{type Request, Request}
import gleam/http.{
  type Method, type Scheme, Delete, Get, Patch, Post, Put, scheme_to_string,
}
import gleam/int
import gleam/io
import gleam/json
import gleam/list
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
  RawDecodingError(dynamic.DecodeErrors)
  JsonDecodingError(json.DecodeError)
}

pub type ResultResponse(a) =
  Result(FacquestResponse(a), FacquestError)

pub type Target(a) {
  Json(Decoder(a))
  Raw(Decoder(a))
}

pub type Url {
  Url(String)

  SplitUrl(scheme: Scheme, host: String, path: String, port: Option(Int))
}

pub type Pairs =
  List(#(String, String))

pub type Config {
  /// A string to use as the body of the request - not meant to be used directly, use `post`, `put`, or `patch` instead, or if necessary, `to_body`
  Body(OpaqueBody)

  /// A list of headers to *prepend* to the request
  Headers(Pairs)

  /// A list of query parameters to append to the URL
  Queries(Pairs)

  /// A list of options to pass to the underlying HTTP client to control things like timeouts and redirects
  ClientOptions(hackney.Options)
}

pub type Opts =
  List(Config)

/// This exists to prevent the body from being added manually to requests like Get and Delete which don't support bodies
/// Since a user cannot create an OpaqueBody, they cannot add a body to a request that doesn't support it
pub opaque type OpaqueBody {
  OpaqueBody(String)
}

/// Convert a string to an OpaqueBody - only use this if you are using the `send` function directly
pub fn to_body(body: String) -> Config {
  Body(OpaqueBody(body))
}

/// convert a FacquestError to a string for display - some errors like HackneyError are not very helpful to the end user and are logged instead
pub fn error_to_string(err: FacquestError) -> String {
  case err {
    URLParseError -> "Invalid URL provided, unable to parse."
    InvalidUtf8Response -> "Received invalid UTF-8 response."
    HackneyError(e) -> {
      io.debug(e)
      "Something really went wrong, see logs for more info"
    }
    RawDecodingError(e) -> {
      io.debug(e)
      "Failed to decode response, ensure your decoder is correct. You can also use a map if you are unsure of the response structure, see the logs for more info."
    }
    JsonDecodingError(e) -> {
      io.debug(e)
      "Failed to decode response into JSON, ensure your decoder is correct. You can also use a map if you are unsure of the response structure, see the logs for more info."
    }
  }
}

fn with_leading_slash(path: String) -> String {
  {
    use <- bool.guard(when: string.starts_with(path, "/"), return: path)
    "/" <> path
  }
  |> string.trim
}

fn without_trailing_slash(path: String) -> String {
  {
    use <- bool.guard(when: !string.ends_with(path, "/"), return: path)
    string.slice(path, 0, string.length(path) - 1)
  }
  |> string.trim
}

pub fn append_path(url: Url, path: String) -> Url {
  case url {
    Url(url) ->
      url
      |> without_trailing_slash
      |> fn(url) { url <> with_leading_slash(path) }
      |> Url

    SplitUrl(scheme, host, raw_path, port) ->
      raw_path
      |> without_trailing_slash
      |> fn(normalized_path) { normalized_path <> with_leading_slash(path) }
      |> SplitUrl(scheme: scheme, host: host, port: port)
  }
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

pub fn extract_params(
  opts: List(Config),
  state: #(Request(String), hackney.Options),
) -> #(Request(String), hackney.Options) {
  let #(req, hackney_opts) = state
  case opts {
    [Body(OpaqueBody(body)), ..rest] ->
      #(append_body(body, req), hackney_opts)
      |> extract_params(rest, _)
    [Headers(headers), ..rest] ->
      #(prepend_headers(headers, req), hackney_opts)
      |> extract_params(rest, _)
    [Queries(query), ..rest] ->
      #(append_queries(query, req), hackney_opts)
      |> extract_params(rest, _)
    [ClientOptions(opts), ..rest] ->
      #(req, list.concat([hackney_opts, opts]))
      |> extract_params(rest, _)
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

pub fn send(
  method method: Method,
  url url: Url,
  expecting decode: Target(a),
  options opts: List(Config),
) -> Result(FacquestResponse(a), FacquestError) {
  let uri = url_to_string(url)
  use req <- result.try(
    request.to(uri)
    |> result.map_error(fn(_) { URLParseError }),
  )

  let #(req, hackney_opts) = {
    req
    |> request.set_method(method)
    |> fn(req) { #(req, []) }
    |> extract_params(opts, _)
  }

  use resp <- result.try(
    hackney.send(req, hackney_opts)
    |> result.map_error(fn(err) {
      case err {
        hackney.InvalidUtf8Response -> InvalidUtf8Response
        hackney.Other(e) -> HackneyError(e)
      }
    }),
  )

  let decode_body = case decode {
    Json(decoder) -> fn(d) {
      d
      |> json.decode(decoder)
      |> result.map_error(fn(err) { JsonDecodingError(err) })
    }
    Raw(decoder) -> fn(d) {
      d
      |> dynamic.from
      |> decoder
      |> result.map_error(fn(err) { RawDecodingError(err) })
    }
  }

  use body <- result.try(
    resp.body
    |> decode_body,
  )

  Ok(FacquestResponse(status: resp.status, headers: resp.headers, body: body))
}

pub fn get(
  to url: Url,
  expecting target: Target(a),
  options opts: Opts,
) -> ResultResponse(a) {
  send(Get, url, target, opts)
}

pub fn post(
  to url: Url,
  body body: String,
  expecting target: Target(a),
  options opts: Opts,
) -> ResultResponse(a) {
  send(Post, url, target, [to_body(body), ..opts])
}

pub fn put(
  to url: Url,
  body body: String,
  expecting target: Target(a),
  options opts: Opts,
) -> ResultResponse(a) {
  send(Put, url, target, [to_body(body), ..opts])
}

pub fn patch(
  to url: Url,
  body body: String,
  expecting target: Target(a),
  options opts: Opts,
) -> ResultResponse(a) {
  send(Patch, url, target, [to_body(body), ..opts])
}

pub fn delete(
  to url: Url,
  expecting target: Target(a),
  options opts: Opts,
) -> ResultResponse(a) {
  send(Delete, url, target, opts)
}
