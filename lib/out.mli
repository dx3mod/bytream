(** Outgoing byte stream. *)

type t
(** The type for an outgoing byte stream. *)

val make : ?buf:Bstr.t -> (Slice_bstr.t -> unit) -> t
(** [make ?buf writer] creates an outgoing byte stream from [writer] with an
    internal buffer [buf].

    @raise Assert_failure if [buf] has length 0. *)

val of_channel : ?io_buffer_size:int -> out_channel -> t
(** [of_channel ?io_buffer_size oc] creates an outgoing byte stream that writes
    to the output channel [oc].

    Note: the output channel [oc] is {b not} closed when the stream is garbage
    collected. You must close it explicitly if needed. *)

val to_buffer : ?buf:bytes -> Buffer.t -> (t -> unit) -> unit
(** [to_buffer ?buf buffer f] creates an outgoing byte stream that writes to
    [buffer], which is populated by the function [f].

    The [buf] parameter defines the internal temporary buffer used for copying
    data between the outgoing byte stream and the buffer. *)

val to_string : (t -> unit) -> string
(** [to_string f] is similar to {!to_buffer} but returns a string. *)

(** {2 Buffering mechanism} *)

(** This section explains how to work with the buffering mechanism of outgoing
    byte streams for efficient streaming of large amounts of bytes. *)

val bytes_written : t -> int
(** [bytes_written out_stream] returns the total number of bytes written to the
    outgoing byte stream. *)

val bytes_available : t -> int
(** [bytes_available out_stream] returns the number of bytes available for
    writing in the internal buffer. *)

val buffer_size : t -> int
(** [buffer_size out_stream] returns the size of the internal buffer in bytes.
*)

exception Shifted_beyond_buffer

val shift : t -> int -> unit
(** [shift out_stream n] shifts the internal buffer offset by [n] bytes.

    @raise Shifted_beyond_buffer
      if [n] is negative or exceeds the available space in the internal buffer.
*)

val ensure_bytes : t -> int -> unit
(** [ensure_bytes out_stream len] ensures that at least [len] bytes are
    available in the internal buffer. If not enough space is available, the
    buffer is flushed first.

    @raise Assert_failure if [len] is negative or greater than {!buffer_size}.
*)

val ensure_slice : t -> int -> Slice_bstr.t
(** [ensure_slice out_stream len] is similar to {!ensure_bytes}, but it
    automatically shifts the internal buffer offset and returns a slice. *)

val ensure_buffer : t -> int -> Bstr.t
(** [ensure_buffer out_stream len] is similar to {!ensure_slice}, but returns a
    sub-buffer of the internal buffer instead of a slice. *)

val flush : t -> unit
(** [flush out_stream] flushes the outgoing byte stream. *)

val with_flush : t -> (unit -> 'a) -> 'a
(** [with_flush out_stream f] automatically flushes the outgoing byte stream
    after calling the function [f], even if [f] raises an exception. *)

(** {2 Output functions} *)

(** {3 Writing to buffers} *)

val output : t -> Bstr.t -> int -> int -> unit
(** [output out_stream buf off len] outputs [len] bytes from [buf] to the
    outgoing byte stream. *)

val really_output : t -> Bstr.t -> int -> int -> unit
(** [really_output out_stream buf off len] outputs [len] bytes from [buf] to the
    outgoing byte stream and {i flushes} it.

    See also {!output}. *)

val output_string : t -> string -> unit
(** [output_string out_stream s] outputs the string [s] to the outgoing byte
    stream. *)

val output_slice : t -> Slice_bstr.t -> unit
(** [output_slice out_stream slice] outputs [slice] to the outgoing byte stream.
*)

(** {3 Writing integer values} *)

val output_char : t -> char -> unit
(** [output_char out_stream c] outputs the character [c] to the outgoing byte
    stream. *)

val output_byte : t -> int -> unit
(** [output_byte out_stream b] outputs the 8-bit byte [b] to the outgoing byte
    stream. *)

val output_int8 : t -> int -> unit
(** [output_int8 out_stream n] outputs the signed 8-bit integer [n] to the
    outgoing byte stream. *)

val output_uint8 : t -> int -> unit
(** [output_uint8 out_stream n] outputs the unsigned 8-bit integer [n] to the
    outgoing byte stream. *)

val output_int16_be : t -> int -> unit
(** [output_int16_be out_stream n] outputs the signed 16-bit integer [n] in
    big-endian byte order to the outgoing byte stream. *)

val output_int16_le : t -> int -> unit
(** [output_int16_le out_stream n] outputs the signed 16-bit integer [n] in
    little-endian byte order to the outgoing byte stream. *)

val output_int16_ne : t -> int -> unit
(** [output_int16_ne out_stream n] outputs the signed 16-bit integer [n] in
    native byte order to the outgoing byte stream. *)

val output_uint16_be : t -> int -> unit
(** [output_uint16_be out_stream n] outputs the unsigned 16-bit integer [n] in
    big-endian byte order to the outgoing byte stream. *)

val output_uint16_le : t -> int -> unit
(** [output_uint16_le out_stream n] outputs the unsigned 16-bit integer [n] in
    little-endian byte order to the outgoing byte stream. *)

val output_uint16_ne : t -> int -> unit
(** [output_uint16_ne out_stream n] outputs the unsigned 16-bit integer [n] in
    native byte order to the outgoing byte stream. *)

val output_int32_be : t -> int32 -> unit
(** [output_int32_be out_stream n] outputs the signed 32-bit integer [n] in
    big-endian byte order to the outgoing byte stream. *)

val output_int32_le : t -> int32 -> unit
(** [output_int32_le out_stream n] outputs the signed 32-bit integer [n] in
    little-endian byte order to the outgoing byte stream. *)

val output_int32_ne : t -> int32 -> unit
(** [output_int32_ne out_stream n] outputs the signed 32-bit integer [n] in
    native byte order to the outgoing byte stream. *)

val output_int64_be : t -> int64 -> unit
(** [output_int64_be out_stream n] outputs the signed 64-bit integer [n] in
    big-endian byte order to the outgoing byte stream. *)

val output_int64_le : t -> int64 -> unit
(** [output_int64_le out_stream n] outputs the signed 64-bit integer [n] in
    little-endian byte order to the outgoing byte stream. *)

val output_int64_ne : t -> int64 -> unit
(** [output_int64_ne out_stream n] outputs the signed 64-bit integer [n] in
    native byte order to the outgoing byte stream. *)

(** {2 Stream transformation} *)

val transform : t -> (Slice_bstr.t -> Slice_bstr.t) -> t
(** [transform out_stream f] transforms the output of the outgoing byte stream
    using the function [f]. *)
