defmodule Tussle.Delete do
  @moduledoc """
  """
  import Plug.Conn

  def delete(conn, %{version: version} = config) when version == "1.0.0" do
    with {:ok, %Tussle.File{} = file} <- get_file(config) do
      Tussle.storage_delete(file, config)
      Tussle.cache_delete(file, config)

      conn
      |> put_resp_header("tus-resumable", config.version)
      |> resp(:no_content, "")
    else
      :file_not_found ->
        conn
        |> put_resp_header("tus-resumable", config.version)
        |> resp(:not_found, "")
    end
  end

  defp get_file(config) do
    case Tussle.cache_get(config) do
      %Tussle.File{} = file -> {:ok, file}
      _ -> :file_not_found
    end
  end
end
