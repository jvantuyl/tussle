defmodule Tussle.Routes do
  @moduledoc """
  Provides a macro for defining TUS upload routes in a Phoenix router.

  This macro sets up all the routes needed for TUS resumable uploads, including
  the CloudFlare-compatible GET route for HEAD-to-GET conversion.

  ## Usage

      defmodule MyAppWeb.Router do
        use MyAppWeb, :router
        import Tussle.Routes

        scope "/api/xfer", MyAppWeb do
          pipe_through :api
          add_tus_routes UploadController
        end
      end

  ## Routes Defined

  | Method | Path | Action | Purpose |
  |--------|------|--------|---------|
  | OPTIONS | `/` | `:options` | Server capabilities |
  | POST | `/` | `:post` | Create new upload |
  | HEAD | `/:uid` | `:head` | Get upload metadata |
  | GET | `/:uid` | `:get` | CloudFlare HEAD-to-GET compatibility |
  | PATCH | `/:uid` | `:patch` | Upload chunk |
  | DELETE | `/:uid` | `:delete` | Cancel upload |

  ## CloudFlare Compatibility

  > **⚠️ Important Note**
  >
  > CloudFlare's caching layer converts HEAD requests to GET requests.
  > This unexpectedly violates the expectations of the TUS protocol, which
  > specifies HEAD for metadata retrieval. The conversion can cause requests
  > to not match HEAD routes, resulting in 404 errors.
  >
  > The `add_tus_routes/1` macro includes a GET route that mirrors HEAD behavior,
  > ensuring resumable uploads work correctly when behind CloudFlare or similar
  > CDNs. See `Tussle.get/2` for details.

  ## Alternative: Manual Route Definition

  If you need custom routing, you can define routes manually:

      scope "/files", MyAppWeb do
        pipe_through :api

        options "/",          UploadController, :options
        post "/",             UploadController, :post
        match :head, "/:uid",  UploadController, :head
        get "/:uid",           UploadController, :get   # CloudFlare compatibility
        patch "/:uid",         UploadController, :patch
        delete "/:uid",        UploadController, :delete
      end
  """

  defmacro add_tus_routes(controller) do
    quote do
      options "/", unquote(controller), :options
      post "/", unquote(controller), :post
      match :head, "/:uid", unquote(controller), :head
      get "/:uid", unquote(controller), :get
      patch "/:uid", unquote(controller), :patch
      delete "/:uid", unquote(controller), :delete
    end
  end
end
