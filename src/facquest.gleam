import facquest/core

pub opaque type Client {
  Client(base_url: core.Url, headers: core.Pairs)
}

pub fn new(base_url base_url: core.Url, headers headers: core.Pairs) -> Client {
  Client(base_url, headers)
}
