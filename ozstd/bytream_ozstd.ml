module In = struct
  let of_stream ?dictionary ?size_limit in_stream =
    let decompressor = Ozstd.Decompressor.create ?dictionary ?size_limit () in
    let state =
      decompressor |> Ozstd.Decompressor.Stream.make
      |> Ozstd.Decompressor.State.make
    in

    let reader () =
      let ~buffer, ~offset:off, ~length:len =
        Bytream.In.input_chunk in_stream
      in
      let Slice.{ buf = buffer; off = offset; len = length } =
        Ozstd.Decompressor.State.feed state Slice_bstr.(make ~off ~len buffer)
      in

      (~buffer, ~offset, ~length)
    in

    Bytream.In.make' reader
end

module Out = struct
  let of_stream ?dictionary ?compression_level out_stream =
    let compressor =
      Ozstd.Compressor.create ?compression_level ?dictionary ()
    in
    let state =
      compressor |> Ozstd.Compressor.Stream.make |> Ozstd.Compressor.State.make
    in

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
