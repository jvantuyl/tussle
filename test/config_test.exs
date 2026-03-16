defmodule Tussle.ConfigTest do
  use ExUnit.Case, async: true
  doctest Tussle.Application

  test "Missing Tussle controller config" do
    Application.put_env(:tussle, :controllers, [Tussle.SomeTestController])
    Application.put_env(:tussle, Tussle.OtherTestController, [
          storage: Tussle.Storage.Local,
          base_path: "/tmp",
          cache: Tussle.Cache.Memory,
          max_size: 1024 * 1024 * 200
          ])

    assert {:error, "Tussle configuration for Elixir.Tussle.SomeTestController not found"} =
      Tussle.Application.start(nil, nil)

  end
end
