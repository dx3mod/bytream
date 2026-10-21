(** Encode and decode binary records from Bytream streams. *)

module In : sig
  (** Decoding. *)

  val input : Bytream.In.t -> 'a Bin.t -> 'a
  (** [input in_stream decoder] inputs the decoded binary record from the
      incoming byte stream.

      @raise End_of_file if the [in_stream] was ended *)
end

module Out : sig
  (** Encoding. *)

  val output : Bytream.Out.t -> 'a Bin.t -> 'a -> unit
  (** [output out_stream encoder value] outputs the encoded binary [value] into
      the outgoing byte stream. *)
end
