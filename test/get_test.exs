defmodule Tussle.GetTest do
  use ExUnit.Case, async: true
  use Plug.Test
  doctest Tussle

  import Plug.Conn.Status, only: [code: 1]
  import Tussle.TestHelpers, only: [test_conn: 3, get_config: 0]
  alias Tussle.TestController

  setup_all do
    %{config: get_config()}
  end

  describe "GET /:uid (CloudFlare HEAD-to-GET compatibility)" do
    test "GET: includes the offset and length in response (same as HEAD)", context do
      config = context[:config]
      uid = "gettest123"
      file = %Tussle.File{uid: uid, offset: 500, size: 123_456}
      config.cache.put(config.cache_name, uid, file)

      conn =
        test_conn(
          :get,
          %Plug.Conn{
            req_headers: [{"tus-resumable", Tussle.latest_version()}]
          },
          "/" <> uid
        )

      response = TestController.get(conn, %{"uid" => uid})

      # GET should return same headers as HEAD
      assert response.status == code(:ok)
      assert response |> get_resp_header("tus-resumable") == [Tussle.latest_version()]
      assert response |> get_resp_header("upload-offset") == ["#{file.offset}"]
      assert response |> get_resp_header("upload-length") == ["#{file.size}"]
      # Body is empty (same as HEAD)
      assert response.resp_body == ""
    end

    test "GET: returns 404 if upload not found (same as HEAD)" do
      conn =
        test_conn(
          :get,
          %Plug.Conn{
            req_headers: [{"tus-resumable", Tussle.latest_version()}]
          },
          "/nonexistent"
        )

      response = TestController.get(conn, %{"uid" => "nonexistent"})

      assert response.status == code(:not_found)
      assert response |> get_resp_header("tus-resumable") == [Tussle.latest_version()]
      assert response |> get_resp_header("upload-offset") == []
    end

    test "GET: includes Upload-Metadata header when present", context do
      config = context[:config]
      uid = "metadata-test"
      file = %Tussle.File{
        uid: uid,
        offset: 0,
        size: 1000,
        metadata_src: "filename dGVzdC50eHQ=,type dGV4dC9wbGFpbg=="
      }
      config.cache.put(config.cache_name, uid, file)

      conn =
        test_conn(
          :get,
          %Plug.Conn{
            req_headers: [{"tus-resumable", Tussle.latest_version()}]
          },
          "/" <> uid
        )

      response = TestController.get(conn, %{"uid" => uid})

      assert response |> get_resp_header("upload-metadata") == [file.metadata_src]
    end

    test "GET: includes Cache-Control and CDN-Cache-Control headers", context do
      config = context[:config]
      uid = "cache-test"
      file = %Tussle.File{uid: uid, offset: 0, size: 100}
      config.cache.put(config.cache_name, uid, file)

      conn =
        test_conn(
          :get,
          %Plug.Conn{
            req_headers: [{"tus-resumable", Tussle.latest_version()}]
          },
          "/" <> uid
        )

      response = TestController.get(conn, %{"uid" => uid})

      # Per TUS spec: prevent caching of HEAD/GET responses
      # CDN-Cache-Control is also set for CDNs like CloudFlare
      assert response |> get_resp_header("cache-control") == ["no-store"]
      assert response |> get_resp_header("cdn-cache-control") == ["no-store"]
    end
  end
end
