defmodule Tussle.Storage do
  @callback create(Tussle.File.t(), map()) :: Tussle.File.t()
  @callback append(Tussle.File.t(), map(), binary()) :: {:ok, Tussle.File.t()} | {:error, term()}
  @callback complete_upload(Tussle.File.t(), map()) :: {:ok, Tussle.File.t()} | {:error, term()}
  @callback delete(Tussle.File.t(), map()) :: any()
end
