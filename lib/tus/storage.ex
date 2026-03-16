defmodule Tus.Storage do
  @callback create(Tus.File.t(), map()) :: Tus.File.t()
  @callback append(Tus.File.t(), map(), binary()) :: {:ok, Tus.File.t()} | {:error, term()}
  @callback complete_upload(Tus.File.t(), map()) :: {:ok, Tus.File.t()} | {:error, term()}
  @callback delete(Tus.File.t(), map()) :: any()
end
