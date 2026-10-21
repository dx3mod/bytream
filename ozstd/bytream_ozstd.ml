module In = struct
  let make ?dictionary ?size_limit in_stream =
    let state =
      Ozstd.Decompressor.create ?dictionary ?size_limit ()
      |> Ozstd.Decompressor.Stream.make |> Ozstd.Decompressor.State.make
    in

    let reader () =
      Bytream.In.input_slice in_stream |> Ozstd.Decompressor.State.feed state
    in

    Bytream.In.make reader
end

module Out = struct
  let make ?dictionary ?compression_level out_stream =
    let state =
      Ozstd.Compressor.create ?compression_level ?dictionary ()
      |> Ozstd.Compressor.Stream.make |> Ozstd.Compressor.State.make
    in

    let f slice = Ozstd.Compressor.State.feed state slice `Flush in
    Bytream.Out.transform out_stream f
end
