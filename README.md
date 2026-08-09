# Bytream

A streaming bytes and crunching them library.

This library contains angostic I/O runtime mechanisms for organization byte streams processing for write and read in an efficient manner, e.g. for buildings codecs and protocol implementations.

Features
* Byte-oriented processing of I/O via slice-based abstraction inspired by the [Bytesrw] library
* Gigabytes throughput with less memory allocation using fixed buffers and reuse exists
* Channels-like APIs make it possible to write natural OCaml code in a direct style

The library is inspired by projects like [Angstrom] and [Faraday], which address the challenge of analyzing and processing data. However, these projects come with a level of complexity and associated overhead that may not be suitable for smaller, more compact solutions.

That's why `Bytream` was created. It aims to work with binary data and formats in the most efficient way possible, using more transparent and effective methods.


## Quick start

You can install the `bytream` library using the [OPAM] package manager or any other method you prefer.

```console
$ opam install bytream
```

You can also get the latest version of the upstream (developer) branch.
```console
$ opam pin serialport.dev https://github.com/dx3mod/serialport.git
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

In real cases, we will of course use channels, files, sockets, and other things to communicate with the outside world. And do it streaming.

```ocaml
match request with
| `Post "/archives/", body_stream ->
  (* The reader has its own internal buffer mechanism that allows it to bufferize 
     the contents of the body stream and decode them without copying chunks. *)
  let reader = Archive_reader.in_stream_of body_stream in
  let archive_meta =
    Bytream.In.make Archive_reader.(to_handler reader)
    |> Archive_reader.input_archive_without_contents 
  in

  let blob = Archive_reader.blob reader in 
  process_archive ~meta:archive_meta ~blob ()
  (* ... *)
```

<!-- ## Cookbook

... -->

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
