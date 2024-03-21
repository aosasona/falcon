import gleeunit
import gleeunit/should
import gleam/list
import gleam/dynamic
import gleam/json
import gleam/option.{type Option, None, Some}
import gleam/result.{try}
import falcon.{extract_headers, merge_opts, new}
import falcon/core.{
  type FalconResponse, type Opts, ClientOptions, Headers, Json, Url,
}
import falcon/hackney.{Timeout}

pub fn main() {
  gleeunit.main()
}

pub type Product {
  Product(
    id: Option(Int),
    title: String,
    description: String,
    price: Int,
    discount_percentage: Option(Float),
    rating: Float,
    stock: Int,
    brand: String,
    category: String,
    thumbnail: String,
    images: List(String),
  )
}

fn decoder(d) {
  use id <- try(dynamic.optional_field("id", dynamic.int)(d))
  use title <- try(dynamic.field("title", dynamic.string)(d))
  use description <- try(dynamic.field("description", dynamic.string)(d))
  use price <- try(dynamic.field("price", dynamic.int)(d))
  use discount_percentage <- try(dynamic.optional_field(
    "discountPercentage",
    dynamic.float,
  )(d))
  use rating <- try(dynamic.field("rating", dynamic.float)(d))
  use stock <- try(dynamic.field("stock", dynamic.int)(d))
  use brand <- try(dynamic.field("brand", dynamic.string)(d))
  use category <- try(dynamic.field("category", dynamic.string)(d))
  use thumbnail <- try(dynamic.field("thumbnail", dynamic.string)(d))
  use images <- try(dynamic.field("images", dynamic.list(dynamic.string))(d))

  Ok(Product(
    id,
    title,
    description,
    price,
    discount_percentage,
    rating,
    stock,
    brand,
    category,
    thumbnail,
    images,
  ))
}

fn encode(product: Product) {
  json.object([
    #("id", json.nullable(from: product.id, of: json.int)),
    #("title", json.string(product.title)),
    #("description", json.string(product.description)),
    #("price", json.int(product.price)),
    #(
      "discountPercentage",
      json.nullable(from: product.discount_percentage, of: json.float),
    ),
    #("rating", json.float(product.rating)),
    #("stock", json.int(product.stock)),
    #("brand", json.string(product.brand)),
    #("category", json.string(product.category)),
    #("thumbnail", json.string(product.thumbnail)),
    #("images", json.array(from: product.images, of: json.string)),
  ])
}

// Labels have been used to make the test more readable
fn make_client() {
  falcon.new(
    base_url: Url("https://dummyjson.com/"),
    headers: [#("content-type", "application/json")],
    timeout: falcon.default_timeout,
  )
}

pub fn get_test() {
  make_client()
  |> falcon.get("/products/1", expecting: Json(decoder), options: [])
  |> should.be_ok
  |> fn(res: FalconResponse(Product)) {
    let data = res.body
    #(data.id, data.title, data.price, data.discount_percentage, data.brand)
  }
  |> should.equal(#(Some(1), "iPhone 9", 549, Some(12.96), "Apple"))
}

pub fn post_test() {
  let product =
    Product(
      id: None,
      title: "Gleam stickers",
      description: "falcon test",
      price: 2,
      discount_percentage: None,
      rating: 3.8,
      stock: 1,
      brand: "Gleam",
      category: "Stickers",
      thumbnail: "https://example.com/gleam.png",
      images: [],
    )

  let body =
    product
    |> encode
    |> json.to_string

  make_client()
  |> falcon.post("/products/add", body, Json(decoder), options: [])
  |> should.be_ok
  |> fn(res: FalconResponse(Product)) { res.body }
  |> should.equal(Product(..product, id: Some(101)))
}

pub fn patch_put_test() {
  let body =
    json.object([
      #("title", json.string("Not iPhone 9")),
      #("price", json.int(999)),
    ])
    |> json.to_string

  let extract = fn(res: FalconResponse(Product)) {
    let data = res.body
    #(data.id, data.title, data.price)
  }

  make_client()
  |> falcon.patch("/products/1", body, expecting: Json(decoder), options: [])
  |> should.be_ok
  |> extract
  |> should.equal(#(Some(1), "Not iPhone 9", 999))

  make_client()
  |> falcon.put("/products/1", body, expecting: Json(decoder), options: [])
  |> should.be_ok
  |> extract
  |> should.equal(#(Some(1), "Not iPhone 9", 999))
}

pub type PartialDeleteResponse {
  PartialDeleteResponse(id: Int, is_deleted: Bool)
}

pub fn delete_test() {
  let resp_decoder =
    dynamic.decode2(
      PartialDeleteResponse,
      dynamic.field("id", dynamic.int),
      dynamic.field("isDeleted", dynamic.bool),
    )

  make_client()
  |> falcon.delete("/products/1", expecting: Json(resp_decoder), options: [])
  |> should.be_ok
  |> fn(res: FalconResponse(PartialDeleteResponse)) { res.body }
  |> should.equal(PartialDeleteResponse(id: 1, is_deleted: True))
}

fn extract_timeout(
  opts: List(hackney.HackneyOption),
  state: List(Option(Int)),
) -> List(Option(Int)) {
  case opts {
    [Timeout(t), ..rest] -> {
      extract_timeout(rest, list.concat([state, [Some(t)]]))
    }
    _ -> state
  }
}

fn extract_timeouts(opts: Opts) -> List(Option(Int)) {
  opts
  |> list.filter(fn(opt) {
    // Extract all client options
    case opt {
      ClientOptions(_) -> True
      _ -> False
    }
  })
  |> list.map(fn(opt) {
    case opt {
      ClientOptions(client_options) -> extract_timeout(client_options, [])
      _ -> []
    }
  })
  |> list.flatten
}

pub fn merge_opts_test() {
  let new_opts =
    new(
      Url("http://example.com"),
      [#("x-client-default", "default")],
      Some(15_000),
    )
    |> merge_opts([Headers([#("x-test", "test")])])

  new_opts
  |> extract_headers
  |> should.equal([#("x-client-default", "default"), #("x-test", "test")])

  new_opts
  |> extract_timeouts
  |> list.first
  |> should.equal(Ok(Some(15_000)))

  // Test that all headers are merged even if timeout is not set
  let new_opts =
    new(Url("http://example.com"), [#("a", "b"), #("c", "d")], None)
    |> merge_opts([Headers([#("e", "f")]), Headers([#("g", "h")])])

  new_opts
  |> extract_headers
  |> should.equal([#("a", "b"), #("c", "d"), #("e", "f"), #("g", "h")])

  new_opts
  |> extract_timeouts
  |> list.first
  |> result.unwrap(None)
  |> should.equal(None)

  // Test that only the new timeout is used
  let new_opts =
    new(Url("http://example.com"), [], Some(15_000))
    |> merge_opts([ClientOptions([Timeout(30_000)])])

  new_opts
  |> extract_headers
  |> should.equal([])

  new_opts
  |> extract_timeouts
  |> should.equal([Some(30_000)])

  // Test that the last timeout provided by the user in the request itself is used instead of the default
  new(Url("http://example.com"), [], Some(15_000))
  |> merge_opts([ClientOptions([Timeout(30_000), Timeout(10_000)])])
  |> extract_timeouts
  |> list.last
  |> should.equal(Ok(Some(10_000)))
}
