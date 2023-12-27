import gleam/http.{Http, Https}
import gleeunit/should
import gleam/option.{None, Some}
import facquest/core.{SplitUrl, Url, append_path, url_to_string}

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

pub fn append_path_test() {
  SplitUrl(host: "example.com", path: "/", scheme: Https, port: None)
  |> append_path("test")
  |> url_to_string
  |> should.equal("https://example.com/test")

  SplitUrl(host: "example.com", path: "/", scheme: Https, port: None)
  |> append_path("/test")
  |> url_to_string
  |> should.equal("https://example.com/test")

  SplitUrl(host: "example.com", path: "/existing/", scheme: Https, port: None)
  |> append_path("new")
  |> url_to_string
  |> should.equal("https://example.com/existing/new")

  SplitUrl(host: "example.com", path: "/existing/", scheme: Https, port: None)
  |> append_path("/new")
  |> url_to_string
  |> should.equal("https://example.com/existing/new")

  Url("https://example.com/url/")
  |> append_path("appended")
  |> url_to_string
  |> should.equal("https://example.com/url/appended")

  Url("https://example.com:9000/url/another")
  |> append_path("another-appended-one")
  |> url_to_string
  |> should.equal("https://example.com:9000/url/another/another-appended-one")

  Url("https://example.com:9000/url/another/")
  |> append_path("another-appended-one-for-trailing-slash")
  |> url_to_string
  |> should.equal(
    "https://example.com:9000/url/another/another-appended-one-for-trailing-slash",
  )
}
