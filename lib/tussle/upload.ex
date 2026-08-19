defmodule Tussle.Upload do
  @moduledoc false
  # Request body reading and appending, shared by PATCH and by the
  # creation-with-upload path in POST.

  require Logger

  # Configurable read_body options with defaults
  @read_body_length Application.compile_env(:tussle, :read_body_length, 100_000_000)
  @read_body_read_length Application.compile_env(:tussle, :read_body_read_length, 262_144)
  @read_body_timeout Application.compile_env(:tussle, :read_body_timeout, 30_000)

  @doc """
  Reads the whole request body, accumulating chunks for streamed bodies.
  """
  @spec read_body(Plug.Conn.t()) :: {:ok, binary(), Plug.Conn.t()} | :no_body
  def read_body(conn) do
    read_all_body(conn, [])
  end

  @doc """
  Appends `data` to `file`, completing the upload if it reaches the declared size.

  Returns the file and the offset to report back to the client. Storage backends
  may report an offset of their own, which takes precedence over the byte count.
  """
  @spec write(Tussle.File.t(), map(), binary()) ::
          {:ok, Tussle.File.t(), non_neg_integer()} | :too_large | {:error, term()}
  def write(%Tussle.File{} = file, config, data) do
    with :ok <- valid_size?(file, byte_size(data)),
         {:ok, file, new_offset} <- append_data(file, config, data),
         {:ok, file} <- maybe_upload_completed(file, new_offset, config) do
      {:ok, file, new_offset}
    end
  end

  defp read_all_body(conn, acc) do
    conn
    |> Plug.Conn.read_body(
      length: @read_body_length,
      read_length: @read_body_read_length,
      timeout: @read_body_timeout
    )
    |> handle_read_body_result(conn, acc)
  end

  defp handle_read_body_result({:ok, binary, conn}, _original_conn, acc) do
    body = acc |> Enum.reverse() |> Enum.join() |> Kernel.<>(binary)
    {:ok, body, conn}
  end

  defp handle_read_body_result({:more, binary, conn}, _original_conn, acc) do
    read_all_body(conn, [binary | acc])
  end

  defp handle_read_body_result({:error, reason}, _conn, _acc) do
    Logger.error("Tussle read_body error: #{inspect(reason)}")
    :no_body
  end

  # Defensive clause — commented out to satisfy the Elixir 1.20 type checker.
  # Plug.Conn.read_body/2 is typed to return only {:ok, ...}, {:more, ...},
  # or {:error, ...}, so this clause is currently unreachable. We keep it as
  # a reference for adapter upgrades or Plug version bumps where the return
  # type contract may expand, at which point it should be uncommented.
  #
  # defp handle_read_body_result(other, _conn, _acc) do
  #   Logger.warning("Tussle read_body unexpected: #{inspect(other)}")
  #   :no_body
  # end

  defp valid_size?(file, data_size) do
    if file.offset + data_size > file.size do
      :too_large
    else
      :ok
    end
  end

  defp append_data(file, config, data) do
    case Tussle.storage_append(file, config, data) do
      {:ok, file} ->
        new_offset = file.offset + byte_size(data)
        {:ok, file, new_offset}

      {:ok, file, new_offset} ->
        {:ok, file, new_offset}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp maybe_upload_completed(%Tussle.File{} = file, new_offset, config) do
    file = %{file | offset: new_offset}
    Tussle.cache_put(file, config)

    case upload_completed?(file) do
      true ->
        Tussle.storage_complete_upload(file, config)
        res = file |> config.on_complete_upload.() |> on_complete_upload_result(file)

        Tussle.cache_delete(file, config)
        res

      false ->
        {:ok, file}
    end
  end

  defp on_complete_upload_result({:error, reason}, _file), do: {:error, reason}
  defp on_complete_upload_result(_callback_res, file), do: {:ok, file}

  defp upload_completed?(file) do
    file.size == file.offset
  end
end
