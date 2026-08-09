type t = {
  mutable reader : unit -> chunk;
  mutable buffer : buffer;
  mutable offset : int;  (** Buffer's offset *)
  mutable length : int;  (** Buffer's length *)
  mutable total_offset : int;  (** Total read bytes from some source *)
  overlap_buffer : buffer;
      (** A small buffer to resolve the data gap situation between chunks *)
}

and buffer =
  (char, Bigarray.int8_unsigned_elt, Bigarray.c_layout) Bigarray.Array1.t

and chunk = buffer:buffer * offset:int * length:int

(* ===================================================================
    CONSTRUCTORS
   =================================================================== *)

let make' ?(overlap_size = 0xFF) reader =
  {
    reader;
    buffer = Bstr.empty;
    offset = 0;
    length = 0;
    total_offset = 0;
    overlap_buffer = Bstr.create overlap_size;
  }

let make ?overlap_size reader =
  let reader () =
    let buffer = reader () in
    (~buffer, ~offset:0, ~length:Bstr.(length buffer))
  in

  make' ?overlap_size reader

let of_buffer buffer =
  {
    reader = (fun () -> (~buffer:Bstr.empty, ~offset:0, ~length:0));
    buffer;
    offset = 0;
    length = 0;
    total_offset = 0;
    overlap_buffer = Bstr.empty;
  }

let of_string s = Bstr.of_string s |> of_buffer

let of_channel ?(io_buffer_size = 4096) ic =
  let buffer = Bstr.create io_buffer_size in

  let reader () =
    match In_channel.input_bigarray ic buffer 0 io_buffer_size with
    | 0 -> raise End_of_file
    | length -> (~buffer, ~offset:0, ~length)
  in

  make' reader

(* ===================================================================
    BUFFER MANIPULATION UTILITY FUNCTIONS
   =================================================================== *)

let[@inline] available_to_read in_stream =
  Bstr.length in_stream.buffer - in_stream.offset

let advance_offset in_stream n =
  in_stream.offset <- in_stream.offset + n;
  in_stream.length <- in_stream.length - n;
  in_stream.total_offset <- in_stream.total_offset + n

let[@inline] acquire_chunk in_stream = in_stream.reader ()

let set_chunk in_stream ((~buffer, ~offset, ~length) : chunk) =
  in_stream.buffer <- buffer;
  in_stream.offset <- offset;
  in_stream.length <- length

let get_chunk in_stream =
  (~buffer:in_stream.buffer, ~offset:in_stream.offset, ~length:in_stream.length)

let position in_stream = in_stream.total_offset

let rec consume_bytes in_stream len =
  if len <> 0 then begin
    let available_bytes = available_to_read in_stream in
    let available_to_consume = min available_bytes len in

    advance_offset in_stream available_to_consume;

    if available_to_consume < len then begin
      set_chunk in_stream (acquire_chunk in_stream);
      consume_bytes in_stream (len - available_to_consume)
    end
  end

(* ===================================================================
    INPUTS
   =================================================================== *)

let rec gen_input
    ~(blit : Bstr.t -> src_off:int -> 'buf -> dst_off:int -> len:int -> unit)
    in_stream buffer off len =
  assert (len > 0);

  let available_bytes = available_to_read in_stream in

  if available_bytes = 0 then (
    set_chunk in_stream (acquire_chunk in_stream);
    gen_input ~blit in_stream buffer off len)
  else
    let batched_bytes = min len available_bytes in

    blit in_stream.buffer ~src_off:in_stream.offset buffer ~dst_off:off
      ~len:batched_bytes;

    advance_offset in_stream batched_bytes;

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

let push_back in_stream chunk =
  let acquire_chunk' = in_stream.reader in

  in_stream.reader <-
    (fun () ->
      in_stream.reader <- acquire_chunk';
      chunk)

let ensure_bytes in_stream length =
  (* assert (len <= Bstr.length in_stream.overlap_buffer); *)
  if available_to_read in_stream < length then begin
    really_input in_stream in_stream.overlap_buffer 0 length;

    push_back in_stream @@ get_chunk in_stream;
    set_chunk in_stream (~buffer:in_stream.overlap_buffer, ~offset:0, ~length)
  end

let ensure_bytes_at in_stream len =
  ensure_bytes in_stream len;
  let offset = in_stream.offset in
  advance_offset in_stream len;
  offset

let ensure_chunk in_stream len =
  let off = ensure_bytes_at in_stream len in
  Bstr.sub in_stream.buffer ~off ~len

(* ===================================================================
    INPUT INTEGER VALUES
   =================================================================== *)

let[@inline] gen_get in_stream f n =
  let off = ensure_bytes_at in_stream n in
  f in_stream.buffer off

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
  really_input_bytes in_stream bytes 0 len;
  Bytes.unsafe_to_string bytes

let input_while ?max p in_stream =
  let buffer = Buffer.create 0x0f in
  let max_len = Option.value max ~default:Int.max_int in

  let rec aux count =
    if count < max_len then
      let ch = input_char in_stream in

      if p ch then begin
        Buffer.add_char buffer ch;
        aux (succ count)
      end
  in

  aux 0;

  Buffer.contents buffer

let input_while' ~max p in_stream =
  let string = input_while ~max p in_stream in
  consume_bytes in_stream (max - String.length string);
  string

(* ===================================================================
    TRANSFORMING
   =================================================================== *)

(* ... *)
