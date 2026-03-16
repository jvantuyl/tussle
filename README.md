# Tussle

[![Tests](https://github.com/jvantuyl/tussle/actions/workflows/main.yml/badge.svg)](https://github.com/jvantuyl/tussle/actions/workflows/main.yml)
[![Hex.pm](https://img.shields.io/hexpm/v/tussle.svg)](https://hex.pm/packages/tussle)
[![HexDocs](https://img.shields.io/badge/hex-docs-blue)](https://hexdocs.pm/tussle/)

An implementation of a *[tus](https://tus.io/)* **server** in Elixir

**Documentation: https://hexdocs.pm/tussle/**

> **tus** is a protocol based on HTTP for *resumable file uploads*. Resumable
> means that an upload can be interrupted at any moment and can be resumed without
> re-uploading the previous data again.
>
> An interruption may happen willingly, if the user wants to pause,
> or by accident in case of an network issue or server outage.

## About This Fork

This is a maintained fork of the original [`tus`](https://hex.pm/packages/tus) package. The package was renamed to **Tussle** to allow publishing updated versions to Hex without conflicting with the original (now unmaintained) package.

It's currently capable of accepting uploads with arbitrary sizes and storing them locally
on disk; or in Amazon S3, by installing the [`tus_storage_s3`](https://hex.pm/packages/tus_storage_s3) hex package.
Due to its modularization and extensibility, support for any other cloud provider can be easily added.

## Features

This library implements the core TUS API v1.0.0 protocol and the following extensions:

- Creation Protocol (http://tus.io/protocols/resumable-upload.html#creation). Deferring the upload's length is not possible.
- Termination Protocol (http://tus.io/protocols/resumable-upload.html#termination)
- Expiration Protocol (https://tus.io/protocols/resumable-upload.html#expiration)

## Installation

Add this repo to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:tussle, "~> 0.2.0"},
  ]
end
```

## Usage

**1. Add new controller(s)**

```elixir
defmodule DemoWeb.UploadController do
  use DemoWeb, :controller
  use Tussle.Controller

  # Optional callback before upload starts
  def on_begin_upload(file) do
    ...
    :ok  # or {:error, reason} to reject the upload
  end

  # Optional callback when upload completes
  def on_complete_upload(file) do
    ...
  end
end
```

**2. Add routes for each of your upload controllers**

```elixir
scope "/files", DemoWeb do
    options "/",          UploadController, :options
    match :head, "/:uid", UploadController, :head
    post "/",             UploadController, :post
    patch "/:uid",        UploadController, :patch
    delete "/:uid",       UploadController, :delete
end
```

**3. Add config for each controller (see next section)**

## Configuration

```elixir
# List all of your upload controllers
config :tussle, controllers: [DemoWeb.UploadController]

# Configuration for the DemoWeb.UploadController
config :tussle, DemoWeb.UploadController,
  storage: Tussle.Storage.Local,
  base_path: "priv/static/files/",

  # Optional: expire unfinished uploads after N seconds
  expiration_period: 300,

  cache: Tussle.Cache.Memory,

  # max supported file size, in bytes (default 20 MB)
  max_size: 1024 * 1024 * 20
```

- `storage`: module which handles file storage. This library includes `Tussle.Storage.Local`.
  Install the [`tus_storage_s3`](https://hex.pm/packages/tus_storage_s3) hex package for **Amazon S3** support.
- `expiration_period`: expire unfinished uploads after a specified number of seconds.
- `cache`: module for handling temporary upload metadata. This library includes `Tussle.Cache.Memory`.
  Install the [`tus_cache_redis`](https://hex.pm/packages/tus_cache_redis) hex package for **Redis** support.
- `max_size`: hard limit on the maximum size an uploaded file can have.

### Options for `Tussle.Storage.Local`

- `base_path`: where in the filesystem the uploaded files will be stored

## Acknowledgments

Thank you to the original author of this library and all the people who graciously published their improvements that I have integrated into this fork.

- **Juan-Pablo Scaletti** ([jpscaletti](https://github.com/jpsca)) -- original author
- **Pierre-Louis Gottfrois** ([gottfrois](https://github.com/gottfrois)) -- maintained the primary fork, merged community PRs
- **Marcin Koziej** ([marcinkoziej](https://github.com/marcinkoziej)) -- init_file callback, missing config handling, empty metadata fix
- **Davide Colombo** ([davec82](https://github.com/davec82)) -- expiration protocol, on_complete_upload result checking, empty metadata values
- **Zachary Kessin** ([zkessin](https://github.com/zkessin)) -- location prefix support
- **Stephen Solka** ([Clause-Logic](https://github.com/Clause-Logic)) -- storage provider offset control
- **Kevin Pan** ([feng19](https://github.com/feng19)) -- source_url fix
- **Ringo De Smet** ([ringods](https://github.com/ringods)) -- Storage behaviour, File typespecs, metadata as map
- **Alexander Buch** ([bucha](https://github.com/bucha)) -- multiple cache support
- **Joel Jucá** ([joeljuca](https://github.com/joeljuca)) -- mix.exs formatting fix

## Contributors

<!-- readme: jvantuyl,collaborators,contributors,sponsors,bots/- -start -->
<table>
	<tbody>
		<tr>
            <td align="center">
                <a href="https://github.com/jvantuyl">
                    <img src="https://avatars.githubusercontent.com/u/101?v=4" width="100;" alt="jvantuyl"/>
                    <br />
                    <sub><b>Jayson Vantuyl</b></sub>
                </a>
            </td>
            <td align="center">
                <a href="https://github.com/jpsca">
                    <img src="https://avatars.githubusercontent.com/u/67524204?v=4" width="100;" alt="jpsca"/>
                    <br />
                    <sub><b>Juan-Pablo Scaletti</b></sub>
                </a>
            </td>
            <td align="center">
                <a href="https://github.com/gottfrois">
                    <img src="https://avatars.githubusercontent.com/u/943784?v=4" width="100;" alt="gottfrois"/>
                    <br />
                    <sub><b>Pierre-Louis Gottfrois</b></sub>
                </a>
            </td>
            <td align="center">
                <a href="https://github.com/marcinkoziej">
                    <img src="https://avatars.githubusercontent.com/u/156725?v=4" width="100;" alt="marcinkoziej"/>
                    <br />
                    <sub><b>Marcin Koziej</b></sub>
                </a>
            </td>
            <td align="center">
                <a href="https://github.com/ringods">
                    <img src="https://avatars.githubusercontent.com/u/77923?v=4" width="100;" alt="ringods"/>
                    <br />
                    <sub><b>Ringo De Smet</b></sub>
                </a>
            </td>
            <td align="center">
                <a href="https://github.com/joeljuca">
                    <img src="https://avatars.githubusercontent.com/u/673884?v=4" width="100;" alt="joeljuca"/>
                    <br />
                    <sub><b>Joel Jucá</b></sub>
                </a>
            </td>
		</tr>
		<tr>
            <td align="center">
                <a href="https://github.com/feng19">
                    <img src="https://avatars.githubusercontent.com/u/2451508?v=4" width="100;" alt="feng19"/>
                    <br />
                    <sub><b>Kevin Pan</b></sub>
                </a>
            </td>
            <td align="center">
                <a href="https://github.com/zkessin">
                    <img src="https://avatars.githubusercontent.com/u/1738082?v=4" width="100;" alt="zkessin"/>
                    <br />
                    <sub><b>Zachary Kessin</b></sub>
                </a>
            </td>
            <td align="center">
                <a href="https://github.com/github-actions[bot]">
                    <img src="https://avatars.githubusercontent.com/in/15368?v=4" width="100;" alt="github-actions[bot]"/>
                    <br />
                    <sub><b>github-actions[bot]</b></sub>
                </a>
            </td>
		</tr>
	<tbody>
</table>
<!-- readme: jvantuyl,collaborators,contributors,sponsors,bots/- -end -->

## License

BSD-3-Clause. See [LICENSE](LICENSE) for details.
