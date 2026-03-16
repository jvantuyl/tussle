defmodule Tus.File do
  @enforce_keys [:uid]

  defstruct uid: nil,
            size: 0,
            offset: 0,
            prefix: "",
            metadata_src: nil,
            metadata: %{},
            created_at: nil,
            path: nil,
            parts: [],
            upload_id: nil

  @type t() :: %__MODULE__{
          uid: String.t(),
          size: integer(),
          offset: integer(),
          metadata_src: String.t(),
          metadata: map(),
          created_at: integer(),
          path: String.t(),
          parts: list(tuple()),
          upload_id: String.t()
        }
end
