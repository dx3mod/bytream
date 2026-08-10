type t = {
  output_chunk : chunk -> unit;
  buffer : buffer;
  mutable written_buffer_bytes : int;
  mutable written_total_bytes : int;
}

and buffer =
  (char, Bigarray.int8_unsigned_elt, Bigarray.c_layout) Bigarray.Array1.t

and chunk = buffer:buffer * offset:int * length:int

(* ===================================================================
    CONSTRUCTORS
   =================================================================== *)

let make ?(buffer_size = 4096) output_chunk =
  {
    output_chunk;
    buffer = Bstr.create buffer_size;
    written_buffer_bytes = 0;
    written_total_bytes = 0;
  }

let of_channel ?io_buffer_size oc =
  make ?buffer_size:io_buffer_size @@ fun (~buffer, ~length, ..) ->
  Out_channel.output_bigarray oc buffer 0 length

(* ===================================================================
    INTERNALS BUFFER MANIPULATION
   =================================================================== *)

let[@inline] available_to_write { buffer; written_buffer_bytes; _ } =
  Bstr.length buffer - written_buffer_bytes

let shift out_stream len =
  let shifted_written_bytes = out_stream.written_buffer_bytes + len in

  if Bstr.length out_stream.buffer >= shifted_written_bytes then (
    out_stream.written_buffer_bytes <- shifted_written_bytes;
    out_stream.written_total_bytes <- out_stream.written_total_bytes + len)
  else
    let exception Shifted_beyond_buffer in
    raise Shifted_beyond_buffer

let perform_io_output_chunk out_stream chunk =
  out_stream.written_buffer_bytes <- 0;
  out_stream.output_chunk chunk

let[@inline] perform_io_output out_stream =
  (~buffer:out_stream.buffer, ~offset:0, ~length:out_stream.written_buffer_bytes)
  |> perform_io_output_chunk out_stream

let[@inline] writable_guard out_stream =
  if available_to_write out_stream = Bstr.length out_stream.buffer then
    perform_io_output out_stream

let ensure_writable_bytes out_stream len =
  assert (len <= Bstr.length out_stream.buffer);

  if available_to_write out_stream < len then perform_io_output out_stream

let[@inline] ensure_writable_bytes_at out_stream len =
  ensure_writable_bytes out_stream len;
  let offset = out_stream.written_buffer_bytes in
  shift out_stream len;
  offset

(* ===================================================================
    FLUSHING
   =================================================================== *)

let[@inline] flush out_stream = perform_io_output out_stream

let[@inline] with_flush out_stream f =
  Fun.protect ~finally:(fun () -> flush out_stream) f

(* ===================================================================
    WITHING
   =================================================================== *)

let with_into_buffer buffer f =
  let out_stream =
    make @@ fun (~buffer:chunk_buffer, ~length:len, ..) ->
    Bstr.sub_string ~off:0 ~len chunk_buffer |> Buffer.add_string buffer
  in

  Fun.protect
    ~finally:(fun () -> perform_io_output out_stream)
    (fun () -> f out_stream);

  ()

let with_into_string f =
  let buffer = Buffer.create 0xFF in
  with_into_buffer buffer f;
  Buffer.contents buffer

(* ===================================================================
    OUTPUTTING
   =================================================================== *)

let[@inline] rec gen_output
    ~(blit : 'src -> src_off:int -> 'dst -> dst_off:int -> len:int -> unit)
    ~buffer_length out_stream (buffer : 'src) off len =
  if len <> 0 then begin
    writable_guard out_stream;

    let available_space = available_to_write out_stream in
    let batched_bytes = min available_space buffer_length in

    blit buffer ~src_off:off out_stream.buffer
      ~dst_off:out_stream.written_buffer_bytes ~len:batched_bytes;

    shift out_stream batched_bytes;

    gen_output ~blit ~buffer_length out_stream buffer (off + batched_bytes)
      (len - batched_bytes)
  end

let gen_really_output ~blit ~buffer_length out_stream buffer off len =
  gen_output ~blit ~buffer_length out_stream buffer off len;
  perform_io_output out_stream

let[@inline] output out_stream buffer off len =
  (* If the buffer is equal to or greater than our internal buffer, 
     then we can directly output it to the sink without worrying about copying. *)
  if Bstr.length out_stream.buffer <= len then
    (~buffer, ~offset:off, ~length:len) |> perform_io_output_chunk out_stream
  else
    (gen_output [@inlined]) ~blit:Bstr.blit
      ~buffer_length:Bstr.(length buffer)
      out_stream buffer off len

let[@inline] really_output out_stream buffer off len =
  gen_really_output ~blit:Bstr.blit
    ~buffer_length:Bstr.(length buffer)
    out_stream buffer off len

let output_string out_stream s =
  let length = String.length s in
  gen_output ~blit:Bstr.blit_from_string ~buffer_length:length out_stream s 0
    length

(* ===================================================================
    OUTPUTTING INTEGER VALUES
   =================================================================== *)

let[@inline] gen_output_val out_stream f len value =
  let off = ensure_writable_bytes_at out_stream len in
  f out_stream.buffer off value

let output_char out_stream ch = gen_output_val out_stream Bstr.set 1 ch

let output_byte out_stream byte =
  gen_output_val out_stream Bstr.set_uint8 1 byte

let output_int8 out_stream int = gen_output_val out_stream Bstr.set_int8 1 int
let output_uint8 out_stream int = gen_output_val out_stream Bstr.set_uint8 1 int

let output_int16_be out_stream int =
  gen_output_val out_stream Bstr.set_int16_be 2 int

let output_int16_le out_stream int =
  gen_output_val out_stream Bstr.set_int16_le 2 int

let output_int16_ne out_stream int =
  gen_output_val out_stream Bstr.set_int16_ne 2 int

let output_uint16_be out_stream int =
  gen_output_val out_stream Bstr.set_uint16_be 2 int

let output_uint16_le out_stream int =
  gen_output_val out_stream Bstr.set_uint16_le 2 int

let output_uint16_ne out_stream int =
  gen_output_val out_stream Bstr.set_uint16_ne 2 int

let output_int32_be out_stream int =
  gen_output_val out_stream Bstr.set_int32_be 4 int

let output_int32_le out_stream int =
  gen_output_val out_stream Bstr.set_int32_le 4 int

let output_int32_ne out_stream int =
  gen_output_val out_stream Bstr.set_int32_ne 4 int

let output_int64_be out_stream int =
  gen_output_val out_stream Bstr.set_int64_be 8 int

let output_int64_le out_stream int =
  gen_output_val out_stream Bstr.set_int64_le 8 int

let output_int64_ne out_stream int =
  gen_output_val out_stream Bstr.set_int64_ne 8 int
