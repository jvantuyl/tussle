import Config

config :tussle, controllers: [Tussle.TestController]

config :tussle, Tussle.TestController,
  storage: Tussle.Storage.Local,
  base_path: "test/files",
  cache: Tussle.Cache.Memory,
  max_size: 1024 * 1024 * 10
