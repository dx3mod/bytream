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
# The latest stable version
$ opam install bytream

# The most recent developer version
$ opam install bytream.dev https://github.com/dx3mod/bytream
```

**For Dune users**

Add `bytream` to a `libraries` stanza in your Dune file, please.

### In use


Bytream provides you with two abstractions: one for input (`Bytream.In.t`), and the other for outputting data (`Bytream.Out.t`). Both use [Bigarray] under the hood to represent an array of bytes. The motivation for this choice is to avoid duplication and fix runtime when transferring this data to external functions.

Inheriting ideas from [Bytesrw], Bytream uses the mechanism of chunks to feed the stream.

For demonstrate this concept see an example of how to construct an incoming byte stream from a queue:
```ocaml
let queue = 
  let queue = Queue.create () in 
  Queue.add "he" queue;
  (* ... *)
  Queue.add "d!" queue;
  queue
in

let in_stream = 
  Bytream.In.make @@ fun () -> 
    Queue.take queue |> Bstr.of_string
in

Bytream.In.input_string in_stream 7
(* - : string = "hello w" *)
```

and equivalent for outgoing byte stream:
```ocaml
let queue = Queue.create () in 
let out_stream = Bytream.Out.make @@ fun chunk ->
  Queue.add Bstr.(to_string chunk) queue
in

Bytream.Out.output_string out_stream "hel";
(* ... *)
Bytream.Out.output_string out_stream "!\n";

Bytream.Out.flush out_stream;
Queue.iter print_string queue
(* hello world! *)
```

In real cases, we will of course use channels, files, sockets, and other things to communicate with the outside world. And do it streaming.

```ocaml
let read_cpio_archive ic = 
  let in_stream = Bytream.of_channel ic in 
  Cpio.input_archive in_stream
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

[Angstrom]: https://github.com/inhabitedtype/angstrom
[Faraday]: https://github.com/inhabitedtype/faraday

[Bigarray]: https://ocaml.org/manual/5.5/api/Bigarray.html