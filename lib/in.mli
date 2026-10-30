(** Incoming byte stream. *)

type t
(** The type for an incoming byte stream. *)

val make : ?overlap_buffer:Bstr.t -> (unit -> Slice_bstr.t) -> t
(** [make ?overlap_buffer reader] creates an incoming byte stream from the
    [reader] with the [overlap_buffer].

    @param reader
      Slices reader from any source. It raises the [End_of_file] exception when
      the end of the source is reached.

    @param overlap_buffer
      Buffer to resolve data gaps between slices, which are used to provide
      linear memory buffers. By default, it is allocated with 0xFF bytes size.

    {b Note}. The buffer within a slice is made available to third parties for a
    limited period of time during which the chunk is considered valid for
    reading or writing (or both).

    @raise Assert_failure if [overlap_buffer] is provided and has length 0. *)

val with_overlap_buffer : t -> Bstr.t -> t
(** [with_overlap_buffer in_stream overlap_buffer] recreates the [in_stream]
    with [overlap_buffer] buffer. *)

val of_bigstring : Bstr.t -> t
(** [of_bigstring buffer] creates an incoming byte stream from an already
    allocated [buffer]. *)

val of_string : string -> t
(** [of_string source] creates an incoming byte stream from a copy of [source]
    string. *)

val of_channel : ?io_buffer_size:int -> in_channel -> t
(** [of_channel ?io_buffer_size ic] creates an incoming byte stream by reading
    from the input channel. *)

(** {2 Buffering mechanism} *)

(** This section explains how to work with the buffering mechanism of incoming
    byte streams for efficient processing of large amounts of bytes.

    You should understand that an incoming byte stream does not copy incoming
    slices gotten from [reader]. The stream uses them until a new slice is
    needed. *)

val bytes_read : t -> int
(** [bytes_read in_stream] returns the total number of bytes read from the
    reader. *)

val bytes_available : t -> int
(** [bytes_available in_stream] returns the number of remaining bytes to read
    from the internal buffer. *)

val peek_slice : t -> Slice_bstr.t
(** [peek_slice in_stream] returns the internal buffer state without advancing
    the offset. *)

val consume_bytes : t -> int -> unit
(** [consume_bytes in_stream n] consumes [n] bytes from the incoming byte
    stream.

    @raise End_of_file if the stream ends before [n] bytes are consumed. *)

val shift : t -> int -> unit
(** [shift in_stream n] advances the internal buffer offset by [n] bytes.

    @raise Invalid_argument if [n] is negative or exceeds available bytes. *)

(** {3 Ensure necessary buffer length} *)

val ensure_bytes : t -> int -> unit
(** [ensure_bytes in_stream len] ensures that at least [len] bytes are available
    in the internal buffer.

    @param len
      The number must be equal to or less than the internal overlap buffer
      length.

    @raise Assert_failure
      if [len] is negative or greater than the overlap buffer size.
    @raise End_of_file if the stream ends before [len] bytes are available. *)

val ensure_slice : t -> int -> Slice_bstr.t
(** [ensure_slice in_stream len] is similar to {!ensure_bytes}, but it
    automatically advances the offset and returns a slice of the ensured length.
*)

val ensure_buffer : t -> int -> Bstr.t
(** [ensure_buffer in_stream len] is similar to {!ensure_bytes}, but it
    automatically advances the offset and returns a sub-buffer of the ensured
    length. *)

(** {2 Input functions} *)

(** {3 Reading into buffers} *)

val input_slice : t -> Slice_bstr.t
(** [input_slice in_stream] inputs all available bytes of the internal buffer.

    @raise End_of_file if the stream is already at the end. *)

val input : t -> Bstr.t -> int -> int -> int
(** [input in_stream buf off len] inputs up to [len] bytes from the incoming
    byte stream into [buf], and returns the number of bytes actually read.

    Similar to {!In_channel.input}.

    {b Note}. Use [ensure_] functions instead to avoid unnecessary allocations.

    @raise End_of_file if the stream is already at the end. *)

val really_input : t -> Bstr.t -> int -> int -> unit
(** [really_input in_stream buf off len] inputs exactly [len] bytes from the
    incoming byte stream into [buf].

    @raise End_of_file if the stream ends before [len] bytes are read. *)

val input_bytes : t -> bytes -> int -> int -> int
(** [input_bytes in_stream buf off len] is similar to {!input} but for [bytes]
    type. *)

val really_input_bytes : t -> bytes -> int -> int -> unit
(** [really_input_bytes in_stream buf off len] is similar to {!really_input} but
    for [bytes] type. *)

(** {3 Reading into strings} *)

val input_string : t -> int -> string
(** [input_string in_stream len] inputs a string of [len] bytes from the
    incoming byte stream.

    @raise End_of_file if the stream ends before [len] bytes are read. *)

val input_line : t -> string option
(** [input_line in_stream] inputs a line from the incoming byte stream,
    stripping the trailing newline character(s). Returns [None] if the stream is
    at the end and the buffer is empty. *)

(** {3 Reading while} *)

val input_while_to_buffer :
  max_len:int -> Buffer.t -> (char -> bool) -> t -> unit
(** [input_while_to_buffer ~max_len buffer p in_stream] inputs characters into
    [buffer] while [p] returns [true] and at most [max_len] characters have been
    read. *)

val input_while : ?max_len:int -> (char -> bool) -> t -> string
(** [input_while ?max_len predicate in_stream] is similar to
    {!input_while_to_buffer} but returns a string. *)

val input_while' : max_len:int -> (char -> bool) -> t -> string
(** [input_while' ~max_len predicate in_stream] is similar to {!input_while} but
    consumes remaining bytes up to [max_len]. Ideal for inputting fixed-size C
    string fields in some binary formats. *)

(** {3 Input combinators} *)

val take : int -> (t -> 'a) -> t -> 'a list
(** [take n input in_stream] calls [input] [n] times and returns the result
    list.

    @raise End_of_file if the stream ends before [n] values are read. *)

val with_size : (t -> 'a) -> t -> 'a * int
(** [with_size input in_stream] returns the result of [input] and the number of
    bytes that were read.

    {b Example}

    {[
    let section, section_size = Bytream.In.with_size input_section in_stream in
    (* ... *)
    ]} *)

val many : (t -> 'a option) -> t -> 'a list
(** [many input in_stream] repeatedly calls [input] until it returns [None] or
    raises [End_of_file]. *)

(** {3 Reading integer values} *)

val input_char : t -> char
(** [input_char in_stream] reads a character from the incoming byte stream. *)

val input_byte : t -> int
(** [input_byte in_stream] reads an 8-bit byte from the incoming byte stream. *)

val input_int8 : t -> int
(** [input_int8 in_stream] reads a signed 8-bit integer from the incoming byte
    stream. *)

val input_uint8 : t -> int
(** [input_uint8 in_stream] reads an unsigned 8-bit integer from the incoming
    byte stream. *)

val input_int16_be : t -> int
(** [input_int16_be in_stream] reads a signed 16-bit integer in big-endian byte
    order from the incoming byte stream. *)

val input_int16_le : t -> int
(** [input_int16_le in_stream] reads a signed 16-bit integer in little-endian
    byte order from the incoming byte stream. *)

val input_int16_ne : t -> int
(** [input_int16_ne in_stream] reads a signed 16-bit integer in native byte
    order from the incoming byte stream. *)

val input_uint16_be : t -> int
(** [input_uint16_be in_stream] reads an unsigned 16-bit integer in big-endian
    byte order from the incoming byte stream. *)

val input_uint16_le : t -> int
(** [input_uint16_le in_stream] reads an unsigned 16-bit integer in
    little-endian byte order from the incoming byte stream. *)

val input_uint16_ne : t -> int
(** [input_uint16_ne in_stream] reads an unsigned 16-bit integer in native byte
    order from the incoming byte stream. *)

val input_int32_be : t -> int32
(** [input_int32_be in_stream] reads a signed 32-bit integer in big-endian byte
    order from the incoming byte stream. *)

val input_int32_le : t -> int32
(** [input_int32_le in_stream] reads a signed 32-bit integer in little-endian
    byte order from the incoming byte stream. *)

val input_int32_ne : t -> int32
(** [input_int32_ne in_stream] reads a signed 32-bit integer in native byte
    order from the incoming byte stream. *)

val input_int64_be : t -> int64
(** [input_int64_be in_stream] reads a signed 64-bit integer in big-endian byte
    order from the incoming byte stream. *)

val input_int64_le : t -> int64
(** [input_int64_le in_stream] reads a signed 64-bit integer in little-endian
    byte order from the incoming byte stream. *)

val input_int64_ne : t -> int64
(** [input_int64_ne in_stream] reads a signed 64-bit integer in native byte
    order from the incoming byte stream. *)
