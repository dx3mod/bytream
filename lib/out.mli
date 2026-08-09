(** Outgoing bytes stream abstraction for streaming to sink. *)

type t
(** Outgoing byte stream. *)

and buffer =
  (char, Bigarray.int8_unsigned_elt, Bigarray.c_layout) Bigarray.Array1.t

(** {1 Constructors} *)

val make : ?buffer_size:int -> (buffer -> unit) -> t
(** [make ?buffer_size output_buffer] construct an outgoing byte stream using an
    output function to some sink.

    @param ?buffer_size by default is 4096 bytes *)

val of_channel : ?buffer_size:int -> out_channel -> t
(** [of_channel ?buffer_size oc] make an outgoing stream from the [channel].

    {b Note}. You can disable internal buffering for the channels to get the
    expected behavior: [Out_channel.set_buffered oc false v]. *)

(** {3 Withing} *)

val with_into_string : (t -> unit) -> string
(** [with_into_string f] make a stream that outgoing to buffer and returns
    [string] value. *)

(** {1 Buffer manipulations} *)

val available_to_write : t -> int
(** [available_to_write out_stream] returns the number of bytes that have not
    been written to the internal buffer. *)

val shift_written_bytes : t -> int -> unit
(** [shift_written_bytes out_stream] the buffer's offset is shifted by [len]
    bytes to account for written bytes. *)

val writable_guard_bytes_at : t -> int -> int
(** [writable_guard_bytes_at out_stream len] function guarantees that the buffer
    has enough space to write [len] bytes into it.

    @return the buffer's offset

    {b Example}

    {[
    let write_hello_record out_stream hello =
      let off = Out.writable_guard_bytes_at out_stream 6 in
      Out.output_byte out_stream 5;
      Out.output_string out_stream "hello"
    ]} *)

(** {3 Flushing} *)

val flush : t -> unit
(** [flush out_stream] flush outgoing stream to sink. *)

val with_flush : t -> (unit -> unit) -> unit
(** [with_flush out_stream f] same as {!section-flush} but with with-function.
*)

(** {1 Output} *)

val output : t -> buffer -> int -> int -> unit
(** [output out_stream buffer off len] write the [buffer] into outgoing byte
    stream. *)

val output_string : t -> string -> unit
(** [output out_stream string] write the [string] into outgoing byte stream. *)

val really_output : t -> buffer -> int -> int -> unit
(** [output out_stream buffer off len] write the [buffer] into outgoing byte
    stream with {i flushing}. *)

(** {3 Integer values outputting} *)

val output_char : t -> char -> unit
val output_byte : t -> int -> unit
val output_int8 : t -> int -> unit
val output_uint8 : t -> int -> unit
val output_int16_be : t -> int -> unit
val output_int16_le : t -> int -> unit
val output_int16_ne : t -> int -> unit
val output_uint16_be : t -> int -> unit
val output_uint16_le : t -> int -> unit
val output_uint16_ne : t -> int -> unit
val output_int32_be : t -> int32 -> unit
val output_int32_le : t -> int32 -> unit
val output_int32_ne : t -> int32 -> unit
val output_int64_be : t -> int64 -> unit
val output_int64_le : t -> int64 -> unit
val output_int64_ne : t -> int64 -> unit
