(** Incoming byte stream module for processing byte sources, using chunk buffers
    when needed, with minimized memory allocations. *)

type t
(** Incoming byte stream type. *)

and buffer =
  (char, Bigarray.int8_unsigned_elt, Bigarray.c_layout) Bigarray.Array1.t
(** Flatten bytes-oriented [Bigarray] buffer.

    {b Note}. The rationale for using bytes instead of BA is to transparently
    transfer memory between the OCaml runtime and external functions, which are
    necessary for working with input/output. *)

and chunk = buffer:buffer * offset:int * length:int
(** A byte chunk is a non-empty consecutive range of bytes in a {!buffer} value.
*)

(** {1 Constructors} *)

val make : ?overlap_size:int -> (unit -> buffer) -> t
(** [make ?overlap_size reader]

    Construct incoming byte stream from [reader].

    @param reader
      This is a function that reads chunks from a source. It raises the
      [End_of_file] exception when the end of the source is reached.

    @param ?overlap_size
      By default, a buffer of [0xFF] bytes is allocated to resolve data gaps
      between chunks, which are used to provide linear memory buffers.

    {b Note}. The {!buffer} within a {!chunk} is made available to third parties
    for a limited period of time during which the chunk is considered valid for
    reading or writing (or both).

    {b Example}

    This example illustrates the basic concept of chunking.

    {[
    (* Queue as a byte chunk source. *)
    let queue =
      let queue = Queue.create () in
      Queue.add "he" queue;
      (* ... *)
      Queue.add "d!" queue;
      queue
    in

    (* Reader function that returns chunks of text from the source. *)
    let reader () =
      match Queue.take_opt queue with
      | None ->
        (** For close incoming byte stream, the reader
            should raise an End_of_file exception.  *)
        raise End_of_file
      | Some chunk -> Bstr.of_string chunk
    in

    Bytream.In.make reader
    ]} *)

val make' : ?overlap_size:int -> (unit -> chunk) -> t
(** [make_intf ?overlap_size reader]

    Same as the {!make} function, but the [reader] returns {!chunk}s instead of
    {!buffer}s. *)

val of_buffer : buffer -> t
(** [of_buffer buffer]

    Construct a byte stream from a previously prepared buffer. *)

val of_string : string -> t
(** [of_string string]

    Same as {!of_buffer}, but for string value.

    @param string
      The [string] will be {b copied} to transform it into the {!buffer} value.
*)

val of_channel : ?io_buffer_size:int -> in_channel -> t
(** [of_channel ?io_buffer_size ic]

    Construct an incoming byte stream from [ic] using the
    [In_channel.input_bigarray] function to get chunks from the source of the
    channel.

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
    [bytes]. *)

(** {2 Substrings inputs} *)

val input_string : t -> int -> string
(** [input_string in_stream len] input [len]-sized string. *)

val input_while : ?max:int -> (char -> bool) -> t -> string
(** [input_while ?max p in_stream] input byte while [p] on the byte returns
    [true].

    @param ?max determined the maximum length of the input string *)

val input_while' : max:int -> (char -> bool) -> t -> string
(** [input_while ~max p in_stream] same as {!input_while} but consuming
    remaining bytes until maximum. *)

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
