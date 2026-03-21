defmodule Tussle.HeadTest do
  use ExUnit.Case, async: true
  use Plug.Test
  doctest Tussle.Head

  import Plug.Conn.Status, only: [code: 1]
  import Tussle.TestHelpers, only: [test_conn: 3, get_config: 0]
  alias Tussle.TestController

  setup_all do
    %{config: get_config()}
  end

  test "HEAD: include the offset and the length in the response", context do
    config = context[:config]
    uid = "heyyou123"
    file = %Tussle.File{uid: uid, offset: 0, size: 123_456}
    config.cache.put(config.cache_name, uid, file)

    conn =
      test_conn(
        :head,
        %Plug.Conn{
          req_headers: [{"tus-resumable", Tussle.latest_version()}]
        },
        "/" <> uid
      )

    response = TestController.head(conn, %{"uid" => uid})

    assert response.status == code(:ok)
    assert response |> get_resp_header("tus-resumable") == [Tussle.latest_version()]
    assert response |> get_resp_header("upload-offset") == ["#{file.offset}"]
    assert response |> get_resp_header("upload-length") == ["#{file.size}"]
    assert response |> get_resp_header("upload-defer-length") == []
    # TUS spec requires no-store to prevent caching
    assert response |> get_resp_header("cache-control") == ["no-store"]
    assert response |> get_resp_header("cdn-cache-control") == ["no-store"]
  end

  test "HEAD: If the resource is not found, the Server SHOULD return a 404 and no Upload-Offset header" do
    conn =
      test_conn(
        :head,
        %Plug.Conn{
          req_headers: [{"tus-resumable", Tussle.latest_version()}]
        },
        "/bad-file-id"
      )

    response = TestController.head(conn, %{"uid" => "bad-file-id"})

    assert response.status == code(:not_found)
    assert response |> get_resp_header("tus-resumable") == [Tussle.latest_version()]
    assert response |> get_resp_header("upload-offset") == []
  end
end
