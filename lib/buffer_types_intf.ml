(* Just types with documentations for .mli files *)

type buffer =
  (char, Bigarray.int8_unsigned_elt, Bigarray.c_layout) Bigarray.Array1.t
(** Flatten bytes-oriented [Bigarray] buffer.

    {b Note}. The rationale for using bytes instead of BA is to transparently
    transfer memory between the OCaml runtime and external functions, which are
    necessary for working with input/output. *)

and chunk = buffer:buffer * offset:int * length:int
(** A byte chunk is a non-empty consecutive range of bytes in a {!buffer} value.
*)
