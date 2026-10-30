(** Binary encoding and decoding for Bytream streams.

    This module provides integration between Bytream streams and the [Bin]
    library for declarative binary serialization. *)

module In : sig
  (** Decoding. *)

  val input : Bytream.In.t -> 'a Bin.t -> 'a
  (** [input in_stream decoder] decodes a binary value of type ['a] from the
      incoming byte stream [in_stream] using the [decoder].

      @raise End_of_file
        if the stream ends before the value can be fully decoded.
      @raise Bin_error.Error
        if the data is malformed or does not match the expected format. *)
end

module Out : sig
  (** Encoding. *)

  val output : Bytream.Out.t -> 'a Bin.t -> 'a -> unit
  (** [output out_stream encoder value] encodes [value] using [encoder] and
      writes the resulting bytes to the outgoing byte stream [out_stream].

      {b Note.} The data is buffered and may not be immediately written to the
      underlying sink. Call {!Bytream.Out.flush} to ensure all data is flushed.
  *)
end
