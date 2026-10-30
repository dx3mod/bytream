# Bytream

[![Documentation](https://img.shields.io/badge/documentation-API-blue)](https://dx3mod.github.io/bytream/)

A streaming bytes and crunching them library.

This library provides agnostic I/O primitives for efficient, incremental byte stream processing. It is specifically designed for building codecs, binary parsers, and network protocol implementations without requiring the entire payload to fit in memory.

**Features**

* Zero-copy semantics: Byte-oriented I/O via a [Slice]-based abstraction, inspired by the [Bytesrw] library, minimizing unnecessary data copying.
* Gigabytes throughput: processing speeds with minimal memory allocation, leveraging fixed, reusable internal buffers.
* Ergonomic API: channel-like interfaces allow you to write natural, direct-style OCaml code without the complexity of monadic parser combinators.

**Motivation**

While libraries like [Angstrom] and [Faraday] excel at complex parsing and serialization, they introduce combinator overhead and abstraction layers that may be excessive for simpler, performance-critical tasks. 

Bytream was created to fill this gap. It provides a transparent, low-level, and highly efficient foundation for working directly with binary data, prioritizing raw speed and predictable memory usage over complex parsing DSLs.

## Quick start

You can install the library using the [OPAM] package manager. 
And if you are using [Dune], add `bytream` to the `(libraries ...)` field in your `dune` file.

### Core concepts

Bytream provides two primary abstractions: `Bytream.In.t` for reading, and `Bytream.Out.t` for writing. Under the hood, both use `Bigarray` (via `Bstr.t`) to represent byte arrays. This choice eliminates data duplication and ensures seamless, zero-copy interoperability with C-bindings and system calls.

Inheriting ideas from [Bytesrw], Bytream feeds the stream using chunks of data.
An example illustrates the basic concept of chunking:
```ocaml
(* A queue acting as a byte chunk source. *)
let queue =
  let q = Queue.create () in
  Queue.add "he" q;
  Queue.add "llo " q;
  Queue.add "world!" q;
  q

(* Reader function that returns chunks of text from the source. *)
let reader () =
  match Queue.take_opt queue with
  | None ->
      (* To close the incoming byte stream, the reader 
         must raise an End_of_file exception. *)
      raise End_of_file
  | Some chunk -> Slice_bstr.of_string chunk

let in_stream = Bytream.In.make reader in 
Bytream.In.input_string in_stream 7
(* - : string = "hello w" *)
```

and alternative for outgoing byte stream.
```ocaml
(* A queue acting as a byte chunk sink. *)
let queue = Queue.create () in

(* Writer function that outputs chunks of text to the sink. *)
let writer slice =
  Queue.add (Slice_bstr.to_string slice) queue

let out_stream = Bytream.Out.make writer in
Bytream.Out.output_string out_stream "Hello, world!";
Bytream.Out.flush out_stream
```

In real cases, you will typically connect streams to channels, file descriptors, or sockets.
```ocaml
(* Standard OCaml channels *)
let in_stream = Bytream.In.of_channel ic in 

(* Unix file descriptors *)
let in_stream = Bytream_unix.In.of_fd fd in

(* Lwt asynchronous I/O *)
let in_stream = Bytream_lwt.In.of_channel ic in
```

The Bytream API is intentionally designed to feel familiar, closely mirroring the standard In_channel and Out_channel modules, but with streaming capabilities:

```ocaml
module In = Bytream.In

let input_greeting_opt in_stream = 
  match In.input_string in_stream 7 with 
  | "Hello, " -> 
      let name = In.input_while ((<>) '!') in_stream in 
      (* Consume the '!' character *)
      let _ = In.input_char in_stream in
      Some name
  | _ -> None
```

For more details, see [API references](https://ocaml.org/p/bytream/latest/doc/index.html).

## Ecosystem & additions

The core library is runtime-agnostic, but several companion packages provide specialized features like compression, alternative runtimes, and binary serialization.

Available packages: `bytream.unix`, `bytream.lwt`, `bytream.ozstd`, `bytream.bin`.

### Declarative binary serialization 

[Bin] is a lightweight library for encoding and decoding data from buffers. It integrates seamlessly with Bytream streams.

```ocaml
#require "bytream.bin";;

type point = { x : int; y : int }

let point_codec = 
  let open Bin in 
  record (fun x y -> { x; y })
  |+ field neint16 (fun t -> t.x)
  |+ field neint16 (fun t -> t.y)
  |> sealr

let _ = 
  (* Decode a point from an input stream *)
  let p = Bytream_bin.In.input in_stream point_codec in 
  (* Encode and write a modified point to an output stream *)
  Bytream_bin.Out.output out_stream point_codec { p with y = 100 }
```

### Zstandard compression

The `bytream.ozstd` package provides transparent compression and decompression streams.

```ocaml
#require "bytream.ozstd";;

let output_compressed_string out_stream = 
  let compressed_stream = Bytream_ozstd.Out.make ~compression_level:3 out_stream in 
  Bytream.Out.output_string compressed_stream "Cras pulvinar sollicitudin nulla quis tempor.";
  Bytream.Out.flush compressed_stream

let input_decompressed_line in_stream = 
  let decompressed_stream = Bytream_ozstd.In.make in_stream in 
  Bytream.In.input_line decompressed_stream
```

### Lwt integration

For asynchronous I/O, Bytream provides the `bytream.lwt` package to bridge Lwt channels with Bytream's incoming and outgoing byte streams. To preserve this ergonomic, direct-style API without blocking the Lwt event loop, `Bytream_lwt` relies on the `Lwt_direct` module.

```ocaml
#require "bytream.lwt";;

open Lwt.Syntax

let () =
  Lwt_main.run
  @@
  let* ic = Lwt_io.open_file ~mode:Lwt_io.input "input.txt" in
  let* oc = Lwt_io.open_file ~mode:Lwt_io.output "output.txt" in

  let in_stream = Bytream_lwt.In.of_channel ic in
  let out_stream = Bytream_lwt.Out.of_channel oc in

  Lwt_direct.spawn begin fun () ->
      let line = Bytream.In.input_line in_stream in
      Bytream.Out.output_string out_stream (Option.get line);
      Bytream.Out.flush out_stream
    end
```

### Showcases

Explore ecosystem libraries that use Bytream to understand its real-world applicability:
- [Rpmfile]: a library for reading and writing RPM packages. It was successfully ported from [Angstrom] to Bytream in version a 1.0.0, resulting in improved performance and a significantly lower memory footprint.

## License

The project is licensed under [the MIT License](./LICENSE). Contributions, bug reports, and feature requests are always welcome!

[Bytesrw]: https://github.com/dbuenzli/bytesrw
[Rpmfile]: https://github.com/dx3mod/rpmfile

[OPAM]: https://opam.ocaml.org/
[Dune]: https://dune.build

[Angstrom]: https://github.com/inhabitedtype/angstrom
[Faraday]: https://github.com/inhabitedtype/faraday

[Bigarray]: https://ocaml.org/manual/5.5/api/Bigarray.html
[Slice]: https://ocaml.org/p/slice/latest
[Bin]: https://ocaml.org/p/bin/latest
