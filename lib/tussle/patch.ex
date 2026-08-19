defmodule Tussle.Patch do
  @moduledoc """
  """
  import Plug.Conn
  require Logger

  def patch(conn, %{version: version} = config) when version == "1.0.0" do
    with {:ok, %Tussle.File{} = file} <- get_file(config),
         :ok <- offsets_match?(conn, file),
         {:ok, data, conn} <- Tussle.Upload.read_body(conn),
         {:ok, file, new_offset} <- Tussle.Upload.write(file, config, data) do
      conn
      |> put_resp_header("tus-resumable", config.version)
      |> put_resp_header("upload-offset", "#{new_offset}")
      |> Tussle.add_expire_hdr(file, config)
      |> resp(:no_content, "")
    else
      :file_not_found ->
        conn |> error(config, :not_found, "File not found")

      :offsets_mismatch ->
        conn |> error(config, :conflict, "Offset don't match")

      :no_body ->
        conn |> error(config, :bad_request, "No body")

      :too_large ->
        conn |> error(config, :request_entity_too_large, "Data is larger than expected")

      {:error, reason} ->
        Logger.error("Tussle PATCH failed: #{inspect(reason)}")
        conn |> error(config, :bad_request, "Unable to save file")

      :too_small ->
        conn
        |> error(config, :conflict, "Data is smaller than what the storage backend can handle")
    end
  end

  # The Tus-Resumable header is required in every response except those
  # rejecting the protocol version itself.
  defp error(conn, config, status, body) do
    conn
    |> put_resp_header("tus-resumable", config.version)
    |> resp(status, body)
  end

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
end
