# Bytream

A streaming bytes and crunching them library.

This library provides I/O-agnostic primitives for efficient, incremental byte stream processing. It's built specifically for creating codecs, binary parsers, and network protocols without needing to load the entire payload into memory.

**Features**

- Zero-copy semantics: byte-oriented I/O via a [Slice]-based abstraction (inspired by the [Bytesrw] library) that minimizes unnecessary data copying.
- Gigabyte-scale throughput: high processing speeds with minimal memory allocation, thanks to fixed, reusable internal buffers.
- Ergonomic API: channel-like interfaces let you write natural, direct-style code without the complexity of monadic parser combinators.

**Motivation**

While libraries like [Angstrom] and [Faraday] are great for complex parsing and serialization, they introduce combinator overhead and abstraction layers that can be overkill for simpler, performance-critical tasks.

That's where Bytream comes in. It gives you a transparent, low-level foundation for working directly with binary data, prioritizing raw speed and predictable memory usage over complex parsing DSLs.

## Quick start

You can install `bytream` via [OPAM]. If you're using [Dune], just add it to your project's dependencies.

### In use

Bytream provides two main abstractions: `Bytream.In.t` for reading and `Bytream.Out.t` for writing. Under the hood, both use `Bigarray` (via `Bstr.t`) to represent byte arrays. This eliminates data duplication and ensures seamless, zero-copy interop with C bindings and system calls.

Borrowing a concept from [Bytesrw], Bytream handles data in chunks. Here's a quick example of how chunking works in action:

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

In practice, you'll typically build streams from channels, file descriptors, or sockets.

```ocaml
(* Standard OCaml channels *)
let in_stream = Bytream.In.of_channel ic in

(* Unix file descriptors *)
let in_stream = Bytream_unix.In.of_fd fd in

(* Lwt asynchronous I/O *)
let in_stream = Bytream_lwt.In.of_channel ic in
```

The Bytream API is designed to feel familiar, closely mirrors the standard `In_channel` and `Out_channel` modules, but adds streaming capabilities.

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

## Additions

The core library is runtime-agnostic, but there are a few companion packages for specialized features like compression, alternative runtimes, and binary serialization.

Available packages: `bytream.unix`, `bytream.lwt`, `bytream.ozstd`, and `bytream.bin`.

### Declarative binary serialization

[Bin] is a lightweight library for encoding and decoding data to and from buffers. It plugs right into Bytream streams.

```ocaml
#require "bytream.bin";;

module Point = struct
  type t = { x : int; y : int }

  let codec =
    let open Bin in
    record (fun x y -> { x; y })
    |+ field neint16 (fun t -> t.x)
    |+ field neint16 (fun t -> t.y)
    |> sealr
end

let _ =
  (* Decode a point from an incoming byte stream *)
  let p = Bytream_bin.In.input in_stream Point.codec in
  (* Encode and write a modified point to an outgoing byte stream *)
  Bytream_bin.Out.output out_stream Point.codec Point.{ p with y = 100 }
```

### Zstandard compression

The `bytream.ozstd` package adds transparent compression and decompression streams.

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

For async I/O, the `bytream.lwt` package bridges [Lwt] channels with Bytream's incoming and outgoing byte streams. To keep this ergonomic, direct-style API without blocking the Lwt event loop, `Bytream_lwt` uses the [Lwt_direct] module.


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

Check out these ecosystem libraries using Bytream in the wild:

- [Rpmfile]: a library for reading and writing RPM packages. It was ported from [Angstrom] to Bytream in version 1.0.0, giving it a nice performance boost and a much lower memory footprint.
- [cpio-svr4]: a library for reading and writing CPIO (SVR4) archives. It was built from the ground up using Bytream.



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
[Lwt]: https://github.com/ocsigen/lwt
[Lwt_direct]: https://ocaml.org/p/lwt_direct/latest/doc/lwt_direct/Lwt_direct/index.html
[cpio-svr4]: https://github.com/dx3mod/cpio-svr4
