(** A library for streaming and crunching bytes.

    This library provides agnostic I/O runtime mechanisms for organizing byte
    stream processing for reading and writing in an efficient manner, e.g. for
    building codecs and protocol implementations. *)

(** {1 Input and output} *)

module In = In
module Out = Out

(** {2 Design notes}

    {3 Core concepts}

    The library is built around two symmetric abstractions: {!module:In} for
    reading and {!module:Out} for writing. Both operate on {e streams} —
    sequences of bytes processed incrementally, without requiring the whole
    payload to fit in memory.

    A stream is {b not} a buffer. It is a stateful cursor over a sequence of
    {e slices} (chunks of bytes) that arrive from or are sent to some underlying
    source or sink (a channel, a file, a socket, a memory buffer, ...).

    {3 Zero-copy semantics}

    Wherever possible, the library avoids copying data:

    - {!In.input_slice} returns a view into the internal buffer.
    - {!Out.output_slice} writes the slice directly to the sink.
    - {!In.peek_slice} exposes the current buffer state without advancing the
      cursor.

    Bytes returned by an input stream are {b owned by the stream} and are only
    valid until the next operation that may advance or replace the buffer. To
    keep data longer, copy it explicitly (e.g. via {!In.input_string} or
    {!In.input_bytes}).

    {3 The overlap buffer}

    {!In} uses an {e overlap buffer} to handle multi-byte values (e.g. a 32-bit
    integer) that straddle the boundary between two incoming slices.

    When {!In.ensure_bytes} detects that the current slice is too short, it
    copies the tail into the overlap buffer and appends the next slice, so the
    requested bytes are contiguous in memory.

    Constraints:

    - The overlap buffer has a {b fixed size}, 255 bytes by default.
    - Calls to {!In.ensure_bytes}, {!In.ensure_slice}, {!In.ensure_buffer} and
      integer readers require [len <= overlap_buffer_size].
    - To read larger atomic values, provide a bigger buffer via
      {!In.make}[ ~overlap_buffer] or {!In.with_overlap_buffer}.

    {!Out} does not need an overlap buffer: writes are buffered internally and
    flushed as a whole.

    {3 [ensure_*] vs [input_*]}

    Two families of read functions are provided:

    - [input_*] copy bytes into a destination you provide. Use when you need the
      data at a specific location.
    - [ensure_*] guarantee that at least [n] bytes are available as a contiguous
      view and return that view. Use to inspect or parse bytes without copying.

    Prefer [ensure_*] for parsing binary formats — it avoids allocations and
    lets you work directly with the stream's memory.

    {[
      let len = In.input_uint16_be in_stream in
      let slice = In.ensure_slice in_stream len in
      (* work with [slice] directly *)
    ]}

    {3 End-of-stream handling}

    End of stream is signaled by raising {!End_of_file}, consistent with the
    standard library. There is no [is_eof] function — the end of stream is
    usually only known after attempting to read.

    For partial reads, use {!In.input} (returns the number of bytes actually
    read) rather than {!In.really_input} (raises {!End_of_file} on short reads).

    {3 Stream transformation}

    {!Out.transform} wraps a stream with a function that rewrites each slice
    before it is written to the sink — useful for compression, encoding or
    encryption layers:

    {[
    let compressed = Out.transform raw_stream compress_slice in
    Out.output_string compressed "hello";
    Out.flush compressed
    ]}

    The transformation is applied {b per slice}, not across the whole stream.
    Design your transform accordingly.

    {3 Performance tips}

    - {b Batch writes.} Group related writes and use {!Out.with_flush} to flush
      once at the end.
    - {b Reuse buffers.} Pass your own buffer to {!In.make}[ ~overlap_buffer] or
      {!Out.make}[ ~buf].
    - {b Prefer slices over strings.} {!In.input_slice} and {!In.ensure_slice}
      avoid allocating OCaml strings.
    - {b Size I/O buffers.} For {!In.of_channel} and {!Out.of_channel}, pick
      [io_buffer_size] based on your workload. The default (4096) is a
      reasonable starting point.
    - {b Avoid tiny reads.} Use {!In.ensure_slice} to grab a chunk and parse it
      in place rather than reading one byte at a time. *)
