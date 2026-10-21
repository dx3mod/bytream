(** Incoming byte stream. *)

type t
(** The type for incoming byte stream. *)

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
    reading or writing (or both). *)

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

(** The section explains how to work with incoming byte stream's buffering
    mechanism for effective processing bytes massive.

    You should understand, an incoming byte stream not copying incoming slices
    gotten from [reader]. The stream use it until not be gotten new slice when
    it be needed. *)

val bytes_received : t -> int
(** [bytes_received in_stream] returns the total number of bytes received from
    the reader. *)

val bytes_available : t -> int
(** [bytes_available in_stream] returns the number of remaining bytes to read
    from the internal buffer. *)

val peek_slice : t -> Slice_bstr.t
(** [peek_slice in_stream] returns the internal buffer state. *)

val consume_bytes : t -> int -> unit
(** [consume_bytes in_stream n] consumes the [n] bytes from the incoming byte
    stream. *)

val advance_offset : t -> int -> unit
(** [advance_offset in_stream offset] advances the internal buffer offset.

    See also {!consume_bytes} function. *)

(** {3 Ensure necessary buffer length} *)

val ensure_bytes : t -> int -> unit
(** [ensure_bytes in_stream len] ensures the [len] bytes of the internal buffer
    length.

    @param len
      The number must be equal to or less than the internal overlap buffer
      length.

    @raise End_of_file if the [in_stream] was ended *)

val ensure_slice : t -> int -> Slice_bstr.t
(** [ensure_slice in_stream len] is similar to the {!ensure_bytes} function, but
    it automatically advances and returns a slice of the ensured length. *)

val ensure_buffer : t -> int -> Bstr.t
(** [ensure_buffer in_stream len] is similar to the {!ensure_bytes} function,
    but it automatically advances and returns a buffer of the ensured length. *)

(** {2 Inputs} *)

(** {3 Inputs into buffers} *)

val input_slice : t -> Slice_bstr.t
(** [input_slice in_stream] inputs all available bytes of the internal buffer.

    @raise End_of_file if the [in_stream] was ended *)

val input : t -> Bstr.t -> int -> int -> int
(** [input in_stream buf off len] inputs the [len] bytes from the incoming byte
    stream into the [buf] buffer, and returns actually batched bytes.

    Similar to [In_channel.input] function.

    {b Note}. Use [ensure_] functions instead it for escape unnecessary
    allocations.

    @raise End_of_file if the [in_stream] was ended *)

val really_input : t -> Bstr.t -> int -> int -> unit
(** [really_input in_stream buf off len] inputs the [len] bytes from the
    incoming byte stream into the [buf] buffer with grantees fill it.

    @raise End_of_file if the [in_stream] was ended *)

val input_bytes : t -> bytes -> int -> int -> int
(** [input_bytes in_stream buf off len] is similar to {!input} function but for
    [bytes] type. *)

val really_input_bytes : t -> bytes -> int -> int -> unit
(** [really_input_bytes in_stream buf off len] is similar to {!really_input}
    function but for [bytes] type. *)

(** {3 Inputs into strings} *)

val input_string : t -> int -> string
(** [input_string in_stream len] inputs a string of [len] bytes length from the
    incoming byte stream.

    @raise End_of_file if the [in_stream] was ended *)

val input_line : t -> string option
(** [input_string in_stream len] inputs a line from the incoming byte stream. *)

(** {3 Inputs while} *)

val input_while_into_buffer :
  max_len:int -> (char -> bool) -> t -> Buffer.t -> unit
(** [input_while_into_buffer ?max_len p in_stream buffer] inputs to the [buffer]
    while the [p] returns [true]. *)

val input_while : ?max_len:int -> (char -> bool) -> t -> string
(** [input_while ?max_len predicate in_stream] is similar to
    {!input_while_into_buffer} function but returns a string as result. *)

val input_while' : max_len:int -> (char -> bool) -> t -> string
(** [input_while ~max_len predicate in_stream] is similar to {!input_while}
    function but consuming remaining bytes until [max]. Ideal for input
    fixed-size C string field some binary formats. *)

(** {3 Input combinators} *)

val take : int -> (t -> 'a) -> t -> 'a list
(** [take n input in_stream] calls [input] [n]-times and returns result list.

    @raise End_of_file if the [in_stream] was ended *)

val with_size : (t -> 'a) -> t -> 'a * int
(** [with_size input in_stream] returns the number of bytes that were input by
    the [input] function.

    {b Example}

    {[
    let section, section_size = Bytream.In.with_size input_section in_stream in
    (* ... *)
    ]} *)

val many : (t -> 'a option) -> t -> 'a list
(** [many input in_stream] *)

(** {3 Inputs integer values} *)

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
