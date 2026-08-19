defmodule Tussle.PostTest do
  use ExUnit.Case, async: false
  import Plug.Conn
  doctest Tussle.Post

  import Plug.Conn.Status, only: [code: 1]
  import Tussle.TestHelpers, only: [test_conn: 2, test_conn: 4, get_config: 0]
  alias Tussle.TestController

  setup_all do
    %{config: get_config()}
  end

  test "`HTTP 413 Request Entity Too Large` if upload larger than the hard config limit",
       context do
    config = context[:config]

    conn =
      test_conn(:post, %Plug.Conn{
        req_headers: [
          {"tus-resumable", Tussle.latest_version()},
          {"upload-length", "#{config.max_size + 1}"}
        ]
      })

    response = TestController.post(conn)
    assert response.status == code(:request_entity_too_large)
    assert response |> get_resp_header("tus-resumable") == [Tussle.latest_version()]
  end

  test "`HTTP 413 Request Entity Too Large` if upload larger than a soft limit defined in the `Tus-Max-Size` header" do
    soft_limit = 1024

    conn =
      test_conn(:post, %Plug.Conn{
        req_headers: [
          {"tus-resumable", Tussle.latest_version()},
          {"upload-length", "#{soft_limit + 1}"},
          {"tus-max-size", "#{soft_limit}"}
        ]
      })

    response = TestController.post(conn)
    assert response.status == code(:request_entity_too_large)
    assert response |> get_resp_header("tus-resumable") == [Tussle.latest_version()]
  end

  test "hard config limit override the `Tus-Max-Size` soft limit", context do
    config = context[:config]

    conn =
      test_conn(:post, %Plug.Conn{
        req_headers: [
          {"tus-resumable", Tussle.latest_version()},
          {"upload-length", "#{config.max_size + 1}"},
          {"tus-max-size", "#{config.max_size + 10}"}
        ]
      })

    response = TestController.post(conn)
    assert response.status == code(:request_entity_too_large)
    assert response |> get_resp_header("tus-resumable") == [Tussle.latest_version()]
  end

  test "create a new upload", context do
    config = context[:config]
    size = 10

    conn =
      test_conn(:post, %Plug.Conn{
        req_headers: [
          {"tus-resumable", Tussle.latest_version()},
          {"upload-length", "#{size}"}
        ]
      })

    response = TestController.post(conn)

    assert response.status == code(:created)
    assert response |> get_resp_header("tus-resumable") == [Tussle.latest_version()]
    assert response |> get_resp_header("upload-offset") == []
    assert response |> get_resp_header("upload-length") == []

    location = response |> get_resp_header("location") |> List.first()
    assert location

    file = config.cache.get(config.cache_name, location |> Path.basename())
    assert file
    assert file.size == size

    File.rm_rf(config.base_path |> Path.expand())
  end

  test "create a new upload with expiration period enabled", context do
    config = context[:config]
    app_env = Application.get_env(:tussle, Tussle.TestController, [])

    new_app_env =
      app_env
      |> Keyword.update(:expiration_period, 300, fn _ -> 300 end)

    Application.put_env(:tussle, Tussle.TestController, new_app_env)
    size = 10

    conn =
      test_conn(:post, %Plug.Conn{
        req_headers: [
          {"tus-resumable", Tussle.latest_version()},
          {"upload-length", "#{size}"}
        ]
      })

    response = TestController.post(conn)

    assert response.status == code(:created)
    assert response |> get_resp_header("tus-resumable") == [Tussle.latest_version()]
    assert response |> get_resp_header("upload-offset") == []
    assert response |> get_resp_header("upload-length") == []

    [expire_at] = response |> get_resp_header("upload-expires")
    assert is_binary(expire_at)

    location = response |> get_resp_header("location") |> List.first()
    assert location

    file = config.cache.get(config.cache_name, location |> Path.basename())
    assert file
    assert file.size == size

    File.rm_rf(config.base_path |> Path.expand())

    on_exit(fn ->
      Application.put_env(:tussle, Tussle.TestController, app_env)
    end)
  end

  test "parse metadata" do
    metadata_src = "filename d29ybGRfZG9taW5hdGlvbl9wbGFuLnBkZg==,username YnJhaW4="

    expected = %{
      "filename" => "world_domination_plan.pdf",
      "username" => "brain"
    }

    assert Tussle.Post.parse_metadata(metadata_src) == expected
  end

  test "parse metadata with invalid spaces" do
    metadata_src = "filename  d29ybGRfZG9taW5hdGlvbl9wbGFuLnBkZg== , username YnJhaW4="

    expected = %{
      "filename" => "world_domination_plan.pdf",
      "username" => "brain"
    }

    assert Tussle.Post.parse_metadata(metadata_src) == expected
  end

  test "parse metadata with key followed by a space and empty value" do
    metadata_src = "filename ,username YnJhaW4="

    expected = %{
      "filename" => nil,
      "username" => "brain"
    }

    assert Tussle.Post.parse_metadata(metadata_src) == expected
  end

  test "parse metadata with only key" do
    metadata_src = "filename,username YnJhaW4="

    expected = %{
      "filename" => nil,
      "username" => "brain"
    }

    assert Tussle.Post.parse_metadata(metadata_src) == expected
  end

  test "create a new upload with metadata", context do
    config = context[:config]
    metadata_src = "filename d29ybGRfZG9taW5hdGlvbl9wbGFuLnBkZg==,username YnJhaW4="

    conn =
      test_conn(:post, %Plug.Conn{
        req_headers: [
          {"tus-resumable", Tussle.latest_version()},
          {"upload-length", "10"},
          {"upload-metadata", metadata_src}
        ]
      })

    uid =
      TestController.post(conn)
      |> get_resp_header("location")
      |> List.first()
      |> Path.basename()

    file = config.cache.get(config.cache_name, uid)

    expected = %{
      "filename" => "world_domination_plan.pdf",
      "username" => "brain"
    }

    assert file
    assert file.metadata_src == metadata_src
    assert file.metadata == expected

    File.rm_rf(config.base_path |> Path.expand())
  end

  test "on_begin_upload called", context do
    config = context[:config]

    TestController.post(
      test_conn(:post, %Plug.Conn{
        req_headers: [
          {"tus-resumable", Tussle.latest_version()},
          {"upload-length", "10"}
        ]
      })
    )

    # https://dockyard.com/blog/2016/03/24/testing-function-delegation-in-elixir-without-stubbing
    assert_receive :on_begin_upload_called

    File.rm_rf(config.base_path |> Path.expand())
  end

  test "init_file called with conn", context do
    config = context[:config]

    TestController.post(
      test_conn(:post, %Plug.Conn{
        req_headers: [
          {"tus-resumable", Tussle.latest_version()},
          {"upload-length", "10"}
        ]
      })
    )

    # https://dockyard.com/blog/2016/03/24/testing-function-delegation-in-elixir-without-stubbing
    assert_receive {:init_file, %Plug.Conn{}}

    File.rm_rf(config.base_path |> Path.expand())
  end

  defp creation_conn(body, headers) do
    test_conn(:post, %Plug.Conn{req_headers: headers}, "/", body)
  end

  defp offset_headers(size) do
    [
      {"tus-resumable", Tussle.latest_version()},
      {"upload-length", "#{size}"},
      {"content-type", "application/offset+octet-stream"}
    ]
  end

  defp uid_of(response) do
    response |> get_resp_header("location") |> List.first() |> Path.basename()
  end

  defp stored_path(config, uid) do
    Path.join([Path.expand(config.base_path), config.storage.get_path(uid), uid])
  end

  defp stored_files(config) do
    base = Path.expand(config.base_path)

    base
    |> Path.join("**/*")
    |> Path.wildcard()
    |> Enum.filter(&File.regular?/1)
    |> Enum.sort()
  end

  describe "creation-with-upload" do
    test "a complete body finishes the upload in one request", context do
      config = context[:config]
      body = "lorem ipsum sit amet 1234567890 this is a test"

      response =
        body
        |> creation_conn(offset_headers(byte_size(body)))
        |> TestController.post()

      assert response.status == code(:created)
      assert response |> get_resp_header("tus-resumable") == [Tussle.latest_version()]
      assert response |> get_resp_header("upload-offset") == ["#{byte_size(body)}"]

      uid = uid_of(response)
      assert_receive :on_complete_upload_called

      # Removed from the cache once complete, and written through to storage.
      refute config.cache.get(config.cache_name, uid)

      assert File.read!(stored_path(config, uid)) == body

      File.rm_rf(config.base_path |> Path.expand())
    end

    test "a partial body can be resumed with PATCH", context do
      config = context[:config]
      first = "lorem ipsum "
      rest = "sit amet"
      size = byte_size(first) + byte_size(rest)

      response =
        first
        |> creation_conn(offset_headers(size))
        |> TestController.post()

      assert response.status == code(:created)
      assert response |> get_resp_header("upload-offset") == ["#{byte_size(first)}"]

      uid = uid_of(response)
      assert config.cache.get(config.cache_name, uid).offset == byte_size(first)

      patched =
        test_conn(
          :patch,
          %Plug.Conn{
            req_headers: [
              {"tus-resumable", Tussle.latest_version()},
              {"upload-offset", "#{byte_size(first)}"},
              {"content-type", "application/offset+octet-stream"}
            ]
          },
          "/files/#{uid}",
          rest
        )
        |> TestController.patch(%{"uid" => uid})

      assert patched.status == code(:no_content)
      assert patched |> get_resp_header("upload-offset") == ["#{size}"]

      assert File.read!(stored_path(config, uid)) == first <> rest

      File.rm_rf(config.base_path |> Path.expand())
    end

    test "an empty body still reports an offset", context do
      config = context[:config]

      response =
        ""
        |> creation_conn(offset_headers(10))
        |> TestController.post()

      assert response.status == code(:created)
      assert response |> get_resp_header("upload-offset") == ["0"]
      assert config.cache.get(config.cache_name, uid_of(response)).offset == 0

      File.rm_rf(config.base_path |> Path.expand())
    end

    test "a body without the offset content type is ignored", context do
      config = context[:config]

      response =
        "this should not be stored"
        |> creation_conn([
          {"tus-resumable", Tussle.latest_version()},
          {"upload-length", "100"},
          {"content-type", "application/octet-stream"}
        ])
        |> TestController.post()

      assert response.status == code(:created)
      assert response |> get_resp_header("upload-offset") == []
      assert config.cache.get(config.cache_name, uid_of(response)).offset == 0

      File.rm_rf(config.base_path |> Path.expand())
    end

    test "a body larger than upload-length is rejected without creating the upload", context do
      config = context[:config]
      body = "lorem ipsum sit amet"
      before = stored_files(config)

      response =
        body
        |> creation_conn(offset_headers(byte_size(body) - 1))
        |> TestController.post()

      assert response.status == code(:request_entity_too_large)
      assert response |> get_resp_header("tus-resumable") == [Tussle.latest_version()]
      assert response |> get_resp_header("location") == []

      # Rejected before creation, so there is no orphan left to expire.
      assert stored_files(config) == before
    end

    test "the extension is advertised" do
      extensions =
        test_conn(:options, %Plug.Conn{})
        |> TestController.options()
        |> get_resp_header("tus-extension")
        |> List.first()
        |> String.split(",")

      assert "creation-with-upload" in extensions
    end
  end
end
