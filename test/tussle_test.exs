defmodule Tussle.TussleTest do
  use ExUnit.Case, async: true

  describe "version functions" do
    test "latest_version returns the current protocol version" do
      assert Tussle.latest_version() == "1.0.0"
    end

    test "supported_versions returns list of supported versions" do
      assert Tussle.supported_versions() == ["1.0.0"]
    end

    test "str_supported_versions returns comma-separated versions" do
      assert Tussle.str_supported_versions() == "1.0.0"
    end
  end

  describe "extension" do
    test "extension returns supported extensions" do
      assert Tussle.extension() == "creation,termination"
    end
  end
end
