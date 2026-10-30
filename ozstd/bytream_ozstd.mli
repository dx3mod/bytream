(** Compression and decompression using Zstandard for Bytream streams. *)

module In : sig
  (** Decompression layer. *)

  val make :
    ?dictionary:Ozstd.Dictionary.t ->
    ?size_limit:int ->
    Bytream.In.t ->
    Bytream.In.t
  (** [make ?dictionary ?size_limit in_stream] creates a decompressed incoming
      byte stream that reads from [in_stream].

      @param dictionary Optional Zstandard dictionary for decompression.
      @param size_limit Optional maximum decompressed frame size.

      @raise End_of_file when the underlying stream is exhausted. *)
end

module Out : sig
  (** Compression layer. *)

  val make :
    ?dictionary:Ozstd.Dictionary.t ->
    ?compression_level:int ->
    Bytream.Out.t ->
    Bytream.Out.t
  (** [make ?dictionary ?compression_level out_stream] creates a compressed
      outgoing byte stream that writes to [out_stream].

      @param dictionary Optional Zstandard dictionary for compression.
      @param compression_level Optional compression level (default is 3).

      @raise End_of_file when the underlying stream is closed. *)
end
