# Bytream

A streaming bytes and crunching them library.

This library contains angostic I/O runtime mechanisms for organization byte streams processing for write and read in an efficient manner, e.g. for buildings codecs and protocol implementations.

Features
* Byte-oriented processing of I/O via [slice]-based abstraction inspired by the [Bytesrw] library
* Gigabytes throughput with less memory allocation using fixed buffers and reuse exists
* Channels-like APIs make it possible to write natural OCaml code in a direct style

The library is inspired by projects like [Angstrom] and [Faraday], which address the challenge of analyzing and processing data. However, these projects come with a level of complexity and associated overhead that may not be suitable for smaller, more compact solutions.

That's why Bytream was created. It aims to work with binary data and formats in the most efficient way possible, using more transparent and effective methods.

## Quick start

You can install the `bytream` library using the [OPAM] package manager or any other method you prefer. If you are using [Dune], please add the `bytream` library to your dependencies.

### In use

Bytream provides you with two abstractions: one for input (`Bytream.In.t`), and the other for output data (`Bytream.Out.t`). Both use [Bigarray] under the hood to represent an array of bytes. The motivation for this choice is to avoid duplication and fix runtime when transferring this data to external functions.

Inheriting ideas from [Bytesrw], Bytream uses the mechanism of chunks to feed the stream.
An example illustrates the basic concept of chunking:
```ocaml
(* Queue as a byte chunk source. *)
let queue =
  let queue = Queue.create () in
  Queue.add "he" queue;
  (* ... *)
  Queue.add "d!" queue;
  queue
in

(* Reader function that returns chunks of text from the source. *)
let reader () =
  match Queue.take_opt queue with
  | None ->
    (** For close incoming byte stream, the reader 
        should raise an End_of_file exception. *)
    raise End_of_file
  | Some chunk -> Slice_bstr.of_string chunk
in

let in_stream = Bytream.In.make reader in 
Bytream.In.input_string in_stream 7
(* - : string = "hello w" *)
```

and alternative for outgoing byte stream.
```ocaml
(* Queue as a byte chunk sink. *)
let queue = Queue.create () in

(* Writer function that outputs chunks of text to the sink. *)
let writer slice =
  Queue.add Slice_bstr.(to_string slice) queue
in

Bytream.Out.make writer
```

In real cases, we will of course use channels, files, sockets, and other things to communicate with the outside world. And do it streaming.

```ocaml
let in_stream = Bytream.In.of_channel ic in 
(* for Unix.file_descr *)
let in_stream = Bytream_unix.In.of_fd fd in
(* or for Lwt... *)
let%lwt _ =
  let%lwt in_stream in Bytream_lwt.of_channel ic in
  (* ... *)
```

A bytream function looks similar to the channels API from OCaml.

```ocaml
module In = Bytream.In

let input_greeting_opt in_stream = 
  match In.input_string in_stream 7 with 
  | "Hello, " -> 
    let name = In.input_while ((<>) '!') in_stream in 
    assert (In.input_char in_stream = '!');
    Some name
  | _ -> None
```

For more details, see [API references](https://ocaml.org/p/bytream/latest/doc/index.html).


## Additions

The library provides you with extra modules (and packages) with useful features, such as compression/decompression streams, supports for different input/output runtimes and others.

Additions: `bytream.unix`, `bytream.lwt`, `bytream.ozstd`, `bytream.bin`.

### Binary encoder and decoders

[Bin] is a small library for encoding and decoding information from a buffer (like bytes or bigstrings). You can use it to encode and decode Bytream streams.

```ocaml
#require "bytream.bin";;

type point = { x : int; y : int }

let point = 
  let open Bin in 
  record (fun x y -> { x; y })
  |+ field neint16 (fun t -> t.x)
  |+ field neint16 (fun t -> t.y)
  |> sealr

let _ = 
  (* ... *)
  let p = Bytream_bin.In.input in_stream point in 
  Bytream_bin.Out.output out_stream { point with y = 100 }
```

### Zstandard compression and decompression 

```ocaml
#require "bytream.ozstd";;

let output_compressed_string out_stream = 
  let out_stream = Bytream_ozstd.Out.make ~compression_level:3 out_stream in 
  Bytream.Out.output_string out_stream "Cras pulvinar sollicitudin nulla quis tempor.";

let input_decompressed_line in_stream = 
  let in_stream = Bytream_ozstd.In.make in_stream in 
  Bytream.In.input_line in_stream
```

## Showcases

You can explore ecosystem libraries that use Bytream to better understand its applicability.

* [Rpmfile] is the library for reading and writing RPM packages has been ported from [Angstrom] since version 1.0.0;

## License

The project is licensed under [the MIT License](./LICENSE), which allows for all permissions.
Just use it and enjoy yourself without fear. We are always open to pull requests!


[Bytesrw]: https://github.com/dbuenzli/bytesrw
[Rpmfile]: https://github.com/dx3mod/rpmfile

[OPAM]: https://opam.ocaml.org/
[Dune]: https://dune.build

[Angstrom]: https://github.com/inhabitedtype/angstrom
[Faraday]: https://github.com/inhabitedtype/faraday

[Bigarray]: https://ocaml.org/manual/5.5/api/Bigarray.html
[slice]: https://ocaml.org/p/slice/latest
[Bin]: https://ocaml.org/p/bin/latest