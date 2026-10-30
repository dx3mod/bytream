(** Unix integration for Bytream.

    This module provides constructors for creating incoming and outgoing byte
    streams from Unix file descriptors. *)

module In : sig
  val of_fd : ?io_buffer_size:int -> Unix.file_descr -> Bytream.In.t
  (** [of_fd ?io_buffer_size fd] creates an incoming byte stream that reads from
      the Unix file descriptor [fd].

      [io_buffer_size] specifies the size of the internal buffer used for
      reading. Defaults to 4096 bytes.

      The returned stream uses blocking reads via {!Unix.read_bigarray}. *)
end

module Out : sig
  val of_fd : ?io_buffer_size:int -> Unix.file_descr -> Bytream.Out.t
  (** [of_fd ?io_buffer_size fd] creates an outgoing byte stream that writes to
      the Unix file descriptor [fd].

      [io_buffer_size] specifies the size of the internal buffer used for
      buffering writes. Defaults to 4096 bytes.

      The returned stream guarantees that all bytes are written to the file
      descriptor, even if a single {!Unix.write_bigarray} call writes fewer
      bytes than requested. *)
end
