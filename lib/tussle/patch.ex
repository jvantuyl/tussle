defmodule Tussle.Patch do
  @moduledoc """
  """
  import Plug.Conn

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
      |> put_resp_header("upload-offset", "#{file.offset}")
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

      {:error, _reason} ->
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
    case read_body(conn, length: 100_000_000) do
      {:ok, binary, conn} ->
        # Final chunk received - combine all parts
        body = acc |> Enum.reverse() |> Enum.join() |> Kernel.<>(binary)
        {:ok, body, conn}

      {:more, binary, conn} ->
        # More chunks to come - accumulate this one and continue
        read_all_body(conn, [binary | acc])

      {:error, _reason} ->
        :no_body

      _ ->
        :no_body
    end
  end

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
