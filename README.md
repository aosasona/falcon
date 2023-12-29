# falcon

[![Package Version](https://img.shields.io/hexpm/v/falcon)](https://hex.pm/packages/falcon)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/falcon/)

> ⚠️ WARNING: This package has not been thoroughly tested yet, please report any bugs you run into. I will work on adding tests in the future but the version you are currently looking at with this warning was made in constrained time to use in a project

## Installation

This package can be added to your Gleam project:

```sh
gleam add falcon
```

and its documentation can be found at <https://hexdocs.pm/falcon>.

## Usage

> This package has not been documented, have a look in the [test](./test/) folder for more examples.

```gleam
import falcon.{type FalconResponse}
import falcon/core.{Json, Url}
import gleam/dynamic
import gleam/io
import gleeunit/should

pub type PartialProduct {
  PartialProduct(id: Int, title: String)
}

pub fn main() {
  let decoder =
    dynamic.decode2(
      PartialProduct,
      dynamic.field("id", dynamic.int),
      dynamic.field("title", dynamic.string),
    )

  let client =
    falcon.new(
      base_url: Url("https://dummyjson.com/"),
      headers: [],
      timeout: falcon.default_timeout,
    )

  client
  |> falcon.get("/products/1", expecting: Json(decoder), options: [])
  |> should.be_ok
  |> fn(res: FalconResponse(PartialProduct)) { res.body }
  |> io.debug
}


// Output: PartialProduct(1, "iPhone 9")
```

## Why should I use this?

You don't need to, [Hackney](https://github.com/gleam-lang/hackney) is probably enough for whatever you are doing but if you need a bit more configuration options or an axios-like interface, this is for you.

> NOTE: part of the hackney bindings were taken from the official Gleam hackney bindings and modified
