defmodule Tussle.UID do
  @moduledoc false

  @doc """
  Generates a random RFC 9562 UUID version 4 as a lowercase hyphenated string.

  Version 4 is used rather than a time-ordered variant because
  `Tussle.Storage.Local.get_path/1` shards uploads into directories by the
  first three characters of the uid; a timestamp prefix would funnel every
  upload into a single directory.
  """
  @spec generate() :: String.t()
  def generate do
    <<a::32, b::16, _::4, c::12, _::2, d::62>> = :crypto.strong_rand_bytes(16)

    <<a::32, b::16, 4::4, c::12, 2::2, d::62>>
    |> Base.encode16(case: :lower)
    |> hyphenate()
  end

  defp hyphenate(<<a::binary-8, b::binary-4, c::binary-4, d::binary-4, e::binary-12>>),
    do: "#{a}-#{b}-#{c}-#{d}-#{e}"
end
