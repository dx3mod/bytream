type t = {
  writer : Slice_bstr.t -> unit;
  buf : Bstr.t;
  mutable off : int;
  mutable total_written_bytes : int;
}

(* ===================================================================
    CONSTRUCTORS
   =================================================================== *)

let make ?buf writer =
  {
    writer;
    buf = (match buf with None -> Bstr.create 4096 | Some buf -> buf);
    off = 0;
    total_written_bytes = 0;
  }

let of_channel ?(io_buffer_size = 4096) oc =
  make ~buf:(Bstr.create io_buffer_size) @@ fun Slice.{ buf; len; off } ->
  Out_channel.output_bigarray oc buf off len

(* ===================================================================
    INTERNALS BUFFER MANIPULATION
   =================================================================== *)

exception Shifted_beyond_buffer

let[@inline] buffer_size { buf; _ } = Bstr.length buf
let[@inline] write_slice out_stream slice = out_stream.writer slice
let[@inline] bytes_available { buf; off; _ } = Bstr.length buf - off
let[@inline] bytes_written { total_written_bytes; _ } = total_written_bytes

let unsafe_shift out_stream len =
  out_stream.off <- out_stream.off + len;
  out_stream.total_written_bytes <- out_stream.total_written_bytes + len

let shift out_stream len =
  let shifted_written_bytes = out_stream.off + len in

  if Bstr.length out_stream.buf >= shifted_written_bytes then
    (unsafe_shift [@inlined]) out_stream len
  else
    let exception Shifted_beyond_buffer in
    raise Shifted_beyond_buffer

let perform_output_slice out_stream slice =
  out_stream.off <- 0;
  write_slice out_stream slice

let[@inline] perform_output out_stream =
  Slice_bstr.make ~len:out_stream.off out_stream.buf
  |> perform_output_slice out_stream

let[@inline] writable_guard out_stream =
  if bytes_available out_stream = Bstr.length out_stream.buf then
    perform_output out_stream

let unsafe_ensure_bytes out_stream len =
  if bytes_available out_stream < len then perform_output out_stream

let ensure_bytes out_stream len =
  assert (len <= Bstr.length out_stream.buf);
  unsafe_ensure_bytes out_stream len

let[@inline] unsafe_ensure_bytes_at out_stream len =
  unsafe_ensure_bytes out_stream len;
  let offset = out_stream.off in
  unsafe_shift out_stream len;
  offset

let ensure_slice out_stream len =
  ensure_bytes out_stream len;
  let off = out_stream.off in
  unsafe_shift out_stream len;
  Slice_bstr.make ~off out_stream.buf

(* ===================================================================
    FLUSHING
   =================================================================== *)

let[@inline] flush out_stream = perform_output out_stream

let[@inline] with_flush out_stream f =
  Fun.protect ~finally:(fun () -> flush out_stream) f

(* ===================================================================
    WITHING
   =================================================================== *)

let to_buffer ?buf buffer f =
  let buf_bytes =
    match buf with None -> Bytes.create 1024 | Some buf -> buf
  in

  let writer (slice : Slice_bstr.t) =
    if slice.len <= Bytes.length buf_bytes then begin
      Slice_bstr.blit_to_bytes ~dst_off:0 ~len:slice.len slice buf_bytes;
      Buffer.add_subbytes buffer buf_bytes 0 slice.len
    end
    else Slice_bstr.to_string slice |> Buffer.add_string buffer
  in

  let out_stream = make writer in

  Fun.protect
    ~finally:(fun () -> perform_output out_stream)
    (fun () -> f out_stream);

  ()

let to_string f =
  let buffer = Buffer.create 4096 in
  to_buffer buffer f;
  Buffer.contents buffer

(* ===================================================================
    OUTPUTTING
   =================================================================== *)

let[@inline] rec gen_output
    ~(blit : 'src -> src_off:int -> 'dst -> dst_off:int -> len:int -> unit)
    ~buffer_length out_stream (buffer : 'src) off len =
  if len <> 0 then begin
    writable_guard out_stream;

    let available_space = bytes_available out_stream in
    let batched_bytes = min available_space buffer_length in

    blit buffer ~src_off:off out_stream.buf ~dst_off:out_stream.off
      ~len:batched_bytes;

    unsafe_shift out_stream batched_bytes;

    gen_output ~blit ~buffer_length out_stream buffer (off + batched_bytes)
      (len - batched_bytes)
  end

let gen_really_output ~blit ~buffer_length out_stream buffer off len =
  gen_output ~blit ~buffer_length out_stream buffer off len;
  perform_output out_stream

let[@inline] output out_stream buf off len =
  (* If the buffer is equal to or greater than our internal buffer,
     then we can directly output it to the sink without worrying about copying. *)
  if Bstr.length out_stream.buf <= len then
    perform_output_slice out_stream Slice_bstr.(make ~off ~len buf)
  else
    (gen_output [@inlined]) ~blit:Bstr.blit
      ~buffer_length:Bstr.(length buf)
      out_stream buf off len

let[@inline] really_output out_stream buffer off len =
  gen_really_output ~blit:Bstr.blit
    ~buffer_length:Bstr.(length buffer)
    out_stream buffer off len

let output_string out_stream s =
  let length = String.length s in
  gen_output ~blit:Bstr.blit_from_string ~buffer_length:length out_stream s 0
    length

let rec output_slice out_stream slice =
  if bytes_available out_stream > slice.Slice.len then
    Bstr.blit ~src_off:slice.off slice.buf ~dst_off:out_stream.off
      out_stream.buf ~len:slice.len
  else (
    perform_output out_stream;

    if Bstr.length out_stream.buf >= slice.Slice.len then
      write_slice out_stream slice
    else output_slice out_stream slice)

(* if out_stream.written_buffer_bytes > 0 then perform_output out_stream;
  perform_output_slice out_stream slice *)

(* ===================================================================
    OUTPUTTING INTEGER VALUES
   =================================================================== *)

let[@inline] gen_output_val out_stream f len value =
  let off = unsafe_ensure_bytes_at out_stream len in
  f out_stream.buf off value

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

let transform out_stream f =
  let write = out_stream.writer in
  { out_stream with writer = (fun slice -> f slice |> write) }
