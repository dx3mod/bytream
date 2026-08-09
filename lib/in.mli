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

(** {1 Construction} *)

(** The section explains how you can create a new incoming byte stream. *)

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

    {b See also}, the {!make'} function allows you to return a subview of the
    {!buffer}.

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
    {!buffer}s.

    {b Example}

    {[
    match In_channel.input_bigarray ic buffer 0 io_buffer_size with
    | (* ... *)
    | length -> (~buffer, ~offset:0, ~length)
    ]} *)

val of_buffer : buffer -> t
(** [of_buffer buffer]

    Construct a byte stream from a previously prepared buffer.

    {b Example}

    {[
    let buffer = mmap_file "bigfile.iso" in
    let in_stream = Bytream.In.of_buffer buffer in
    (* ... *)
    ]} *)

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

    @param ?buffer_size by default is 4096 bytes

    {b Example pattern for your modules}

    {[
    module Tar_archive = struct
      (* ... *)
      let of_channel ic =
        Bytream.In.of_channel ic
        |> Tar_reader.input_archive in_stream
    ]} *)

(** {1 Buffering mechanism} *)

(** The section explains how to work with incoming byte stream's buffering
    mechanism for effective processing bytes massive.

    You should understand, an incoming byte stream not copying incoming
    {!chunk}s gotten from [reader]. The stream use it until not be gotten new
    chunk when it be needed. *)

val available_to_read : t -> int
(** [available_to_read in_stream]

    @return remaining bytes of current chunk that available to read. *)

val consume_bytes : t -> int -> unit
(** [consume_bytes in_stream len]

    Consume [len] bytes from incoming bytes stream with offset shifting.

    @raise End_of_file if you try consume more bytes than a source provide. *)

val ensure_buffer : t -> int -> buffer
(** [ensure_chunk in_stream len]

    @return {!buffer} value that guarantee have [len] bytes.

    @raise End_of_file if the [in_stream] was ended

    {b See}. {!ensure_chunk} function that have most fast allocation. *)

val ensure_chunk : t -> int -> chunk
(** [ensure_chunk in_stream len]

    Same as the {!make} function, but returns {!chunk}.

    {b Note}. Maybe be most performance than {!ensure_buffer} because {!buffer}
    subbing is more expressive. Recommended to use. *)

val position : t -> int
(** [position in_stream]

    @return Total bytes number read from incoming byte stream. *)

(** {1 Input} *)

val input : t -> buffer -> int -> int -> int
(** [input in_stream buffer off len]

    Input streams's bytes into [buffer] and return actually batched bytes.
    Similar to [Stdlib.input] channel's function.

    {b Note}. Try use [ensure_] functions instead it for escape unnecessary
    allocations.

    @param off The is [buffer]'s offset.
    @param len The is [buffer]'s length.

    @raise End_of_file if the [in_stream] was ended *)

val input_bytes : t -> bytes -> int -> int -> int
(** [input_bytes in_stream bytes off len] s

    Same as the {!section-input} function, but working with [bytes] value. *)

val really_input : t -> buffer -> int -> int -> unit
(** [really_input in_stream buffer off len] input streams's bytes into [buffer]
    and grantees fill it.

    {b Example}

    {[
    let input_request in_stream =
      (* ... *)
      Bytream.In.really_input in_stream payload_buffer 0 payload_size
    ]}

    @raise End_of_file if [in_stream] not have enough bytes for input *)

val really_input_bytes : t -> bytes -> int -> int -> unit
(** [really_input_bytes in_stream bytes off len] same as {!really_input} but for
    [bytes]. *)

(** {2 Inputting substrings} *)

val input_string : t -> int -> string
(** [input_string in_stream len]

    Input [len]-sized bytes value from incoming byte stream. *)

val input_while : ?max:int -> (char -> bool) -> t -> string
(** [input_while ?max p in_stream]

    Input byte while [p] on the byte returns [true].

    @param ?max determined the maximum length of the input string *)

val input_while' : max:int -> (char -> bool) -> t -> string
(** [input_while ~max p in_stream]

    Same as the {!input_while} function, but consuming remaining bytes until
    [max]. Ideal for input fixed-size C string field some binary formats. *)

(** {2 Input combinators} *)

val take : int -> t -> (t -> 'a) -> 'a list
(** [take n in_stream input_value]

    Call [input_value] [n] times and save function's results in list. *)

(** {2 Inputting integer values} *)

(** Input bytes and decode them into integer values. *)

val input_char : t -> char
(** [input_char in_stream] *)

val input_int8 : t -> int
(** [input_int8 in_stream] *)

val input_uint8 : t -> int
(** [input_uint8 in_stream] *)

val input_byte : t -> int
(** [input_byte in_stream] *)

val input_int16_be : t -> int
(** [input_int16_be in_stream] *)

val input_int16_ne : t -> int
(** [input_int16_ne in_stream] *)

val input_int16_le : t -> int
(** [input_int16_le in_stream] *)

val input_uint16_be : t -> int
(** [input_uint16_be in_stream] *)

val input_uint16_ne : t -> int
(** [input_uint16_ne in_stream] *)

val input_uint16_le : t -> int
(** [input_uint16_le in_stream] *)

val input_int32_be : t -> int32
(** [input_int32_be in_stream] *)

val input_int32_ne : t -> int32
(** [input_int32_ne in_stream] *)

val input_int32_le : t -> int32
(** [input_int32_le in_stream] *)

val input_int64_be : t -> int64
(** [input_int64_be in_stream] *)

val input_int64_ne : t -> int64
(** [input_int64_ne in_stream] *)

val input_int64_le : t -> int64
(** [input_int64_le in_stream] *)
