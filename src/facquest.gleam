import gleam/dict.{type Dict}
import gleam/dynamic.{type Decoder}
import gleam/hackney
import gleam/http/request
import gleam/http.{
  type Method, type Scheme, Delete, Get, Patch, Post, Put, scheme_to_string,
}
import gleam/int
import gleam/result
import gleam/string

pub type FacquestError {
  URLParseError
  RequestError(String)
}

pub type Url {
  Url(String)

  SplitUrl(scheme: Scheme, host: String, path: String, port: Int)
}

pub type Opts {
  Headers(List(Dict(String, String)))
  Query(List(Dict(String, String)))
}

fn with_leading_slash(path: String) -> String {
  case path {
    "/" <> _ -> path
    _ -> "/" <> path
  }
}

fn without_trailing_slash(path: String) -> String {
  case string.ends_with(path, "/") {
    True -> string.slice(path, 0, string.length(path) - 1)
    False -> path
  }
}

fn url_to_string(url: Url) -> String {
  case url {
    Url(url) -> url
    SplitUrl(scheme, raw_host, raw_path, raw_port) -> {
      let host = without_trailing_slash(raw_host)
      let port = int.to_string(raw_port)
      let path = with_leading_slash(raw_path)

      scheme_to_string(scheme) <> "://" <> host <> ":" <> port <> path
    }
  }
}

fn send(
  method: Method,
  url: Url,
  target: Decoder(a),
  opts: Opts,
) -> Result(a, FacquestError) {
  let uri = url_to_string(url)
  use req <- result.try(
    request.to(uri)
    |> result.map_error(fn(_) { URLParseError }),
  )
  todo
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
