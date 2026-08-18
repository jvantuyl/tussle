defmodule Tussle.Patch do
  @moduledoc """
  """
  import Plug.Conn
  require Logger

  # Configurable read_body options with defaults
  @read_body_length Application.compile_env(:tussle, :read_body_length, 100_000_000)
  @read_body_read_length Application.compile_env(:tussle, :read_body_read_length, 262_144)
  @read_body_timeout Application.compile_env(:tussle, :read_body_timeout, 30_000)

  def patch(conn, %{version: version} = config) when version == "1.0.0" do
    with {:ok, %Tussle.File{} = file} <- get_file(config),
         :ok <- offsets_match?(conn, file),
         {:ok, data, conn} <- get_body(conn),
         data_size <- byte_size(data),
         :ok <- valid_size?(file, data_size),
         {:ok, file, new_offset} <- append_data(file, config, data),
         {:ok, file} <- maybe_upload_completed(file, new_offset, config) do
      conn
      |> put_resp_header("tus-resumable", config.version)
      |> put_resp_header("upload-offset", "#{new_offset}")
      |> Tussle.add_expire_hdr(file, config)
      |> resp(:no_content, "")
    else
      :file_not_found ->
        conn |> resp(:not_found, "File not found")

      :offsets_mismatch ->
        conn |> resp(:conflict, "Offset don't match")

      :no_body ->
        conn |> resp(:bad_request, "No body")

      :too_large ->
        conn |> resp(:request_entity_too_large, "Data is larger than expected")

      {:error, reason} ->
        Logger.error("Tussle PATCH failed: #{inspect(reason)}")
        conn |> resp(:bad_request, "Unable to save file")

      :too_small ->
        conn |> resp(:conflict, "Data is smaller than what the storage backend can handle")
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

  defp get_file(config) do
    case Tussle.cache_get(config) do
      %Tussle.File{} = file -> {:ok, file}
      _ -> :file_not_found
    end
  end

  defp offsets_match?(conn, file) do
    if file.offset == get_offset(conn) do
      :ok
    else
      :offsets_mismatch
    end
  end

  defp get_offset(conn) do
    conn
    |> get_req_header("upload-offset")
    |> List.first()
    |> Kernel.||("0")
    |> String.to_integer()
  end

  defp get_body(conn) do
    # Read the full body by accumulating chunks until we get :ok
    # read_body may return :more for chunked/streamed bodies
    read_all_body(conn, [])
  end

  defp read_all_body(conn, acc) do
    conn
    |> read_body(
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

  defp upload_completed?(file) do
    file.size == file.offset
  end
end
