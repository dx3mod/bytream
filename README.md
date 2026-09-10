# Bytream

A streaming bytes and crunching them library.

This library contains angostic I/O runtime mechanisms for organization byte streams processing for write and read in an efficient manner, e.g. for buildings codecs and protocol implementations.

Features
* Byte-oriented processing of I/O via slice-based abstraction inspired by the [Bytesrw] library
* Gigabytes throughput with less memory allocation using fixed buffers and reuse exists
* Channels-like APIs make it possible to write natural OCaml code in a direct style

The library is inspired by projects like [Angstrom] and [Faraday], which address the challenge of analyzing and processing data. However, these projects come with a level of complexity and associated overhead that may not be suitable for smaller, more compact solutions.

That's why Bytream was created. It aims to work with binary data and formats in the most efficient way possible, using more transparent and effective methods.


## Quick start

You can install the `bytream` library using the [OPAM] package manager or any other method you prefer.

```console
$ opam install bytream
```

You can also get the latest version of the upstream (developer) branch.
```console
$ opam pin bytream.dev https://github.com/dx3mod/bytream.git
```

If you are using [Dune], please add the `bytream` library to your dependencies.

### In use

Bytream provides you with two abstractions: one for input (`Bytream.In.t`), and the other for outputting data (`Bytream.Out.t`). Both use [Bigarray] under the hood to represent an array of bytes. The motivation for this choice is to avoid duplication and fix runtime when transferring this data to external functions.

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
        should raise an End_of_file exception.  *)
    raise End_of_file
  | Some chunk -> Bstr.of_string chunk
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
let writer (~buffer, ~length:len, ..) =
  Queue.add Bstr.(sub_string ~off:0 ~len buffer) queue
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
let input_greeting_opt in_stream = 
  match In.input_string in_stream 7 with 
  | "Hello, " -> 
    let name = In.input_while ((<>) '!') in_stream in 
    assert (In.input_char in_stream = '!');
    Some name
  | _ -> None
```

For more details, see [API references](https://ocaml.org/p/bytream/latest/doc/index.html).


## Guidelines

This section describes some recommendations and idiomatic approaches for writing good code using the Bytream library.

### Naming

**Streams naming**. Use the `in_stream` name for incoming bytes stream (`ByteStream.In.t`) and the `out_stream` name to outgoing bytes stream (`BytesStream.Out.t`).

**Processing streams function naming**. Use the `input_` prefix for functions that work with incoming byte streams, and the `output_` prefix to functions that work on outgoing byte streams.

**End-user function naming**. Use the `from_` prefix for functions that read from and decode data from some source (e.g. `Tar_archive.from_channel`). Use the `into_` prefix for functions that encode data and write it to some sink.

**Short aliases for modules.** Use `module In = Bytream.In` or `module Out = Bytream.Out` in your code.

### Effective decoding of a stream

You can use typical input functions, but their sequential use can make performance less efficient than it could be.

Not actually effective:
```ocaml
let input_packet in_stream = 
  let version = input_version in_stream in 
  (* ... *)
  let checksum = input_checksum in_stream in 
```

**Use** `ensure_` functions and manual, or like bin libraries, to unpack raw bytes into OCaml values.

```ocaml
let input_packet in_stream =
  let ~buffer, ~offset, .. = In.ensure_chunk in_stream 12 in
  let version = Bstr.get_int32_be buffer offset in
  (* ... *)
  let checksum = Bstr.get_uint8 buffer (offset + 11) in
```

## Additionals

The library provides you with extra modules with useful features, such as compressors, support for different input/output runtimes and others.

Additionals: `bytream.unix`, `bytream.lwt`.

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
