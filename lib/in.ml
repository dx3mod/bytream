type t = {
  mutable reader : unit -> Slice_bstr.t;
  (* Current slice *)
  mutable buf : Bstr.t;
  mutable off : int;  (** Buffer's offset *)
  mutable len : int;  (** Buffer's length *)
  (* *)
  mutable bytes_received : int;  (** Total read bytes from some source *)
  (* *)
  overlap_buffer : Bstr.t;
      (** A small buffer to resolve the data gap situation between chunks *)
}

(* ===================================================================
    CONSTRUCTORS
   =================================================================== *)

let make ?overlap_buffer reader =
  {
    reader;
    buf = Bstr.empty;
    off = 0;
    len = 0;
    bytes_received = 0;
    overlap_buffer =
      (match overlap_buffer with
      | None -> Bstr.create 0xFF
      | Some overlap_buffer -> overlap_buffer);
  }

let of_bigstring buf =
  {
    reader = (fun () -> raise End_of_file);
    buf;
    off = 0;
    len = Bstr.length buf;
    bytes_received = 0;
    overlap_buffer = Bstr.empty;
  }

let of_string s = Bstr.of_string s |> of_bigstring

let of_channel ?(io_buffer_size = Sys.io_buffer_size) ic =
  let buffer = Bstr.create io_buffer_size in

  let reader () =
    match In_channel.input_bigarray ic buffer 0 io_buffer_size with
    | 0 -> raise End_of_file
    | len -> Slice_bstr.make ~len buffer
  in

  make reader

let with_overlap_buffer in_stream overlap_buffer =
  { in_stream with overlap_buffer }

let[@inline] bytes_received in_stream = in_stream.bytes_received

(* ===================================================================
    BUFFER MANIPULATION UTILITY FUNCTIONS
   =================================================================== *)

let[@inline] bytes_available in_stream = in_stream.len

let unsafe_advance_offset in_stream n =
  in_stream.off <- in_stream.off + n;
  in_stream.len <- in_stream.len - n;
  in_stream.bytes_received <- in_stream.bytes_received + n

let advance_offset in_stream n =
  assert (in_stream.len - n >= 0);
  unsafe_advance_offset in_stream n

let[@inline] acquire_slice in_stream = in_stream.reader ()

let set_slice in_stream Slice.{ buf; off; len } =
  in_stream.buf <- buf;
  in_stream.off <- off;
  in_stream.len <- len

let peek_slice in_stream =
  Slice.unsafe_make ~off:in_stream.off ~len:in_stream.len in_stream.buf

let rec consume_bytes in_stream len =
  if len <> 0 then begin
    let available_bytes = bytes_available in_stream in
    let available_to_consume = min available_bytes len in

    unsafe_advance_offset in_stream available_to_consume;

    if available_to_consume < len then begin
      set_slice in_stream (acquire_slice in_stream);
      consume_bytes in_stream (len - available_to_consume)
    end
  end

(* ===================================================================
    INPUTS
   =================================================================== *)

let input_slice in_stream =
  match bytes_available in_stream with
  | 0 ->
      let slice = acquire_slice in_stream in
      set_slice in_stream slice;
      unsafe_advance_offset in_stream slice.len;
      slice
  | _ ->
      let slice = peek_slice in_stream in
      unsafe_advance_offset in_stream slice.len;
      slice

let gen_input
    ~(blit : Bstr.t -> src_off:int -> 'buf -> dst_off:int -> len:int -> unit)
    in_stream buffer off len =
  assert (len > 0);

  let available_bytes = bytes_available in_stream in

  if available_bytes = 0 then begin
    set_slice in_stream (acquire_slice in_stream)
  end;

  let batched_bytes = min len available_bytes in

  blit in_stream.buf ~src_off:in_stream.off buffer ~dst_off:off
    ~len:batched_bytes;

  unsafe_advance_offset in_stream batched_bytes;

  batched_bytes

let rec gen_really_input ~blit in_stream buffer off len =
  if len > 0 then
    let batched_bytes = gen_input ~blit in_stream buffer off len in
    gen_really_input ~blit in_stream buffer (off + batched_bytes)
      (len - batched_bytes)

let[@inline] input in_stream buffer off len =
  gen_input ~blit:Bstr.blit in_stream buffer off len

and[@inline] really_input in_stream buffer off len =
  gen_really_input ~blit:Bstr.blit in_stream buffer off len

let[@inline] input_bytes in_stream bytes off len =
  gen_input ~blit:Bstr.blit_to_bytes in_stream bytes off len

and[@inline] really_input_bytes in_stream bytes off len =
  gen_really_input ~blit:Bstr.blit_to_bytes in_stream bytes off len

(* ===================================================================
    ENSURE MECHANISM WITH OVERLAPPING
   =================================================================== *)

let push_back in_stream slice =
  let acquire_slice' = in_stream.reader in

  in_stream.reader <-
    (fun () ->
      in_stream.reader <- acquire_slice';
      slice)

let[@inline] unsafe_ensure_bytes in_stream len =
  let aux in_stream available_bytes len =
    if available_bytes <> 0 then (
      really_input in_stream in_stream.overlap_buffer 0 len;
      push_back in_stream @@ peek_slice in_stream;

      set_slice in_stream @@ Slice_bstr.make ~len in_stream.overlap_buffer)
    else set_slice in_stream (acquire_slice in_stream)
  in

  let available_bytes = (bytes_available [@inlined]) in_stream in
  if available_bytes < len then aux in_stream available_bytes len

let ensure_bytes in_stream len =
  assert (len <= Bstr.length in_stream.overlap_buffer);
  unsafe_ensure_bytes in_stream len

let[@inline] ensure_bytes_at in_stream len =
  (unsafe_ensure_bytes [@inlined]) in_stream len;
  let offset = in_stream.off in
  (unsafe_advance_offset [@inlined]) in_stream len;
  offset

let ensure_slice in_stream len =
  let off = ensure_bytes_at in_stream len in
  Slice_bstr.make ~off ~len in_stream.buf

let ensure_buffer in_stream len =
  let off = ensure_bytes_at in_stream len in
  Bstr.sub in_stream.buf ~off ~len

(* ===================================================================
    COMBINATORS
   =================================================================== *)

let take n input_value in_stream = List.init n @@ fun _ -> input_value in_stream

let with_size f in_stream =
  let off = bytes_received in_stream in
  let result = f in_stream in
  let off' = bytes_received in_stream in

  (result, off' - off)

let[@tail_mod_cons] rec many input_value in_stream =
  match input_value in_stream with
  | (exception End_of_file) | None -> []
  | Some value -> value :: many input_value in_stream

(* ===================================================================
    INPUT INTEGER VALUES
   =================================================================== *)

let[@inline] gen_get in_stream f n =
  let off = (ensure_bytes_at [@inlined]) in_stream n in
  f in_stream.buf off

let[@inline] input_char in_stream = gen_get in_stream Bstr.get 1
let[@inline] input_int8 in_stream = gen_get in_stream Bstr.get_int8 1
let[@inline] input_uint8 in_stream = gen_get in_stream Bstr.get_uint8 1
let[@inline] input_byte in_stream = gen_get in_stream Bstr.get_uint8 1

(* int16 *)
let[@inline] input_int16_be in_stream = gen_get in_stream Bstr.get_int16_be 2
let[@inline] input_int16_ne in_stream = gen_get in_stream Bstr.get_int16_ne 2
let[@inline] input_int16_le in_stream = gen_get in_stream Bstr.get_int16_le 2
let[@inline] input_uint16_be in_stream = gen_get in_stream Bstr.get_uint16_be 2
let[@inline] input_uint16_ne in_stream = gen_get in_stream Bstr.get_uint16_ne 2
let[@inline] input_uint16_le in_stream = gen_get in_stream Bstr.get_uint16_le 2

(* int32 *)
let[@inline] input_int32_be in_stream = gen_get in_stream Bstr.get_int32_be 4
let[@inline] input_int32_ne in_stream = gen_get in_stream Bstr.get_int32_ne 4
let[@inline] input_int32_le in_stream = gen_get in_stream Bstr.get_int32_le 4

(* int64 *)
let[@inline] input_int64_be in_stream = gen_get in_stream Bstr.get_int64_be 4
let[@inline] input_int64_ne in_stream = gen_get in_stream Bstr.get_int64_ne 4
let[@inline] input_int64_le in_stream = gen_get in_stream Bstr.get_int64_le 4

(* ===================================================================
    OTHER
   =================================================================== *)

let input_string in_stream len =
  let bytes = Bytes.create len in
  (really_input_bytes [@inlined]) in_stream bytes 0 len;
  Bytes.unsafe_to_string bytes

let input_while_into_buffer ~max_len p in_stream buffer =
  let rec aux count =
    try
      if count <= max_len then begin
        (unsafe_ensure_bytes [@inlined]) in_stream 1;
        let ch = Bstr.get in_stream.buf in_stream.off in

        if p ch then begin
          (unsafe_advance_offset [@inlined]) in_stream 1;
          Buffer.add_char buffer ch;
          aux (succ count)
        end
      end
    with _ -> ()
  in

  aux 0

let check_on_end_of_file in_steam =
  try
    let new_chunk = acquire_slice in_steam in
    push_back in_steam new_chunk;
    false
  with End_of_file -> true

let input_while ?(max_len = Int.max_int) p in_stream =
  let[@inline] input_while_buffered max_len p in_stream =
    let[@local] buffer =
      Buffer.create (if max_len <> Int.max_int then max_len else 60)
    in

    input_while_into_buffer ~max_len p in_stream buffer;
    Buffer.contents buffer
  in

  let rec try_count_in_buffer max_len p in_stream length =
    let remaining_bytes_in_buffer = bytes_available in_stream - length in

    if remaining_bytes_in_buffer > 0 then begin
      let ch = Bstr.get in_stream.buf (in_stream.off + length) in
      if length <= max_len && p ch then
        try_count_in_buffer max_len p in_stream (succ length)
      else input_string in_stream length
    end
    else if check_on_end_of_file in_stream then input_string in_stream length
    else (input_while_buffered [@inlined]) max_len p in_stream
  in

  try_count_in_buffer max_len p in_stream 0

let input_while' ~max_len p in_stream =
  let string = input_while ~max_len p in_stream in
  consume_bytes in_stream (max_len - String.length string);
  string

let input_line in_stream =
  let rec aux in_stream buffer =
    match input_char in_stream with
    | (exception End_of_file) | '\n' ->
        if Buffer.length buffer > 0 then Some (Buffer.contents buffer) else None
    | ch ->
        Buffer.add_char buffer ch;
        aux in_stream buffer
  in

  aux in_stream (Buffer.create 100)
