(** Compression and decompression using Zstandard for Bytream streams. *)

module In : sig
  (** Decompression layer. *)

  val make :
    ?dictionary:Ozstd.Dictionary.t ->
    ?size_limit:int ->
    Bytream.In.t ->
    Bytream.In.t
  (** [of_stream ?dictionary ?size_limit in_stream] creates a decompressed the
      incoming byte stream. *)
end

module Out : sig
  (** Compression layer. *)

  val make :
    ?dictionary:Ozstd.Dictionary.t ->
    ?compression_level:int ->
    Bytream.Out.t ->
    Bytream.Out.t
  (** [of_stream ?dictionary ?compression_level out_stream] creates a compressed
      the outgoing byte stream. *)
end
