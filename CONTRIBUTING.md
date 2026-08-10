# Contributing

Nice to see you! xD

Bytream is a project that manipulates bytes and performs other low-level operations. It should be as efficient and fast as possible, since libraries like Bytstream are fundamental to the ecosystem (i.e., they form the basic layer of abstraction).

We are always open to pull requests that improve the performance, minimize memory allocations, and remove unnecessary bound checks and other checks in the library's code!

### References

When designing Bytream, we used the following libraries from the ecosystem as a reference. To understand the design decisions, it is helpful to familiarize yourself with these libraries.

* [Bigstringaf](https://github.com/inhabitedtype/bigstringaf) &mdash; Bigstring intrinsics and fast blits based on memcpy/memmove
  * [Angstrom](https://github.com/inhabitedtype/angstrom) &mdash; parser combinators built for speed and memory efficiency
  * [Faraday](https://github.com/inhabitedtype/faraday) &mdash; serialization library built for speed and memory efficiency
* [Cstruct](https://github.com/mirage/ocaml-cstruct) &mdash; map OCaml arrays onto C-like structs
* [Bstr](https://github.com/robur-coop/bstr) &mdash; a synthetic library for bigstrings
* [Bytesrw](https://erratique.ch/software/bytesrw) &mdash; Composable byte stream readers and writers for OCaml
* [Iostream](https://ocaml.org/p/iostream/latest) &mdash; generic, composable IO input and output streams





