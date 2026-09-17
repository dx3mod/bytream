module In = struct
  let of_stream ?dictionary ?size_limit in_stream =
    let state = Ozstd.Decompressor.State.create ?dictionary ?size_limit () in

    Bytream.In.make' @@ fun () ->
    let ~buffer, ~offset:off, ~length:len = Bytream.In.input_chunk in_stream in
    let Slice.{ buf = buffer; off = offset; len = length } =
      Ozstd.Decompressor.State.feed state Slice_bstr.(make ~off ~len buffer)
    in

    (~buffer, ~offset, ~length)
end

module Out = struct
  let of_stream ?dictionary ?level out_stream =
    let state = Ozstd.Compressor.State.create ?dictionary ?level () in

    let writer (~buffer, ~offset:off, ~length:len) =
      let slice =
        let in_slice = Slice_bstr.make ~off ~len buffer in
        Ozstd.Compressor.State.feed state in_slice `Flush
      in

      if not (Slice_bstr.is_empty slice) then
        let Slice.{ buf = buffer; off = offset; len = length } = slice in
        Bytream.Out.output_chunk out_stream (~buffer, ~offset, ~length)
    in

    Bytream.Out.make writer
end
