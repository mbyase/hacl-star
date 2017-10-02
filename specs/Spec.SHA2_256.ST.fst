module Spec.SHA2_256

module ST = FStar.HyperStack.ST

open FStar.Seq
open FStar.UInt32

open Spec.Loops
open Spec.Lib

module Word = FStar.UInt32


val pow2_values: x:nat -> Lemma
  (requires True)
  (ensures (let p = pow2 x in
   match x with
   | 61 -> p=2305843009213693952
   | _  -> True))
  [SMTPat (pow2 x)]
let pow2_values x =
   match x with
   | 61 -> assert_norm (pow2 61 == 2305843009213693952)
   | _  -> ()


#set-options "--initial_fuel 0 --max_fuel 0 --z3rlimit 25"


//
// SHA-256
//

type u64 = UInt64.t
type u32 = UInt32.t
type u32seq n = s:Seq.seq u32{Seq.length s == n}
type u8 = UInt8.t
type u8seq n = s:Seq.seq u8{Seq.length s == n}

type block = u8seq 64
let max_input_len_8 = pow2 61
type len = n:nat {n < max_input_len_8}

type state_spec = {
  k: u32seq 64;
  h0: u32seq 8;
  data: u32seq 16;
  ws: u32seq 64;
  whash: u32seq 8;
  whash_copy: u32seq 8;
  len: s:seq len{length s == 1};
  pad: u8seq 128
}

(* The following could be autogenerated from the type definition above *)
type idx_l (l:nat) = i:nat {i < l}
type key = 
 | K
 | H0 
 | Data 
 | Ws 
 | Whash 
 | Whash_copy 
 | Len
 | Pad

unfold let seqlen (k:key) = 
  match k with
 | K  -> 64
 | H0  -> 8
 | Data  -> 16
 | Ws  -> 64
 | Whash  -> 8
 | Whash_copy  -> 8
 | Len  -> 1
 | Pad -> 128
 
let index (k:key) = n:nat {n < seqlen k}

unfold let value (k:key) = 
  match k with
 | K   -> u32
 | H0  -> u32
 | Data  -> u32
 | Ws  -> u32
 | Whash  -> u32
 | Whash_copy  -> u32
 | Len  -> len
 | Pad -> u8

let x () : Lemma (value Data == value K) = ()


let seqvalue (k:key) = s:seq (value k){length s == seqlen k}

let get_value (st:state_spec) (k:key) : seqvalue k = 
 match k with
 | K   -> st.k
 | H0  -> st.h0
 | Data  -> st.data
 | Ws  -> st.ws
 | Whash  -> st.whash
 | Whash_copy  -> st.whash_copy
 | Len  -> st.len
 | Pad -> st.pad
 
type stateful 'b = state_spec -> Tot ('b * state_spec)

let apply_read (k:key) (f:seqvalue k -> 'b) : stateful 'b = 
  fun st -> f (get_value st k), st

let read (k:key) (x:index k)  : stateful (value k) = 
  apply_read k (fun s -> Seq.index s x)

let apply_write (k:key) (f:seq1_st (value k) (seqlen k) 'b) : stateful 'b =
  fun st -> match k with
 | K   ->  let b,s' = f st.k in b,{st with k = s'}
 | H0  -> let b,s' = f st.h0 in b,{st with h0 = s'}
 | Data  -> let b,s' = f st.data in b,{st with data = s'}
 | Ws  -> let b,s' = f st.ws in b,{st with ws = s'}
 | Whash  -> let b,s' = f st.whash in b,{st with whash = s'}
 | Whash_copy  -> let b,s' = f st.whash_copy in b,{st with whash_copy = s'}
 | Len  -> let b,s' = f st.len in b,{st with len = s'}
 | Pad ->  let b,s' = f st.pad in b,{st with pad = s'}

let write (k:key) (x:index k) (v:value k) : stateful unit = 
  apply_write k (seq1_write x v)

let apply_read_write (k1:key) (k2:key{k1 <> k2}) 
  (f:seqvalue k1 -> seq1_st (value k2) (seqlen k2) 'b) : stateful 'b = 
  fun st -> 
    apply_write k2 (f (get_value st k1)) st


let bind (f:stateful 'b) (g:'b -> stateful 'c) : stateful 'c = 
  fun st -> let (b,s) = f st in g b s

let return (x:'b): stateful 'b = fun st -> (x,st)

let iteri (min:nat) (max:nat{min <= max}) (f:x:nat{x >= min /\ x < max} -> stateful unit) : stateful unit = 
    fun s -> 
      (),Spec.Loops.repeat_range_spec min max (fun s i -> snd (f i s)) s

(* The above could be autogenerated from the type definition above *)

(* SHA2-256 Begins Here *)

let rotate_right (a:u32) (s:u32 {0 < v s /\ v s < 32}) : Tot u32 =
  ((a >>^ s) |^ (a <<^ (32ul -^ s)))

let _Ch x y z = (x &^ y) |^ ((lognot x) &^ z)

let _Maj x y z = (x &^ y) ^^ ((x &^ z) ^^ (y &^ z))

let _Sigma0 x = (x >>> 2ul) ^^ ((x >>> 13ul) ^^ (x >>> 22ul))

let _Sigma1 x = (x >>> 6ul) ^^ ((x >>> 11ul) ^^ (x >>> 25ul))

let _sigma0 x = (x >>> 7ul) ^^ ((x >>> 18ul) ^^ (x >>^ 3ul))

let _sigma1 x = (x >>> 17ul) ^^ ((x >>> 19ul) ^^ (x >>^ 10ul))


let setup_k: stateful unit = 
  apply_write K (
  seq1_upd64 #u32  
  0x428a2f98ul 0x71374491ul 0xb5c0fbcful 0xe9b5dba5ul
  0x3956c25bul 0x59f111f1ul 0x923f82a4ul 0xab1c5ed5ul
  0xd807aa98ul 0x12835b01ul 0x243185beul 0x550c7dc3ul
  0x72be5d74ul 0x80deb1feul 0x9bdc06a7ul 0xc19bf174ul
  0xe49b69c1ul 0xefbe4786ul 0x0fc19dc6ul 0x240ca1ccul
  0x2de92c6ful 0x4a7484aaul 0x5cb0a9dcul 0x76f988daul
  0x983e5152ul 0xa831c66dul 0xb00327c8ul 0xbf597fc7ul
  0xc6e00bf3ul 0xd5a79147ul 0x06ca6351ul 0x14292967ul
  0x27b70a85ul 0x2e1b2138ul 0x4d2c6dfcul 0x53380d13ul
  0x650a7354ul 0x766a0abbul 0x81c2c92eul 0x92722c85ul
  0xa2bfe8a1ul 0xa81a664bul 0xc24b8b70ul 0xc76c51a3ul
  0xd192e819ul 0xd6990624ul 0xf40e3585ul 0x106aa070ul
  0x19a4c116ul 0x1e376c08ul 0x2748774cul 0x34b0bcb5ul
  0x391c0cb3ul 0x4ed8aa4aul 0x5b9cca4ful 0x682e6ff3ul
  0x748f82eeul 0x78a5636ful 0x84c87814ul 0x8cc70208ul
  0x90befffaul 0xa4506cebul 0xbef9a3f7ul 0xc67178f2ul)


let alloc (f:stateful 'b) : Tot 'b =
  let k = Seq.create 64 0ul in
  let h0 = Seq.create 8 0ul in
  let data = Seq.create 16 0ul in
  let ws = Seq.create 64 0ul in
  let whash = Seq.create 8 0ul in
  let whash_copy = Seq.create 8 0ul in
  let len = Seq.create 1 0 in
  let pad = Seq.create 128 0uy in
  let s = {k=k; h0=h0; data=data;
	   ws=ws; whash=whash; whash_copy=whash_copy;
	   len=len; pad=pad} in
  fst (f s)


let setup_h_0 : stateful unit =
  apply_write H0 (
  seq1_upd8 #u32 0  
  0x6a09e667ul 0xbb67ae85ul 0x3c6ef372ul 0xa54ff53aul
  0x510e527ful 0x9b05688cul 0x1f83d9abul 0x5be0cd19ul)

(* OLD Spec:
let rec ws (b:u32seq 16) (t:nat{t < 64}) : Tot u32 =
  if t < 16 then b.[t]
  else
    let t16 = ws b (t - 16) in
    let t15 = ws b (t - 15) in
    let t7  = ws b (t - 7) in
    let t2  = ws b (t - 2) in

    let s1 = _sigma1 t2 in
    let s0 = _sigma0 t15 in
    (s1 +%^ (t7 +%^ (s0 +%^ t16)))
*)

let setup_ws0 : stateful unit = 
  iteri 0 16 (fun i ->
     x <-- read Data i ;
     write Ws i x)

let setup_ws1 : stateful unit = 
  iteri 16 64 (fun i ->
    t16 <-- read Ws (i - 16) ;
    t15 <-- read Ws (i - 15) ;
    t7  <-- read Ws (i - 7)  ;
    t2  <-- read Ws (i - 2)  ;
    let s1 = _sigma1 t2 in
    let s0 = _sigma0 t15 in
    write Ws i (s1 +%^ (t7 +%^ (s0 +%^ t16))))

let setup_ws : stateful unit = 
  setup_ws0 ;;
  setup_ws1
  
let shuffle_core  (t:nat{t >= 0 /\ t < 64}) : stateful unit =
  a <-- read Whash 0 ;
  b <-- read Whash 1 ;
  c <-- read Whash 2 ;
  d <-- read Whash 3 ;
  e <-- read Whash 4 ;
  f <-- read Whash 5 ;
  g <-- read Whash 6 ;
  h <-- read Whash 7 ;
  kt <-- read K t ;
  wst <-- read Ws t ;
  
  let t1 = h +%^ (_Sigma1 e) +%^ (_Ch e f g) +%^ kt +%^ wst in
  let t2 = (_Sigma0 a) +%^ (_Maj a b c) in

  write Whash 0 (t1 +%^ t2);;
  write Whash 1 a ;;
  write Whash 2 b ;;
  write Whash 3 c ;;
  write Whash 4 (d +%^ t1);;
  write Whash 5 e ;;
  write Whash 6 f ;;
  write Whash 7 g 


let shuffle : stateful unit = 
  iteri 0 64 shuffle_core

let copy_whash: stateful unit = 
  iteri 0 8 (fun i -> x <-- read Whash i; write Whash_copy i x)

let sum_whash_copy: stateful unit = 
  iteri 0 8 (fun i -> x <-- read Whash i; y <-- read Whash_copy i; write Whash i (x +%^ y))

let update_core : stateful unit = 
  copy_whash ;;
  shuffle ;;
  sum_whash_copy

let update (b:block) : stateful unit =
  apply_write Data (seq1_uint32s_from_be b 0 16);;
  update_core

let rec update_multi (n:nat) (blocks:bytes{length blocks == FStar.Mul.(n * 64)}) : stateful unit = 
  if Seq.length blocks = 0 then return ()
  else
    let (block,rem) = Seq.split blocks 64 in
    update block ;;
    update_multi (n-1) rem

let padding_blocks (len:nat) : nat = 
  if (len < 56) then 1 else 2

let rec big_bytes #max (start:nat) (len:nat{start+len <= max}) (n:nat) : seq1_st u8 max unit = 
  if len = 0 then 
    seq1_return #u8 #max ()
  else
    let bind = seq1_bind in
    let len = len - 1 in 
    let byte = UInt8.uint_to_t (n % 256) in
    let n' = n / 256 in 
    seq1_write (start+len) byte;;
    big_bytes #max start len n'

let pad (n:nat) (last:seq u8{length last < 64}) : stateful nat =
  let lastlen = length last in
  let blocks = padding_blocks lastlen in
  let plen = FStar.Mul.(blocks * 64) in
  let tlen = FStar.Mul.(n * 64) + lastlen in
  iteri 0 lastlen (fun i -> write Pad i last.[i]);;
  write Pad lastlen 0x80uy ;;
  iteri (lastlen+1) (plen - 8) (fun i -> write Pad i 0uy);;
  let tlenbits = FStar.Mul.(tlen * 8) in
  apply_write Pad (big_bytes #128 (plen - 8) 8 tlenbits) ;;
  return blocks
  

let update_last (n:nat) (last:seq u8{length last < 64}) : stateful unit =
  b <-- pad n last;
  apply_read_write Pad Data (fun s -> 
    let s' = Seq.slice s 0 64 in
    seq1_uint32s_from_be s' 0 16);;
  update_core;;
  if b > 0 then (
    apply_read_write Pad Data (fun s -> 
      let s' = Seq.slice s 64 128 in
      seq1_uint32s_from_be s' 0 16);;
    update_core)
  else return ()

let finish (whash:u32seq 8) =
    uint32s_to_be 8 whash


let hash (input:bytes{Seq.length input < max_input_len_8}) : Tot (hash:bytes{length hash = 32}) =
  let n = Seq.length input / 64 in
  let (bs,l) = Seq.split input FStar.Mul.(n * 64) in
  alloc (
    update_multi n bs;;
    update_last n l;;
    apply_read Whash (uint32s_to_be 8))


//
// Test 1
//

let test_plaintext1 = [
  0x61uy; 0x62uy; 0x63uy;
]

let test_expected1 = [
  0xbauy; 0x78uy; 0x16uy; 0xbfuy; 0x8fuy; 0x01uy; 0xcfuy; 0xeauy;
  0x41uy; 0x41uy; 0x40uy; 0xdeuy; 0x5duy; 0xaeuy; 0x22uy; 0x23uy;
  0xb0uy; 0x03uy; 0x61uy; 0xa3uy; 0x96uy; 0x17uy; 0x7auy; 0x9cuy;
  0xb4uy; 0x10uy; 0xffuy; 0x61uy; 0xf2uy; 0x00uy; 0x15uy; 0xaduy
]

//
// Test 2
//

let test_plaintext2 = []

let test_expected2 = [
  0xe3uy; 0xb0uy; 0xc4uy; 0x42uy; 0x98uy; 0xfcuy; 0x1cuy; 0x14uy;
  0x9auy; 0xfbuy; 0xf4uy; 0xc8uy; 0x99uy; 0x6fuy; 0xb9uy; 0x24uy;
  0x27uy; 0xaeuy; 0x41uy; 0xe4uy; 0x64uy; 0x9buy; 0x93uy; 0x4cuy;
  0xa4uy; 0x95uy; 0x99uy; 0x1buy; 0x78uy; 0x52uy; 0xb8uy; 0x55uy
]

//
// Test 3
//

let test_plaintext3 = [
  0x61uy; 0x62uy; 0x63uy; 0x64uy; 0x62uy; 0x63uy; 0x64uy; 0x65uy;
  0x63uy; 0x64uy; 0x65uy; 0x66uy; 0x64uy; 0x65uy; 0x66uy; 0x67uy;
  0x65uy; 0x66uy; 0x67uy; 0x68uy; 0x66uy; 0x67uy; 0x68uy; 0x69uy;
  0x67uy; 0x68uy; 0x69uy; 0x6auy; 0x68uy; 0x69uy; 0x6auy; 0x6buy;
  0x69uy; 0x6auy; 0x6buy; 0x6cuy; 0x6auy; 0x6buy; 0x6cuy; 0x6duy;
  0x6buy; 0x6cuy; 0x6duy; 0x6euy; 0x6cuy; 0x6duy; 0x6euy; 0x6fuy;
  0x6duy; 0x6euy; 0x6fuy; 0x70uy; 0x6euy; 0x6fuy; 0x70uy; 0x71uy
]

let test_expected3 = [
  0x24uy; 0x8duy; 0x6auy; 0x61uy; 0xd2uy; 0x06uy; 0x38uy; 0xb8uy;
  0xe5uy; 0xc0uy; 0x26uy; 0x93uy; 0x0cuy; 0x3euy; 0x60uy; 0x39uy;
  0xa3uy; 0x3cuy; 0xe4uy; 0x59uy; 0x64uy; 0xffuy; 0x21uy; 0x67uy;
  0xf6uy; 0xecuy; 0xeduy; 0xd4uy; 0x19uy; 0xdbuy; 0x06uy; 0xc1uy
]


//
// Test 4
//

let test_plaintext4 = [
  0x61uy; 0x62uy; 0x63uy; 0x64uy; 0x65uy; 0x66uy; 0x67uy; 0x68uy;
  0x62uy; 0x63uy; 0x64uy; 0x65uy; 0x66uy; 0x67uy; 0x68uy; 0x69uy;
  0x63uy; 0x64uy; 0x65uy; 0x66uy; 0x67uy; 0x68uy; 0x69uy; 0x6auy;
  0x64uy; 0x65uy; 0x66uy; 0x67uy; 0x68uy; 0x69uy; 0x6auy; 0x6buy;
  0x65uy; 0x66uy; 0x67uy; 0x68uy; 0x69uy; 0x6auy; 0x6buy; 0x6cuy;
  0x66uy; 0x67uy; 0x68uy; 0x69uy; 0x6auy; 0x6buy; 0x6cuy; 0x6duy;
  0x67uy; 0x68uy; 0x69uy; 0x6auy; 0x6buy; 0x6cuy; 0x6duy; 0x6euy;
  0x68uy; 0x69uy; 0x6auy; 0x6buy; 0x6cuy; 0x6duy; 0x6euy; 0x6fuy;
  0x69uy; 0x6auy; 0x6buy; 0x6cuy; 0x6duy; 0x6euy; 0x6fuy; 0x70uy;
  0x6auy; 0x6buy; 0x6cuy; 0x6duy; 0x6euy; 0x6fuy; 0x70uy; 0x71uy;
  0x6buy; 0x6cuy; 0x6duy; 0x6euy; 0x6fuy; 0x70uy; 0x71uy; 0x72uy;
  0x6cuy; 0x6duy; 0x6euy; 0x6fuy; 0x70uy; 0x71uy; 0x72uy; 0x73uy;
  0x6duy; 0x6euy; 0x6fuy; 0x70uy; 0x71uy; 0x72uy; 0x73uy; 0x74uy;
  0x6euy; 0x6fuy; 0x70uy; 0x71uy; 0x72uy; 0x73uy; 0x74uy; 0x75uy
]

let test_expected4 = [
  0xcfuy; 0x5buy; 0x16uy; 0xa7uy; 0x78uy; 0xafuy; 0x83uy; 0x80uy;
  0x03uy; 0x6cuy; 0xe5uy; 0x9euy; 0x7buy; 0x04uy; 0x92uy; 0x37uy;
  0x0buy; 0x24uy; 0x9buy; 0x11uy; 0xe8uy; 0xf0uy; 0x7auy; 0x51uy;
  0xafuy; 0xacuy; 0x45uy; 0x03uy; 0x7auy; 0xfeuy; 0xe9uy; 0xd1uy
]

//
// Test 5
//

let test_expected5 = [
  0xcduy; 0xc7uy; 0x6euy; 0x5cuy; 0x99uy; 0x14uy; 0xfbuy; 0x92uy;
  0x81uy; 0xa1uy; 0xc7uy; 0xe2uy; 0x84uy; 0xd7uy; 0x3euy; 0x67uy;
  0xf1uy; 0x80uy; 0x9auy; 0x48uy; 0xa4uy; 0x97uy; 0x20uy; 0x0euy;
  0x04uy; 0x6duy; 0x39uy; 0xccuy; 0xc7uy; 0x11uy; 0x2cuy; 0xd0uy
]


//
// Main
//

let test () =
  assert_norm(List.Tot.length test_plaintext1 = 3);
  assert_norm(List.Tot.length test_expected1 = 32);
//  assert_norm(List.Tot.length test_plaintext2 = 0);
  assert_norm(List.Tot.length test_expected2 = 32);
  assert_norm(List.Tot.length test_plaintext3 = 56);
  assert_norm(List.Tot.length test_expected3 = 32);
  assert_norm(List.Tot.length test_plaintext4 = 112);
  assert_norm(List.Tot.length test_expected4 = 32);
  assert_norm(List.Tot.length test_expected5 = 32);
  let test_plaintext1 = createL test_plaintext1 in
  let test_expected1 = createL test_expected1 in
  let test_plaintext2 = createL test_plaintext2 in
  let test_expected2 = createL test_expected2 in
  let test_plaintext3 = createL test_plaintext3 in
  let test_expected3 = createL test_expected3 in
  let test_plaintext4 = createL test_plaintext4 in
  let test_expected4 = createL test_expected4 in
//  let test_plaintext5 = create 1000000 0x61uy in
//  let test_expected5 = createL test_expected5 in

  (hash test_plaintext1 = test_expected1) && 
  (hash test_plaintext2 = test_expected2) && 
  (hash test_plaintext3 = test_expected3) && 
  (hash test_plaintext4 = test_expected4)
//  (hash test_plaintext5 = test_expected5) && 

