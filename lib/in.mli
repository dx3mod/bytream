(** Incoming bytes stream abstraction for processing byte sources on damage.

    {b Decode BSON's [int32] element}

    {[
    open Bytream

    let input_bson_int32_element in_stream =
      let ename = In.input_while ((<>) '\0') in_stream in
      let int32 = In.input_int32_be in_stream in

      Bson.Element (ename, Bson.Int32 int32)


    let input_bson_element in_stream =
      match In.input_byte in_stream with
      | (* ... *)
      | 16 -> input_bson_int32_element in_stream
    ]} *)

type t
(** Incoming byte stream. *)

and buffer =
  (char, Bigarray.int8_unsigned_elt, Bigarray.c_layout) Bigarray.Array1.t
(** Flatten bytes-oriented [Bigarray] buffer. *)

(** {1 Constructors} *)

val make : (unit -> buffer) -> t
(** [make acquire_chunk] construct incoming byte stream from reader function.

    @param acquire_chunk
      is a function that reads a chunk from any given source. If the chunk is
      empty, it is equivalent to {!End_of_file}. *)

val of_buffer : buffer -> t
(** [of_buffer buffer] construct byte stream from already complete buffer.

    {b Note}. An attempt to acquire a new chunk will cause an exception to be
    thrown. *)

val of_string : string -> t
(** [of_string string] same as {!of_buffer} but for [string] value.

    {b Note}. Keep in mind that the string will be copied! *)

val of_channel : ?buffer_size:int -> in_channel -> t
(** [of_channel ?buffer_size ic] construct incoming byte stream from
    [In_channel] value

    @param ?buffer_size by default is 4096 bytes *)

(** {1 Buffer manipulations} *)

val available_to_read : t -> int
(** [available_to_read in_stream] returns remaining bytes of current buffer that
    available to read. *)

val consume_bytes : t -> int -> unit
(** [consume_bytes in_stream len] consume [len] bytes from incoming bytes stream
    with [offset] shifting. *)

val ensure_chunk : t -> int -> buffer
(** [ensure_chunk in_stream len] returns {!buffer} value that guarantee have
    [len] bytes.

    @raise End_of_file if the [in_stream] was ended *)

val position : t -> int
(** [position in_stream] returns total read bytes from some source. *)

(** {1 Input} *)

val input : t -> buffer -> int -> int -> int
(** [input in_stream buffer off len] input streams's bytes into [buffer] and
    return actually batched bytes. *)

val input_bytes : t -> bytes -> int -> int -> int
(** [input_bytes in_stream bytes off len] same as {!section-input} but for
    {!bytes}. *)

val really_input : t -> buffer -> int -> int -> unit
(** [really_input in_stream buffer off len] input streams's bytes into [buffer]
    and grantees fill it.

    @raise End_of_file if [in_stream] not have enough bytes for input *)

val really_input_bytes : t -> bytes -> int -> int -> unit
(** [really_input_bytes in_stream bytes off len] same as {!really_input} but for
    {!bytes}. *)

(** {2 Substrings inputs} *)

val input_string : t -> int -> string
(** [input_string in_stream len] input [len]-sized string. *)

val input_while : ?max:int -> (char -> bool) -> t -> string
(** [input_while ?max p in_stream] input byte while [p] on the byte returns
    [true].

    @param ?max determined the maximum length of the input string *)

(** {2 Integers inputs} *)

(** Input bytes and decode them into integer values. *)

val input_char : t -> char
val input_int8 : t -> int
val input_uint8 : t -> int
val input_byte : t -> int
val input_int16_be : t -> int
val input_int16_ne : t -> int
val input_int16_le : t -> int
val input_uint16_be : t -> int
val input_uint16_ne : t -> int
val input_uint16_le : t -> int
val input_int32_be : t -> int32
val input_int32_ne : t -> int32
val input_int32_le : t -> int32
val input_int64_be : t -> int64
val input_int64_ne : t -> int64
val input_int64_le : t -> int64
