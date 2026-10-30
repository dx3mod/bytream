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
  let buf = match buf with Some b -> b | None -> Bstr.create 4096 in
  assert (Bstr.length buf > 0);
  { writer; buf; off = 0; total_written_bytes = 0 }

let of_channel ?(io_buffer_size = 4096) oc =
  let writer (slice : Slice_bstr.t) =
    Out_channel.output_bigarray oc slice.buf slice.off slice.len
  in
  make ~buf:(Bstr.create io_buffer_size) writer

(* ===================================================================
   INTERNAL BUFFER MANIPULATION
   =================================================================== *)

exception Shifted_beyond_buffer

let[@inline] buffer_size { buf; _ } = Bstr.length buf
let[@inline] bytes_available { buf; off; _ } = Bstr.length buf - off
let[@inline] bytes_written { total_written_bytes; _ } = total_written_bytes
let[@inline] write_slice out_stream slice = out_stream.writer slice

let unsafe_shift out_stream len =
  out_stream.off <- out_stream.off + len;
  out_stream.total_written_bytes <- out_stream.total_written_bytes + len

let shift out_stream len =
  if len >= 0 && bytes_available out_stream >= len then
    unsafe_shift out_stream len
  else raise Shifted_beyond_buffer

let[@inline] perform_output out_stream =
  if out_stream.off > 0 then begin
    let slice = Slice_bstr.make ~len:out_stream.off out_stream.buf in
    out_stream.off <- 0;
    write_slice out_stream slice
  end

let[@inline] flush_if_needed out_stream len =
  if bytes_available out_stream < len then perform_output out_stream

let ensure_bytes out_stream len =
  assert (len >= 0 && len <= Bstr.length out_stream.buf);
  flush_if_needed out_stream len

let[@inline] unsafe_ensure_bytes_at out_stream len =
  flush_if_needed out_stream len;
  let offset = out_stream.off in
  unsafe_shift out_stream len;
  offset

let ensure_slice out_stream len =
  let off = unsafe_ensure_bytes_at out_stream len in
  Slice_bstr.make ~off ~len out_stream.buf

let ensure_buffer out_stream len =
  let off = unsafe_ensure_bytes_at out_stream len in
  Bstr.sub ~off ~len out_stream.buf

(* ===================================================================
   FLUSHING
   =================================================================== *)

let[@inline] flush out_stream = perform_output out_stream

let[@inline] with_flush out_stream f =
  Fun.protect ~finally:(fun () -> flush out_stream) f

(* ===================================================================
   CONVERSION TO BUFFERS
   =================================================================== *)

let to_buffer ?buf buffer f =
  let buf_bytes = match buf with Some b -> b | None -> Bytes.create 1024 in

  let writer (slice : Slice_bstr.t) =
    if slice.len <= Bytes.length buf_bytes then begin
      Slice_bstr.blit_to_bytes ~dst_off:0 ~len:slice.len slice buf_bytes;
      Buffer.add_subbytes buffer buf_bytes 0 slice.len
    end
    else Buffer.add_string buffer (Slice_bstr.to_string slice)
  in

  let out_stream = make writer in

  Fun.protect
    ~finally:(fun () -> perform_output out_stream)
    (fun () -> f out_stream)

let to_string f =
  let buffer = Buffer.create 4096 in
  to_buffer buffer f;
  Buffer.contents buffer

(* ===================================================================
   OUTPUT FUNCTIONS
   =================================================================== *)

let rec gen_output ~blit out_stream src src_off remaining =
  if remaining > 0 then begin
    flush_if_needed out_stream 1;

    let to_write = min (bytes_available out_stream) remaining in

    blit src ~src_off out_stream.buf ~dst_off:out_stream.off ~len:to_write;
    unsafe_shift out_stream to_write;

    gen_output ~blit out_stream src (src_off + to_write) (remaining - to_write)
  end

let gen_really_output ~blit out_stream buffer off len =
  gen_output ~blit out_stream buffer off len;
  perform_output out_stream

let[@inline] output out_stream buf off len =
  gen_output ~blit:Bstr.blit out_stream buf off len

let[@inline] really_output out_stream buffer off len =
  gen_really_output ~blit:Bstr.blit out_stream buffer off len

let[@inline] output_string out_stream s =
  gen_output ~blit:Bstr.blit_from_string out_stream s 0 (String.length s)

let[@inline] output_slice out_stream (slice : Slice_bstr.t) =
  output out_stream slice.buf slice.off slice.len

(* ===================================================================
   OUTPUTTING INTEGER VALUES
   =================================================================== *)

let[@inline] gen_output_val out_stream f len value =
  let off = unsafe_ensure_bytes_at out_stream len in
  f out_stream.buf off value

let output_char out_stream ch = gen_output_val out_stream Bstr.set 1 ch

let output_byte out_stream byte =
  gen_output_val out_stream Bstr.set_uint8 1 byte

let output_int8 out_stream n = gen_output_val out_stream Bstr.set_int8 1 n
let output_uint8 out_stream n = gen_output_val out_stream Bstr.set_uint8 1 n

let output_int16_be out_stream n =
  gen_output_val out_stream Bstr.set_int16_be 2 n

let output_int16_le out_stream n =
  gen_output_val out_stream Bstr.set_int16_le 2 n

let output_int16_ne out_stream n =
  gen_output_val out_stream Bstr.set_int16_ne 2 n

let output_uint16_be out_stream n =
  gen_output_val out_stream Bstr.set_uint16_be 2 n

let output_uint16_le out_stream n =
  gen_output_val out_stream Bstr.set_uint16_le 2 n

let output_uint16_ne out_stream n =
  gen_output_val out_stream Bstr.set_uint16_ne 2 n

let output_int32_be out_stream n =
  gen_output_val out_stream Bstr.set_int32_be 4 n

let output_int32_le out_stream n =
  gen_output_val out_stream Bstr.set_int32_le 4 n

let output_int32_ne out_stream n =
  gen_output_val out_stream Bstr.set_int32_ne 4 n

let output_int64_be out_stream n =
  gen_output_val out_stream Bstr.set_int64_be 8 n

let output_int64_le out_stream n =
  gen_output_val out_stream Bstr.set_int64_le 8 n

let output_int64_ne out_stream n =
  gen_output_val out_stream Bstr.set_int64_ne 8 n

(* ===================================================================
   STREAM TRANSFORMATION
   =================================================================== *)

let transform out_stream f =
  let write = out_stream.writer in
  { out_stream with writer = (fun slice -> write (f slice)) }
