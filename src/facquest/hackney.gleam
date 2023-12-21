// Originally from https://github.com/gleam-lang/hackney/blob/main/src/gleam/hackney.gleam
// This will be upstreamed to the hackney repo once it's stable and properly tested in the future
import gleam/result
import gleam/dynamic.{type Dynamic}
import gleam/http.{type Method}
import gleam/http/request.{type Request}
import gleam/http/response.{type Response, Response}
import gleam/bit_array
import gleam/bytes_builder.{type BytesBuilder}
import gleam/string
import gleam/list
import gleam/uri

pub type Error {
  InvalidUtf8Response
  Other(Dynamic)
}

pub type SSLVerifyMode {
  VerifyNone
  VerifyPeer
  VerifyPeerStrict
}

pub type CrlCheckMode {
  Peer
}

pub type SslCrlInternalCacheOptions {
  Http(Int)
}

pub type SslCrlCacheOptions {
  Internal(List(SslCrlInternalCacheOptions))
}

pub type CrlCacheOptions {
  SslCrlCache(SslCrlCacheOptions)
}

pub type SSLOption {

  Cacertfile(String)

  CrlCheck(CrlCheckMode)

  CrlCache(CrlCacheOptions)

  Verify(SSLVerifyMode)

  Versions(List(String))
}

pub type HackneyOption {
  /// You probably DO NOT want to use this option. It is only here for compatibility
  Async

  FollowRedirect(Bool)

  MaxConnections(Int)

  MaxRedirect(Int)

  SSLOptions(List(SSLOption))

  Timeout(Int)

  // this may be added in the future, currently absent so we don't have generics littered everywhere and we don't have any functions dealing with pools yet either
  // Pool(_)
  WithBody(Bool)
}

pub type Options =
  List(HackneyOption)

@external(erlang, "hackney_ffi", "send")
fn ffi_send(
  method: Method,
  url: String,
  headers: List(http.Header),
  body: BytesBuilder,
  options: Options,
) -> Result(Response(BitArray), Error)

pub fn send_bits(
  request: Request(BytesBuilder),
  options: Options,
) -> Result(Response(BitArray), Error) {
  use response <- result.then(
    request
    |> request.to_uri
    |> uri.to_string
    |> ffi_send(request.method, _, request.headers, request.body, options),
  )
  let headers = list.map(response.headers, normalise_header)
  Ok(Response(..response, headers: headers))
}

pub fn send(
  request req: Request(String),
  options options: Options,
) -> Result(Response(String), Error) {
  use resp <- result.then(
    req
    |> request.map(bytes_builder.from_string)
    |> send_bits(options),
  )

  case bit_array.to_string(resp.body) {
    Ok(body) -> Ok(response.set_body(resp, body))
    Error(_) -> Error(InvalidUtf8Response)
  }
}

fn normalise_header(header: http.Header) -> http.Header {
  #(string.lowercase(header.0), header.1)
}
