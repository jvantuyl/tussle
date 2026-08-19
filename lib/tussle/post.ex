defmodule Tussle.Post do
  @moduledoc """
  A POST request is used to create a new upload resource.

  The request body is normally empty. Clients implementing the
  creation-with-upload extension may send the first part of the upload alongside
  the creation request by setting a
  `Content-Type: application/offset+octet-stream` header, saving a round trip.
  """
  import Plug.Conn
  require Logger

  @offset_content_type "application/offset+octet-stream"

  def post(conn, %{version: version, max_size: max_size} = config) when version == "1.0.0" do
    with {:ok, file} <- build_file(conn),
         file <- config.init_file.(file, conn),
         :ok <- file_size_ok?(conn, file, max_size),
         {:ok, data, conn} <- read_creation_body(conn),
         :ok <- creation_body_fits?(file, data),
         {:ok, file} <- create_file(file, config),
         :ok <- cache_file(file, config),
         :ok <- config.on_begin_upload.(file),
         {:ok, file, offset} <- maybe_write(file, config, data) do
      location =
        if file.prefix != "" do
          file.prefix <> file.uid
        else
          file.uid
        end

      conn
      |> put_resp_header("tus-resumable", config.version)
      |> put_resp_header("location", location)
      |> maybe_put_offset_header(offset)
      |> Tussle.add_expire_hdr(file, config)
      |> resp(:created, "")
    else
      :too_large ->
        conn
        |> put_resp_header("tus-resumable", config.version)
        |> resp(:request_entity_too_large, "Data is larger than expected")

      :no_body ->
        conn
        |> put_resp_header("tus-resumable", config.version)
        |> resp(:bad_request, "Unable to read request body")

      {:write_error, reason} ->
        Logger.error("Tussle POST failed: #{inspect(reason)}")

        conn
        |> put_resp_header("tus-resumable", config.version)
        |> resp(:bad_request, "Unable to save file")

      {:error, reason} ->
        conn
        |> put_resp_header("tus-resumable", config.version)
        |> resp(:bad_request, reason)
    end
  end

  # Only a request labelled as carrying upload data is treated as
  # creation-with-upload; any other body is ignored, as is its content.
  defp read_creation_body(conn) do
    if creation_with_upload?(conn) do
      Tussle.Upload.read_body(conn)
    else
      {:ok, :none, conn}
    end
  end

  defp creation_with_upload?(conn) do
    conn
    |> get_req_header("content-type")
    |> List.first()
    |> case do
      nil -> false
      content_type -> String.starts_with?(content_type, @offset_content_type)
    end
  end

  # Checked before the upload resource is created so that the common client
  # error does not leave an orphaned upload behind.
  defp creation_body_fits?(_file, :none), do: :ok

  defp creation_body_fits?(%{size: size}, data) when byte_size(data) > size, do: :too_large

  defp creation_body_fits?(_file, _data), do: :ok

  defp maybe_write(file, _config, :none), do: {:ok, file, nil}

  # An empty body still reports an offset, but has nothing to hand to storage.
  defp maybe_write(file, _config, ""), do: {:ok, file, file.offset}

  defp maybe_write(file, config, data) do
    case Tussle.Upload.write(file, config, data) do
      {:ok, file, offset} -> {:ok, file, offset}
      :too_large -> :too_large
      {:error, reason} -> {:write_error, reason}
    end
  end

  defp maybe_put_offset_header(conn, nil), do: conn

  defp maybe_put_offset_header(conn, offset),
    do: put_resp_header(conn, "upload-offset", "#{offset}")

  defp build_file(conn) do
    metadata_src =
      conn
      |> get_req_header("upload-metadata")
      |> List.first()

    metadata =
      if metadata_src do
        parse_metadata(metadata_src)
      else
        %{}
      end

    file = %Tussle.File{
      uid: Tussle.UID.generate(),
      size: get_size(conn),
      created_at: DateTime.to_unix(DateTime.utc_now()),
      metadata_src: metadata_src,
      metadata: metadata
    }

    {:ok, file}
  end

  def parse_metadata(metadata_src) do
    metadata_src
    |> String.split(~r/\s*,\s*/)
    |> Enum.map(&split_metadata/1)
    |> Map.new()
  end

  defp split_metadata(kv) do
    case String.split(kv, ~r/\s+/, parts: 2) do
      [key] -> {key, nil}
      [key, value] -> {key, Base.decode64!(value)}
    end
  end

  defp get_size(conn) do
    conn
    |> get_req_header("upload-length")
    |> List.first()
    |> Kernel.||("0")
    |> String.to_integer()
  end

  defp file_size_ok?(conn, %{size: size}, hard_limit) do
    soft_limit =
      conn
      |> get_req_header("tus-max-size")
      |> List.first()
      |> Kernel.||("#{hard_limit}")
      |> String.to_integer()

    if size < min(hard_limit, soft_limit) do
      :ok
    else
      :too_large
    end
  end

  defp create_file(file, config) do
    file = Tussle.storage_create(file, config)
    {:ok, file}
  end

  defp cache_file(file, config) do
    Tussle.cache_put(file, config)
    :ok
  end
end
