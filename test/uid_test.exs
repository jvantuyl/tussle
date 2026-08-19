defmodule Tussle.UIDTest do
  use ExUnit.Case, async: true

  @format ~r/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/

  describe "generate/0" do
    test "returns a lowercase hyphenated 36 character uuid" do
      uid = Tussle.UID.generate()

      assert String.length(uid) == 36
      assert Regex.match?(@format, uid)
    end

    test "sets the version 4 and RFC 9562 variant bits" do
      <<_::48, version::4, _::12, variant::2, _::62>> =
        Tussle.UID.generate()
        |> String.replace("-", "")
        |> Base.decode16!(case: :lower)

      assert version == 4
      assert variant == 2
    end

    test "does not repeat" do
      uids = for _ <- 1..1_000, do: Tussle.UID.generate()

      assert uids |> Enum.uniq() |> length() == 1_000
    end
  end
end
