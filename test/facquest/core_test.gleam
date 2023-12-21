import gleam/http.{Http, Https}
import gleeunit/should
import gleam/option.{None, Some}
import facquest/core.{SplitUrl, url_to_string}

pub fn url_to_string_test() {
  // http with None port
  SplitUrl(
    host: "example.com",
    path: "/http-with-none",
    scheme: Https,
    port: None,
  )
  |> url_to_string
  |> should.equal("https://example.com/http-with-none")

  // http with custom port
  SplitUrl(
    host: "example.com",
    path: "/http-with-port",
    scheme: Http,
    port: Some(8080),
  )
  |> url_to_string
  |> should.equal("http://example.com:8080/http-with-port")

  // https with None port
  SplitUrl(
    host: "example.com",
    path: "/https-with-none",
    scheme: Https,
    port: None,
  )
  |> url_to_string
  |> should.equal("https://example.com/https-with-none")

  // https with port
  SplitUrl(
    host: "example.com",
    path: "/https-with-port",
    scheme: Https,
    port: Some(8080),
  )
  |> url_to_string
  |> should.equal("https://example.com:8080/https-with-port")

  // https with default port and path with extra spaces
  SplitUrl(
    host: "example.com",
    path: "/oddity   ",
    scheme: Https,
    port: Some(443),
  )
  |> url_to_string
  |> should.equal("https://example.com/oddity")

  // path with extra spaces
  SplitUrl(
    host: "example.com",
    path: "/another-oddity   ",
    scheme: Http,
    port: Some(80),
  )
  |> url_to_string
  |> should.equal("http://example.com/another-oddity")

  // force https
  SplitUrl(host: "example.com", path: "/test", scheme: Http, port: Some(443))
  |> url_to_string
  |> should.equal("https://example.com/test")

  // path without leading slash, https with port 80
  SplitUrl(
    host: "example.com",
    path: "path-without-leading-slash",
    scheme: Https,
    port: Some(80),
  )
  |> url_to_string
  |> should.equal("http://example.com/path-without-leading-slash")

  // host with trailing slash, https with port 80
  SplitUrl(
    host: "example.com/",
    path: "/trailing-host-slash",
    scheme: Https,
    port: Some(80),
  )
  |> url_to_string
  |> should.equal("http://example.com/trailing-host-slash")
}
