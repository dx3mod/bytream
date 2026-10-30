(** Lwt integration for Bytream.

    This module provides Lwt-based constructors for creating incoming and
    outgoing byte streams from Lwt channels, file descriptors, and Unix file
    descriptors.

    {b Note.} This module uses [Lwt_direct] for synchronous waiting within
    stream readers and writers. Ensure that your Lwt runtime is properly
    configured for blocking operations. *)

(** {1 Incoming byte streams} *)

module In : sig
  val of_channel : ?io_buffer_size:int -> Lwt_io.input_channel -> Bytream.In.t
  (** [of_channel ?io_buffer_size ic] creates an incoming byte stream that reads
      from the Lwt input channel [ic].

      [io_buffer_size] specifies the size of the internal buffer used for
      reading. Defaults to [Lwt_bytes.page_size].

      The returned stream uses blocking reads via [Lwt_direct.await], so it
      should be used in a context where blocking is acceptable (e.g., within a
      dedicated thread or when using the [Lwt_direct] runtime). *)

  val of_fd : ?io_buffer_size:int -> Lwt_unix.file_descr -> Bytream.In.t
  (** [of_fd ?io_buffer_size fd] creates an incoming byte stream from the Lwt
      file descriptor [fd]. *)

  val of_unix_fd : ?io_buffer_size:int -> Unix.file_descr -> Bytream.In.t
  (** [of_unix_fd ?io_buffer_size unix_fd] creates an incoming byte stream from
      the Unix file descriptor [unix_fd]. *)
end

(** {1 Outgoing byte streams} *)

module Out : sig
  val of_channel : ?io_buffer_size:int -> Lwt_io.output_channel -> Bytream.Out.t
  (** [of_channel ?io_buffer_size oc] creates an outgoing byte stream that
      writes to the Lwt output channel [oc].

      [io_buffer_size] specifies the size of the internal buffer used for
      buffering writes. Defaults to [Lwt_bytes.page_size].

      The returned stream uses asynchronous writes via
      [Lwt_direct.spawn_in_the_background], so writes are non-blocking from the
      caller's perspective. *)

  val of_fd : ?io_buffer_size:int -> Lwt_unix.file_descr -> Bytream.Out.t
  (** [of_fd ?io_buffer_size fd] creates an outgoing byte stream from the Lwt
      file descriptor [fd]. *)

  val of_unix_fd : ?io_buffer_size:int -> Unix.file_descr -> Bytream.Out.t
  (** [of_unix_fd ?io_buffer_size unix_fd] creates an outgoing byte stream from
      the Unix file descriptor [unix_fd]. *)
end
