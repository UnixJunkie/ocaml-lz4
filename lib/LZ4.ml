open Ctypes

module C = LZ4_bindings.C(LZ4_generated)

exception Input_too_large
exception Corrupted

let compress_bound (sz: int) =
  if sz < 0 then invalid_arg "LZ4.compress_bound";
  if Sys.word_size = 32 then (
    if  sz > 1_069_547_504 then
      raise Input_too_large;
  )
  else if sz > 0x7E000000 then
    raise Input_too_large;
  C.compressBound sz

module type S = sig
  type storage

  val compress   : storage -> storage
  val compress_buff : storage -> storage -> int -> int -> int
  val decompress : length:int -> storage -> storage
end

module Bytes = struct
  type storage = Bytes.t

  let compress_buff input out_buff offset len =
    let in_length = Bytes.length input in
    let bound = compress_bound in_length in
    if bound > len then raise Input_too_large;
    C.b_compress
      (ocaml_bytes_start input)
      (ocaml_bytes_start out_buff +@ offset)
      in_length

  let compress input =
    let in_length = Bytes.length input in
    let out_length = compress_bound in_length in
    let output = Bytes.create out_length in
    let length = compress_buff input output 0 out_length in
    Bytes.sub output 0 length

  let decompress ~length input =
    if length < 0 then invalid_arg "LZ4.decompress";
    let output  = Bytes.create length in
    let length' = C.b_decompress (ocaml_bytes_start input) (ocaml_bytes_start output)
                                 (Bytes.length input) length in
    if length' < 0 then
      raise Corrupted
    else if length' <> length then
      Bytes.sub output 0 length'
    else
      output
end

module Bigbytes = struct
  type storage = (char, Bigarray.int8_unsigned_elt, Bigarray.c_layout)
                 Bigarray.Array1.t

  open Bigarray

  let compress input =
    let output = Array1.create char c_layout (compress_bound (Array1.dim input)) in
    let length = C.ba_compress (bigarray_start array1 input) (bigarray_start array1 output)
                               (Array1.dim input) in
    Array1.sub output 0 length

  let compress_buff input out_buff offset len =
    failwith "not implemented yet"

  let decompress ~length input =
    if length < 0 then invalid_arg "LZ4.decompress";
    let output  = Array1.create char c_layout length in
    let length' = C.ba_decompress (bigarray_start array1 input) (bigarray_start array1 output)
                                  (Array1.dim input) length in
    if length' < 0 then
      raise Corrupted
    else if length' <> length then
      Array1.sub output 0 length'
    else
      output
end
