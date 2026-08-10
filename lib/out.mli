(** Outgoing bytes stream module for streaming bytes to a sink in chunks. *)

type t
(** Outgoing byte stream type. *)

include module type of Buffer_types_intf

(** {1 Construction} *)

val make : ?buffer_size:int -> (chunk -> unit) -> t
(** [make ?buffer_size writer]

    Construct an outgoing byte stream using the [writer] function to output
    chunks to a sink.

    @param writer
      Function that accepting a {!chunk} of {!buffer} that always has an offset
      of zero and a variable length. Therefore, for you, it is enough to match
      only the [buffer] and [length] fields.
      {[
      let writer (~buffer, ~length, ..) = (* ... *)
      ]}

    @param ?buffer_size by default is 4096 bytes

    {b Example}

    This example illustrates the basic concept of chunking.

    {[
    (* Queue as a byte chunk sink. *)
    let queue = Queue.create () in

    (* Writer function that outputs chunks of text to the sink. *)
    let writer (~buffer, ~length:len, ..) =
      Queue.add Bstr.(sub_string ~off:0 ~len buffer) queue
    in

    Bytream.Out.make writer
    ]} *)

val of_channel : ?io_buffer_size:int -> out_channel -> t
(** [of_channel ?io_buffer_size oc] make an outgoing stream from the [channel].

    {b Note}. You can disable internal buffering for the channels to get the
    expected behavior: [Out_channel.set_buffered oc false v]. *)

(** {3 Withing into} *)

val with_into_buffer : Buffer.t -> (t -> unit) -> unit
(** [with_into_string f] make a stream that outgoing to buffer. *)

val with_into_string : (t -> unit) -> string
(** [with_into_string f] make a stream that outgoing to buffer and returns
    [string] value. *)

(** {1 Buffering mechanism} *)

val available_to_write : t -> int
(** [available_to_write out_stream]

    @return Number of bytes that have not been written to the internal buffer.
*)

(* exception Shifted_beyond_buffer *)

val shift : t -> int -> unit
(** [shift out_stream n]

    Shift the {!buffer}'s offset by [n] bytes to account for the written bytes.

    @raise Shifted_beyond_buffer if [n] is more than available space to write *)

val ensure_writable_bytes_at : t -> int -> int
(** [writable_guard_bytes_at out_stream len]

    Guarantees that the {!buffer} has enough space to write [len] bytes into it.

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
(** [output out_stream buffer off len]

    Output the [buffer] into outgoing byte stream. *)

val output_string : t -> string -> unit
(** [output out_stream string]

    Output the [string] into outgoing byte stream. *)

val really_output : t -> buffer -> int -> int -> unit
(** [output out_stream buffer off len]

    Output the [buffer] into outgoing byte stream with {i flushing}. *)

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
