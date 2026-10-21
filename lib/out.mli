(** Outgoing byte stream. *)

type t
(** The type for outgoing byte stream. *)

val make : ?buf:Bstr.t -> (Slice_bstr.t -> unit) -> t
(** [make ?buf writer] creates an outgoing byte stream from [writer] with an
    internal [buf] buffer. *)

val of_channel : ?io_buffer_size:int -> out_channel -> t
(** [of_channel ?io_buffer_size oc] creates an outgoing byte stream by writing
    into the output channel. *)

val to_buffer : ?buf:bytes -> Buffer.t -> (t -> unit) -> unit
(** [to_buffer ?buf buffer f] creates an outgoing byte stream to the [buffer],
    which is filled by the [f] function.

    The [buf] parameter defines the internal temporal buffer for copying between
    the outgoing byte stream and the buffer. *)

val to_string : (t -> unit) -> string
(** [to_string f] is similar to {!to_buffer} function but returns an string. *)

(** {2 Buffering mechanism} *)

val buffer_size : t -> int
(** [buffer_size out_stream] returns the number of the size of the internal
    buffer. *)

exception Shifted_beyond_buffer

val bytes_available : t -> int
(** [bytes_available out_stream] returns the number of bytes available to write
    into the internal buffer. *)

val shift : t -> int -> unit
(** [shift out_stream n] shifts the internal buffer offset on [n] bytes. *)

val ensure_bytes : t -> int -> unit
(** [ensure_bytes out_stream len] ensures the [len] bytes of the internal buffer
    length. *)

val ensure_slice : t -> int -> Slice_bstr.t
(** [ensure_bytes_at out_stream len] is similar to the {!ensure_bytes} function,
    but it automatically advances and returns an slice. *)

val flush : t -> unit
(** [flush out_stream] flushes the outgoing byte stream. *)

val with_flush : t -> (unit -> 'a) -> 'a
(** [with_flush out_stream f] automatic flushes the outgoing byte stream after
    call the [f] function. *)

(** {2 Outputs} *)

(** {3 Outputs into buffers} *)

val output : t -> Bstr.t -> int -> int -> unit
(** [output out_stream buf off len] outputs the [len] bytes from the [buffer]
    into the outgoing byte stream. *)

val really_output : t -> Bstr.t -> int -> int -> unit
(** [output out_stream buf off len] outputs the [len] bytes from the [buffer]
    into the outgoing byte stream with {i flushing}.

    See also {!output} function. *)

val output_string : t -> string -> unit
(** [output_string out_stream s] outputs the [s] string into the outgoing byte
    stream. *)

val output_slice : t -> Slice_bstr.t -> unit
(** [output_string out_stream s] outputs the [slice] into the outgoing byte
    stream. *)

(** {3 Outputs integer values} *)

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

(** {2 Stream transforming} *)

val transform : t -> (Slice_bstr.t -> Slice_bstr.t) -> t
(** [transform out_stream f] transforms the outgoing stream output via [f]
    functions. *)
