module In = struct
  let input in_stream decoding =
    let decode = Bin.Staged.unstage @@ Bin.decode_bstr decoding in

    let rec aux Slice.{ buf; off; len } =
      match decode ~len buf (ref @@ Bin.Off.v off) with
      | decoded_value -> decoded_value
      | exception Bin_error.Error { kind = Truncated { need; _ }; _ } ->
          let slice = Slice_bstr.create (Bin_type.Len.to_int need) in
          Bytream.In.really_input in_stream slice.buf 0 slice.len;
          aux slice
    in

    aux (Bytream.In.peek_slice in_stream)
end

module Out = struct
  let output out_stream encoding value =
    let encoding_size = Bin.size_of_value encoding value in
    let encode = Bin.Staged.unstage @@ Bin.encode_bstr encoding in

    let Slice.{ buf; off; len } =
      if Bytream.Out.buffer_size out_stream > encoding_size then
        Bytream.Out.ensure_slice out_stream encoding_size
      else Slice_bstr.create encoding_size
    in

    encode value buf ~len (ref @@ Bin.Off.v off)
end
