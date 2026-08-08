# Bytream

A streaming bytes and crunching them library.

This library contains angostic I/O runtime mechanisms for organization byte streams processing for write and read in an efficient manner, e.g. for buildings codecs and protocol implementations.

Features
* Byte-oriented processing of I/O via slice-based abstraction inspired by the [Bytesrw] library
* Gigabytes throughput with less memory allocation using fixed buffers
* Channels-like APIs make it possible to write natural OCaml code in a direct style

## License

The project is licensed under [the MIT License](./LICENSE), which allows for all permissions.
Just use it and enjoy yourself without fear. We are always open to pull requests!


[Bytesrw]: https://github.com/dbuenzli/bytesrw