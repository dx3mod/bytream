(* module In = struct
  let input_record in_stream decoding =
    let ~buffer, ~offset, ~length = Bytream.In.ensure_chunk in_stream length in

    let decode = Bin.Staged.unstage @@ Bin.decode_bstr decoding in
    decode ~len:length buffer (ref @@ Bin.Off.v offset)
end *)
