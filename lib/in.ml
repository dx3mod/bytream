type t = {
  mutable reader : unit -> Slice_bstr.t;
  mutable buf : Bstr.t;
  mutable off : int;
  mutable len : int;
  mutable bytes_read : int;
  overlap_buffer : Bstr.t;
}

(* ===================================================================
   CONSTRUCTORS
   =================================================================== *)

let make ?overlap_buffer reader =
  let overlap_buffer =
    match overlap_buffer with Some b -> b | None -> Bstr.create 0xFF
  in

  assert (Bstr.length overlap_buffer > 0);

  { reader; buf = Bstr.empty; off = 0; len = 0; bytes_read = 0; overlap_buffer }

let of_bigstring buf =
  {
    reader = (fun () -> raise End_of_file);
    buf;
    off = 0;
    len = Bstr.length buf;
    bytes_read = 0;
    overlap_buffer = Bstr.empty;
  }

let of_string s = Bstr.of_string s |> of_bigstring

let of_channel ?(io_buffer_size = 4096) ic =
  let buf = Bstr.create io_buffer_size in

  let reader () =
    match In_channel.input_bigarray ic buf 0 io_buffer_size with
    | 0 -> raise End_of_file
    | len -> Slice_bstr.make ~len buf
  in

  make reader

let with_overlap_buffer in_stream overlap_buffer =
  { in_stream with overlap_buffer }

let[@inline] bytes_read in_stream = in_stream.bytes_read

(* ===================================================================
   INTERNAL BUFFER MANIPULATION
   =================================================================== *)

let[@inline] bytes_available in_stream = in_stream.len

let unsafe_shift in_stream n =
  in_stream.off <- in_stream.off + n;
  in_stream.len <- in_stream.len - n;
  in_stream.bytes_read <- in_stream.bytes_read + n

let shift in_stream n =
  if n >= 0 && in_stream.len >= n then unsafe_shift in_stream n
  else invalid_arg "shift: negative or out of bounds"

let[@inline] acquire_slice in_stream = in_stream.reader ()

let set_slice in_stream Slice.{ buf; off; len } =
  in_stream.buf <- buf;
  in_stream.off <- off;
  in_stream.len <- len

let[@inline] peek_slice in_stream =
  Slice_bstr.make ~off:in_stream.off ~len:in_stream.len in_stream.buf

let rec consume_bytes in_stream n =
  if n > 0 then
    match bytes_available in_stream with
    | 0 ->
        set_slice in_stream (acquire_slice in_stream);
        consume_bytes in_stream n
    | available ->
        let to_consume = min available n in
        unsafe_shift in_stream to_consume;

        if to_consume < n then consume_bytes in_stream (n - to_consume)

(* ===================================================================
   INPUT FUNCTIONS
   =================================================================== *)

let input_slice in_stream =
  match bytes_available in_stream with
  | 0 ->
      let slice = acquire_slice in_stream in
      set_slice in_stream slice;
      unsafe_shift in_stream slice.len;
      slice
  | _ ->
      let slice = peek_slice in_stream in
      unsafe_shift in_stream slice.len;
      slice

let gen_input ~blit in_stream dst dst_off len =
  if bytes_available in_stream = 0 then
    set_slice in_stream (acquire_slice in_stream);

  let to_read = min len (bytes_available in_stream) in

  if to_read > 0 then begin
    blit in_stream.buf ~src_off:in_stream.off dst ~dst_off ~len:to_read;
    unsafe_shift in_stream to_read
  end;

  to_read

let rec gen_really_input ~blit in_stream dst dst_off remaining =
  if remaining > 0 then
    match gen_input ~blit in_stream dst dst_off remaining with
    | 0 -> raise End_of_file
    | read ->
        gen_really_input ~blit in_stream dst (dst_off + read) (remaining - read)

let[@inline] input in_stream buf off len =
  gen_input ~blit:Bstr.blit in_stream buf off len

let[@inline] really_input in_stream buf off len =
  gen_really_input ~blit:Bstr.blit in_stream buf off len

let[@inline] input_bytes in_stream bytes off len =
  gen_input ~blit:Bstr.blit_to_bytes in_stream bytes off len

let[@inline] really_input_bytes in_stream bytes off len =
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
  if bytes_available in_stream < len then
    match bytes_available in_stream with
    | 0 -> set_slice in_stream (acquire_slice in_stream)
    | _ ->
        really_input in_stream in_stream.overlap_buffer 0 len;
        push_back in_stream (peek_slice in_stream);
        set_slice in_stream (Slice_bstr.make ~len in_stream.overlap_buffer)

let ensure_bytes in_stream len =
  assert (len >= 0 && len <= Bstr.length in_stream.overlap_buffer);
  unsafe_ensure_bytes in_stream len

let[@inline] unsafe_ensure_bytes_at in_stream len =
  unsafe_ensure_bytes in_stream len;
  let offset = in_stream.off in
  unsafe_shift in_stream len;
  offset

let ensure_slice in_stream len =
  let off = unsafe_ensure_bytes_at in_stream len in
  Slice_bstr.make ~off ~len in_stream.buf

let ensure_buffer in_stream len =
  let off = unsafe_ensure_bytes_at in_stream len in
  Bstr.sub in_stream.buf ~off ~len

(* ===================================================================
   COMBINATORS
   =================================================================== *)

let take n input_value in_stream = List.init n (fun _ -> input_value in_stream)

let with_size f in_stream =
  let off = bytes_read in_stream in
  let result = f in_stream in
  (result, bytes_read in_stream - off)

let[@tail_mod_cons] rec many input_value in_stream =
  match input_value in_stream with
  | (exception End_of_file) | None -> []
  | Some value -> value :: many input_value in_stream

(* ===================================================================
   INPUT INTEGER VALUES
   =================================================================== *)

let[@inline] gen_get in_stream f len =
  let off = unsafe_ensure_bytes_at in_stream len in
  f in_stream.buf off

(* 8-bit integers *)
let[@inline] input_char in_stream = gen_get in_stream Bstr.get 1
let[@inline] input_int8 in_stream = gen_get in_stream Bstr.get_int8 1
let[@inline] input_uint8 in_stream = gen_get in_stream Bstr.get_uint8 1
let[@inline] input_byte in_stream = gen_get in_stream Bstr.get_uint8 1

(* 16-bit integers *)
let[@inline] input_int16_be in_stream = gen_get in_stream Bstr.get_int16_be 2
let[@inline] input_int16_le in_stream = gen_get in_stream Bstr.get_int16_le 2
let[@inline] input_int16_ne in_stream = gen_get in_stream Bstr.get_int16_ne 2
let[@inline] input_uint16_be in_stream = gen_get in_stream Bstr.get_uint16_be 2
let[@inline] input_uint16_le in_stream = gen_get in_stream Bstr.get_uint16_le 2
let[@inline] input_uint16_ne in_stream = gen_get in_stream Bstr.get_uint16_ne 2

(* 32-bit integers *)
let[@inline] input_int32_be in_stream = gen_get in_stream Bstr.get_int32_be 4
let[@inline] input_int32_le in_stream = gen_get in_stream Bstr.get_int32_le 4
let[@inline] input_int32_ne in_stream = gen_get in_stream Bstr.get_int32_ne 4

(* 64-bit integers *)
let[@inline] input_int64_be in_stream = gen_get in_stream Bstr.get_int64_be 8
let[@inline] input_int64_le in_stream = gen_get in_stream Bstr.get_int64_le 8
let[@inline] input_int64_ne in_stream = gen_get in_stream Bstr.get_int64_ne 8

(* ===================================================================
   OTHER
   =================================================================== *)

let input_string in_stream len =
  assert (len >= 0);
  let bytes = Bytes.create len in
  really_input_bytes in_stream bytes 0 len;
  Bytes.unsafe_to_string bytes

let input_while_to_buffer ~max_len buffer p in_stream =
  assert (max_len >= 0);

  let rec aux count =
    if count < max_len then
      try
        unsafe_ensure_bytes in_stream 1;
        let ch = Bstr.get in_stream.buf in_stream.off in

        if p ch then begin
          unsafe_shift in_stream 1;
          Buffer.add_char buffer ch;
          aux (succ count)
        end
      with End_of_file -> ()
  in

  aux 0

let input_while ?(max_len = Int.max_int) p in_stream =
  assert (max_len >= 0);

  let buffer = Buffer.create (min max_len 60) in
  input_while_to_buffer ~max_len buffer p in_stream;
  Buffer.contents buffer

let input_while' ~max_len p in_stream =
  assert (max_len >= 0);

  let string = input_while ~max_len p in_stream in
  consume_bytes in_stream (max_len - String.length string);
  string

let peek_char in_stream =
  match bytes_available in_stream with
  | 0 -> None
  | _ -> Some (Bstr.get in_stream.buf in_stream.off)

let input_line in_stream =
  let buffer = Buffer.create 100 in

  let rec aux () =
    match (input_char in_stream, peek_char in_stream) with
    | (exception End_of_file) | '\n', _ ->
        if Buffer.length buffer > 0 then Some (Buffer.contents buffer) else None
    | '\r', Some '\n' ->
        unsafe_shift in_stream 1;
        Some (Buffer.contents buffer)
    | ch, _ ->
        Buffer.add_char buffer ch;
        aux ()
  in
  aux ()
